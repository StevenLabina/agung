import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum PhotoIssue { unreadable, blurry, tooDark, tooBright, glare }

/// Hasil pengecekan kualitas foto sebelum dikirim ke API OCR.
class PhotoQuality {
  const PhotoQuality({
    required this.sharpness,
    required this.brightness,
    required this.glareRatio,
    required this.issues,
  });

  /// Variansi Laplacian pada gambar 480px. Makin besar makin tajam.
  final double sharpness;

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
      return 'Foto terlalu buram. Dekatkan kartu, tunggu fokus, lalu ambil lagi.';
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
  /// Nilai awal ini baru dikalibrasi kasar (foto KTP tajam ≈ 2500, preview webcam buram ≈ 30).
  /// Kalibrasi ulang dengan foto asli dari HP sebelum dipakai sungguhan.
  static PhotoQuality analyze(
    Uint8List bytes, {
    double minSharpness = 150,
    double minBrightness = 70,
    double maxBrightness = 235,
    double maxGlareRatio = 0.08,
    int analysisWidth = 480,
  }) {
    const unreadable = PhotoQuality(
      sharpness: 0,
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

    final issues = <PhotoIssue>{};
    if (sharpness < minSharpness) issues.add(PhotoIssue.blurry);
    if (brightness < minBrightness) issues.add(PhotoIssue.tooDark);
    if (brightness > maxBrightness) issues.add(PhotoIssue.tooBright);
    if (glareRatio > maxGlareRatio) issues.add(PhotoIssue.glare);

    return PhotoQuality(
      sharpness: sharpness,
      brightness: brightness,
      glareRatio: glareRatio,
      issues: issues,
    );
  }

  /// Dari beberapa jepretan, pilih yang paling tajam (cara murah menghindari foto goyang).
  static Uint8List pickSharpest(List<Uint8List> frames) {
    assert(frames.isNotEmpty);
    var best = frames.first;
    var bestScore = -1.0;
    for (final f in frames) {
      final s = analyze(f).sharpness;
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
