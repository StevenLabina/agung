import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum PhotoIssue { unreadable, blurry, tooDark, tooBright, glare }

/// Hasil pengecekan kualitas foto sebelum dikirim ke API OCR.
class PhotoQuality {
  const PhotoQuality({
    required this.sharpness,
    required this.textSharpness,
    required this.brightness,
    required this.glareRatio,
    required this.issues,
  });

  /// Variansi Laplacian pada gambar 480px. Makin besar makin tajam.
  /// Mudah "tertipu" foto goyang (tepi searah gerakan tetap tajam), jadi hanya
  /// dipakai sebagai pengaman tambahan.
  final double sharpness;

  /// Ketajaman di area teks KTP: min(variansi gradien X, gradien Y) dibagi
  /// kontras². Arah terburuk yang dihitung, jadi foto goyang ikut tertangkap.
  /// Tidak bergantung terang/gelap. Kira-kira: tajam ≈ 0.5, buram/goyang < 0.1.
  final double textSharpness;

  /// Rata-rata kecerahan 0-255.
  final double brightness;

  /// Porsi piksel yang hampir putih (>= 250), 0-1.
  final double glareRatio;

  final Set<PhotoIssue> issues;

  bool get ok => issues.isEmpty;

  /// Pesan untuk pengguna (masalah paling penting dulu).
  String get message {
    if (issues.contains(PhotoIssue.unreadable)) {
      return 'Foto tidak dapat dibaca. Coba ambil ulang.';
    }
    if (issues.contains(PhotoIssue.blurry)) {
      return 'Foto buram atau goyang. Tahan HP diam, tunggu fokus, lalu ambil lagi.';
    }
    if (issues.contains(PhotoIssue.glare)) {
      return 'Ada pantulan cahaya di kartu. Miringkan kartu sedikit lalu ambil lagi.';
    }
    if (issues.contains(PhotoIssue.tooDark)) {
      return 'Foto terlalu gelap. Cari tempat yang lebih terang.';
    }
    if (issues.contains(PhotoIssue.tooBright)) {
      return 'Foto terlalu terang. Kurangi cahaya langsung ke kartu.';
    }
    return 'Foto baik.';
  }
}

class PhotoTools {
  /// Kalibrasi (Okt 2026, Samsung S21 FE + webcam laptop):
  /// - textSharpness: HP tajam ≈ 0.48-0.54, HP goyang ≈ 0.06, webcam ≈ 0.08 -> ambang 0.2
  /// - sharpness (Laplacian): HP tajam ≈ 6165, webcam ≈ 62 -> ambang 300
  /// Perlu dicek lagi di HP murah. Area teks diasumsikan kartu memenuhi foto
  /// (hasil crop kotak panduan); untuk foto dari galeri hasilnya kurang presisi.
  static PhotoQuality analyze(
    Uint8List bytes, {
    double minSharpness = 300,
    double minTextSharpness = 0.2,
    double minBrightness = 70,
    double maxBrightness = 235,
    double maxGlareRatio = 0.08,
    int analysisWidth = 480,
  }) {
    const unreadable = PhotoQuality(
      sharpness: 0,
      textSharpness: 0,
      brightness: 0,
      glareRatio: 0,
      issues: {PhotoIssue.unreadable},
    );

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return unreadable;

    // Selalu skala ke lebar yang sama supaya skor bisa dibandingkan antar foto.
    final small = img.copyResize(decoded, width: analysisWidth);
    final w = small.width;
    final h = small.height;
    if (w < 3 || h < 3) return unreadable;

    final lum = Float64List(w * h);
    var sum = 0.0;
    var glare = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = small.getPixel(x, y).luminance.toDouble();
        lum[y * w + x] = v;
        sum += v;
        if (v >= 250) glare++;
      }
    }
    final brightness = sum / (w * h);
    final glareRatio = glare / (w * h);

    // Variansi Laplacian (kernel 4-tetangga): ukuran ketajaman standar.
    var lapSum = 0.0;
    var lapSq = 0.0;
    var n = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final l = 4 * lum[i] - lum[i - w] - lum[i + w] - lum[i - 1] - lum[i + 1];
        lapSum += l;
        lapSq += l * l;
        n++;
      }
    }
    final mean = lapSum / n;
    final sharpness = math.max(0.0, lapSq / n - mean * mean);
    final textSharpness = _textZoneSharpness(lum, w, h);

    final issues = <PhotoIssue>{};
    if (sharpness < minSharpness || textSharpness < minTextSharpness) {
      issues.add(PhotoIssue.blurry);
    }
    if (brightness < minBrightness) issues.add(PhotoIssue.tooDark);
    if (brightness > maxBrightness) issues.add(PhotoIssue.tooBright);
    if (glareRatio > maxGlareRatio) issues.add(PhotoIssue.glare);

    return PhotoQuality(
      sharpness: sharpness,
      textSharpness: textSharpness,
      brightness: brightness,
      glareRatio: glareRatio,
      issues: issues,
    );
  }

  /// Area kolom teks KTP (kiri, tanpa pas foto): x 3%-62%, y 15%-90%.
  /// Skor = min(var(gx), var(gy)) / (std_area² + eps).
  static double _textZoneSharpness(Float64List lum, int w, int h) {
    final x0 = (w * 0.03).floor(), x1 = (w * 0.62).floor();
    final y0 = (h * 0.15).floor(), y1 = (h * 0.90).floor();
    if (x1 - x0 < 4 || y1 - y0 < 4) return 0;

    var s = 0.0, s2 = 0.0;
    var gxS = 0.0, gxS2 = 0.0, gyS = 0.0, gyS2 = 0.0;
    var n = 0, m = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final v = lum[y * w + x];
        s += v;
        s2 += v * v;
        n++;
        if (x > x0 && x < x1 - 1 && y > y0 && y < y1 - 1) {
          final gx = lum[y * w + x + 1] - lum[y * w + x - 1];
          final gy = lum[(y + 1) * w + x] - lum[(y - 1) * w + x];
          gxS += gx;
          gxS2 += gx * gx;
          gyS += gy;
          gyS2 += gy * gy;
          m++;
        }
      }
    }
    if (n == 0 || m == 0) return 0;
    final mean = s / n;
    final contrastSq = math.max(0.0, s2 / n - mean * mean);
    final varGx = math.max(0.0, gxS2 / m - (gxS / m) * (gxS / m));
    final varGy = math.max(0.0, gyS2 / m - (gyS / m) * (gyS / m));
    return math.min(varGx, varGy) / (contrastSq + 1e-6);
  }

  /// Dari beberapa jepretan, pilih yang paling tajam (cara murah menghindari foto goyang).
  static Uint8List pickSharpest(List<Uint8List> frames) {
    assert(frames.isNotEmpty);
    var best = frames.first;
    var bestScore = -1.0;
    for (final f in frames) {
      final s = analyze(f).textSharpness;
      if (s > bestScore) {
        bestScore = s;
        best = f;
      }
    }
    return best;
  }

  /// Siapkan foto untuk diunggah: putar sesuai EXIF (foto kamera HP sering "miring"
  /// di metadata), kecilkan sisi terpanjang, lalu simpan sebagai JPEG.
  static Uint8List prepareForUpload(
    Uint8List bytes, {
    int maxSide = 1600,
    int quality = 88,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    var image = img.bakeOrientation(decoded);
    final longest = math.max(image.width, image.height);
    if (longest > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide)
          : img.copyResize(image, height: maxSide);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}
