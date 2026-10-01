-- =============================================================================
-- SKRIP MIGRASI DATABASE: demo_ocr_ktp
-- =============================================================================
-- Skrip ini membuat database `ocr_ktp` dan tabel `demo_ocr_ktp` sesuai struktur
-- pada phpMyAdmin:
-- 1. id          : INT AUTO_INCREMENT PRIMARY KEY
-- 2. nama        : LONGTEXT (Nama lengkap KTP)
-- 3. nik         : LONGTEXT (16 digit Nomor Induk Kependudukan)
-- 4. alamat      : LONGTEXT (Penggabungan nama jalan, RT/RW, kelurahan, kecamatan)
-- 5. foto_ktp    : LONGTEXT (Format Base64 Data URI)
-- 6. no_kavling  : VARCHAR(500) (Nomor kavling / blok tujuan)
-- 7. metadata    : JSON (TTL, jenis kelamin, agama, status, pekerjaan, dll)
-- 8. jam_masuk   : DATETIME (Waktu check-in)
-- 9. jam_keluar  : DATETIME (Waktu check-out)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `ocr_ktp`
CHARACTER SET utf8mb4 
COLLATE utf8mb4_general_ci;

USE `ocr_ktp`;

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
