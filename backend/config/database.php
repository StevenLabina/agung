<?php
/**
 * =============================================================================
 * KONFIGURASI DAN KONEKSI DATABASE PDO (SINGLETON)
 * =============================================================================
 * File ini bertugas untuk mengelola koneksi ke database MySQL menggunakan
 * ekstensi PHP Data Objects (PDO) secara aman dan efisien.
 * 
 * Fitur:
 * - Singleton Pattern: Menjamin hanya ada 1 instance koneksi PDO selama request.
 * - Auto Setup: Otomatis mendeteksi dan membuat tabel `demo_ocr_ktp` jika belum ada.
 * - Konfigurasi dinamis: Membaca dari environment (.env) atau parameter default.
 * =============================================================================
 */

namespace Config;

use PDO;
use PDOException;
use Exception;

class Database
{
    /**
     * @var PDO|null $instance Menyimpan objek koneksi PDO tunggal
     */
    private static ?PDO $instance = null;

    /**
     * @var string $host Alamat host database (default: 127.0.0.1 / localhost)
     */
    private static string $host = '127.0.0.1';

    /**
     * @var int $port Port server MySQL (default: 3306)
     */
    private static int $port = 3306;

    /**
     * @var string $dbName Nama database MySQL yang digunakan
     */
    private static string $dbName = 'ocr_ktp';

    /**
     * @var string $username Pengguna database (default XAMPP: root)
     */
    private static string $username = 'root';

    /**
     * @var string $password Kata sandi pengguna database (default XAMPP: kosong)
     */
    private static string $password = '';

    /**
     * @var string $charset Karakter encoding database (utf8mb4 untuk kompatibilitas penuh teks KTP)
     */
    private static string $charset = 'utf8mb4';

    /**
     * Private constructor untuk mencegah instansiasi langsung dari luar (Singleton).
     */
    private function __construct() {}

    /**
     * Memuat konfigurasi dari file .env jika tersedia.
     *
     * @return void
     */
    public static function loadEnv(): void
    {
        $envPath = dirname(__DIR__) . '/.env';
        if (file_exists($envPath)) {
            $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line) || str_starts_with($line, '#')) {
                    continue;
                }
                [$key, $value] = explode('=', $line, 2);
                $key = trim($key);
                $value = trim($value, " \t\n\r\0\x0B\"'");
                putenv("$key=$value");
                $_ENV[$key] = $value;
            }
        }

        // Terapkan nilai konfigurasi jika ada di environment
        self::$host     = getenv('DB_HOST') ?: self::$host;
        self::$port     = (int)(getenv('DB_PORT') ?: self::$port);
        self::$dbName   = getenv('DB_NAME') ?: self::$dbName;
        self::$username = getenv('DB_USER') ?: self::$username;
        self::$password = getenv('DB_PASS') !== false ? getenv('DB_PASS') : self::$password;
    }

    /**
     * Mendapatkan koneksi PDO ke database.
     *
     * @return PDO Instance koneksi PDO yang aktif
     * @throws Exception Jika koneksi database gagal
     */
    public static function getConnection(): PDO
    {
        if (self::$instance === null) {
            self::loadEnv();

            try {
                // Buat DSN (Data Source Name)
                $dsn = sprintf(
                    'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                    self::$host,
                    self::$port,
                    self::$dbName,
                    self::$charset
                );

                // Opsi koneksi PDO
                $options = [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION, // Lempar exception saat terjadi error SQL
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,        // Ambil data dalam bentuk array asosiatif
                    PDO::ATTR_EMULATE_PREPARES   => false,                  // Gunakan native prepared statements
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES " . self::$charset // Pastikan charset UTF-8
                ];

                self::$instance = new PDO($dsn, self::$username, self::$password, $options);

            } catch (PDOException $e) {
                // Jika database belum ada, coba buat database dan tabel secara otomatis
                if ($e->getCode() == 1049) {
                    self::createDatabaseIfNotExists();
                    return self::getConnection();
                }

                throw new Exception("Koneksi Database Gagal: " . $e->getMessage(), (int)$e->getCode());
            }
        }

        return self::$instance;
    }

    /**
     * Membuat database dan tabel `demo_ocr_ktp` jika belum tersedia di server MySQL.
     * Memastikan backend dapat langsung dijalankan tanpa perlu setup manual di phpMyAdmin.
     *
     * @return void
     * @throws Exception Jika pembuatan database/tabel gagal
     */
    public static function createDatabaseIfNotExists(): void
    {
        try {
            // Hubungkan ke server MySQL tanpa memilih database
            $serverDsn = sprintf('mysql:host=%s;port=%d;charset=%s', self::$host, self::$port, self::$charset);
            $pdoServer = new PDO($serverDsn, self::$username, self::$password, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
            ]);

            // 1. Buat Database
            $createDbSql = sprintf(
                "CREATE DATABASE IF NOT EXISTS `%s` CHARACTER SET %s COLLATE utf8mb4_general_ci;",
                self::$dbName,
                self::$charset
            );
            $pdoServer->exec($createDbSql);

            // 2. Hubungkan ke database yang baru dibuat
            $pdoServer->exec(sprintf("USE `%s`;", self::$dbName));

            // 3. Buat Tabel demo_ocr_ktp sesuai struktur yang diminta
            $createTableSql = "
                CREATE TABLE IF NOT EXISTS `demo_ocr_ktp` (
                    `id` INT NOT NULL AUTO_INCREMENT,
                    `nama` LONGTEXT NULL,
                    `nik` LONGTEXT NULL,
                    `alamat` LONGTEXT NULL,
                    `foto_ktp` LONGTEXT NULL,
                    `no_kavling` VARCHAR(500) NULL,
                    `metadata` JSON NULL,
                    `jam_masuk` DATETIME NULL,
                    `jam_keluar` DATETIME NULL,
                    PRIMARY KEY (`id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
            ";
            $pdoServer->exec($createTableSql);

        } catch (PDOException $e) {
            throw new Exception("Inisialisasi Database Otomatis Gagal: " . $e->getMessage());
        }
    }
}
