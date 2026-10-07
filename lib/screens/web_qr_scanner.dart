import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class WebQrScanner extends StatefulWidget {
  final void Function(String raw) onCode;
  final bool useFrontCamera;
  final bool mirrored; // mirror lewat CSS, tanpa restart kamera
  final bool paused; // hentikan decode sementara (mis. saat cooldown)

  const WebQrScanner({
    super.key,
    required this.onCode,
    this.useFrontCamera = false,
    this.mirrored = false,
    this.paused = false,
  });

  @override
  State<WebQrScanner> createState() => _WebQrScannerState();
}

class _WebQrScannerState extends State<WebQrScanner> {
  static int _counter = 0;

  // Interval antar scan (dihitung setelah scan sebelumnya selesai)
  static const Duration _interval = Duration(milliseconds: 60);
  // Lebar decode untuk fallback jsQR, bergantian tiap tick
  static const List<int> _scales = [480, 960, 1280];

  late final String _viewType;
  late final html.VideoElement _video;
  late final html.CanvasElement _canvas;
  late final html.CanvasRenderingContext2D _ctx;

  html.MediaStream? _stream;
  Timer? _timer;
  dynamic _detector; // BarcodeDetector bila didukung
  bool _hasJsQr = false;
  int _scaleIdx = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-qr-scanner-${_counter++}';

    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = widget.mirrored ? 'scaleX(-1)' : 'none';

    _canvas = html.CanvasElement();
    _ctx = _canvas.getContext('2d', {'willReadFrequently': true})
        as html.CanvasRenderingContext2D;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) => _video);

    _initDetector();
    _startCamera();
  }

  @override
  void didUpdateWidget(covariant WebQrScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mirrored != widget.mirrored) {
      _video.style.transform = widget.mirrored ? 'scaleX(-1)' : 'none';
    }
  }

  void _initDetector() {
    try {
      if (js_util.hasProperty(html.window, 'BarcodeDetector')) {
        final ctor = js_util.getProperty(html.window, 'BarcodeDetector');
        _detector = js_util.callConstructor(ctor, [
          js_util.jsify({'formats': ['qr_code']}),
        ]);
      }
    } catch (e, stack) {
      debugPrint('BarcodeDetector tidak tersedia: $e\n$stack');
      _detector = null;
    }
    _hasJsQr = js_util.hasProperty(html.window, 'jsQR');
    debugPrint('QR engine: ${_detector != null ? 'BarcodeDetector' : (_hasJsQr ? 'jsQR' : 'TIDAK ADA')}');
  }

  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': widget.useFrontCamera ? 'user' : 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
        },
      });

      if (_disposed) {
        for (final t in stream.getTracks()) {
          t.stop();
        }
        return;
      }

      _stream = stream;
      _video.srcObject = stream;
      await _video.play();

      // Fokus kontinu (kalau didukung perangkat)
      try {
        final track = stream.getVideoTracks().first;
        await js_util.promiseToFuture(js_util.callMethod(track, 'applyConstraints', [
          js_util.jsify({
            'advanced': [
              {'focusMode': 'continuous'}
            ]
          })
        ]));
      } catch (e) {
        debugPrint('Continuous focus tidak didukung browser ini: $e');
      }

      _schedule();
    } catch (e, stack) {
      debugPrint('Gagal membuka kamera QR: $e\n$stack');
    }
  }

  void _schedule() {
    if (_disposed) return;
    _timer = Timer(_interval, _tick);
  }

  Future<void> _tick() async {
    if (_disposed) return;
    if (!widget.paused && _video.readyState >= 2 && _video.videoWidth > 0) {
      final code = await _scanOnce();
      if (code != null && code.isNotEmpty && !_disposed && !widget.paused) {
        widget.onCode(code);
      }
    }
    _schedule(); // dijadwalkan setelah selesai -> tidak menumpuk
  }

  Future<String?> _scanOnce() async {
    // 1) Native BarcodeDetector
    if (_detector != null) {
      try {
        final res = await js_util
            .promiseToFuture(js_util.callMethod(_detector, 'detect', [_video]));
        final list = res as List;
        if (list.isNotEmpty) {
          return js_util.getProperty(list.first, 'rawValue')?.toString();
        }
        return null;
      } catch (e, stack) {
        debugPrint('BarcodeDetector detect error: $e\n$stack');
        _detector = null; // tidak jalan di browser ini -> pakai jsQR
      }
    }

    // 2) Fallback jsQR multi-skala
    if (!_hasJsQr) return null;
    return _scanJsQr();
  }

  String? _scanJsQr() {
    final vw = _video.videoWidth;
    final vh = _video.videoHeight;
    final w = math.min(_scales[_scaleIdx++ % _scales.length], vw);
    final h = (vh * w / vw).round();

    _canvas.width = w;
    _canvas.height = h;
    _ctx.drawImageScaled(_video, 0, 0, w, h);
    final img = _ctx.getImageData(0, 0, w, h);

    final result = js_util.callMethod(html.window, 'jsQR', [
      img.data,
      w,
      h,
      js_util.jsify({'inversionAttempts': 'dontInvert'}), // lebih cepat
    ]);
    if (result == null) return null;
    return js_util.getProperty(result, 'data')?.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _stream?.getTracks().forEach((t) => t.stop());
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}