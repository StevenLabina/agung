# Dokumentasi Backend Service OCR KTP & Akses Perumahan

Backend RESTful API modular berbasis **PHP (Native Modern)** dan **Python OCR** untuk pemindaian otomatis Kartu Tanda Penduduk (KTP) Indonesia, penyimpanan ke basis data MySQL (tabel `demo_ocr_ktp`), serta pengelolaan data CRUD lengkap (Check-in/Check-out pengunjung).

---

## 📌 Daftar Isi
1. [Arsitektur & Struktur Direktori](#-arsitektur--struktur-direktori)
2. [Struktur Tabel Database (`demo_ocr_ktp`)](#-struktur-tabel-database-demo_ocr_ktp)
3. [Alur Pemrosesan OCR KTP](#-alur-pemrosesan-ocr-ktp)
4. [Petunjuk Konfigurasi & Cara Menjalankan](#-petunjuk-konfigurasi--cara-menjalankan)
5. [Dokumentasi API Endpoints](#-dokumentasi-api-endpoints)
   - [1. Scan OCR KTP (`POST /api/ocr/scan`)](#1-scan-ocr-ktp-post-apiocrscan)
   - [2. Ambil Semua Data KTP (`GET /api/ktp`)](#2-ambil-semua-data-ktp-get-apiktp)
   - [3. Ambil Detail KTP (`GET /api/ktp/{id}`)](#3-ambil-detail-ktp-get-apiktpid)
   - [4. Tambah Data KTP Manual (`POST /api/ktp`)](#4-tambah-data-ktp-manual-post-apiktp)
   - [5. Update Data KTP (`PUT /api/ktp/{id}`)](#5-update-data-ktp-put-apiktpid)
   - [6. Hapus Data KTP (`DELETE /api/ktp/{id}`)](#6-hapus-data-ktp-delete-apiktpid)
   - [7. Check-in Pengunjung (`POST /api/ktp/{id}/checkin`)](#7-check-in-pengunjung-post-apiktpidcheckin)
   - [8. Check-out Pengunjung (`POST /api/ktp/{id}/checkout`)](#8-check-out-pengunjung-post-apiktpidcheckout)
   - [9. Setup & Cek Database (`GET /api/setup`)](#9-setup--cek-database-get-apisetup)
6. [Penjelasan Modul, Class, & Function](#-penjelasan-modul-class--function)

---

## 🏗 Arsitektur & Struktur Direktori

Backend dirancang dengan pola **Modular Service-Repository** yang memisahkan logika routing, kontroler, layanan bisnis, manipulasi database, dan format respon secara independen:

```
backend/
├── .env.example                # Template konfigurasi environment
├── .env                        # Konfigurasi aktif (Host, Port, User DB, dll)
├── .htaccess                   # Rewrite rule untuk web server Apache
├── index.php                   # Front Controller & REST Router utama
├── config/
│   └── database.php            # Singleton PDO Connection & Auto-Setup DB
├── controllers/
│   ├── KtpController.php       # Controller CRUD data KTP (Index, Show, Store, Update, Delete)
│   └── OcrController.php       # Controller penerima upload gambar & pemroses scan OCR
├── models/
│   └── KtpModel.php            # Model PDO Prepared Statements untuk tabel demo_ocr_ktp
├── services/
│   ├── OcrService.php          # Service integrasi proses Python OCR (proc_open)
│   └── ImageService.php        # Service handling file upload dan konversi Base64 Data URI
├── helpers/
│   └── ResponseHelper.php      # Helper standarisasi respon JSON & CORS headers
├── database/
│   ├── migration.sql           # Skrip DDL MySQL pembuatan tabel demo_ocr_ktp
│   └── seeder.php              # Skrip pengisian data awal dummy
└── storage/
    └── uploads/                # Direktori penyimpanan fisik file foto KTP
```

---

## 🗄 Struktur Tabel Database (`demo_ocr_ktp`)

Sesuai rancangan pada phpMyAdmin:

| # | Nama Kolom | Tipe Data | Nullable | Keterangan |
|---|---|---|---|---|
| 1 | `id` | `INT AUTO_INCREMENT` | NO | Primary Key |
| 2 | `nama` | `LONGTEXT` | YES | Nama lengkap pemilik KTP (dibersihkan dari noise/angka) |
| 3 | `nik` | `LONGTEXT` | YES | 16 digit Nomor Induk Kependudukan |
| 4 | `alamat` | `LONGTEXT` | YES | **Penggabungan** nama jalan, RT/RW, kelurahan, dan kecamatan |
| 5 | `foto_ktp` | `LONGTEXT` | YES | Citra foto KTP dalam format **Base64 Data URI** |
| 6 | `no_kavling` | `VARCHAR(500)` | YES | Nomor kavling/rumah tujuan kunjungan |
| 7 | `metadata` | `JSON` | YES | Seluruh data pendukung lainnya (TTL, Agama, Pekerjaan, dll) |
| 8 | `jam_masuk` | `DATETIME` | YES | Waktu check-in / masuk perumahan |
| 9 | `jam_keluar` | `DATETIME` | YES | Waktu check-out / keluar perumahan |

---

## 🔍 Alur Pemrosesan OCR KTP

1. **Frontend**: Pengguna mengunggah foto KTP melalui antarmuka web/mobile (via `multipart/form-data` atau Base64 JSON).
2. **ImageService**: Memvalidasi MIME type gambar, menyimpan file fisik ke `backend/storage/uploads/`, dan mengonversi ke format `data:image/jpeg;base64,...`.
3. **OcrService**: Menjalankan subprocess Python (`OCR-Script/ktp_quick_scan.py`).
4. **Python OCR Engine**:
   - Melakukan pra-pengolahan citra (CLAHE, kontras lokal, penskalaan dimensi).
   - Menjalankan deteksi teks (PaddleOCR jika tersedia, atau fallback otomatis ke Tesseract OCR).
   - Mengekstrak data utama:
     - `nama`: Sanitasi string dari label sistem.
     - `nik`: Ekstraksi 16 digit angka dengan decoding otomatis tanggal lahir & gender.
     - `alamat`: Menggabungkan secara otomatis jalan, RT/RW, kelurahan/desa, dan kecamatan.
     - `metadata`: Memasukkan data sisanya (TTL, jenis kelamin, golongan darah, agama, status perkawinan, pekerjaan, kewarganegaraan, masa berlaku, provinsi, kabupaten/kota) ke dalam dictionary JSON.
5. **KtpModel**: Jika opsi `auto_save=true` (default), data langsung disisipkan ke tabel `demo_ocr_ktp` dengan `jam_masuk = NOW()`.
6. **ResponseHelper**: Mengembalikan respon JSON terstruktur dan siap ditampilkan langsung di layar frontend.

---

## ⚙️ Petunjuk Konfigurasi & Cara Menjalankan

### 1. Konfigurasi Environment (`.env`)
Salin file `.env.example` menjadi `.env` lalu sesuaikan kredensial MySQL Anda:
```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=ocr_ktp
DB_USER=root
DB_PASS=

# Path eksekusi Python (opsional)
PYTHON_PATH=py
```

### 2. Inisialisasi Database
Jalankan inisialisasi tabel otomatis melalui browser/cURL atau seeder CLI:
```bash
# Opsi 1: Melalui CLI Seeder
php backend/database/seeder.php

# Opsi 2: Melalui file SQL di phpMyAdmin
Import file backend/database/migration.sql
```

### 3. Menjalankan Server Backend
#### Menggunakan Apache / XAMPP:
Pastikan folder proyek berada di dalam direktori `htdocs` (misal: `C:\xampp\htdocs\agung\backend`). Akses melalui:
`http://localhost/agung/backend/`

#### Menggunakan PHP Built-in Server:
Jalankan perintah berikut di terminal:
```bash
cd backend
php -S 127.0.0.1:8000
```
Server akan aktif di `http://127.0.0.1:8000/`.

---

## 📡 Dokumentasi API Endpoints

### 1. Scan OCR KTP (`POST /api/ocr/scan`)
Memindai foto KTP, mengekstrak data identitas, menyimpannya ke database, dan mengembalikan data JSON.

**Metode**: `POST`  
**Content-Type**: `multipart/form-data` atau `application/json`

**Parameter**:
| Parameter | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `foto_ktp` / `image` | File / String Base64 | Ya | File gambar citra KTP atau string Base64 |
| `no_kavling` | String | Tidak | *(Opsional)* Nomor kavling tujuan. Dapat dikosongkan saat scan dan diisi kemudian dari frontend melalui `PUT /api/ktp/{id}` |
| `auto_save` | Boolean | Tidak | Default `true`. Jika `true`, otomatis simpan ke DB |

> **Catatan Alur Nomor Kavling**: Fisik kartu KTP tidak memuat nomor kavling. Oleh karena itu, endpoint OCR fokus mengekstrak data identitas KTP. Nomor kavling dapat diinput secara terpisah oleh petugas di antarmuka frontend, lalu disimpan ke database via endpoint `PUT /api/ktp/{id}` (dengan body `{"no_kavling": "Blok A No. 12"}`).

**Contoh cURL (Hanya Kirim Foto KTP)**:
```bash
curl -X POST "http://127.0.0.1:8000/api/ocr/scan" \
  -F "foto_ktp=@/path/to/ktp.jpg"
```

**Contoh Respon JSON (HTTP 201 Created)**:
```json
{
  "success": true,
  "message": "KTP berhasil di-scan dan disimpan ke database.",
  "data": {
    "id": 1,
    "nama": "BUDI SANTOSO",
    "nik": "3578011508900001",
    "alamat": "JL. MEDOKAN AYU NO. 45, RT/RW 008/001, KEL. MEDOKAN AYU, KEC. RUNGKUT",
    "foto_ktp": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ...",
    "no_kavling": "Blok B No. 04",
    "metadata": {
      "tempat_lahir": "SURABAYA",
      "tanggal_lahir": "15-08-1990",
      "jenis_kelamin": "Laki-laki",
      "golongan_darah": "O",
      "agama": "ISLAM",
      "status_perkawinan": "KAWIN",
      "pekerjaan": "KARYAWAN SWASTA",
      "kewarganegaraan": "WNI",
      "berlaku_hingga": "SEUMUR HIDUP",
      "provinsi": "PROVINSI JAWA TIMUR",
      "kabupaten_kota": "KOTA SURABAYA",
      "detail_alamat": {
        "jalan": "JL. MEDOKAN AYU NO. 45",
        "rt_rw": "008/001",
        "kel_desa": "MEDOKAN AYU",
        "kecamatan": "RUNGKUT"
      },
      "confidence": 94.5,
      "ocr_engine": "Tesseract OCR"
    },
    "jam_masuk": "2026-10-01 08:30:00",
    "jam_keluar": null,
    "is_saved": true,
    "image_url": "storage/uploads/ktp_20261001_083000_1a2b3c.jpg"
  }
}
```

---

### 2. Ambil Semua Data KTP (`GET /api/ktp`)
Mengambil daftar rekaman KTP dengan dukungan filter pencarian dan paginasi.

**Parameter Query**:
- `search` (opsional): Pencarian berdasarkan nama, NIK, alamat, atau no_kavling.
- `page` (opsional, default: 1): Halaman data.
- `limit` (opsional, default: 20): Jumlah item per halaman.
- `status` (opsional): Filter status pengunjung: `masuk` (belum keluar) atau `keluar`.

**Contoh Request**:
`GET /api/ktp?search=Budi&page=1&limit=10`

---

### 3. Ambil Detail KTP (`GET /api/ktp/{id}`)
Mengambil detail satu rekaman KTP berdasarkan ID primary key.

**Contoh Request**:
`GET /api/ktp/1`

---

### 4. Tambah Data KTP Manual (`POST /api/ktp`)
Menambahkan data KTP secara manual tanpa proses OCR.

**Content-Type**: `application/json`  
**Body JSON**:
```json
{
  "nama": "AHMAD WAHYUDI",
  "nik": "3578012010850003",
  "alamat": "JL. RUNGKUT INDUSTRI NO. 10, RT/RW 002/003, KEL. KENDANGSARI, KEC. TENGGILIS MEJOYO",
  "foto_ktp": "data:image/jpeg;base64,...",
  "no_kavling": "Blok A No. 01",
  "metadata": {
    "tempat_lahir": "SURABAYA",
    "tanggal_lahir": "20-10-1985",
    "jenis_kelamin": "Laki-laki",
    "agama": "ISLAM"
  },
  "jam_masuk": "2026-10-01 09:00:00"
}
```

---

### 5. Update Data KTP (`PUT /api/ktp/{id}`)
Memperbarui kolom pada rekaman KTP yang sudah tersimpan.

**Contoh Body JSON**:
```json
{
  "no_kavling": "Blok A No. 08",
  "alamat": "JL. MEDOKAN AYU BARAT NO. 2"
}
```

---

### 6. Hapus Data KTP (`DELETE /api/ktp/{id}`)
Menghapus rekaman KTP dari database berdasarkan ID.

---

### 7. Check-in Pengunjung (`POST /api/ktp/{id}/checkin`)
Mencatat atau memperbarui waktu `jam_masuk` menjadi waktu sekarang.

---

### 8. Check-out Pengunjung (`POST /api/ktp/{id}/checkout`)
Mencatat waktu `jam_keluar` pengunjung.

---

### 9. Setup & Cek Database (`GET /api/setup`)
Memeriksa status koneksi database MySQL dan memastikan tabel `demo_ocr_ktp` sudah siap digunakan.

---

## 🧩 Penjelasan Modul, Class, & Function

### 1. `Config\Database` (`config/database.php`)
- `getConnection(): PDO`  
  Mengembalikan koneksi PDO tunggal (Singleton) dengan konfigurasi `ERRMODE_EXCEPTION`, `FETCH_ASSOC`, dan encoding `utf8mb4`.
- `createDatabaseIfNotExists(): void`  
  Otomatis membuat database dan tabel `demo_ocr_ktp` bila belum tersedia di MySQL.

### 2. `Helpers\ResponseHelper` (`helpers/ResponseHelper.php`)
- `enableCors(): void`  
  Mengirimkan header HTTP `Access-Control-Allow-Origin: *` dan menangani preflight request `OPTIONS`.
- `success($data, $message, $statusCode)`  
  Membungkus respon sukses dengan atribut `success: true`.
- `error($message, $statusCode, $errors)`  
  Membungkus respon kegagalan dengan kode status HTTP yang relevan.

### 3. `Services\ImageService` (`services/ImageService.php`)
- `processImage(?array $fileData, ?string $base64String): array`  
  Menerima input dari multipart `$_FILES` maupun string Base64, memvalidasi ukuran & MIME type, menyimpannya ke `backend/storage/uploads/`, dan menghasilkan Base64 Data URI.

### 4. `Services\OcrService` (`services/OcrService.php`)
- `scanKtp(string $imagePath): array`  
  Mengeksekusi proses Python melalui `proc_open`, menangkap output JSON, dan menyaring data utama: `nama`, `nik`, `alamat`, `foto_ktp`, dan `metadata`.

### 5. `Models\KtpModel` (`models/KtpModel.php`)
- `getAll($search, $limit, $offset): array`  
  Query SELECT dengan prepared statement untuk paginasi dan pencarian.
- `getById(int $id): ?array`  
  Mengambil 1 baris berdasarkan Primary Key ID.
- `create(array $data): int`  
  Menyisipkan baris baru ke tabel `demo_ocr_ktp` dan mengembalikan `lastInsertId`.
- `update(int $id, array $data): bool`  
  Dinamis UPDATE kolom sesuai data yang dikirimkan.
- `recordCheckout(int $id, ?string $jamKeluar): bool`  
  Memperbarui kolom `jam_keluar`.

### 6. `Controllers\OcrController` (`controllers/OcrController.php`)
- `scan(): void`  
  Menangani endpoint `POST /api/ocr/scan`, mengorkestrasi ImageService -> OcrService -> KtpModel, dan menghasilkan JSON untuk frontend.

### 7. `Controllers\KtpController` (`controllers/KtpController.php`)
- `index()`, `show()`, `store()`, `update()`, `destroy()`, `checkin()`, `checkout()`  
  Method RESTful controller untuk seluruh operasi CRUD.
