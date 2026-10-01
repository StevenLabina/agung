# -*- coding: utf-8 -*-
"""
=============================================================================
KTP OCR PROCESSOR - ENGINE PADDLEOCR KHUSUS KTP INDONESIA
=============================================================================
Modul ini bertugas melakukan pemrosesan ekstraksi data teks khusus untuk
Kartu Tanda Penduduk (KTP) Republik Indonesia menggunakan PaddleOCR.
Seluruh logika dokumen lain (Paspor, NPWP, SIM, ID asing) telah dibersihkan
sehingga engine ini 100% terfokus pada format baku KTP Indonesia.

Fitur Utama:
1. Spatial Box Clustering: Mengelompokkan kotak teks berdasarkan posisi Y (baris)
   dan urutan baku field KTP Indonesia.
2. Sanitasi Nama & Label: Membersihkan teks nama dari label KTP dan noise OCR.
3. Standar NIK Dukcapil: Ekstraksi NIK 16 digit dan fallback tanggal lahir/gender
   sesuai standar UU Kependudukan RI.
=============================================================================
"""

import os
import sys
import json
import re
import datetime
import atexit
from difflib import SequenceMatcher

# Pastikan direktori script masuk ke sys.path
_script_dir = os.path.dirname(os.path.abspath(__file__))
if _script_dir not in sys.path:
    sys.path.insert(0, _script_dir)

import preprocess_adaptive as preproc

# Batasi thread OpenCV agar tidak memonopoli CPU
try:
    import cv2
    cv2.setNumThreads(int(os.environ.get("OCR_THREAD_LIMIT_PER_PROCESS", "1")))
except Exception:
    pass

# Manajemen pembersihan file temporary saat exit
_temp_files_to_cleanup = set()

def _cleanup_registered_temp_files():
    for path in list(_temp_files_to_cleanup):
        if path and os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

atexit.register(_cleanup_registered_temp_files)

# Turunkan prioritas CPU proses OCR ke Below Normal agar tidak lag
try:
    import psutil
    _p = psutil.Process()
    if sys.platform == 'win32':
        _p.nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    else:
        _p.nice(10)
except Exception:
    pass

# Inisialisasi PaddleOCR
try:
    from paddleocr import PaddleOCR
except ImportError:
    PaddleOCR = None


def sanitize_name(name: str):
    """
    Sanitasi nama pemilik KTP:
    1. Ganti tanda hubung (- / en-dash / em-dash / underscore) dengan spasi.
    2. Hapus angka / digit (nama resmi KTP tidak memuat angka).
    3. Hapus kata-kata template / label dokumen KTP yang bocor (PROVINSI, KOTA, dll).
    4. Hapus token noise yang memiliki karakter berulang 3x atau lebih.
    5. Hapus token acak dan tanda baca menggantung.
    """
    if not name or not isinstance(name, str):
        return name

    cleaned = re.sub(r"[\-–—_]+", " ", name)
    cleaned = re.sub(r"\d+", " ", cleaned)

    label_patterns = [
        r"\b(?:REPUBLIK\s*INDONESIA|INDONESIA|PROVINSI|KABUPATEN|KOTA)\b",
        r"\b(?:NIK|NAMA|TEMPAT|TGL|LAHIR|JENIS|KELAMIN|ALAMAT|AGAMA|STATUS)\b",
        r"\b(?:GOL|DARAH|WARGANEGARA|KEWARGANEGARAAN|WNI|WNA)\b",
        r"\b(?:PEKERJAAN|BERLAKU|HINGGA|SEUMUR|HIDUP)\b",
    ]
    for pat in label_patterns:
        cleaned = re.sub(pat, " ", cleaned, flags=re.IGNORECASE)

    # Hapus karakter berulang 3x atau lebih (misal CCCC, XXXX)
    cleaned = re.sub(r"\b[A-Za-z]*([A-Za-z])\1{2,}[A-Za-z]*\b", " ", cleaned)

    tokens = []
    for token in cleaned.split():
        t = re.sub(r"[^A-Za-z']", "", token)
        if not t or len(t) < 2:
            continue
        tokens.append(t)

    cleaned = " ".join(tokens).strip().strip(" .,'\"-")
    return cleaned.upper() if len(cleaned) >= 2 else None


def looks_like_header(line: str) -> bool:
    """Cek apakah baris teks adalah header administratif (PROVINSI, KABUPATEN, KOTA)."""
    t = re.sub(r"[^A-Z]", "", line.upper())
    for prefix in ("PROVINSI", "KABUPATEN", "KOTA"):
        if len(t) < len(prefix) - 2:
            continue
        if prefix == "KOTA" and (not t or t[0] != "K"):
            continue
        ratio = SequenceMatcher(None, t[:len(prefix)], prefix).ratio()
        if ratio >= 0.7:
            return True
    return False


def looks_like_goldarah(text: str) -> bool:
    """Cek apakah sebuah box teks adalah label Gol. Darah agar tidak tertukar."""
    t = re.sub(r"[^A-Z]", "", text.upper())
    if len(t) < 4:
        return False
    return SequenceMatcher(None, t[:8], "GOLDARAH").ratio() >= 0.55


def validate_value(field: str, val: str) -> bool:
    """Validasi ketat tipe data untuk tiap field KTP Indonesia."""
    if not val or not isinstance(val, str):
        return False

    val_upper = val.upper().strip()
    if not val_upper:
        return False

    labels = [
        'NIK', 'NAMA', 'NAME', 'TEMPAT/TGL LAHIR', 'TEMPAT', 'TGL LAHIR', 'LAHIR',
        'JENIS KELAMIN', 'KELAMIN', 'GOL. DARAH', 'GOL DARAH', 'ALAMAT', 'ALAMAL',
        'RT/RW', 'RT', 'RW', 'KEL/DESA', 'KELURAHAN', 'DESA', 'KECAMATAN',
        'AGAMA', 'STATUS PERKAWINAN', 'PERKAWINAN', 'STATUS', 'PEKERJAAN',
        'KEWARGANEGARAAN', 'BERLAKU HINGGA', 'BERLAKU', 'GOL', 'PROVINSI', 'KABUPATEN', 'KOTA'
    ]
    val_clean = re.sub(r'[^A-Z0-9/]', '', val_upper)
    for lbl in labels:
        if val_clean == re.sub(r'[^A-Z0-9/]', '', lbl):
            return False

    field_norm = field.lower().replace(" ", "").replace("_", "").replace("/", "")

    if field_norm in ['nik', 'documentnumber']:
        digits = re.sub(r'[^0-9]', '', val_upper)
        return len(digits) >= 15

    elif field_norm in ['nama', 'fullname']:
        if any(c.isdigit() for c in val_upper):
            return False
        if not any(c.isalpha() for c in val_upper):
            return False
        if re.search(r'([A-Z])\1{2,}', val_upper):
            return False
        forbidden = {'PROVINSI', 'KABUPATEN', 'KOTA', 'REPUBLIK', 'INDONESIA', 'AGAMA', 'NIK', 'LAKI', 'PEREMPUAN'}
        if set(re.findall(r'[A-Z]+', val_upper)).intersection(forbidden):
            return False

    elif field_norm in ['tempattgllahir', 'dobraw', 'datebirth', 'ttl']:
        return any(c.isdigit() for c in val_upper)

    elif field_norm in ['jeniskelamin', 'genderraw', 'gender']:
        return any(k in val_upper for k in ['LAKI', 'PEREMPUAN', 'WANITA', 'PRIA'])

    elif field_norm in ['agama', 'religion']:
        return any(r in val_upper for r in ['ISLAM', 'KRISTEN', 'KATOLIK', 'HINDU', 'BUDHA', 'BUDDHA', 'KONGHUCU', 'PROTESTAN'])

    elif field_norm in ['statusperkawinan', 'perkawinan', 'maritalstatus']:
        return any(s in val_upper for s in ['KAWIN', 'BELUM KAWIN', 'CERAI'])

    elif field_norm in ['pekerjaan', 'occupation']:
        jobs = ['BELUM', 'TIDAK BEKERJA', 'PELAJAR', 'MAHASISWA', 'PNS', 'SWASTA', 'WIRASWASTA', 'TNI', 'POLRI', 'BURUH', 'PETANI', 'PEDAGANG', 'IBU RUMAH TANGGA']
        return any(j in val_upper for j in jobs)

    elif field_norm in ['kewarganegaraan', 'nationality']:
        return any(k in val_upper for k in ['WNI', 'WNA', 'INDONESIA', 'IDN'])

    elif field_norm in ['expiryraw', 'expirydate', 'berlakuhingga']:
        return 'SEUMUR' in val_upper or any(c.isdigit() for c in val_upper)

    elif field_norm in ['alamat', 'address']:
        return len(val_upper) >= 3 and val_upper not in ['ALAMAT', 'ALAMAL', 'LAMAT']

    return True


def extract_ktp_fields_spatial(texts, boxes):
    """
    Memetakan kotak teks hasil OCR ke field KTP melalui GEOMETRI baris dan urutan
    baku field KTP Indonesia (NIK -> Nama -> TTL -> Kelamin -> Alamat -> RT/RW ->
    Kel/Desa -> Kecamatan -> Agama -> Status -> Pekerjaan -> WNI -> Berlaku).
    """
    def norm(s):
        return re.sub(r"[^A-Z]", "", s.upper())

    field_order = [
        ("NAMA", "full_name"),
        ("TEMPATTGLLAHIR", "dob_raw"),
        ("JENISKELAMIN", "gender_raw"),
        ("ALAMAT", None),
        ("RTRW", None),
        ("KELDESA", None),
        ("KECAMATAN", None),
        ("AGAMA", None),
        ("STATUSPERKAWINAN", None),
        ("PEKERJAAN", None),
        ("KEWARGANEGARAAN", "nationality_raw"),
        ("BERLAKUHINGGA", "expiry_raw"),
    ]

    n = len(texts)
    if n == 0 or boxes is None or len(boxes) != n:
        return {}

    nik_line_idx = None
    for i, t in enumerate(texts):
        digits = re.sub(r"[^0-9]", "", t.replace("O", "0").replace("I", "1").replace("L", "1"))
        if len(digits) == 16:
            nik_line_idx = i
            break

    # Kumpulkan index non-header, non-goldarah
    valid_indices = []
    for i in range(n):
        if looks_like_header(texts[i]) or looks_like_goldarah(texts[i]):
            continue
        valid_indices.append(i)

    # Klaster baris berdasarkan koordinat Y
    rows = []
    sorted_by_y = sorted(valid_indices, key=lambda idx: (boxes[idx][1] + boxes[idx][3]) / 2.0)

    for idx in sorted_by_y:
        cy = (boxes[idx][1] + boxes[idx][3]) / 2.0
        h = max(boxes[idx][3] - boxes[idx][1], 10)
        matched_row = None
        for row in rows:
            row_cys = [(boxes[i][1] + boxes[i][3]) / 2.0 for i in row]
            avg_cy = sum(row_cys) / len(row_cys)
            if abs(cy - avg_cy) < (h * 0.6):
                matched_row = row
                break
        if matched_row is not None:
            matched_row.append(idx)
        else:
            rows.append([idx])

    # Urutkan box dalam baris dari kiri ke kanan
    for row in rows:
        row.sort(key=lambda idx: boxes[idx][0])

    # Ekstraksi field setelah baris NIK
    result = {}
    nik_row_idx = None
    for r_idx, row in enumerate(rows):
        if nik_line_idx in row:
            nik_row_idx = r_idx
            break

    start_r = (nik_row_idx + 1) if nik_row_idx is not None else 0
    f_idx = 0

    for r_idx in range(start_r, len(rows)):
        if f_idx >= len(field_order):
            break
        row = rows[r_idx]
        target_label, target_key = field_order[f_idx]

        # Jika baris punya lebih dari 1 box: box pertama adalah label, box selanjutnya adalah value
        if len(row) >= 2:
            val_text = " ".join(texts[i] for i in row[1:]).strip()
            if target_key:
                result[target_key] = val_text
            f_idx += 1
        elif len(row) == 1:
            line_text = texts[row[0]].strip()
            # Cek apakah baris memuat teks value langsung
            if not norm(line_text).startswith(target_label[:4]):
                if target_key and target_key not in result:
                    result[target_key] = line_text
                f_idx += 1

    return result


def process_document(image_path: str) -> dict:
    """
    Eksekusi PaddleOCR khusus untuk dokumen KTP Indonesia.
    Mengembalikan dictionary data terstruktur hasil deteksi KTP.
    """
    if PaddleOCR is None:
        return {"success": False, "error": "Library paddleocr belum terinstal."}
    if not os.path.exists(image_path):
        return {"success": False, "error": f"File tidak ditemukan: {image_path}"}

    try:
        # Inisialisasi model OCR PP-OCRv5 deteksi + Latin recognition
        ocr = PaddleOCR(
            text_detection_model_name="PP-OCRv5_mobile_det",
            text_recognition_model_name="latin_PP-OCRv5_mobile_rec",
            use_doc_orientation_classify=True,
            use_doc_unwarping=True,
            use_textline_orientation=True,
            lang="en",
        )

        result = ocr.predict(image_path)
        if not result or not result[0]:
            return {"success": False, "error": "Hasil OCR kosong"}

        ocr_result = result[0]
        if "rec_texts" not in ocr_result or not ocr_result["rec_texts"]:
            return {"success": False, "error": "Teks tidak terdeteksi"}

        full_results = [text.upper() for text in ocr_result["rec_texts"]]
        full_text = " ".join(full_results)
        rec_boxes = ocr_result.get("rec_boxes")
        scores = ocr_result.get("rec_scores", [])
        avg_confidence = round(sum(scores) / len(scores) * 100, 1) if scores else 0.0

        data = {
            "success": True,
            "document_type": "KTP",
            "document_number": None,
            "full_name": None,
            "nationality": "IDN",
            "date_birth": None,
            "gender": None,
            "address": None,
            "occupation": None,
            "expiry_date": None,
            "raw_text": full_text,
            "confidence": avg_confidence,
        }

        # 1. Ekstraksi NIK 16 Digit
        m_nik = re.search(r"\b([0-9OI]{16})\b", full_text)
        if m_nik:
            data["document_number"] = m_nik.group(1).replace('O', '0').replace('I', '1').replace('L', '1')
        else:
            m_nik_key = re.search(r"N[I1][K\s]+([0-9OI\s]{10,20})", full_text, re.IGNORECASE)
            if m_nik_key:
                clean_nik = re.sub(r"[^0-9]", "", m_nik_key.group(1).replace('O', '0').replace('I', '1').replace('L', '1'))
                if len(clean_nik) >= 15:
                    data["document_number"] = clean_nik

        # 2. Ekstraksi Spasial KTP
        spatial = extract_ktp_fields_spatial(full_results, rec_boxes)
        if spatial.get("full_name"):
            sp_name = sanitize_name(spatial["full_name"])
            if sp_name and validate_value("Nama", sp_name):
                data["full_name"] = sp_name

        if spatial.get("gender_raw"):
            g = spatial["gender_raw"].upper()
            if "PEREMPUAN" in g or "WANITA" in g or "FEMALE" in g:
                data["gender"] = "Perempuan"
            elif "LAKI" in g or "PRIA" in g or "MALE" in g:
                data["gender"] = "Laki-laki"

        if spatial.get("dob_raw"):
            m_dob = re.search(r"(\d{2}[-/]\d{2}[-/]\d{4})", spatial["dob_raw"])
            if m_dob:
                data["date_birth"] = m_dob.group(1)

        # 3. Fallback Regex Lapisan Kedua
        ktp_labels = [
            r"NAMA", r"TEMPAT[/\s]*TGL\.?\s*LAHIR", r"JENIS\s*KELAMIN",
            r"GOL\.?\s*DARAH", r"ALAMAT", r"RT[/\s]*RW", r"KEL[/\s]*DESA",
            r"KECAMATAN", r"AGAMA", r"STATUS\s*PERKAWINAN", r"PEKERJAAN",
            r"KEWARGANEGARAAN", r"BERLAKU\s*HINGGA",
        ]

        def extract_field_regex(label_pattern):
            stop = "|".join(l for l in ktp_labels if l != label_pattern)
            m = re.search(rf"{label_pattern}\s*[:\.]?\s*([A-Z0-9,\.\-/\s]{{2,60}}?)(?=\s*(?:{stop})\b|$)", full_text, re.IGNORECASE)
            return m.group(1).strip(" .,:-") if m else None

        if not data["full_name"]:
            nama_cand = extract_field_regex(r"NAMA")
            if nama_cand:
                nama_cand = sanitize_name(nama_cand)
            if nama_cand and validate_value("Nama", nama_cand):
                data["full_name"] = nama_cand

        if not data["gender"]:
            m_g = re.search(r"(?:JENIS\s*KELAMIN|GENDER)\s*[:\.]?\s*(LAKI[\s\-]*LAKI|LAKILAKI|PEREMPUAN|WANITA|PRIA)", full_text, re.IGNORECASE)
            if m_g:
                data["gender"] = "Perempuan" if "PEREMPUAN" in m_g.group(1).upper() or "WANITA" in m_g.group(1).upper() else "Laki-laki"

        if not data["address"]:
            alamat_cand = extract_field_regex(r"ALAMAT")
            if alamat_cand and validate_value("Alamat", alamat_cand):
                data["address"] = alamat_cand

        if not data["occupation"]:
            pek = extract_field_regex(r"PEKERJAAN")
            if pek and validate_value("Pekerjaan", pek):
                data["occupation"] = pek

        # 4. Penentuan Tanggal Lahir & Gender dari 16 digit NIK (Standar UU RI)
        if data["document_number"] and len(str(data["document_number"])) == 16:
            nik = str(data["document_number"])
            day = int(nik[6:8])
            is_female = day > 40
            if is_female:
                day -= 40
            month = int(nik[8:10])
            year_suffix = int(nik[10:12])

            if not data["gender"]:
                data["gender"] = "Perempuan" if is_female else "Laki-laki"

            if not data["date_birth"] and (1 <= day <= 31) and (1 <= month <= 12):
                curr_year = datetime.datetime.now().year % 100
                y_full = (2000 + year_suffix) if year_suffix <= curr_year else (1900 + year_suffix)
                data["date_birth"] = f"{day:02d}-{month:02d}-{y_full}"

        return data

    except Exception as e:
        return {"success": False, "error": f"OCR Error: {str(e)}"}
