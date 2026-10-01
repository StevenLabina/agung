<?php
/**
 * =============================================================================
 * SERVICE PENGELOLAAN CITRA / GAMBAR KTP
 * =============================================================================
 * File ini bertugas untuk menangani pemrosesan file gambar foto KTP:
 * 1. Menerima file upload (multipart/form-data) atau Base64 string dari frontend.
 * 2. Memvalidasi tipe MIME dan ekstensi gambar (JPG, JPEG, PNG, WEBP).
 * 3. Menyimpan file fisik ke folder penyimpanan (backend/storage/uploads).
 * 4. Mengonversi citra menjadi format Base64 Data URI untuk disimpan pada kolom
 *    `foto_ktp` (longtext) di tabel database `demo_ocr_ktp`.
 * =============================================================================
 */

namespace Services;

use Exception;

class ImageService
{
    /**
     * @var string $uploadDir Direktori absolut untuk menyimpan file gambar yang diupload
     */
    private string $uploadDir;

    /**
     * @var array $allowedMimes Daftar tipe MIME gambar yang diperbolehkan
     */
    private array $allowedMimes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp'
    ];

    /**
     * Constructor: Menyiapkan folder penyimpanan fisik jika belum ada.
     */
    public function __construct()
    {
        $this->uploadDir = dirname(__DIR__) . '/storage/uploads';
        if (!file_exists($this->uploadDir)) {
            mkdir($this->uploadDir, 0755, true);
        }
    }

    /**
     * Memproses file gambar dari $_FILES (multipart/form-data)
     * atau dari Base64 string yang dikirimkan oleh frontend.
     *
     * @param array|null $fileData Array data dari $_FILES['foto_ktp']
     * @param string|null $base64String String base64 (opsional jika upload via JSON)
     * @return array Array berisi:
     *               - 'file_path' : Path absolut file yang disimpan
     *               - 'relative_path': Path relatif file (contoh: storage/uploads/ktp_123.jpg)
     *               - 'base64'    : Data URI base64 lengkap untuk database
     * @throws Exception Jika validasi file gagal
     */
    public function processImage(?array $fileData = null, ?string $base64String = null): array
    {
        // 1. Prioritaskan file upload dari multipart form-data
        if ($fileData !== null && isset($fileData['tmp_name']) && is_uploaded_file($fileData['tmp_name'])) {
            return $this->handleUploadedFile($fileData);
        }

        // 2. Jika tidak ada file upload, periksa apakah ada base64 string
        if (!empty($base64String)) {
            return $this->handleBase64String($base64String);
        }

        throw new Exception("Tidak ada file gambar foto KTP yang diunggah.");
    }

    /**
     * Menangani file upload dari $_FILES.
     *
     * @param array $file Array file dari $_FILES
     * @return array Informasi file yang tersimpan dan representasi Base64
     * @throws Exception Jika file tidak valid atau melebihi batas ukuran
     */
    private function handleUploadedFile(array $file): array
    {
        if ($file['error'] !== UPLOAD_ERR_OK) {
            throw new Exception("Gagal mengunggah file. Error code: " . $file['error']);
        }

        // Validasi ukuran file (maksimal 10 MB)
        $maxSizeBytes = 10 * 1024 * 1024;
        if ($file['size'] > $maxSizeBytes) {
            throw new Exception("Ukuran file terlalu besar. Maksimal 10 MB.");
        }

        // Validasi tipe MIME menggunakan finfo
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);

        if (!in_array($mimeType, $this->allowedMimes)) {
            throw new Exception("Format gambar tidak didukung: {$mimeType}. Gunakan JPG, PNG, atau WEBP.");
        }

        // Tentukan ekstensi
        $ext = match ($mimeType) {
            'image/png'  => 'png',
            'image/webp' => 'webp',
            default      => 'jpg'
        };

        // Buat nama file unik dengan timestamp & random string
        $filename = 'ktp_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
        $targetPath = $this->uploadDir . '/' . $filename;

        // Pindahkan file dari temp ke folder storage uploads
        if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
            throw new Exception("Gagal memindahkan file yang diunggah ke folder penyimpanan.");
        }

        // Konversi isi file ke Base64 Data URI
        $fileContents = file_get_contents($targetPath);
        $base64Data = "data:{$mimeType};base64," . base64_encode($fileContents);

        return [
            'file_path'     => $targetPath,
            'relative_path' => 'storage/uploads/' . $filename,
            'base64'        => $base64Data
        ];
    }

    /**
     * Menangani input gambar berupa string Base64 dari frontend.
     *
     * @param string $base64String String Base64 gambar
     * @return array Informasi file yang tersimpan dan representasi Base64
     * @throws Exception Jika decode base64 gagal
     */
    private function handleBase64String(string $base64String): array
    {
        $mimeType = 'image/jpeg';
        $ext = 'jpg';

        // Deteksi header Data URI jika ada (contoh: data:image/png;base64,...)
        if (preg_match('/^data:(image\/[a-zA-Z0-9\+\-]+);base64,(.+)$/', $base64String, $matches)) {
            $mimeType = $matches[1];
            $rawData = base64_decode($matches[2]);
            $ext = match ($mimeType) {
                'image/png'  => 'png',
                'image/webp' => 'webp',
                default      => 'jpg'
            };
        } else {
            // Raw base64 tanpa header Data URI
            $rawData = base64_decode($base64String);
        }

        if ($rawData === false || strlen($rawData) === 0) {
            throw new Exception("Format Base64 gambar KTP tidak valid.");
        }

        $filename = 'ktp_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
        $targetPath = $this->uploadDir . '/' . $filename;

        if (file_put_contents($targetPath, $rawData) === false) {
            throw new Exception("Gagal menyimpan citra base64 ke disk.");
        }

        $formattedBase64 = str_starts_with($base64String, 'data:image')
            ? $base64String
            : "data:{$mimeType};base64," . base64_encode($rawData);

        return [
            'file_path'     => $targetPath,
            'relative_path' => 'storage/uploads/' . $filename,
            'base64'        => $formattedBase64
        ];
    }
}
