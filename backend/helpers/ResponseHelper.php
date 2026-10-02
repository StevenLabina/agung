<?php
/**
 * =============================================================================
 * HELPER FORMAT RESPONSE API JSON
 * =============================================================================
 * File ini menyediakan fungsi pembantu (helper) untuk menyeragamkan format respon
 * JSON dari seluruh endpoint backend yang akan dikonsumsi oleh frontend.
 * 
 * Standar format respon sukses:
 * {
 *   "success": true,
 *   "message": "Pesan status",
 *   "data": { ... }
 * }
 * 
 * Standar format respon error:
 * {
 *   "success": false,
 *   "message": "Pesan error",
 *   "errors": { ... }
 * }
 * =============================================================================
 */

namespace Helpers;

class ResponseHelper
{
    /**
     * Mengatur HTTP Header CORS (Cross-Origin Resource Sharing).
     * Memungkinkan API diakses secara aman dari frontend apapun (Flutter Web, Vue, React, Postman, dll).
     *
     * @return void
     */
    public static function enableCors(): void
    {
        // Izinkan semua domain origin mengakses API ini
        header("Access-Control-Allow-Origin: *");
        // Izinkan metode HTTP standar RESTful
        header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH");
        // Izinkan semua header (termasuk custom header dari browser)
        header("Access-Control-Allow-Headers: *");
        // Dukung Private Network Access (PNA) di Google Chrome (localhost <-> 127.0.0.1)
        header("Access-Control-Allow-Private-Network: true");
        // Waktu cache untuk preflight request (OPTIONS)
        header("Access-Control-Max-Age: 86400");

        // Tangani preflight OPTIONS request secara langsung
        if (isset($_SERVER['REQUEST_METHOD']) && strtoupper($_SERVER['REQUEST_METHOD']) === 'OPTIONS') {
            http_response_code(204);
            exit(0);
        }
    }

    /**
     * Mengirimkan respon data mentah dalam format JSON.
     *
     * @param mixed $payload Data yang akan dienkode ke JSON
     * @param int $statusCode HTTP status code (default: 200)
     * @return void
     */
    public static function json(mixed $payload, int $statusCode = 200): void
    {
        self::enableCors();
        http_response_code($statusCode);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit(0);
    }

    /**
     * Mengirimkan respon sukses berstandar seragam.
     *
     * @param mixed $data Data objek atau array hasil proses
     * @param string $message Pesan deskriptif hasil operasi
     * @param int $statusCode Kode status HTTP (default: 200 OK)
     * @return void
     */
    public static function success(mixed $data = null, string $message = 'Operasi berhasil', int $statusCode = 200): void
    {
        $response = [
            'success' => true,
            'message' => $message,
            'data'    => $data
        ];

        self::json($response, $statusCode);
    }

    /**
     * Mengirimkan respon error berstandar seragam.
     *
     * @param string $message Pesan kesalahan yang mudah dimengerti user
     * @param int $statusCode Kode status HTTP error (default: 400 Bad Request)
     * @param mixed $errors Detail error teknis atau array validasi field
     * @return void
     */
    public static function error(string $message = 'Terjadi kesalahan sistem', int $statusCode = 400, mixed $errors = null): void
    {
        $response = [
            'success' => false,
            'message' => $message
        ];

        if ($errors !== null) {
            $response['errors'] = $errors;
        }

        self::json($response, $statusCode);
    }

    /**
     * Mengirimkan respon data tidak ditemukan (404 Not Found).
     *
     * @param string $message Pesan item tidak ditemukan
     * @return void
     */
    public static function notFound(string $message = 'Data yang diminta tidak ditemukan'): void
    {
        self::error($message, 404);
    }
}
