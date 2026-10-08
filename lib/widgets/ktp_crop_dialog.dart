import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Dialog layar penuh untuk memotong (crop) foto KTP.
///
/// Mengembalikan foto hasil potong, atau null kalau dibatalkan.
/// Rasio kotak dibuat bebas supaya KTP yang miring/perspektif tetap bisa
/// dipotong rapat. Untuk mengunci ke rasio KTP, beri `aspectRatio: 85.6 / 54`
/// pada widget [Crop].
Future<Uint8List?> showKtpCropDialog(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _KtpCropDialog(imageBytes: imageBytes),
  );
}

class _KtpCropDialog extends StatefulWidget {
  const _KtpCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_KtpCropDialog> createState() => _KtpCropDialogState();
}

class _KtpCropDialogState extends State<_KtpCropDialog> {
  static const Color _primary = Color(0xFF3D8D7A);

  final CropController _controller = CropController();
  bool _cropping = false;
  String? _error;

  void _crop() {
    if (_cropping) return;
    setState(() {
      _cropping = true;
      _error = null;
    });
    try {
      // Hasil datang lewat onCropped.
      _controller.crop();
    } catch (e, stack) {
      debugPrint('Crop gagal dimulai: $e\n$stack');
      setState(() {
        _cropping = false;
        _error = 'Gagal memotong foto. Coba lagi.';
      });
    }
  }

  void _onCropped(CropResult result) {
    // Hanya field `croppedImage` yang dipakai (ada di hasil sukses); hasil gagal
    // tidak punya field itu sehingga jatuh ke cabang error di bawah.
    Uint8List? data;
    try {
      data = (result as dynamic).croppedImage as Uint8List?;
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    if (data == null || data.isEmpty) {
      setState(() {
        _cropping = false;
        _error = 'Gagal memotong foto. Coba lagi.';
      });
      return;
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Potong foto KTP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Geser sudut dan sisi kotak sampai hanya KTP yang terlihat, '
                'dengan seluruh tulisannya tetap di dalam.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Crop(
                image: widget.imageBytes,
                controller: _controller,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.6),
                progressIndicator: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                onCropped: _onCropped,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _cropping ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cropping ? null : _crop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _cropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Pakai',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
