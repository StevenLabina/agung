import 'dart:typed_data';

/// Versi non-web: tidak tersedia. Pemanggil harus memakai jalur cadangan.
class NativeImageOps {
  const NativeImageOps._();

  static bool get available => false;

  static Future<Uint8List?> cropToGuideJpeg(
    Uint8List bytes, {
    required double boxAspect,
    required double guideScale,
    required double cropMargin,
    required bool mirror,
    required int maxSide,
    double quality = 0.88,
  }) async =>
      null;

  static Future<Uint8List?> resizeJpeg(
    Uint8List bytes, {
    required int maxSide,
    double quality = 0.85,
  }) async =>
      null;

  static Future<Uint8List?> cropRectJpeg(
    Uint8List bytes, {
    required List<double> rect,
    required int maxSide,
    double quality = 0.92,
  }) async =>
      null;

  static Future<List<double>?> detectCardRect(Uint8List bytes) async => null;
}
