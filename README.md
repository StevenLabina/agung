# Panduan Development & Testing (Mobile) — Akses Perumahan / OCR KTP

Panduan ini menjelaskan cara menjalankan dan menguji fitur kamera + Baca KTP
(`lib/screens/oct_ktp.dart`) di **HP Android** dan di **PC/laptop**.

Target utama aplikasi: **web app di browser HP (Android)**. Tes di PC hanya untuk
pengembangan cepat, hasilnya tidak mewakili kualitas kamera HP.

---

## 1. Perbedaan Singkat: HP vs PC

| Hal | HP (Chrome Android) | PC / Laptop |
|---|---|---|
| Kamera | Kamera belakang (autofocus, tajam) | Webcam (resolusi rendah, sering fokus tetap) |
| Mirror | Tidak di-mirror | Kamera depan di-mirror, sudah dibalik otomatis oleh `KtpCameraView` |
| Skor ketajaman (`tajam` / `teks`) | Tajam: sekitar 4700–6200 / 0.48–0.84 | Webcam: sekitar 60 / 0.08 (**akan ditolak "buram"**, wajar) |
| Cocok untuk | Tes akurasi OCR, kualitas foto, UX kotak panduan | Tes alur layar, UI, error handling, backend |
| Syarat kamera | `localhost` (lewat `adb reverse`) atau HTTPS | `localhost` otomatis diizinkan |

> Kamera browser **hanya jalan di HTTPS atau `localhost`**. Membuka lewat IP
> (mis. `http://192.168.1.5:8080`) di HP akan membuat kamera diblokir. Itu sebabnya
> di HP kita memakai `adb reverse` supaya HP melihat `localhost`.

---

## 2. Persiapan Sekali Saja

1. Flutter SDK, PHP, XAMPP (MySQL), dan Chrome terpasang di laptop.
2. Dependensi Flutter:
   ```powershell
   flutter pub get
   ```
3. `backend/.env` berisi konfigurasi database dan layanan OCR CRM. **Jangan di-commit.**
   ```
   CRM_OCR_URL=https://crm.apikkedu.com/api/ocr/ktp
   CRM_API_KEY=<minta ke tim, jangan ditempel di chat/commit>
   CRM_OCR_TIMEOUT=120
   ```
   API key hanya boleh ada di backend, **tidak boleh** ada di kode Flutter.
4. Ubah `lib/url.dart` untuk lokal (**jangan di-commit**):
   ```dart
   static const baseUrl = 'http://localhost:8000/api/';
   ```

---

## 3. Menjalankan Server (dipakai untuk HP maupun PC)

Buka 3 hal berikut:

1. **XAMPP**: start **MySQL** (Apache tidak wajib kalau memakai `php -S`).
2. **Backend PHP** (terminal 1, dari folder proyek):
   ```powershell
   php -S 127.0.0.1:8000 -t backend
   ```
3. **Flutter web** (terminal 2): lihat bagian PC atau HP di bawah.

---

## 4. Tes di PC / Laptop

```powershell
flutter run -d chrome
```

(atau `flutter run -d web-server --web-port 8080` lalu buka `http://localhost:8080`)

Yang dicek:
- Browser meminta izin kamera → **Allow**.
- Kotak panduan kuning tampil, area luar kotak gelap.
- Tombol **Kamera** mengambil foto, **Foto Ulang** membuka kamera lagi tanpa error.
- Foto tidak ter-mirror (tulisan tidak terbalik).
- Webcam akan sering ditolak dengan pesan "Foto buram atau goyang". Itu perilaku yang benar,
  bukan bug. Untuk tes alur OCR di PC, pakai **Pilih File** dengan foto KTP yang tajam.

---

## 5. Tes di HP Android (via USB)

### 5.1 Setup HP (sekali)
1. Aktifkan **Opsi Pengembang** (Pengaturan → Tentang ponsel → ketuk *Nomor build* 7×).
2. Aktifkan **USB debugging**.
3. Sambungkan HP ke laptop dengan kabel. Mode USB pilih **Transfer file**
   (bukan "Hanya mengisi daya").
4. Saat muncul **Izinkan debugging USB?** → centang *Selalu izinkan* → **Izinkan**.

### 5.2 Setup `adb` di PowerShell
Kalau `adb` tidak dikenali, buat alias untuk sesi itu:
```powershell
Set-Alias adb "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
adb devices
```
Status harus `device`. Kalau `unauthorized`, terima prompt di HP lalu ulangi.

### 5.3 Teruskan port laptop ke HP
```powershell
adb reverse tcp:8080 tcp:8080    # aplikasi Flutter
adb reverse tcp:8000 tcp:8000    # backend PHP
adb reverse --list               # harus muncul kedua port
```
Ulangi dua perintah `reverse` **setiap kali** kabel dicabut/dicolok atau `adb` restart.

### 5.4 Jalankan Flutter dan buka di HP
```powershell
flutter run -d web-server --web-port 8080
```
Di **Chrome HP** buka: `http://localhost:8080` lalu izinkan kamera.

> Mode `web-server` tidak mendukung hot restart lewat `R`. Kalau mengubah kode,
> hentikan (`q`) lalu jalankan ulang, kemudian muat ulang halaman di HP.

### 5.5 Melihat console/log dari HP
1. Di laptop buka Chrome → `chrome://inspect/#devices`.
2. Pastikan HP muncul dan halaman `localhost:8080` terdaftar → klik **inspect**.
3. Tab **Console** menampilkan log, termasuk `Kamera: ... preview=... mirror=...`.

(Browser HP selain Chrome, mis. Brave, sulit diinspeksi. Pakai Chrome HP untuk tes.)

---

## 6. Skor Kualitas Foto (mode debug)

Di mode debug, skor tampil di layar setelah foto diambil:

| Skor | Arti | Ambang |
|---|---|---|
| `tajam` | Variansi Laplacian (ketajaman umum) | minimal **300** |
| `teks` | Ketajaman area teks, peka terhadap foto goyang | minimal **0.2** |
| Kecerahan | Rata-rata terang | 70–235 |
| Pantulan | Porsi piksel hampir putih | maks 8% |

Contoh hasil kalibrasi (Samsung S21 FE): foto tajam `tajam` 4780–6165 / `teks` 0.48–0.84;
foto goyang `teks` 0.06; webcam laptop `tajam` 62 / `teks` 0.08.

---

## 7. Troubleshooting

| Gejala | Penyebab / Solusi |
|---|---|
| `adb` tidak dikenali | Pakai alias di bagian 5.2 atau tambahkan `platform-tools` ke PATH |
| `adb devices` → `unauthorized` | Terima prompt debugging di HP, atau cabut-colok kabel |
| `adb devices` kosong | Ganti kabel (harus kabel data), mode USB = Transfer file, aktifkan USB debugging |
| HP: `localhost refused to connect` | `flutter run` belum jalan, atau `adb reverse` belum dijalankan ulang |
| HP membuka alamat lain (mis. `rukuntetangga.net`) / **Failed to fetch** | `lib/url.dart` masih menunjuk server online; ubah ke `http://localhost:8000/api/`, jalankan ulang Flutter |
| Kamera tidak meminta izin / diblokir | Halaman tidak dibuka lewat `localhost` atau HTTPS |
| `cameraNotReadable` | Kamera dipakai tab/aplikasi lain. Tutup tab lain; widget sudah mencoba ulang otomatis |
| Foto ter-mirror | Cek log `mirror=`; harus `false` untuk kamera belakang |
| Semua foto webcam ditolak buram | Normal (lihat bagian 1). Tes OCR pakai foto dari HP atau **Pilih File** |
| Baca KTP: *Timeout menunggu slot worker OCR* | Antrean OCR di CRM penuh (batch lain sedang jalan). Coba lagi nanti / koordinasi dengan tim CRM |
| Baca KTP: *API key tidak valid* (401) | `CRM_API_KEY` di `backend/.env` salah/kosong; restart `php -S` setelah mengubah `.env` |
| Baca KTP: *Terlalu banyak permintaan* (429) | Rate limit CRM 60 request/menit; tunggu sebentar |
| *Failed to fetch* padahal URL benar | Backend `php -S` mati, atau port 8000 belum di-`adb reverse` |
