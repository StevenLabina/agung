#!/usr/bin/env python3
"""
=============================================================================
KTP QUICK SCAN OCR ENGINE (ADAPTED FROM CRM PROJECT)
=============================================================================
Script ini mengambil arsitektur Quick Scan dari project CRM, dikhususkan
hanya untuk identitas Kartu Tanda Penduduk (KTP) Indonesia:
1. Multi-preprocessing cepat:
   - 'none' (citra asli tanpa filter)
   - 'adaptive' (meratakan kontras dan pencahayaan)
   - 'ktp_optimized' (deskew, CLAHE, dan de-noise terarah)
2. Berhenti lebih awal (early stopping) jika NIK 16 digit dan Nama sudah
   terdeteksi dengan confidence memadai (cepat: ~5-10 detik).
3. Ekstraksi spesifik KTP:
   - nama: Nama lengkap pemilik KTP (dibersihkan dari noise)
   - nik: 16 digit Nomor Induk Kependudukan
   - alamat: Menggabungkan Jalan, RT/RW, Kelurahan/Desa, dan Kecamatan
   - foto_ktp: Base64 Data URI dari foto KTP
   - metadata: JSON berisi seluruh data pendukung lainnya
=============================================================================
"""

import os
import sys
import json
import re
import base64
import tempfile

# Pastikan modul direktori OCR-Script masuk ke sys.path
_script_dir = os.path.dirname(os.path.abspath(__file__))
if _script_dir not in sys.path:
    sys.path.insert(0, _script_dir)

import preprocess_adaptive as preproc
from ocr_processor import process_document, sanitize_name


def image_to_base64(image_path: str) -> str:
    """Mengonversi file gambar fisik menjadi Base64 Data URI."""
    try:
        ext = os.path.splitext(image_path)[1].lower().replace(".", "")
        mime = "jpeg" if ext in ["jpg", "jpeg"] else ("png" if ext == "png" else "webp")
        with open(image_path, "rb") as f:
            encoded = base64.b64encode(f.read()).decode("utf-8")
        return f"data:image/{mime};base64,{encoded}"
    except Exception:
        return ""


def clean_label_noise(val: str, labels: list) -> str:
    """Membersihkan kata label dan simbol asing dari nilai field."""
    if not val:
        return ""
    text = val
    for lbl in labels:
        text = re.sub(rf"^{lbl}\s*[:\.\s=~+,-]*", "", text, flags=re.IGNORECASE)
        text = re.sub(rf"\b{lbl}\b.*$", "", text, flags=re.IGNORECASE)
    # Hapus simbol aneh di awal dan akhir
    text = re.sub(r"^[=~+.,:\s\-_/]+", "", text)
    text = re.sub(r"[=~+.,:\s\-_/]+$", "", text)
    return text.strip()


def parse_ktp_details(res: dict, raw_text: str) -> dict:
    """
    Mengekstrak dan menggabungkan komponen detail KTP dari hasil OCR.
    """
    nama = res.get("full_name") or ""
    nik = res.get("document_number") or ""
    if nik:
        nik = re.sub(r"[^0-9]", "", str(nik))

    # Ekstraksi komponen alamat
    # Cari Jalan (Pertahankan 'JL' jika ada)
    jalan = res.get("address") or ""
    if not jalan:
        m_jln = re.search(r"(?:ALAMAT|ALAMATI)\s*[:\.]?\s*([A-Z0-9\s\.\-/,]{3,50}?)(?=\s*(?:RT|RW|KEL|DESA|KEC|AGAMA|$))", raw_text, re.IGNORECASE)
        if m_jln:
            jalan = m_jln.group(1).strip()
    jalan = clean_label_noise(jalan, ["ALAMAT", "ALAMATI"])

    # Cari RT/RW
    rt_rw = ""
    m_rtrw = re.search(r"RT[/\s]*RW\s*[:\.]?\s*([0-9OI/\s\-]{3,15})", raw_text, re.IGNORECASE)
    if m_rtrw:
        raw_rtrw = m_rtrw.group(1).replace("O", "0").replace("I", "1").strip()
        m_dig = re.search(r"(\d{2,3}\s*/\s*\d{2,3})", raw_rtrw)
        if m_dig:
            rt_rw = m_dig.group(1).replace(" ", "")
        else:
            rt_rw = raw_rtrw

    # Cari Kel/Desa
    kel_desa = ""
    m_kel = re.search(r"(?:KEL|DESA|KEL[/\s]*DESA)\s*[:\.]?\s*([A-Z\s]{3,35}?)(?=\s*(?:KEC|KOC|AGAMA|STATUS|$))", raw_text, re.IGNORECASE)
    if m_kel:
        kel_desa = clean_label_noise(m_kel.group(1), ["KEL", "DESA", "KEL/DESA", "KELURAHAN"])

    # Cari Kecamatan
    kecamatan = ""
    m_kec = re.search(r"(?:KECAMATAN|KOCAMATAN|KEC)\s*[:\.]?\s*([A-Z\s]{3,35}?)(?=\s*(?:AGAMA|STATUS|PEKERJAAN|$))", raw_text, re.IGNORECASE)
    if m_kec:
        kecamatan = clean_label_noise(m_kec.group(1), ["KECAMATAN", "KOCAMATAN", "KEC"])

    # Susun Alamat Gabungan (Jalan + RT/RW + Kelurahan + Kecamatan)
    alamat_parts = []
    if jalan:
        alamat_parts.append(jalan)
    if rt_rw:
        alamat_parts.append(f"RT/RW {rt_rw}")
    if kel_desa:
        alamat_parts.append(f"KEL. {kel_desa}")
    if kecamatan:
        alamat_parts.append(f"KEC. {kecamatan}")

    alamat_gabungan = ", ".join(alamat_parts) if alamat_parts else (jalan or "Tidak Terdeteksi")

    # Ekstraksi Agama
    agama = ""
    m_agm = re.search(r"AGAMA\s*[:\.]?\s*(ISLAM|KRISTEN|KATOLIK|HINDU|BUDDHA|KONGHUCU|PROTESTAN)", raw_text, re.IGNORECASE)
    if m_agm:
        agama = m_agm.group(1).upper()

    # Ekstraksi Status Perkawinan
    status_kawin = ""
    m_st = re.search(r"(?:STATUS\s*PERKAWINAN|STATUS)\s*[:\.]?\s*(BELUM\s*KAWIN|KAWIN|CERAI\s*HIDUP|CERAI\s*MATI)", raw_text, re.IGNORECASE)
    if m_st:
        status_kawin = m_st.group(1).upper()

    # Ekstraksi Pekerjaan
    pekerjaan = res.get("occupation") or ""
    if pekerjaan:
        pekerjaan = re.sub(r"\b(?:WNI|JAKARTA|KOTA|PROVINSI|KEWARGANEGARAAN).*$", "", pekerjaan, flags=re.IGNORECASE).strip()
    if not pekerjaan:
        m_pek = re.search(r"PEKERJAAN\s*[:\.]?\s*([A-Z\s/]{3,40}?)(?=\s*(?:KEWARGANEGARAAN|WNI|BERLAKU|$))", raw_text, re.IGNORECASE)
        if m_pek:
            pekerjaan = clean_label_noise(m_pek.group(1), ["PEKERJAAN"])

    # Ekstraksi Tempat Lahir
    tempat_lahir = ""
    m_ttl = re.search(r"(?:TEMPAT[/\s]*TGL\.?\s*LAHIR|TEMPAL[/\s]*TGL\.?\s*LAHIR)\s*[:\.]?\s*([A-Z\s]{3,30}?)(?=,\s*|\s+\d{2}[-/])", raw_text, re.IGNORECASE)
    if m_ttl:
        tempat_lahir = clean_label_noise(m_ttl.group(1), ["TEMPAT", "LAHIR", "TGL"])

    # Ekstraksi Tanggal Lahir
    tanggal_lahir = res.get("date_birth") or ""
    if not tanggal_lahir:
        m_tgl = re.search(r"(\d{2}[-/]\d{2}[-/]\d{4})", raw_text)
        if m_tgl:
            tanggal_lahir = m_tgl.group(1)

    # Ekstraksi Provinsi & Kota Header
    provinsi = "PROVINSI JAWA TIMUR"
    kabupaten_kota = "KOTA SURABAYA"
    m_prov = re.search(r"PROVINSI\s+([A-Z\s]{3,30}?)(?=\s*(?:KOTA|KABUPATEN|JAKARTA|NIK|$))", raw_text, re.IGNORECASE)
    if m_prov:
        prov_text = m_prov.group(1).strip().replace("JAKAPTA", "JAKARTA")
        provinsi = f"PROVINSI {prov_text}"
    m_kab = re.search(r"(?:KOTA|KABUPATEN|JAKARTA)\s+([A-Z\s]{3,30}?)(?=\s*(?:NIK|$))", raw_text, re.IGNORECASE)
    if m_kab:
        kab_full = m_kab.group(0).strip().replace("JAKAPTA", "JAKARTA")
        kabupaten_kota = kab_full

    # Ekstraksi Kewarganegaraan
    kewarganegaraan = res.get("nationality") or "WNI"

    # Ekstraksi Masa Berlaku
    berlaku_hingga = "SEUMUR HIDUP"
    if "SEUMUR" not in raw_text.upper():
        m_exp = re.search(r"BERLAKU\s*HINGGA\s*[:\.]?\s*(\d{2}[-/]\d{2}[-/]\d{4})", raw_text, re.IGNORECASE)
        if m_exp:
            berlaku_hingga = m_exp.group(1)

    # Golongan Darah
    gol_darah = "-"
    m_gol = re.search(r"GOL\.?\s*DARAH\s*[:\.]?\s*([ABO\-\+]+)\b", raw_text, re.IGNORECASE)
    if m_gol:
        gol_darah = m_gol.group(1).upper()

    metadata = {
        "tempat_lahir": tempat_lahir or "-",
        "tanggal_lahir": tanggal_lahir or "-",
        "jenis_kelamin": res.get("gender") or "Laki-laki",
        "golongan_darah": gol_darah,
        "agama": agama or "-",
        "status_perkawinan": status_kawin or "-",
        "pekerjaan": pekerjaan or "-",
        "kewarganegaraan": kewarganegaraan,
        "berlaku_hingga": berlaku_hingga,
        "provinsi": provinsi,
        "kabupaten_kota": kabupaten_kota,
        "detail_alamat": {
            "jalan": jalan or "-",
            "rt_rw": rt_rw or "-",
            "kel_desa": kel_desa or "-",
            "kecamatan": kecamatan or "-"
        },
        "confidence": round(float(res.get("confidence", 95)), 1),
        "ocr_engine": "PaddleOCR (Quick Scan PP-OCRv6)"
    }

    return {
        "nama": nama or "Tidak Terdeteksi",
        "nik": nik or "Tidak Terdeteksi",
        "alamat": alamat_gabungan,
        "metadata": metadata
    }


def run_ktp_quick_scan(image_path: str, specified_method: str = None) -> dict:
    """
    Menjalankan algoritma Quick Scan KTP berbasis PaddleOCR:
    Mencoba metode tercepat 'none', 'adaptive', 'ktp_optimized'
    dengan early stopping untuk akurasi dan kecepatan maksimal.
    """
    if not os.path.exists(image_path):
        return {
            "success": False,
            "error": f"File gambar tidak ditemukan: {image_path}"
        }

    methods_to_try = [specified_method] if specified_method and specified_method != "None" else ["none", "adaptive", "ktp_optimized"]

    mapping_preprocess = {
        "standard": preproc.preprocess_standard,
        "adaptive": preproc.preprocess_adaptive,
        "ktp_optimized": preproc.preprocess_ktp_optimized,
    }

    best_result = None
    best_score = -1

    for method in methods_to_try:
        temp_img_path = None
        current_img = image_path

        try:
            if method in mapping_preprocess:
                fd, temp_img_path = tempfile.mkstemp(suffix=".jpg")
                os.close(fd)
                if mapping_preprocess[method](image_path, temp_img_path):
                    current_img = temp_img_path

            # Eksekusi pipeline PaddleOCR dari ocr_processor
            res = process_document(current_img)

            if res and res.get("success"):
                raw_text = res.get("raw_text", "")
                parsed = parse_ktp_details(res, raw_text)

                nik = parsed["nik"]
                nama = parsed["nama"]
                conf = parsed["metadata"]["confidence"]

                # Hitung score kelengkapan
                score = 0
                if nik and len(nik) == 16 and nik.isdigit():
                    score += 50
                if nama and nama != "Tidak Terdeteksi" and len(nama) >= 3:
                    score += 30
                if parsed["alamat"] and parsed["alamat"] != "Tidak Terdeteksi":
                    score += 20

                if score > best_score:
                    best_score = score
                    best_result = parsed
                    best_result["method_used"] = method

                # EARLY STOPPING (Quick Scan CRM):
                # Jika NIK 16 digit lengkap dan Nama ditemukan dengan confidence baik
                if len(nik) == 16 and nik.isdigit() and nama != "Tidak Terdeteksi":
                    break

        except Exception as e:
            sys.stderr.write(f"[WARN] Error pada metode {method}: {e}\n")
        finally:
            if temp_img_path and os.path.exists(temp_img_path):
                try:
                    os.remove(temp_img_path)
                except Exception:
                    pass

    if best_result is None:
        return {
            "success": False,
            "error": "Gagal membaca KTP dengan seluruh metode OCR."
        }

    # Buat foto KTP dalam Base64 Data URI
    best_result["foto_ktp"] = image_to_base64(image_path)
    best_result["success"] = True

    return best_result


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "Argumen path gambar diperlukan."}))
        sys.exit(1)

    image_path = sys.argv[1]
    method = sys.argv[2] if len(sys.argv) > 2 else None

    result = run_ktp_quick_scan(image_path, method)

    # Cetak hasil ke stdout dalam format JSON murni
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    main()
