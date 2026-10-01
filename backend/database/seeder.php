<?php
/**
 * =============================================================================
 * SEEDER DATA CONTOH (DUMMY DATA) KTP
 * =============================================================================
 * Skrip ini berguna untuk mengisi data contoh KTP ke dalam tabel `demo_ocr_ktp`
 * agar frontend dapat langsung melakukan pengujian fitur tampilan list/CRUD.
 * 
 * Cara Menjalankan:
 * php backend/database/seeder.php
 * =============================================================================
 */

require_once dirname(__DIR__) . '/config/database.php';
require_once dirname(__DIR__) . '/models/KtpModel.php';

use Models\KtpModel;
use Config\Database;

try {
    echo "[SEEDER] Memulai inisialisasi tabel...\n";
    Database::createDatabaseIfNotExists();
    $model = new KtpModel();

    $dummyData = [
        [
            'nama'       => 'BUDI SANTOSO',
            'nik'        => '3578011508900001',
            'alamat'     => 'JL. MEDOKAN AYU NO. 45, RT/RW 008/001, KEL. MEDOKAN AYU, KEC. RUNGKUT',
            'foto_ktp'   => 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...',
            'no_kavling' => 'Blok A No. 12',
            'metadata'   => [
                'tempat_lahir'      => 'SURABAYA',
                'tanggal_lahir'     => '15-08-1990',
                'jenis_kelamin'     => 'Laki-laki',
                'golongan_darah'    => 'O',
                'agama'             => 'ISLAM',
                'status_perkawinan' => 'KAWIN',
                'pekerjaan'         => 'KARYAWAN SWASTA',
                'kewarganegaraan'   => 'WNI',
                'berlaku_hingga'    => 'SEUMUR HIDUP',
                'provinsi'          => 'PROVINSI JAWA TIMUR',
                'kabupaten_kota'    => 'KOTA SURABAYA',
                'confidence'        => 95.0,
                'ocr_engine'        => 'Tesseract OCR'
            ],
            'jam_masuk'  => date('Y-m-d H:i:s', strtotime('-2 hours')),
            'jam_keluar' => null
        ],
        [
            'nama'       => 'SITI NURHALIZA',
            'nik'        => '3578025503920002',
            'alamat'     => 'JL. SUTOREJO PRIMA UTARA NO. 8, RT/RW 003/009, KEL. DUKUH SUTOREJO, KEC. MULYOREJO',
            'foto_ktp'   => 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...',
            'no_kavling' => 'Blok B No. 05',
            'metadata'   => [
                'tempat_lahir'      => 'SURABAYA',
                'tanggal_lahir'     => '15-03-1992',
                'jenis_kelamin'     => 'Perempuan',
                'golongan_darah'    => 'A',
                'agama'             => 'ISLAM',
                'status_perkawinan' => 'BELUM KAWIN',
                'pekerjaan'         => 'WIRASWASTA',
                'kewarganegaraan'   => 'WNI',
                'berlaku_hingga'    => 'SEUMUR HIDUP',
                'provinsi'          => 'PROVINSI JAWA TIMUR',
                'kabupaten_kota'    => 'KOTA SURABAYA',
                'confidence'        => 92.5,
                'ocr_engine'        => 'PaddleOCR'
            ],
            'jam_masuk'  => date('Y-m-d H:i:s', strtotime('-5 hours')),
            'jam_keluar' => date('Y-m-d H:i:s', strtotime('-1 hour'))
        ]
    ];

    foreach ($dummyData as $row) {
        $insertedId = $model->create($row);
        echo "[SEEDER] Sukses menyisipkan data KTP: '{$row['nama']}' (ID: {$insertedId})\n";
    }

    echo "[SEEDER] Selesai! Data dummy berhasil disisipkan.\n";

} catch (Exception $e) {
    echo "[SEEDER ERROR] " . $e->getMessage() . "\n";
    exit(1);
}
