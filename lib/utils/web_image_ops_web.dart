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
