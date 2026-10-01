<?php
/**
 * =============================================================================
 * CONTROLLER PROSES SCAN OCR KTP
 * =============================================================================
 * File ini menangani request pemindaian citra KTP dari frontend:
 * 1. Menerima file upload foto KTP (multipart/form-data) atau Base64 JSON.
 * 2. Memanggil ImageService untuk menyimpan file secara aman.
 * 3. Menjalankan OcrService yang memicu script Python OCR KTP.
 * 4. Mengambil data hasil pembacaan:
 *    - nama
 *    - nik
 *    - alamat (gabungan nama jalan, RT/RW, kelurahan/desa, kecamatan)
 *    - foto_ktp (Base64 Data URI)
 *    - metadata (JSON informasi pendukung)
 * 5. Menyimpan data langsung ke tabel `demo_ocr_ktp` (jika auto_save aktif).
 * 6. Mengembalikan output terstruktur dalam format JSON untuk langsung ditampilkan
 *    di antarmuka pengguna (frontend).
 * =============================================================================
 */

namespace Controllers;

use Services\ImageService;
use Services\OcrService;
use Models\KtpModel;
use Helpers\ResponseHelper;
use Exception;

class OcrController
{
    /**
     * @var ImageService $imageService Layanan pengelolaan citra
     */
    private ImageService $imageService;

    /**
     * @var OcrService $ocrService Layanan eksekusi OCR Python
     */
    private OcrService $ocrService;

    /**
     * @var KtpModel $ktpModel Model database demo_ocr_ktp
     */
    private KtpModel $ktpModel;

    /**
     * Constructor: Inisialisasi service dan model pendukung.
     */
    public function __construct()
    {
        $this->imageService = new ImageService();
        $this->ocrService   = new OcrService();
        $this->ktpModel     = new KtpModel();
    }

    /**
     * Endpoint: POST /api/ocr/scan
     * Memindai foto KTP, mengekstrak data, menyimpan ke database, dan mengembalikan JSON.
     *
     * Parameter Request (Form-data atau JSON):
     * - foto_ktp / image : File gambar (multipart) ATAU string Base64
     * - no_kavling       : (opsional) String nomor kavling tujuan kunjungan
     * - auto_save        : (opsional, default true) Apakah langsung disimpan ke DB
     *
     * @return void
     */
    public function scan(): void
    {
        try {
            // 1. Ambil data input (support multipart form-data & JSON payload)
            $input = $this->getRequestPayload();

            $fileData = $_FILES['foto_ktp'] ?? $_FILES['image'] ?? $_FILES['file'] ?? null;
            $base64String = $input['foto_ktp'] ?? $input['image_base64'] ?? $input['image'] ?? null;
            $noKavling = $input['no_kavling'] ?? $_POST['no_kavling'] ?? null;
            
            // Evaluasi opsi auto_save (default: true)
            $autoSaveParam = $input['auto_save'] ?? $_POST['auto_save'] ?? true;
            $isAutoSave = filter_var($autoSaveParam, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($isAutoSave === null) {
                $isAutoSave = true;
            }

            if ($fileData === null && empty($base64String)) {
                ResponseHelper::error("Foto KTP wajib diunggah (via multipart/form-data atau Base64).", 422);
                return;
            }

            // 2. Simpan gambar secara fisik ke storage dan dapatkan Base64 Data URI
            $imageResult = $this->imageService->processImage($fileData, $base64String);
            $filePath = $imageResult['file_path'];
            $base64Image = $imageResult['base64'];

            // 3. Jalankan OCR Python
            $ocrResult = $this->ocrService->scanKtp($filePath);

            $nama      = !empty($ocrResult['nama']) ? $ocrResult['nama'] : null;
            $nik       = !empty($ocrResult['nik']) ? $ocrResult['nik'] : null;
            $alamat    = !empty($ocrResult['alamat']) ? $ocrResult['alamat'] : null;
            $metadata  = !empty($ocrResult['metadata']) ? $ocrResult['metadata'] : [];
            $fotoKtpDb = $ocrResult['foto_ktp'] ?: $base64Image;

            $recordId = null;
            $savedRecord = null;
            $jamMasuk = date('Y-m-d H:i:s');

            // 4. Jika auto_save aktif, simpan data ke database tabel `demo_ocr_ktp`
            if ($isAutoSave) {
                $dataToInsert = [
                    'nama'       => $nama,
                    'nik'        => $nik,
                    'alamat'     => $alamat,
                    'foto_ktp'   => $fotoKtpDb,
                    'no_kavling' => $noKavling,
                    'metadata'   => $metadata,
                    'jam_masuk'  => $jamMasuk,
                    'jam_keluar' => null
                ];

                $recordId = $this->ktpModel->create($dataToInsert);
                $savedRecord = $this->ktpModel->getById($recordId);
            }

            // 5. Susun format JSON respon untuk frontend
            $responsePayload = [
                'id'         => $recordId,
                'nama'       => $nama,
                'nik'        => $nik,
                'alamat'     => $alamat,
                'foto_ktp'   => $fotoKtpDb,
                'no_kavling' => $noKavling,
                'metadata'   => $metadata,
                'jam_masuk'  => $jamMasuk,
                'jam_keluar' => null,
                'is_saved'   => $isAutoSave,
                'image_url'  => $imageResult['relative_path']
            ];

            // Jika berhasil disimpan, gunakan data dari database
            if ($savedRecord !== null) {
                $responsePayload['id'] = $savedRecord['id'];
                $responsePayload['jam_masuk'] = $savedRecord['jam_masuk'];
            }

            ResponseHelper::success(
                $responsePayload,
                $isAutoSave ? "KTP berhasil di-scan dan disimpan ke database." : "KTP berhasil di-scan (Mode Pratinjau).",
                $isAutoSave ? 201 : 200
            );

        } catch (Exception $e) {
            ResponseHelper::error("Gagal melakukan scan KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Membaca input body request baik berupa JSON maupun Form Data.
     *
     * @return array Array payload data
     */
    private function getRequestPayload(): array
    {
        $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

        if (str_contains($contentType, 'application/json')) {
            $rawInput = file_get_contents('php://input');
            $decoded = json_decode($rawInput, true);
            return is_array($decoded) ? $decoded : [];
        }

        return $_POST;
    }
}
