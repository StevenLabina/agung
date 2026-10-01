#!/usr/bin/env python3
import cv2
import sys
import os
import numpy as np
import argparse

# Batasi thread OpenCV agar tidak memonopoli 100% semua core CPU sistem
try:
    cv2.setNumThreads(2)
except Exception:
    pass


def resize_if_needed(image_path, output_path=None, max_dim=1600):
    """
    Jika dimensi gambar (width atau height) > max_dim (misal foto kamera HP 12MP-48MP),
    resize gambar dengan mempertahankan rasio aspek (cv2.INTER_AREA).
    Mengurangi beban inferensi PaddleOCR CPU hingga 60-80% tanpa menurunkan akurasi teks.
    Jika tidak perlu di-resize, kembalikan image_path asli.
    Jika di-resize, simpan ke output_path (atau temporary file) dan kembalikan path-nya.
    """
    try:
        if not os.path.exists(image_path):
            return image_path

        img = cv2.imread(image_path)
        if img is None:
            return image_path

        h, w = img.shape[:2]
        if max(h, w) <= max_dim:
            return image_path

        scale = max_dim / float(max(h, w))
        new_w = int(round(w * scale))
        new_h = int(round(h * scale))

        resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)

        if output_path is None:
            import tempfile
            fd, output_path = tempfile.mkstemp(suffix="_resized.jpg")
            os.close(fd)

        cv2.imwrite(output_path, resized, [cv2.IMWRITE_JPEG_QUALITY, 95])
        print(
            f"[AUTO-RESIZE] Scaled down {os.path.basename(image_path)} from ({w}x{h}) to ({new_w}x{new_h}) for optimal CPU OCR speed",
            file=sys.stderr,
        )
        return output_path
    except Exception as e:
        print(f"[RESIZE_WARN] Failed to resize {image_path}: {e}", file=sys.stderr)
        return image_path


def preprocess_standard(image_path, output_path):
    """Standard preprocessing dengan threshold Otsu"""
    img = cv2.imread(image_path)
    if img is None:
        return False

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return cv2.imwrite(output_path, thresh)

def preprocess_adaptive(image_path, output_path):
    """Adaptive threshold untuk gambar dengan pencahayaan tidak merata"""
    img = cv2.imread(image_path)
    if img is None:
        return False

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                   cv2.THRESH_BINARY, 11, 2)

    # Denoise
    denoised = cv2.fastNlMeansDenoising(thresh, None, 10, 7, 21)
    return cv2.imwrite(output_path, denoised)

def preprocess_denoise(image_path, output_path):
    """Fokus pada noise reduction"""
    img = cv2.imread(image_path)
    if img is None:
        return False

    # Denoise
    denoised = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)

    # Convert ke grayscale dan sharpen
    gray = cv2.cvtColor(denoised, cv2.COLOR_BGR2GRAY)
    kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
    sharpened = cv2.filter2D(gray, -1, kernel)

    return cv2.imwrite(output_path, sharpened)

def preprocess_sharpen(image_path, output_path):
    """Fokus pada sharpening untuk text blur"""
    img = cv2.imread(image_path)
    if img is None:
        return False

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Gaussian blur untuk mengurangi noise
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)

    # Sharpening menggunakan unsharp masking
    gaussian = cv2.GaussianBlur(blurred, (9, 9), 2.0)
    sharpened = cv2.addWeighted(blurred, 1.5, gaussian, -0.5, 0)

    # Contrast enhancement
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    enhanced = clahe.apply(sharpened.astype(np.uint8))

    return cv2.imwrite(output_path, enhanced)

def preprocess_ktp_optimized(image_path, output_path):
    """Optimized preprocessing for Indonesian KTP/Passport (Deskew + CLAHE + Adaptive Threshold)"""
    img = cv2.imread(image_path)
    if img is None:
        return False

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 1. Binarize roughly for deskewing
    thresh_for_deskew = cv2.bitwise_not(cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 2))

    # 2. Deskew using coordinates of text
    coords = np.column_stack(np.where(thresh_for_deskew > 0))
    if len(coords) > 0:
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle

        if abs(angle) > 0.5 and abs(angle) < 45:
            (h, w) = img.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            gray = cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

    # 3. CLAHE to remove glare and normalize contrast
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    clahe_img = clahe.apply(gray)

    # 4. Adaptive Threshold to make text pure black and background pure white
    final_thresh = cv2.adaptiveThreshold(clahe_img, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 5)

    # 5. Fast Denoise to remove small pepper noise
    denoised = cv2.fastNlMeansDenoising(final_thresh, None, 10, 7, 21)

    return cv2.imwrite(output_path, denoised)

def rotate_90_multiple(image_path, output_path, angle):
    """Rotasi BERSIH kelipatan 90 derajat (90/180/270) -- pakai cv2.rotate, bukan
    warpAffine kayak fungsi deskew lain di file ini. warpAffine didesain buat sudut
    SEMBARANG (perlu interpolasi piksel & bisa mepetin/motong tepi gambar), sedangkan
    kelipatan 90 derajat itu murni muter posisi piksel tanpa interpolasi sama sekali --
    presisi sempurna & jauh lebih murah komputasinya. Dipakai khusus buat fallback
    retry rotasi di ocr_processor.py, BUKAN buat koreksi kemiringan halus (itu tugas
    fungsi preprocess_* yang lain)."""
    img = cv2.imread(image_path)
    if img is None:
        return False
    mapping = {
        90: cv2.ROTATE_90_CLOCKWISE,
        180: cv2.ROTATE_180,
        270: cv2.ROTATE_90_COUNTERCLOCKWISE,
    }
    code = mapping.get(angle % 360)
    if code is None:
        return False
    rotated = cv2.rotate(img, code)
    return cv2.imwrite(output_path, rotated)


def analyze_image(gray):
    """Ukur kualitas gambar: brightness, contrast, ketajaman"""
    brightness = float(np.mean(gray))
    contrast = float(np.std(gray))
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    return brightness, contrast, sharpness


def estimate_directional_sharpness(gray):
    """Ketajaman per-arah (horizontal & vertikal). Laplacian itu omnidirectional jadi
    kurang sensitif ke motion blur yang cuma nurunin ketajaman di 1 arah gerakan."""
    sobel_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    sobel_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    return float(sobel_x.var()), float(sobel_y.var())


def estimate_noise(gray):
    """Estimasi noise sensor: residual antara gambar asli vs median-blur.
    Beda sama Laplacian yang malah salah baca noise sebagai 'sangat tajam'."""
    median = cv2.medianBlur(gray, 5)
    residual = gray.astype(np.float32) - median.astype(np.float32)
    return float(np.std(residual))


def text_zone_mask(shape):
    """Mask area yang KEMUNGKINAN BESAR berisi TEKS field, ngecualiin kuadran kanan-atas
    (foto wajah + logo/lambang) yang posisinya KONSISTEN di semua KTP Indonesia terlepas
    dari isi/kualitas fotonya. Dipakai buat estimate_glare_ratio() supaya silau yang jatuh
    di foto/logo (gak ngerusak keterbacaan TEKS sama sekali) gak ikut nge-gugurin kartu yang
    tulisannya sendiri sebenernya masih kebaca sempurna.

    Asumsi orientasi: kartu udah landscape & belum diputar 90/180/270 derajat -- ini cek
    dipanggil check_quality() SEBELUM tahap rotasi (lihat ocr_processor.py), jadi buat kartu
    yang kefoto muter penuh, mask ini gak representatif & bisa aja malah ngecualiin area
    yang salah. Gak masalah -- efek terburuknya cuma glare_ratio kurang presisi buat kasus
    itu, bukan bikin krusak; kartu yang muter tetap ketangkep & dikoreksi lewat jalur retry
    rotasi terpisah, gak lewat sini."""
    h, w = shape
    mask = np.ones((h, w), dtype=bool)
    photo_x0 = int(w * 0.62)
    photo_y1 = int(h * 0.58)
    mask[:photo_y1, photo_x0:] = False
    return mask


def estimate_glare_ratio(gray, threshold=248, zone_only=True):
    """Rasio pixel yang clipped/overexposed total. Pixel yang sudah mentok 255
    kehilangan informasi aslinya secara permanen -> gak ada preprocessing yang bisa
    mengembalikannya.

    zone_only=True (default): rasio cuma dihitung di text_zone_mask() (ngecualiin kuadran
    foto+logo) -- BUKAN seluruh gambar. Alasan ganti: sebelumnya rasio dihitung atas
    SELURUH gambar, jadi silau yang jatuh PERSIS di foto wajah/logo (elemen yang emang
    sering reflektif/mengkilap di KTP asli, dan sama sekali gak ngerusak keterbacaan
    TEKS) ikut kehitung penuh ke rasio yang sama dipakai buat mutusin kartu ini
    "unfixable" & langsung ditolak SEBELUM OCR sempat dicoba -- padahal tulisannya
    sendiri masih kebaca sempurna. Set zone_only=False kalau butuh angka rasio ATAS
    SELURUH gambar juga (mis. buat logging/perbandingan)."""
    region = gray[text_zone_mask(gray.shape)] if zone_only else gray
    if region.size == 0:
        return 0.0
    return float(np.mean(region >= threshold))


def assess_quality(gray):
    """Kumpulan metrik kualitas + klasifikasi apakah gambar ini masih bisa
    diperbaiki preprocessing, atau sudah rusak permanen (unfixable)."""
    brightness, contrast, sharpness = analyze_image(gray)
    sobel_x_var, sobel_y_var = estimate_directional_sharpness(gray)
    noise = estimate_noise(gray)
    glare_ratio = estimate_glare_ratio(gray)
    glare_ratio_full = estimate_glare_ratio(gray, zone_only=False)  # buat logging/perbandingan aja, gak dipakai buat keputusan

    # Laplacian & Sobel itu operator linear: kalau gambar di-scale (gelap/terang) pakai
    # alpha, variansnya ikut ke-scale alpha^2 -- sama kayak contrast (std) yang ke-scale alpha.
    # Makanya dibagi contrast^2 dulu (normalisasi) supaya gambar yang cuma gelap TIDAK
    # ikut kebaca "blur" gara-gara efek samping penggelapan, bukan blur asli.
    norm_sharpness = sharpness / (contrast ** 2 + 1e-6)
    norm_sobel_min = min(sobel_x_var, sobel_y_var) / (contrast ** 2 + 1e-6)
    is_blurry = norm_sharpness < 0.15 or norm_sobel_min < 1.0
    is_noisy = noise > 12
    # Background dokumen (kotak putih, border) secara natural udah ada porsi pixel putih
    # terang tanpa glare sama sekali -> threshold dipasang di atas itu, baru dianggap glare
    # brutal kalau area clipped-nya jauh lebih luas dari sekadar elemen desain dokumen.
    # CATATAN: angka 0.227 ini awalnya dikalibrasi pas glare_ratio masih dihitung atas
    # SELURUH gambar (termasuk kuadran foto+logo). Sekarang glare_ratio cuma dihitung di
    # text_zone_mask() (lihat estimate_glare_ratio) yang ngecualiin kuadran foto -- baseline
    # "putih natural"-nya kemungkinan sedikit BEDA (foto wajah/background foto sering
    # nyumbang piksel terang yang sekarang gak ikut kehitung), tapi belum ada cukup sampel
    # kartu asli buat ngalibrasi ulang angka pastinya. Threshold lama dipertahankan sbg
    # titik awal yang wajar -- perlu divalidasi lagi begitu ada beberapa kartu asli yang
    # sebelumnya ke-reject gara-gara glare, buat mastiin 0.227 masih pas atau perlu digeser.
    is_glare_brutal = glare_ratio > 0.227

    return {
        "brightness": brightness,
        "contrast": contrast,
        "sharpness": sharpness,
        "sobel_x_var": sobel_x_var,
        "sobel_y_var": sobel_y_var,
        "noise": noise,
        "glare_ratio": glare_ratio,
        "glare_ratio_full": glare_ratio_full,
        "is_blurry": is_blurry,
        "is_noisy": is_noisy,
        "is_glare_brutal": is_glare_brutal,
        "unfixable": is_glare_brutal,
    }


# Range Hue biru khas background KTP Indonesia (skala OpenCV: Hue 0-179). Dikalibrasi
# dari sampel kartu asli (kartu Kab. Bandung yang framingnya longgar, banyak background
# ramai di sekitarnya): histogram Hue piksel yang cukup jenuh warnanya (S>40, V>60) punya
# puncak tajam di Hue=108 dengan ~26 ribu piksel di 1 bin -- jauh ngalahin warna lain di
# foto. Range di bawah dilebarkan dikit dari puncak itu (95-125) buat toleransi variasi
# pencahayaan/cetakan kartu yang beda-beda -- BELUM divalidasi ke banyak kartu lain,
# perlu dicek ulang kalau ada laporan crop yang salah potong.
KTP_BLUE_HSV_LOWER = (95, 30, 40)
KTP_BLUE_HSV_UPPER = (125, 255, 255)


def locate_card_bbox(image_path, boxes, pad_frac=0.35, min_boxes=3):
    """Cari batas fisik kartu KTP dalam foto yang framingnya longgar (kartu cuma
    ngisi sebagian kecil frame, banyak background di sekitarnya -- mis. diletakkan
    di atas kain/lantai). Gabungan 2 sinyal:

    1. KOTAK TEKS hasil OCR (parameter `boxes`, format [x1,y1,x2,y2] per box) --
       background acak (kain, kabel, lantai) HAMPIR TIDAK PERNAH menghasilkan kotak
       teks sama sekali, walau BACAANNYA sendiri berantakan (huruf salah baca) --
       jadi lokasinya tetap jangkar yang jauh lebih bisa diandalkan daripada
       nebak-nebak dari warna doang.
    2. WARNA BIRU khas background KTP -- dipakai buat NGELEBARIN dari jangkar kotak
       teks ke batas fisik kartu yang sebenarnya (teks nggak nyampe ke pinggir
       kartu/area foto tanpa keterangan).

    PENTING: pencarian warna biru DIBATASI ke jendela lokal di sekitar kotak teks
    (bukan ke SELURUH gambar) -- kalau dicari sejagad gambar, benda biru lain di
    background (kain, baju, dll) gampang nyambung jadi 1 blob sama kartu lewat
    morphological closing, bikin crop kebablasan. Sudah dites langsung ke kartu
    dengan kain polkadot biru persis di belakangnya: pencarian sejagad gambar
    nyangkut ke kain (crop jadi ketinggian, ratio 320x484), pencarian lokal
    (jendela di sekitar kotak teks) berhasil motong pas di pinggir kartu.

    Return (x0, y0, x1, y1) kalau ketemu, None kalau sinyalnya kurang meyakinkan
    (dipakai caller buat fallback ke gambar aslinya -- JANGAN paksa crop kalau
    nggak yakin, lebih baik gak crop daripada crop salah & bikin kartu yang
    tadinya kebaca malah rusak)."""
    if boxes is None or len(boxes) < min_boxes:
        return None

    img = cv2.imread(image_path)
    if img is None:
        return None
    img_h, img_w = img.shape[:2]

    xs1 = [b[0] for b in boxes]
    ys1 = [b[1] for b in boxes]
    xs2 = [b[2] for b in boxes]
    ys2 = [b[3] for b in boxes]
    tx1, ty1, tx2, ty2 = min(xs1), min(ys1), max(xs2), max(ys2)
    tw, th = tx2 - tx1, ty2 - ty1
    if tw <= 0 or th <= 0:
        return None

    # Kalau kotak teks udah nyaris memenuhi seluruh frame, kartu memang udah
    # framing rapat -- gak perlu crop tambahan, biar gak nambah kerjaan/risiko
    # buat kasus yang sebenarnya udah OK.
    if (tw * th) >= 0.7 * (img_w * img_h):
        return None

    rx0 = max(0, int(tx1 - tw * pad_frac))
    ry0 = max(0, int(ty1 - th * pad_frac))
    rx1 = min(img_w, int(tx2 + tw * pad_frac))
    ry1 = min(img_h, int(ty2 + th * pad_frac))
    if rx1 <= rx0 or ry1 <= ry0:
        return None

    region = img[ry0:ry1, rx0:rx1]
    hsv = cv2.cvtColor(region, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, np.array(KTP_BLUE_HSV_LOWER), np.array(KTP_BLUE_HSV_UPPER))
    kernel = np.ones((9, 9), np.uint8)
    mask_closed = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(mask_closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

    biggest = max(contours, key=cv2.contourArea)
    region_area = (rx1 - rx0) * (ry1 - ry0)
    if cv2.contourArea(biggest) < 0.05 * region_area:
        return None  # kontur biru ketemu tapi kekecilan, kemungkinan cuma noise/pantulan

    bx, by, bw, bh = cv2.boundingRect(biggest)
    fx0, fy0 = rx0 + bx, ry0 + by
    fx1, fy1 = fx0 + bw, fy0 + bh

    # Padding kecil final (5%) biar pinggir kartu gak kepotong pas-pasan
    pad2_x, pad2_y = int(bw * 0.05), int(bh * 0.05)
    fx0 = max(0, fx0 - pad2_x)
    fy0 = max(0, fy0 - pad2_y)
    fx1 = min(img_w, fx1 + pad2_x)
    fy1 = min(img_h, fy1 + pad2_y)

    return (fx0, fy0, fx1, fy1)


def crop_to_bbox(image_path, output_path, bbox):
    """Crop gambar ke bbox (x0,y0,x1,y1) & simpan. Langkah TERPISAH dari
    preprocess_* lain -- crop dulu baru preprocessing biasa (sharpen/CLAHE/dll)
    jalan di atas hasil crop-nya, bukan gantiin urutan yang udah ada."""
    img = cv2.imread(image_path)
    if img is None:
        return False
    x0, y0, x1, y1 = bbox
    crop = img[y0:y1, x0:x1]
    if crop.size == 0:
        return False
    return cv2.imwrite(output_path, crop)


def crop_below_detected_content(image_path, output_path, boxes, pad_frac=0.03):
    """Crop dari sedikit di atas kotak teks TERBAWAH yang UDAH kebaca, sampai
    ke pinggir bawah gambar. Dibangun khusus buat mengisolasi strip MRZ
    paspor lewat pass OCR KE-2 yang lebih terarah, dipanggil kalau pass
    UTAMA berhasil baca teks body (nama, tanggal, nomor dokumen) tapi GAK
    berhasil baca baris MRZ-nya sendiri.

    KENAPA JANGKAR INI (bukan persentase tetap dari seluruh foto): MRZ
    posisinya SELALU di bawah semua field body yang tercetak di halaman foto
    paspor -- itu berlaku terlepas dari seberapa banyak background (uang,
    tangan, meja) yang ngelilingin paspornya di foto mentah, dan terlepas
    dari resolusi gambar. Pakai deteksi yang UDAH BERHASIL dari gambar yang
    SAMA sebagai jangkar itu otomatis nyesuain diri; persentase tetap dari
    SELURUH foto mentah enggak -- kebukti langsung: Paspor1.jpeg framingnya
    longgar banget (banyak uang & tangan di sekitar), sedangkan Paspor2/3
    framingnya lebih rapat -- persentase tetap yang pas buat salah satu bisa
    salah total buat yang lain.

    Return True/False (berhasil nulis crop atau enggak), sama kayak
    preprocess_* lain di file ini."""
    img = cv2.imread(image_path)
    # PENTING: "not boxes" (bukan "boxes is None") -- `boxes` dari
    # PaddleOCR (rec_boxes) itu numpy array, BUKAN list Python biasa.
    # Numpy array dengan lebih dari 1 elemen GAK BISA langsung dicek
    # truthy/falsy kayak gitu -- python bakal lempar
    # "ValueError: truth value of an array... is ambiguous" TEPAT di
    # baris ini. Ini persis kenapa recovery MRZ gagal total, SETIAP
    # kali dicoba, dari awal fitur ini dibikin -- selalu ke-catch diam-diam
    # sama except Exception di ocr_processor.py, gak pernah kelihatan
    # sampai ditambahin print [MRZ DEBUG] & dijalanin manual (lihat chat).
    if img is None or boxes is None or len(boxes) == 0:
        return False

    img_h, img_w = img.shape[:2]

    # Buang box TERISOLASI di bagian bawah yang kepisah jauh dari klaster
    # teks utama, sebelum nentuin jangkar -- kemungkinan besar itu noise
    # background (uang, meja, dll ikut kefoto), BUKAN bagian dari halaman
    # paspor itu sendiri.
    #
    # PENTING: cari GAP TERBESAR di SELURUH daftar (bukan cuma "gap pertama
    # yang kelihatan gede" jalan dari nilai terkecil) -- percobaan pertama
    # pakai cara itu GAGAL kebukti langsung di Paspor1.jpeg: ada 2 gap
    # gede di data yang sama (193px antara header kecil paspor & body
    # utama, VS 224px antara akhir body [y2=703, field NO.REG] & noise
    # background di bawahnya [y2=927/999/1125, "APULU"/"Wt"/"Co%" -- jelas
    # bukan teks paspor]). Jalan dari nilai terkecil nabrak gap 193px
    # DULUAN, jangkar jadi salah total (y2=45, ke atas dari body-nya
    # sendiri). Nyari gap TERBESAR di seluruh daftar + verifikasi cuma
    # motong SEBAGIAN KECIL box (bukan separuh halaman) itu yang benar --
    # ini otomatis nemuin gap 224px yang tepat, karena itu MEMANG paling
    # gede di seluruh data, dan cuma motong 3 dari 39 box (jelas minoritas).
    y2_sorted = sorted(b[3] for b in boxes)
    max_y = y2_sorted[-1]
    if len(y2_sorted) >= 2:
        gaps = [(y2_sorted[i] - y2_sorted[i - 1], i) for i in range(1, len(y2_sorted))]
        biggest_gap, split_idx = max(gaps, key=lambda g: g[0])
        num_isolated = len(y2_sorted) - split_idx
        if biggest_gap > img_h * 0.08 and num_isolated <= max(1, len(y2_sorted) * 0.25):
            max_y = y2_sorted[split_idx - 1]  # pinggir bawah kotak TERBAWAH yang DIPERCAYA

    # Mulai SEDIKIT DI ATAS pinggir bawah yang kedeteksi (padding negatif
    # kecil) biar baris yang KEPOTONG SEBAGIAN di batas itu gak ikut kepotong.
    crop_y0 = max(0, int(max_y - img_h * pad_frac))
    if crop_y0 >= img_h - 10:
        return False  # udah gak ada sisa berarti di bawah konten yang kedeteksi

    # BATASI tinggi crop -- JANGAN sampai ke pinggir bawah gambar tanpa batas.
    # Dikalibrasi langsung dari Paspor3.jpg (yang MRZ-nya KEBACA BERSIH di
    # pass utama, jadi posisi asli/pasti diketahui): dari akhir field
    # NO.REG (y2=389) sampe akhir baris ke-2 MRZ (y2=478) cuma 89px, sekitar
    # 11-13% dari tinggi gambar itu. Crop tanpa batas ke bawah nyeret
    # background/uang/meja yang JAUH lebih luas dari itu ikut masuk --
    # kebukti langsung di percobaan pertama fitur ini (Paspor1.jpeg): teks
    # hasil crop-nya cuma noise pendek ("C0", "M", "BAnd", dll), bukan MRZ
    # sama sekali, karena crop-nya kebesaran & MRZ ke-encer di tengah
    # banyak background lain. Kasih margin longgar (20%, bukan 12% pas)
    # biar tetep aman kalau posisi MRZ agak beda dikit di paspor lain.
    max_crop_height = int(img_h * 0.20)
    crop_y1 = min(img_h, crop_y0 + max_crop_height)

    crop = img[crop_y0:crop_y1, 0:img_w]
    if crop.size == 0:
        return False

    # Kasih PADDING VERTIKAL kalau rasio lebar:tinggi-nya EKSTRIM.
    #
    # DIKONFIRMASI LANGSUNG (lihat mrz_debug_crop.jpg di chat): geometri crop
    # ini SEBENARNYA UDAH TEPAT -- kedua baris MRZ kelihatan JELAS &
    # KEBACA SEMPURNA secara visual ke mata manusia. Tapi PaddleOCR TETAP
    # gagal total ngedeteksi teksnya (cuma nemu 1 fragment gak jelas). Root
    # cause-nya BUKAN geometri crop lagi -- crop-nya udah lebar penuh
    # (img_w) tapi tinggi cuma strip tipis (dibatasi ~20% dari img_h di atas),
    # jadi rasio lebar:tinggi-nya BISA >6:1 SEBELUM upscale sekalipun. Model
    # deteksi teks PaddleOCR kemungkinan besar KESULITAN sama gambar yang
    # se-elongated ini pas resize internalnya, walaupun teksnya sendiri
    # tajam & jelas.
    #
    # Solusinya BUKAN crop lebih sempit (teks MRZ udah mepet ke pinggir kiri
    # -kanan crop, motong lebar bisa kepotong beneran), tapi nambah PADDING
    # atas-bawah biar rasio-nya balik ke proporsi yang lebih wajar buat
    # model deteksi teks -- pakai BORDER_REPLICATE (nyalin pinggiran gambar,
    # bukan bikin garis hitam/putih tegas) biar gak nambah artefak baru yang
    # malah bisa ganggu deteksi.
    crop_h, crop_w = crop.shape[:2]
    max_aspect_ratio = 4.0
    if crop_w / max(crop_h, 1) > max_aspect_ratio:
        target_h = int(crop_w / max_aspect_ratio)
        total_pad = max(0, target_h - crop_h)
        pad_top = total_pad // 2
        pad_bottom = total_pad - pad_top
        crop = cv2.copyMakeBorder(crop, pad_top, pad_bottom, 0, 0, cv2.BORDER_REPLICATE)

    # Upscale -- strip ini seringnya potongan tipis dari foto yang jauh lebih
    # besar, dan teks kecil lebih kebaca konsisten kalau ukurannya gak
    # mini-mini banget relatif ke frame yang diharapkan model recognition.
    scale = 2
    crop = cv2.resize(crop, (crop.shape[1] * scale, crop.shape[0] * scale), interpolation=cv2.INTER_CUBIC)

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    return cv2.imwrite(output_path, gray)


def check_quality(image_path):
    """Load gambar dari path & nilai kualitasnya. Dipanggil ocr_processor.py
    SEBELUM OCR jalan, buat deteksi dini kondisi yang gak bisa diperbaiki."""
    gray = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if gray is None:
        return None
    return assess_quality(gray)


def preprocess_dynamic(image_path, output_path):
    """Preprocessing adaptif: analisis gambar dulu, baru terapkan treatment yang perlu saja"""
    img = cv2.imread(image_path)
    if img is None:
        return False # Misalnya gagal baca nanti lgsg berhenti, tandai gagal

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) # Ubah ke grayscale, semua step analisis/OCR kerja di 1 channel aja
    quality = assess_quality(gray)  # Semua metrik + keputusan (blurry/noisy/glare) dari sini

    # Deskew akan selalu dijalankan, digunakan untuk meluruskan gambar yang miring
    thresh_for_deskew = cv2.bitwise_not(cv2.adaptiveThreshold(     # Buat versi hitam-putih kasar cuma buat cari kemiringan teks
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 2))  # bitwise_not supaya teks jadi putih di atas background hitam
    coords = np.column_stack(np.where(thresh_for_deskew > 0))
    if len(coords) > 0:                     # Kalau ada teks yang kedeteksi
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle # Balik tanda supaya arah rotasinya benar

        if abs(angle) > 0.5 and abs(angle) < 45:  # Cuma rotasi kalau miringnya signifikan (>0.5°) tapi masih wajar (<45°)
            (h, w) = gray.shape[:2]# ambil tinggi sm lebar gambar
            center = (w // 2, h // 2) # Titik tengah gambar, dijadiin pusat rotasi
            M = cv2.getRotationMatrix2D(center, angle, 1.0) #jadiin matrix, gausa dizoom
            gray = cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_CUBIC,  #  rotasi ke gambar asli (grayscale)
                                   borderMode=cv2.BORDER_REPLICATE)         # Area kosong hasil rotasi diisi pke pixel tepi terdekat

    # Denoise - kalau noise sensor tinggi. Dicek sebelum CLAHE/sharpen biar gak dobel proses di atas noise.
    if quality["is_noisy"]:
        gray = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    # Brightness & contrast -> digunakan hanya kalau memang bermasalah
    if quality["brightness"] < 90 or quality["contrast"] < 40: # semisal gambar gelap ATAU kontrasnya datar/pudar
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))  # Siapkan CLAHE: naikkan kontras lokal per blok 8x8, dibatasi biar tidak over
        gray = clahe.apply(gray) # Terapkan CLAHE ke gambar -> jadi lebih terang & kontras merata

    # Sharpening - hanya kalau memang buram (termasuk motion blur searah lewat is_blurry).
    # Kekuatan unsharp masking sekarang ADAPTIF terhadap separah apa blur-nya, bukan angka
    # tetap (1.5/-0.5) buat semua kartu. Kartu yang cuma DIKIT di bawah ambang blur dapat
    # penajaman ringan (biar gak over-sharpen/nambah noise-halo di kartu yang udah lumayan
    # tajam); kartu yang jauh di bawah ambang (blur berat) dapat penajaman lebih kuat.
    if quality["is_blurry"]:
        norm_sharpness = quality["sharpness"] / (quality["contrast"] ** 2 + 1e-6)
        # deficit: 0.0 pas di ambang (0.15), mendekati 1.0 kalau sharpness-nya nyaris nol.
        # Diclip ke [0, 1] supaya amount gak meledak buat kasus ekstrem (sharpness~0).
        deficit = min(1.0, max(0.0, (0.15 - norm_sharpness) / 0.15))
        amount = 1.5 + deficit * 1.5  # rentang 1.5 (borderline) s/d 3.0 (blur sangat parah)

        # CATATAN: sebelumnya ada langkah "blur ringan 3x3 dulu sebelum sharpen" di sini
        # (alasannya: kurangi noise dulu biar gak ikut di-sharpen). Dites langsung ke kartu
        # asli (HENRY ALEXANDER, sharpness mentah 647) dan ternyata blur 3x3 itu SENDIRI
        # udah menghancurkan detail tajam sampai varians Laplacian anjlok ke 76 (dari 647)
        # SEBELUM sempat di-unsharp-mask -- jadi hasil akhirnya malah lebih buram dari
        # gambar asli walau sudah "disharpen". Noise sendiri sudah ditangani terpisah di
        # atas (fastNlMeansDenoising, blok is_noisy) sebelum sampai ke sini, jadi blur 3x3
        # tambahan ini cuma bikin rugi tanpa manfaat -- makanya dihapus, unsharp mask
        # sekarang langsung dari `gray` apa adanya.
        gaussian = cv2.GaussianBlur(gray, (9, 9), 2.0) # Versi halus dipakai sebagai "referensi" buat cari detail frekuensi-tinggi
        gray = cv2.addWeighted(gray, amount, gaussian, -(amount - 1.0), 0)  # unsharp masking: gray + (amount-1)*(gray - gaussian)

    print(   # Cetak angka-angka hasil analisis ke stderr (bukan stdout, biar tidak ganggu parsing JSON hasil OCR)
        f"[INFO] brightness={quality['brightness']:.1f} contrast={quality['contrast']:.1f} "
        f"sharpness={quality['sharpness']:.1f} noise={quality['noise']:.1f} "
        f"glare_ratio={quality['glare_ratio']:.3f} (full_img={quality['glare_ratio_full']:.3f}) "
        f"is_blurry={quality['is_blurry']} unfixable={quality['unfixable']}",
        file=sys.stderr,
    )

    return cv2.imwrite(output_path, gray)

def main():
    parser = argparse.ArgumentParser(description='Adaptive image preprocessing for OCR')
    parser.add_argument('input_path', help='Path to input image')
    parser.add_argument('output_path', help='Path to output image')
    parser.add_argument('--method', choices=['standard', 'adaptive', 'denoise', 'sharpen', 'ktp_optimized', 'dynamic'],
                       default='standard', help='Preprocessing method')


    args = parser.parse_args()

    # Validate input
    if not os.path.exists(args.input_path):
        print(f"[ERROR] File not found: {args.input_path}", file=sys.stderr)
        sys.exit(1)

    # Apply selected preprocessing method
    success = False
    if args.method == 'standard':
        success = preprocess_standard(args.input_path, args.output_path)
    elif args.method == 'adaptive':
        success = preprocess_adaptive(args.input_path, args.output_path)
    elif args.method == 'denoise':
        success = preprocess_denoise(args.input_path, args.output_path)
    elif args.method == 'sharpen':
        success = preprocess_sharpen(args.input_path, args.output_path)
    elif args.method == 'ktp_optimized':
        success = preprocess_ktp_optimized(args.input_path, args.output_path)
    elif args.method == 'dynamic':
        success = preprocess_dynamic(args.input_path, args.output_path)

    if success:
        print(f"[OK] Preprocessed with {args.method} method: {args.output_path}")
    else:
        print(f"[ERROR] Failed to preprocess image", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
