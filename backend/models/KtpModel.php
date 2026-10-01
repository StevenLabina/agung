<?php
/**
 * =============================================================================
 * MODEL DATA KTP (TABEL: demo_ocr_ktp)
 * =============================================================================
 * File ini menangani seluruh interaksi CRUD (Create, Read, Update, Delete)
 * terhadap tabel `demo_ocr_ktp` menggunakan PDO Prepared Statements
 * untuk mencegah kerentanan SQL Injection.
 * 
 * Struktur Kolom Tabel:
 * - id          : INT (Auto Increment, Primary Key)
 * - nama        : LONGTEXT
 * - nik         : LONGTEXT
 * - alamat      : LONGTEXT (Gabungan jalan, RT/RW, kelurahan, kecamatan)
 * - foto_ktp    : LONGTEXT (Base64 Data URI foto KTP)
 * - no_kavling  : VARCHAR(500) (Nomor kavling / blok tujuan kunjungan)
 * - metadata    : JSON (Field tambahan seperti TTL, Agama, Pekerjaan, dll)
 * - jam_masuk   : DATETIME (Waktu check-in / masuk perumahan)
 * - jam_keluar  : DATETIME (Waktu check-out / keluar perumahan)
 * =============================================================================
 */

namespace Models;

use Config\Database;
use PDO;
use Exception;

class KtpModel
{
    /**
     * @var PDO $db Objek koneksi PDO
     */
    private PDO $db;

    /**
     * @var string $table Nama tabel database
     */
    private string $table = 'demo_ocr_ktp';

    /**
     * Constructor: Inisialisasi koneksi PDO ke database.
     */
    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    /**
     * Mengambil daftar seluruh rekaman data KTP dengan filter pencarian dan paginasi.
     *
     * @param string $search Kata kunci pencarian (nama, NIK, alamat, atau no_kavling)
     * @param int $limit Jumlah data per halaman (default: 50)
     * @param int $offset Offset data awal (default: 0)
     * @return array List data KTP
     */
    public function getAll(string $search = '', int $limit = 50, int $offset = 0): array
    {
        $sql = "SELECT id, nama, nik, alamat, foto_ktp, no_kavling, metadata, jam_masuk, jam_keluar 
                FROM {$this->table}";

        $params = [];

        if (!empty($search)) {
            $sql .= " WHERE (nama LIKE :s1 OR nik LIKE :s2 OR alamat LIKE :s3 OR no_kavling LIKE :s4)";
            $keyword = "%{$search}%";
            $params[':s1'] = $keyword;
            $params[':s2'] = $keyword;
            $params[':s3'] = $keyword;
            $params[':s4'] = $keyword;
        }

        $sql .= " ORDER BY id DESC LIMIT :limit OFFSET :offset";

        $stmt = $this->db->prepare($sql);

        // Bind nilai parameter
        foreach ($params as $param => $val) {
            $stmt->bindValue($param, $val, PDO::PARAM_STR);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);

        $stmt->execute();
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Parse kolom metadata dari JSON string ke PHP array
        foreach ($rows as &$row) {
            $row['metadata'] = $this->parseMetadata($row['metadata']);
        }

        return $rows;
    }

    /**
     * Menghitung total rekaman data KTP yang cocok dengan kata kunci pencarian.
     *
     * @param string $search Kata kunci pencarian
     * @return int Jumlah total baris
     */
    public function countAll(string $search = '', ?string $filterStatus = null): int
    {
        $sql = "SELECT COUNT(*) as total FROM {$this->table}";
        $params = [];
        $conditions = [];

        if (!empty($search)) {
            $conditions[] = "(nama LIKE :s1 OR nik LIKE :s2 OR alamat LIKE :s3 OR no_kavling LIKE :s4)";
            $keyword = "%{$search}%";
            $params[':s1'] = $keyword;
            $params[':s2'] = $keyword;
            $params[':s3'] = $keyword;
            $params[':s4'] = $keyword;
        }

        if ($filterStatus === 'masuk') {
            $conditions[] = "(jam_masuk IS NOT NULL AND jam_keluar IS NULL)";
        } elseif ($filterStatus === 'keluar') {
            $conditions[] = "(jam_keluar IS NOT NULL)";
        }

        if (!empty($conditions)) {
            $sql .= " WHERE " . implode(' AND ', $conditions);
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $res = $stmt->fetch(PDO::FETCH_ASSOC);
        return (int)($res['total'] ?? 0);
    }

    /**
     * Mengambil satu rekaman data KTP berdasarkan ID primary key.
     *
     * @param int $id ID data KTP
     * @return array|null Data rekaman KTP atau null jika tidak ditemukan
     */
    public function getById(int $id): ?array
    {
        $sql = "SELECT id, nama, nik, alamat, foto_ktp, no_kavling, metadata, jam_masuk, jam_keluar 
                FROM {$this->table} WHERE id = :id LIMIT 1";

        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':id', $id, PDO::PARAM_INT);
        $stmt->execute();

        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            return null;
        }

        $row['metadata'] = $this->parseMetadata($row['metadata']);
        return $row;
    }

    /**
     * Mencari rekaman data KTP berdasarkan 16 digit NIK.
     *
     * @param string $nik Nomor Induk Kependudukan
     * @return array|null Data KTP atau null jika belum pernah terdaftar
     */
    public function getByNik(string $nik): ?array
    {
        $sql = "SELECT id, nama, nik, alamat, foto_ktp, no_kavling, metadata, jam_masuk, jam_keluar 
                FROM {$this->table} WHERE nik = :nik ORDER BY id DESC LIMIT 1";

        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':nik', $nik, PDO::PARAM_STR);
        $stmt->execute();

        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            return null;
        }

        $row['metadata'] = $this->parseMetadata($row['metadata']);
        return $row;
    }

    /**
     * Menyimpan data KTP baru ke tabel demo_ocr_ktp.
     *
     * @param array $data Data field KTP:
     *                    - nama        : string|null
     *                    - nik         : string|null
     *                    - alamat      : string|null
     *                    - foto_ktp    : string|null (Base64)
     *                    - no_kavling  : string|null
     *                    - metadata    : array|string|null
     *                    - jam_masuk   : string|null (format Y-m-d H:i:s)
     *                    - jam_keluar  : string|null (format Y-m-d H:i:s)
     * @return int ID baris yang baru saja disisipkan (insert ID)
     * @throws Exception Jika proses query INSERT gagal
     */
    public function create(array $data): int
    {
        $sql = "INSERT INTO {$this->table} (nama, nik, alamat, foto_ktp, no_kavling, metadata, jam_masuk, jam_keluar) 
                VALUES (:nama, :nik, :alamat, :foto_ktp, :no_kavling, :metadata, :jam_masuk, :jam_keluar)";

        $stmt = $this->db->prepare($sql);

        // Format metadata ke JSON string
        $metadataJson = $this->formatMetadata($data['metadata'] ?? null);

        $stmt->bindValue(':nama', $data['nama'] ?? null, PDO::PARAM_STR);
        $stmt->bindValue(':nik', $data['nik'] ?? null, PDO::PARAM_STR);
        $stmt->bindValue(':alamat', $data['alamat'] ?? null, PDO::PARAM_STR);
        $stmt->bindValue(':foto_ktp', $data['foto_ktp'] ?? null, PDO::PARAM_STR);
        $stmt->bindValue(':no_kavling', $data['no_kavling'] ?? null, PDO::PARAM_STR);
        $stmt->bindValue(':metadata', $metadataJson, PDO::PARAM_STR);
        $stmt->bindValue(':jam_masuk', $data['jam_masuk'] ?? date('Y-m-d H:i:s'), PDO::PARAM_STR);
        $stmt->bindValue(':jam_keluar', $data['jam_keluar'] ?? null, PDO::PARAM_STR);

        $stmt->execute();

        return (int)$this->db->lastInsertId();
    }

    /**
     * Memperbarui data KTP yang sudah ada berdasarkan ID.
     *
     * @param int $id ID rekaman yang akan diperbarui
     * @param array $data Kolom-kolom yang ingin diubah
     * @return bool True jika berhasil diperbarui
     * @throws Exception Jika update gagal
     */
    public function update(int $id, array $data): bool
    {
        $allowedFields = ['nama', 'nik', 'alamat', 'foto_ktp', 'no_kavling', 'metadata', 'jam_masuk', 'jam_keluar'];
        $setClauses = [];
        $params = [':id' => $id];

        foreach ($allowedFields as $field) {
            if (array_key_exists($field, $data)) {
                $setClauses[] = "`{$field}` = :{$field}";
                if ($field === 'metadata') {
                    $params[":{$field}"] = $this->formatMetadata($data[$field]);
                } else {
                    $params[":{$field}"] = $data[$field];
                }
            }
        }

        if (empty($setClauses)) {
            return false; // Tidak ada kolom yang diperbarui
        }

        $sql = "UPDATE {$this->table} SET " . implode(', ', $setClauses) . " WHERE id = :id";
        $stmt = $this->db->prepare($sql);

        return $stmt->execute($params);
    }

    /**
     * Menghapus rekaman KTP berdasarkan ID.
     *
     * @param int $id ID data KTP
     * @return bool True jika berhasil dihapus
     */
    public function delete(int $id): bool
    {
        $sql = "DELETE FROM {$this->table} WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':id', $id, PDO::PARAM_INT);
        return $stmt->execute();
    }

    /**
     * Mencatat waktu keluar (checkout) untuk KTP / pengunjung.
     *
     * @param int $id ID data KTP
     * @param string|null $jamKeluar Waktu keluar (default: waktu sekarang)
     * @return bool True jika berhasil
     */
    public function recordCheckout(int $id, ?string $jamKeluar = null): bool
    {
        $time = $jamKeluar ?? date('Y-m-d H:i:s');
        $sql = "UPDATE {$this->table} SET jam_keluar = :jam_keluar WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':jam_keluar', $time, PDO::PARAM_STR);
        $stmt->bindValue(':id', $id, PDO::PARAM_INT);
        return $stmt->execute();
    }

    /**
     * Helper untuk memastikan nilai metadata disimpan dalam bentuk JSON string valid.
     *
     * @param mixed $metadata Array atau string JSON
     * @return string|null String JSON siap simpan ke database
     */
    private function formatMetadata(mixed $metadata): ?string
    {
        if ($metadata === null) {
            return null;
        }

        if (is_array($metadata)) {
            return json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        if (is_string($metadata)) {
            // Validasi apakah string merupakan JSON valid
            json_decode($metadata);
            if (json_last_error() === JSON_ERROR_NONE) {
                return $metadata;
            }
            return json_encode(['raw' => $metadata]);
        }

        return null;
    }

    /**
     * Helper untuk mengubah nilai JSON string dari database menjadi PHP array asosiatif.
     *
     * @param mixed $metadata Nilai kolom metadata dari DB
     * @return array|null Array metadata atau null
     */
    private function parseMetadata(mixed $metadata): ?array
    {
        if (empty($metadata)) {
            return null;
        }

        if (is_array($metadata)) {
            return $metadata;
        }

        $decoded = json_decode($metadata, true);
        return (json_last_error() === JSON_ERROR_NONE) ? $decoded : null;
    }
}
