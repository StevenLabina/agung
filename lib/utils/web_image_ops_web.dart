// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

/// Versi web: memakai <img> + <canvas> milik browser.
///
/// - Decode foto dilakukan browser (tidak memblokir UI seperti package:image).
/// - Rotasi EXIF diterapkan otomatis oleh browser saat foto dimuat.
/// - Hasil selalu JPEG. Mengembalikan null kalau gagal (pemanggil memakai cadangan).
class NativeImageOps {
  const NativeImageOps._();

  static bool get available => true;

  /// Potong ke area kotak panduan lalu perkecil ke maks [maxSide] px.
  /// Logika crop sama dengan `KtpCameraViewState.cropToGuide`.
  static Future<Uint8List?> cropToGuideJpeg(
    Uint8List bytes, {
    required double boxAspect,
    required double guideScale,
    required double cropMargin,
    required bool mirror,
    required int maxSide,
    double quality = 0.88,
  }) {
    return _render(
      bytes,
      mirror: mirror,
      quality: quality,
      plan: (w, h) {
        final wd = w.toDouble();
        final hd = h.toDouble();

        double visW, visH;
        if (wd / hd > boxAspect) {
          visH = hd;
          visW = hd * boxAspect;
        } else {
          visW = wd;
          visH = wd / boxAspect;
        }

        final scale = math.min(1.0, guideScale * (1 + 2 * cropMargin));
        final cw = (visW * scale).clamp(1.0, wd).toDouble();
        final ch = (visH * scale).clamp(1.0, hd).toDouble();
        final x = ((wd - cw) / 2).round();
        final y = ((hd - ch) / 2).round();
        return _fit(x, y, cw.round(), ch.round(), maxSide);
      },
    );
  }

  /// Perkecil seluruh foto ke maks [maxSide] px (sisi terpanjang), simpan JPEG.
  static Future<Uint8List?> resizeJpeg(
    Uint8List bytes, {
    required int maxSide,
    double quality = 0.85,
  }) {
    return _render(
      bytes,
      mirror: false,
      quality: quality,
      plan: (w, h) => _fit(0, 0, w, h, maxSide),
    );
  }

  /// Potong foto ke persegi panjang [left, top, right, bottom] (piksel foto,
  /// rotasi EXIF sudah diterapkan), perkecil ke maks [maxSide] px, simpan JPEG.
  static Future<Uint8List?> cropRectJpeg(
    Uint8List bytes, {
    required List<double> rect,
    required int maxSide,
    double quality = 0.92,
  }) {
    return _render(
      bytes,
      mirror: false,
      quality: quality,
      plan: (w, h) {
        final l = rect[0].round().clamp(0, w - 1).toInt();
        final t = rect[1].round().clamp(0, h - 1).toInt();
        final r = rect[2].round().clamp(l + 1, w).toInt();
        final b = rect[3].round().clamp(t + 1, h).toInt();
        return _fit(l, t, r - l, b - t, maxSide);
      },
    );
  }

  /// Menebak posisi KTP di dalam foto (untuk kotak awal dialog crop).
  ///
  /// Mengembalikan [kiri, atas, kanan, bawah] dalam piksel foto (ukuran
  /// alami [bytes], rotasi EXIF sudah diterapkan), atau null kalau tidak yakin
  /// (KTP tidak terpisah jelas dari latar, atau sudah memenuhi hampir seluruh
  /// foto). Hanya tebakan: pengguna tetap bisa menggeser kotaknya.
  ///
  /// Cara kerja: foto diperkecil, warna latar ditaksir dari pinggir foto,
  /// piksel yang warnanya jauh dari latar dianggap bagian KTP, lalu diambil
  /// gumpalan terbesar yang bentuknya cukup "penuh" seperti kartu.
  static Future<List<double>?> detectCardRect(Uint8List bytes) async {
    String? url;
    try {
      url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      final img = html.ImageElement();
      final loaded = Completer<void>();
      img.onLoad.first.then((_) {
        if (!loaded.isCompleted) loaded.complete();
      });
      img.onError.first.then((_) {
        if (!loaded.isCompleted) {
          loaded.completeError(StateError('Browser gagal memuat gambar'));
        }
      });
      img.src = url;
      await loaded.future.timeout(const Duration(seconds: 20));

      final w = img.naturalWidth;
      final h = img.naturalHeight;
      if (w <= 0 || h <= 0) return null;

      // Perkecil ke maks 160 px supaya cepat.
      const maxDim = 160;
      final k = math.min(1.0, maxDim / math.max(w, h));
      final sw = math.max(8, (w * k).round());
      final sh = math.max(8, (h * k).round());
      final canvas = html.CanvasElement(width: sw, height: sh);
      final ctx = canvas.context2D;
      ctx.imageSmoothingEnabled = true;
      ctx.drawImageScaled(img, 0, 0, sw, sh);
      final data = ctx.getImageData(0, 0, sw, sh).data;

      final box = _findCardBox(data, sw, sh);
      if (box == null) return null;

      // Margin kecil supaya tepi KTP tidak terpotong.
      final mx = (box[2] - box[0] + 1) * 0.03;
      final my = (box[3] - box[1] + 1) * 0.03;
      final l = ((box[0] - mx) / sw * w).clamp(0, w - 2).toDouble();
      final t = ((box[1] - my) / sh * h).clamp(0, h - 2).toDouble();
      final r = ((box[2] + 1 + mx) / sw * w).clamp(l + 1, w).toDouble();
      final b = ((box[3] + 1 + my) / sh * h).clamp(t + 1, h).toDouble();
      return [l, t, r, b];
    } catch (e, stack) {
      debugPrint('detectCardRect gagal: $e\n$stack');
      return null;
    } finally {
      if (url != null) html.Url.revokeObjectUrl(url);
    }
  }

  /// Mengembalikan [x0, y0, x1, y1] (indeks piksel pada grid kecil) atau null.
  static List<int>? _findCardBox(List<int> rgba, int sw, int sh) {
    final n = sw * sh;

    // 1) Warna latar = median piksel di cincin pinggir foto (tebal 6%).
    final ring = math.max(2, (math.min(sw, sh) * 0.06).round());
    final rs = <int>[], gs = <int>[], bs = <int>[];
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < sw; x++) {
        if (x < ring || y < ring || x >= sw - ring || y >= sh - ring) {
          final i = (y * sw + x) * 4;
          rs.add(rgba[i]);
          gs.add(rgba[i + 1]);
          bs.add(rgba[i + 2]);
        }
      }
    }
    int median(List<int> v) {
      v.sort();
      return v[v.length ~/ 2];
    }

    final br = median(rs), bg = median(gs), bb = median(bs);

    // 2) Jarak warna tiap piksel dari latar (L1), lalu haluskan 3x3.
    final raw = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      raw[i] = (rgba[o] - br).abs() + (rgba[o + 1] - bg).abs() +
          (rgba[o + 2] - bb).abs();
    }
    final dist = List<int>.filled(n, 0);
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < sw; x++) {
        var sum = 0, c = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= sh) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= sw) continue;
            sum += raw[yy * sw + xx];
            c++;
          }
        }
        dist[y * sw + x] = sum ~/ c;
      }
    }

    // 3) Ambang Otsu pada histogram jarak (ember lebar 8).
    final hist = List<int>.filled(97, 0);
    for (final d in dist) {
      hist[math.min(96, d ~/ 8)]++;
    }
    final total = n;
    var sumAll = 0;
    for (var i = 0; i < hist.length; i++) {
      sumAll += i * hist[i];
    }
    var wB = 0, sumB = 0;
    var bestVar = -1.0, bestT = 0;
    for (var t = 0; t < hist.length; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sumAll - sumB) / wF;
      final v = wB * wF * (mB - mF) * (mB - mF);
      if (v > bestVar) {
        bestVar = v;
        bestT = t;
      }
    }
    final thr = math.max(40, (bestT + 1) * 8);

    // 4) Gumpalan (4-tetangga) dari piksel "bukan latar". Yang dipilih adalah
    //    gumpalan terbesar yang tidak menempel ke tepi foto dan bentuknya
    //    seperti kartu (benda gelap di pinggir foto, bayangan, dll. terbuang).
    final mask = List<bool>.generate(n, (i) => dist[i] > thr);
    final seen = List<bool>.filled(n, false);
    final stack = List<int>.filled(n, 0);
    var bestCount = 0;
    List<int>? best;
    for (var s = 0; s < n; s++) {
      if (!mask[s] || seen[s]) continue;
      var sp = 0;
      stack[sp++] = s;
      seen[s] = true;
      var count = 0;
      var x0 = sw, y0 = sh, x1 = 0, y1 = 0;
      while (sp > 0) {
        final p = stack[--sp];
        final x = p % sw, y = p ~/ sw;
        count++;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
        if (x > 0 && mask[p - 1] && !seen[p - 1]) {
          seen[p - 1] = true;
          stack[sp++] = p - 1;
        }
        if (x < sw - 1 && mask[p + 1] && !seen[p + 1]) {
          seen[p + 1] = true;
          stack[sp++] = p + 1;
        }
        if (y > 0 && mask[p - sw] && !seen[p - sw]) {
          seen[p - sw] = true;
          stack[sp++] = p - sw;
        }
        if (y < sh - 1 && mask[p + sw] && !seen[p + sw]) {
          seen[p + sw] = true;
          stack[sp++] = p + sw;
        }
      }

      // Menempel ke tepi foto: bukan KTP utuh.
      if (x0 == 0 || y0 == 0 || x1 == sw - 1 || y1 == sh - 1) continue;

      final boxW = x1 - x0 + 1, boxH = y1 - y0 + 1;
      final areaFrac = boxW * boxH / n;
      final fill = count / (boxW * boxH);
      final aspect = boxW / boxH;
      if (areaFrac < 0.04 || areaFrac > 0.90) continue; // noise / terlalu besar
      if (fill < 0.55) continue; // bentuk bukan kartu (tekstur latar)
      if (aspect < 0.7 || aspect > 3.2) continue;
      if (count > bestCount) {
        bestCount = count;
        best = [x0, y0, x1, y1];
      }
    }
    return best;
  }

  static _Plan _fit(int sx, int sy, int sw, int sh, int maxSide) {
    final ratio = math.min(1.0, maxSide / math.max(sw, sh));
    return _Plan(
      sx: sx,
      sy: sy,
      sw: sw,
      sh: sh,
      dw: math.max(1, (sw * ratio).round()),
      dh: math.max(1, (sh * ratio).round()),
    );
  }

  static Future<Uint8List?> _render(
    Uint8List bytes, {
    required _Plan Function(int w, int h) plan,
    required bool mirror,
    required double quality,
  }) async {
    String? url;
    try {
      url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));

      final img = html.ImageElement();
      final loaded = Completer<void>();
      img.onLoad.first.then((_) {
        if (!loaded.isCompleted) loaded.complete();
      });
      img.onError.first.then((_) {
        if (!loaded.isCompleted) {
          loaded.completeError(StateError('Browser gagal memuat gambar'));
        }
      });
      img.src = url;
      await loaded.future.timeout(const Duration(seconds: 20));

      // Ukuran sudah memperhitungkan rotasi EXIF.
      final w = img.naturalWidth;
      final h = img.naturalHeight;
      if (w <= 0 || h <= 0) return null;

      final p = plan(w, h);
      final canvas = html.CanvasElement(width: p.dw, height: p.dh);
      final ctx = canvas.context2D;
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = 'high';
      if (mirror) {
        ctx.translate(p.dw, 0);
        ctx.scale(-1, 1);
      }
      ctx.drawImageScaledFromSource(
        img,
        p.sx,
        p.sy,
        p.sw,
        p.sh,
        0,
        0,
        p.dw,
        p.dh,
      );

      final dataUrl = canvas.toDataUrl('image/jpeg', quality);
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (e, stack) {
      debugPrint('NativeImageOps gagal: $e\n$stack');
      return null;
    } finally {
      if (url != null) html.Url.revokeObjectUrl(url);
    }
  }
}

class _Plan {
  const _Plan({
    required this.sx,
    required this.sy,
    required this.sw,
    required this.sh,
    required this.dw,
    required this.dh,
  });

  final int sx, sy, sw, sh; // area sumber (piksel foto asli)
  final int dw, dh; // ukuran hasil
}
