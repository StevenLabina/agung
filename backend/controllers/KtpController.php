<?php
/**
 * =============================================================================
 * CONTROLLER CRUD KTP (TABEL: demo_ocr_ktp)
 * =============================================================================
 * File ini menangani seluruh endpoint CRUD RESTful untuk entitas KTP:
 * 1. GET    /api/ktp          : Mengambil daftar KTP (dengan filter & paginasi)
 * 2. GET    /api/ktp/{id}     : Mengambil detail satu KTP berdasarkan ID
 * 3. POST   /api/ktp          : Menyimpan data KTP baru secara manual
 * 4. PUT    /api/ktp/{id}     : Memperbarui data KTP yang sudah ada
 * 5. DELETE /api/ktp/{id}     : Menghapus data KTP berdasarkan ID
 * 6. POST   /api/ktp/{id}/checkin  : Mencatat waktu jam_masuk pengunjung
 * 7. POST   /api/ktp/{id}/checkout : Mencatat waktu jam_keluar pengunjung
 * =============================================================================
 */

namespace Controllers;

use Models\KtpModel;
use Helpers\ResponseHelper;
use Exception;

class KtpController
{
    /**
     * @var KtpModel $model Model KTP untuk query database
     */
    private KtpModel $model;

    /**
     * Constructor: Inisialisasi KtpModel.
     */
    public function __construct()
    {
        $this->model = new KtpModel();
    }

    /**
     * Mengambil daftar data KTP dengan fitur pencarian dan paginasi.
     * Endpoint: GET /api/ktp?search=budi&page=1&limit=20&status=masuk
     *
     * @return void
     */
    public function index(): void
    {
        try {
            $search = isset($_GET['search']) ? trim($_GET['search']) : '';
            $page   = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
            $limit  = isset($_GET['limit']) ? max(1, min(100, (int)$_GET['limit'])) : 20;
            $status = isset($_GET['status']) ? trim($_GET['status']) : null; // 'masuk' atau 'keluar'

            $offset = ($page - 1) * $limit;

            $items = $this->model->getAll($search, $limit, $offset);
            $total = $this->model->countAll($search, $status);
            $totalPages = ceil($total / $limit);

            $data = [
                'items' => $items,
                'pagination' => [
                    'current_page' => $page,
                    'per_page'     => $limit,
                    'total_items'  => $total,
                    'total_pages'  => (int)$totalPages
                ]
            ];

            ResponseHelper::success($data, "Daftar data KTP berhasil diambil.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal mengambil data KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Mengambil data detail satu KTP berdasarkan ID.
     * Endpoint: GET /api/ktp/{id}
     *
     * @param int $id ID data KTP
     * @return void
     */
    public function show(int $id): void
    {
        try {
            $ktp = $this->model->getById($id);

            if (!$ktp) {
                ResponseHelper::notFound("Data KTP dengan ID {$id} tidak ditemukan.");
                return;
            }

            ResponseHelper::success($ktp, "Data KTP berhasil ditemukan.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal mengambil detail KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Menambahkan data KTP baru secara manual.
     * Endpoint: POST /api/ktp
     *
     * @return void
     */
    public function store(): void
    {
        try {
            $payload = $this->getRequestPayload();

            if (empty($payload['nama']) && empty($payload['nik'])) {
                ResponseHelper::error("Nama atau NIK wajib diisi.", 422);
                return;
            }

            $newId = $this->model->create([
                'nama'       => $payload['nama'] ?? null,
                'nik'        => $payload['nik'] ?? null,
                'alamat'     => $payload['alamat'] ?? null,
                'foto_ktp'   => $payload['foto_ktp'] ?? null,
                'no_kavling' => $payload['no_kavling'] ?? null,
                'metadata'   => $payload['metadata'] ?? null,
                'jam_masuk'  => $payload['jam_masuk'] ?? date('Y-m-d H:i:s'),
                'jam_keluar' => $payload['jam_keluar'] ?? null
            ]);

            $created = $this->model->getById($newId);
            ResponseHelper::success($created, "Data KTP berhasil ditambahkan.", 201);
        } catch (Exception $e) {
            ResponseHelper::error("Gagal menambahkan data KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Memperbarui data KTP yang sudah ada.
     * Endpoint: PUT /api/ktp/{id}
     *
     * @param int $id ID KTP yang akan diupdate
     * @return void
     */
    public function update(int $id): void
    {
        try {
            $existing = $this->model->getById($id);
            if (!$existing) {
                ResponseHelper::notFound("Data KTP dengan ID {$id} tidak ditemukan.");
                return;
            }

            $payload = $this->getRequestPayload();
            if (empty($payload)) {
                ResponseHelper::error("Tidak ada data yang dikirim untuk diperbarui.", 422);
                return;
            }

            $this->model->update($id, $payload);
            $updated = $this->model->getById($id);

            ResponseHelper::success($updated, "Data KTP berhasil diperbarui.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal memperbarui data KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Menghapus rekaman KTP.
     * Endpoint: DELETE /api/ktp/{id}
     *
     * @param int $id ID KTP yang akan dihapus
     * @return void
     */
    public function destroy(int $id): void
    {
        try {
            $existing = $this->model->getById($id);
            if (!$existing) {
                ResponseHelper::notFound("Data KTP dengan ID {$id} tidak ditemukan.");
                return;
            }

            $this->model->delete($id);
            ResponseHelper::success(['id' => $id], "Data KTP berhasil dihapus.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal menghapus data KTP: " . $e->getMessage(), 500);
        }
    }

    /**
     * Mencatat jam masuk (check-in) untuk KTP / pengunjung.
     * Endpoint: POST /api/ktp/{id}/checkin
     *
     * @param int $id ID KTP
     * @return void
     */
    public function checkin(int $id): void
    {
        try {
            $existing = $this->model->getById($id);
            if (!$existing) {
                ResponseHelper::notFound("Data KTP tidak ditemukan.");
                return;
            }

            $payload = $this->getRequestPayload();
            $jamMasuk = $payload['jam_masuk'] ?? date('Y-m-d H:i:s');

            $this->model->update($id, ['jam_masuk' => $jamMasuk]);
            $updated = $this->model->getById($id);

            ResponseHelper::success($updated, "Waktu masuk berhasil dicatat.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal mencatat checkin: " . $e->getMessage(), 500);
        }
    }

    /**
     * Mencatat jam keluar (check-out) untuk KTP / pengunjung.
     * Endpoint: POST /api/ktp/{id}/checkout
     *
     * @param int $id ID KTP
     * @return void
     */
    public function checkout(int $id): void
    {
        try {
            $existing = $this->model->getById($id);
            if (!$existing) {
                ResponseHelper::notFound("Data KTP tidak ditemukan.");
                return;
            }

            $payload = $this->getRequestPayload();
            $jamKeluar = $payload['jam_keluar'] ?? date('Y-m-d H:i:s');

            $this->model->recordCheckout($id, $jamKeluar);
            $updated = $this->model->getById($id);

            ResponseHelper::success($updated, "Waktu keluar berhasil dicatat.");
        } catch (Exception $e) {
            ResponseHelper::error("Gagal mencatat checkout: " . $e->getMessage(), 500);
        }
    }

    /**
     * Membaca isi request payload (JSON / Form).
     *
     * @return array
     */
    private function getRequestPayload(): array
    {
        $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

        if (str_contains($contentType, 'application/json')) {
            $raw = file_get_contents('php://input');
            $data = json_decode($raw, true);
            return is_array($data) ? $data : [];
        }

        // Support PUT dengan form-urlencoded
        if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
            parse_str(file_get_contents('php://input'), $putData);
            return is_array($putData) ? $putData : [];
        }

        return $_POST;
    }
}
