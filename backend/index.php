<?php
/**
 * =============================================================================
 * FRONT CONTROLLER & API ROUTER UTAMA (BACKEND PHP)
 * =============================================================================
 * File ini merupakan gerbang utama (entry point) seluruh request HTTP ke backend.
 * 
 * Tugas Utama:
 * 1. Mengaktifkan class autoloader untuk seluruh modul backend (PSR-4 style).
 * 2. Mengaktifkan CORS (Cross-Origin Resource Sharing).
 * 3. Membaca URL path dan menentukan controller serta method yang harus dipanggil.
 * 4. Menangani error dan exception secara terpusat dalam format JSON.
 * =============================================================================
 */

// Aktifkan pelaporan error untuk kemudahan debugging
error_reporting(E_ALL);
ini_set('display_errors', '0'); // Sembunyikan output HTML error, kirim via JSON

// Set zona waktu default ke Waktu Indonesia Barat (WIB)
date_default_timezone_set('Asia/Jakarta');

/**
 * Autoloader Sederhana & Mandiri (Tanpa memerlukan Composer)
 */
spl_autoload_register(function ($class) {
    // Ubah namespace separator '\' menjadi direktori '/'
    $classPath = str_replace('\\', DIRECTORY_SEPARATOR, $class);
    $file = __DIR__ . DIRECTORY_SEPARATOR . $classPath . '.php';

    if (file_exists($file)) {
        require_once $file;
        return;
    }

    // Coba case-insensitive lookup untuk folder controllers/models/dsb
    $parts = explode(DIRECTORY_SEPARATOR, $classPath);
    if (count($parts) > 1) {
        $parts[0] = strtolower($parts[0]);
        $altFile = __DIR__ . DIRECTORY_SEPARATOR . implode(DIRECTORY_SEPARATOR, $parts) . '.php';
        if (file_exists($altFile)) {
            require_once $altFile;
        }
    }
});

use Helpers\ResponseHelper;
use Controllers\KtpController;
use Controllers\OcrController;
use Config\Database;

// Aktifkan CORS untuk seluruh request
ResponseHelper::enableCors();

// Tangkap seluruh uncaught exception dan kembalikan JSON
set_exception_handler(function ($exception) {
    ResponseHelper::error("Server Error: " . $exception->getMessage(), 500, [
        'file' => basename($exception->getFile()),
        'line' => $exception->getLine()
    ]);
});

/**
 * Ekstraksi Path Route URL
 * Mendukung Apache Rewrite, PHP Built-in Server, maupun parameter query ?route=...
 */
$requestUri = $_SERVER['REQUEST_URI'] ?? '/';
$scriptName = $_SERVER['SCRIPT_NAME'] ?? '';

// Hapus query string dari URI
$path = parse_url($requestUri, PHP_URL_PATH);

// Hapus prefix folder skrip jika ada (misal /agung/backend/index.php)
$scriptDir = dirname($scriptName);
if ($scriptDir !== '/' && str_starts_with($path, $scriptDir)) {
    $path = substr($path, strlen($scriptDir));
}
if (str_starts_with($path, '/index.php')) {
    $path = substr($path, strlen('/index.php'));
}

// Support fallback query string: ?route=/api/ktp
if (isset($_GET['route'])) {
    $path = '/' . ltrim($_GET['route'], '/');
}

// Normalisasi path
$path = '/' . trim($path, '/');
$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

// Support method overriding via Header X-HTTP-Method-Override atau parameter _method
if ($method === 'POST' && isset($_POST['_method'])) {
    $method = strtoupper($_POST['_method']);
} elseif ($method === 'POST' && isset($_SERVER['HTTP_X_HTTP_METHOD_OVERRIDE'])) {
    $method = strtoupper($_SERVER['HTTP_X_HTTP_METHOD_OVERRIDE']);
}

// =============================================================================
// ROUTING API RESTFUL
// =============================================================================

// 1. Frontend Demo Testing Dashboard
if ($path === '/demo' || $path === '/test' || $path === '/demo.html') {
    $demoFile = __DIR__ . '/demo.html';
    if (file_exists($demoFile)) {
        header('Content-Type: text/html; charset=utf-8');
        readfile($demoFile);
        exit(0);
    }
}

// 2. Root / Health Check
if ($path === '/' || $path === '') {
    ResponseHelper::success([
        'app_name'      => 'OCR KTP Backend Service',
        'version'       => '1.0.0',
        'status'        => 'Active & Ready',
        'server_time'   => date('Y-m-d H:i:s T'),
        'frontend_demo' => '/demo',
        'endpoints'     => [
            'GET /demo'                   => 'Frontend Dashboard Interaktif untuk pengujian KTP & CRUD',
            'POST /api/ocr/scan'          => 'Upload dan scan citra KTP via Python OCR & simpan ke DB',
            'GET /api/ktp'                => 'Daftar data KTP (paginasi & pencarian)',
            'GET /api/ktp/{id}'           => 'Detail data KTP berdasarkan ID',
            'POST /api/ktp'               => 'Tambah data KTP manual ke DB',
            'PUT /api/ktp/{id}'           => 'Update data KTP',
            'DELETE /api/ktp/{id}'        => 'Hapus data KTP',
            'POST /api/ktp/{id}/checkin'  => 'Catat waktu masuk (jam_masuk)',
            'POST /api/ktp/{id}/checkout' => 'Catat waktu keluar (jam_keluar)',
            'GET /api/setup'              => 'Cek database dan pastikan tabel demo_ocr_ktp tersedia'
        ]
    ], "Layanan API Backend OCR KTP siap digunakan. Buka /demo untuk antarmuka pengujian frontend.");
}

// 2. Setup Database & Inisialisasi Tabel
if ($path === '/api/setup' && $method === 'GET') {
    try {
        Database::createDatabaseIfNotExists();
        $pdo = Database::getConnection();
        $stmt = $pdo->query("SHOW TABLES LIKE 'demo_ocr_ktp'");
        $exists = $stmt->fetch();
        ResponseHelper::success([
            'database' => 'Terkoneksi',
            'table_demo_ocr_ktp' => $exists ? 'Tersedia' : 'Belum dibuat'
        ], "Database dan tabel demo_ocr_ktp siap digunakan.");
    } catch (Exception $e) {
        ResponseHelper::error("Inisialisasi database gagal: " . $e->getMessage(), 500);
    }
}

// 3. Scan OCR KTP
if ($path === '/api/ocr/scan' && $method === 'POST') {
    $controller = new OcrController();
    $controller->scan();
}

// 4. CRUD KTP: GET /api/ktp atau /ktp (List Data)
if (($path === '/api/ktp' || $path === '/ktp') && $method === 'GET') {
    $controller = new KtpController();
    $controller->index();
}

// 5. CRUD KTP: POST /api/ktp atau /ktp (Tambah Data Manual)
if (($path === '/api/ktp' || $path === '/ktp') && $method === 'POST') {
    $controller = new KtpController();
    $controller->store();
}

// 6. Routing dengan Parameter ID: /api/ktp/{id} atau /ktp/{id}
if (preg_match('#^/(?:api/)?ktp/([0-9]+)$#', $path, $matches)) {
    $id = (int)$matches[1];
    $controller = new KtpController();

    if ($method === 'GET') {
        $controller->show($id);
    } elseif ($method === 'PUT' || $method === 'PATCH') {
        $controller->update($id);
    } elseif ($method === 'DELETE') {
        $controller->destroy($id);
    } else {
        ResponseHelper::error("Metode HTTP {$method} tidak diizinkan untuk endpoint ini.", 405);
    }
}

// 7. Check-in Pengunjung: POST /api/ktp/{id}/checkin atau /ktp/{id}/checkin
if (preg_match('#^/(?:api/)?ktp/([0-9]+)/checkin$#', $path, $matches) && $method === 'POST') {
    $id = (int)$matches[1];
    $controller = new KtpController();
    $controller->checkin($id);
}

// 8. Check-out Pengunjung: POST /api/ktp/{id}/checkout atau /ktp/{id}/checkout
if (preg_match('#^/(?:api/)?ktp/([0-9]+)/checkout$#', $path, $matches) && $method === 'POST') {
    $id = (int)$matches[1];
    $controller = new KtpController();
    $controller->checkout($id);
}

// Jika route tidak ditemukan
ResponseHelper::notFound("Endpoint '{$method} {$path}' tidak ditemukan di server backend.");
