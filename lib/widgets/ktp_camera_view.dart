import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:iuran_rt_web/utils/web_image_ops.dart';

/// Kamera live dengan kotak panduan KTP.
///
/// - Memakai kamera belakang bila ada (HP), kalau tidak kamera pertama (laptop).
/// - Preview mengisi penuh area (cover), area di luar kotak digelapkan.
/// - [capture] memotong foto sesuai kotak kuning (+ sedikit margin), membalik foto
///   kamera depan di web (mirror), lalu mengecilkan ke maks [maxSide] px (JPEG).
///
/// Taruh di dalam widget berukuran tetap (mis. AspectRatio rasio KTP).
/// Panggil foto lewat GlobalKey:
///   final key = GlobalKey<KtpCameraViewState>();
///   KtpCameraView(key: key, onCaptured: (bytes) {...});
///   key.currentState?.capture();
class KtpCameraView extends StatefulWidget {
  const KtpCameraView({
    super.key,
    required this.onCaptured,
    this.onError,
    this.guideScale = 0.86,
    this.cropMargin = 0.04,
    this.maxSide = 1080,
    this.hint = 'Posisikan seluruh KTP di dalam kotak kuning',
  });

  /// Dipanggil dengan JPEG hasil crop.
  final ValueChanged<Uint8List> onCaptured;

  /// Dipanggil kalau kamera tidak bisa dipakai / gagal memotret.
  final ValueChanged<String>? onError;

  /// Ukuran kotak panduan relatif terhadap area preview (0-1).
  final double guideScale;

  /// Margin ekstra di sekitar kotak saat crop (relatif ukuran kotak), supaya
  /// tepi kartu tidak terpotong kalau kartu sedikit keluar garis.
  final double cropMargin;

  final int maxSide;
  final String hint;

  @override
  State<KtpCameraView> createState() => KtpCameraViewState();
}

class KtpCameraViewState extends State<KtpCameraView> {
  CameraController? _controller;
  bool _mirror = false;
  bool _busy = false;
  String? _error;

  /// Rasio lebar/tinggi area preview terakhir (dipakai untuk menghitung crop).
  double _boxAspect = 85.6 / 54;

  bool get isReady =>
      _controller != null && _controller!.value.isInitialized && !_busy;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({int attempt = 1}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('Kamera tidak ditemukan. Gunakan "Pilih File".');
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Di web, foto dari kamera non-belakang ikut ter-mirror -> dibalik lagi.
      _mirror = kIsWeb && cam.lensDirection != CameraLensDirection.back;

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await controller.initialize();
      } catch (err, stack) {
        debugPrint('Controller initialize error: $err\n$stack');
        await controller.dispose();
        rethrow;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      debugPrint('Kamera: ${cam.name} (${cam.lensDirection}) '
          'preview=${controller.value.previewSize} mirror=$_mirror');
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      debugPrint('CameraException (percobaan $attempt): ${e.code} ${e.description}');
      // Kamera masih dipegang stream sebelumnya (mis. habis "Foto Ulang") atau
      // sedang dilepas aplikasi lain: tunggu sebentar lalu coba lagi.
      if (e.code == 'cameraNotReadable' && attempt < 4 && mounted) {
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        if (mounted) return _init(attempt: attempt + 1);
        return;
      }
      final denied = '${e.code} ${e.description}'.toLowerCase();
      _fail(denied.contains('denied') || denied.contains('permission')
          ? 'Izin kamera ditolak. Izinkan kamera di pengaturan browser, '
              'atau gunakan "Pilih File".'
          : e.code == 'cameraNotReadable'
              ? 'Kamera sedang dipakai aplikasi/tab lain. Tutup aplikasi itu '
                  'lalu muat ulang halaman, atau gunakan "Pilih File".'
              : 'Kamera tidak dapat dibuka. Gunakan "Pilih File".');
    } catch (e, stack) {
      debugPrint('Error init kamera tidak terduga: $e\n$stack');
      _fail('Kamera tidak dapat dibuka. Gunakan "Pilih File".');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    widget.onError?.call(message);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Ambil foto, potong ke kotak panduan, kirim lewat [KtpCameraView.onCaptured].
  Future<void> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() => _busy = true);
    try {
      final sw = Stopwatch()..start();
      final shot = await controller.takePicture();
      final raw = await shot.readAsBytes();
      final tShot = sw.elapsedMilliseconds;

      // Di web: crop/resize/encode oleh browser (cepat, UI tidak membeku).
      Uint8List? out;
      if (NativeImageOps.available) {
        out = await NativeImageOps.cropToGuideJpeg(
          raw,
          boxAspect: _boxAspect,
          guideScale: widget.guideScale,
          cropMargin: widget.cropMargin,
          mirror: _mirror,
          maxSide: widget.maxSide,
        );
      }
      // Cadangan: jalur Dart murni (lebih lambat, memblokir UI).
      out ??= cropToGuide(
        raw,
        boxAspect: _boxAspect,
        guideScale: widget.guideScale,
        cropMargin: widget.cropMargin,
        mirror: _mirror,
        maxSide: widget.maxSide,
      );
      debugPrint('Foto kamera: ${raw.length} B -> crop ${out.length} B | '
          'ambil $tShot ms, olah ${sw.elapsedMilliseconds - tShot} ms '
          '(native=${NativeImageOps.available})');
      if (mounted) widget.onCaptured(out);
    } catch (e, stack) {
      debugPrint('Gagal memotret: $e\n$stack');
      widget.onError?.call('Gagal mengambil foto, coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Potong foto ke area kotak panduan.
  ///
  /// Preview ditampilkan "cover" di area dengan rasio [boxAspect], jadi bagian
  /// foto yang terlihat = potongan tengah dengan rasio itu. Kotak panduan =
  /// [guideScale] dari area terlihat, di tengah. Ditambah [cropMargin].
  @visibleForTesting
  static Uint8List cropToGuide(
    Uint8List bytes, {
    required double boxAspect,
    required double guideScale,
    required double cropMargin,
    required bool mirror,
    required int maxSide,
  }) {
    final src = img.decodeImage(bytes);
    if (src == null) return bytes;

    final w = src.width.toDouble();
    final h = src.height.toDouble();

    double visW, visH;
    if (w / h > boxAspect) {
      visH = h;
      visW = h * boxAspect;
    } else {
      visW = w;
      visH = w / boxAspect;
    }

    final scale = math.min(1.0, guideScale * (1 + 2 * cropMargin));
    final cw = (visW * scale).clamp(1.0, w);
    final ch = (visH * scale).clamp(1.0, h);
    final x = ((w - cw) / 2).round();
    final y = ((h - ch) / 2).round();

    var out = img.copyCrop(
      src,
      x: x,
      y: y,
      width: cw.round(),
      height: ch.round(),
    );
    if (mirror) out = img.flipHorizontal(out);

    final longest = math.max(out.width, out.height);
    if (longest > maxSide) {
      out = out.width >= out.height
          ? img.copyResize(out, width: maxSide)
          : img.copyResize(out, height: maxSide);
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: 88));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Message(icon: Icons.no_photography_outlined, text: _error!);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _Message(
        icon: Icons.photo_camera_outlined,
        text: 'Membuka kamera...',
        loading: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0) {
          _boxAspect = constraints.maxWidth / constraints.maxHeight;
        }

        // Ukuran video asli (di web = ukuran stream sebenarnya).
        final size = controller.value.previewSize;
        final videoW = size?.width ?? 1280;
        final videoH = size?.height ?? 720;

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoW,
                  height: videoH,
                  child: controller.buildPreview(),
                ),
              ),
            ),
            CustomPaint(
              painter: _GuidePainter(scale: widget.guideScale),
            ),
            if (widget.hint.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
            if (_busy)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
          ],
        );
      },
    );
  }
}

/// Menggelapkan area di luar kotak + garis kuning + sudut tebal.
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final gw = size.width * scale;
    final gh = size.height * scale;
    final rect = Rect.fromLTWH(
      (size.width - gw) / 2,
      (size.height - gh) / 2,
      gw,
      gh,
    );
    final radius = Radius.circular(math.min(gw, gh) * 0.05);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.45));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.yellowAccent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final corner = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final len = math.min(gw, gh) * 0.14;
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    canvas
      ..drawLine(Offset(l, t + len), Offset(l, t), corner)
      ..drawLine(Offset(l, t), Offset(l + len, t), corner)
      ..drawLine(Offset(r - len, t), Offset(r, t), corner)
      ..drawLine(Offset(r, t), Offset(r, t + len), corner)
      ..drawLine(Offset(l, b - len), Offset(l, b), corner)
      ..drawLine(Offset(l, b), Offset(l + len, b), corner)
      ..drawLine(Offset(r - len, b), Offset(r, b), corner)
      ..drawLine(Offset(r, b), Offset(r, b - len), corner);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => old.scale != scale;
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.loading = false});

  final IconData icon;
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(color: Colors.white70),
                  )
                : Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
