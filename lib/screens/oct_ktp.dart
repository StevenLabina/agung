import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/utils/photo_quality.dart';
import 'package:iuran_rt_web/widgets/ktp_camera_view.dart';

/// Kolom form. [key] = nama field yang dikirim ke backend (PUT /api/ktp/{id}).
class _KtpField {
  final String key;
  final String label;
  final bool fullWidth;
  final TextInputType keyboard;
  final int? maxLength;

  const _KtpField(
    this.key,
    this.label, {
    this.fullWidth = false,
    this.keyboard = TextInputType.text,
    this.maxLength,
  });
}

class OcrKtpPage extends StatefulWidget {
  const OcrKtpPage({super.key});

  @override
  State<OcrKtpPage> createState() => _OcrKtpPageState();
}

class _OcrKtpPageState extends State<OcrKtpPage> {
  static const Color primaryColor = Color(0xFF3D8D7A);
  static const Color bgColor = Color(0xFF3D8D7A);
  static const double wideBreakpoint = 900;
  static const int maxImageBytes = 8 * 1024 * 1024; // 8 MB
  static const int pageSize = 10;

  // =========================================================
  // KONFIGURASI API
  // =========================================================
  // ApiUrls.baseUrl harus berakhiran "/api/"
  // contoh: http://127.0.0.1:8000/api/
  String get _base => ApiUrls.baseUrl;

  static const String endpointScan = 'ocr/scan'; // POST multipart
  static const String endpointKtp = 'ktp'; // GET list, PUT /{id}, POST /{id}/checkout
  static const String fieldFoto = 'image'; // dibaca backend dari $_FILES['image']

  // Kolom yang bisa diedit (sesuai tabel demo_ocr_ktp)
  static const List<_KtpField> _fields = [
    _KtpField('nama', 'Nama'),
    _KtpField('nik', 'NIK', keyboard: TextInputType.number, maxLength: 16),
    _KtpField('alamat', 'Alamat', fullWidth: true),
    _KtpField('no_kavling', 'No. Kavling Tujuan', fullWidth: true),
  ];

  // ---- state scan ----
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<KtpCameraViewState> _camKey = GlobalKey<KtpCameraViewState>();
  bool _cameraUnavailable = false; // kamera live gagal -> pakai kamera bawaan HP
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrl = {
    for (final f in _fields) f.key: TextEditingController(),
  };

  Uint8List? _imageBytes;
  String? _imageName;
  bool _scanning = false;
  bool _saving = false;
  String? _scanError;
  String? _scanInfo;
  String? _ktpId; // id record hasil scan (dipakai untuk PUT)
  Map<String, dynamic> _metadata = {}; // data tambahan hasil OCR (TTL, agama, dll)

  // ---- state daftar tersimpan ----
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loadingList = false;
  String? _listError;
  int _page = 1;
  int _totalPages = 1;
  final Set<String> _busyIds = {}; // id yang sedang proses checkout

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // HELPER
  // =========================================================

  static bool _isOk(Map j) {
    final s = j['success'] ?? j['result'] ?? j['status'];
    return s == true || s == 1 || s == 'success' || s == 'ok';
  }

  static String? _msg(Map j) {
    final m = j['message'] ?? j['error'] ?? j['msg'];
    return m?.toString();
  }

  static String _str(dynamic v) => v == null ? '' : v.toString().trim();

  static String _maskNik(String nik) {
    if (nik.length < 10) return nik;
    return '${nik.substring(0, 6)}${'*' * (nik.length - 10)}${nik.substring(nik.length - 4)}';
  }

  /// "2026-10-01 14:30:25" -> "2026-10-01 14:30"
  static String _fmtTime(dynamic v) {
    final s = _str(v);
    return s.length >= 16 ? s.substring(0, 16) : s;
  }

  static MediaType _mediaType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return MediaType('image', 'png');
    if (n.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  static Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.trim().startsWith('{')) {
      try {
        final d = jsonDecode(v);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  Future<Map> _decode(http.Response response) async {
    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (_) {
      json = null;
    }
    if (json is! Map) {
      throw Exception('Respons server tidak valid (${response.statusCode})');
    }
    if (!_isOk(json)) {
      throw Exception(_msg(json) ?? 'Permintaan gagal (${response.statusCode})');
    }
    return json;
  }

  // =========================================================
  // PILIH FOTO
  // =========================================================

  Future<void> _pickImage(ImageSource source) async {
    if (_scanning) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 92,
      );
      if (file == null) return;

      final raw = await file.readAsBytes();
      if (raw.length > maxImageBytes) {
        if (!mounted) return;
        setState(() {
          _scanError = 'Ukuran foto terlalu besar (maks 8 MB)';
          _scanInfo = null;
        });
        return;
      }

      // Putar sesuai EXIF + kecilkan ke maks 1600px (upload lebih cepat)
      final bytes = PhotoTools.prepareForUpload(raw);
      if (!mounted) return;
      _setPhoto(bytes);
    } catch (e) {
      debugPrint('Gagal memilih foto: $e');
      if (!mounted) return;
      setState(() {
        _scanError = source == ImageSource.camera
            ? 'Kamera tidak tersedia di perangkat ini, gunakan "Pilih File"'
            : 'Gagal memilih foto';
      });
    }
  }

  /// Simpan foto + cek kualitas (peringatan saja, belum memblokir).
  void _setPhoto(Uint8List bytes) {
    final q = PhotoTools.analyze(bytes);
    debugPrint('Kualitas foto: tajam=${q.sharpness.toStringAsFixed(0)} '
        'terang=${q.brightness.toStringAsFixed(0)} '
        'glare=${(q.glareRatio * 100).toStringAsFixed(1)}% ok=${q.ok}');
    setState(() {
      _imageBytes = bytes;
      _imageName = 'ktp.jpg';
      _scanError = q.ok ? null : q.message;
      _scanInfo = null;
    });
  }

  /// Tombol KAMERA: potret dari kamera live (dengan kotak panduan).
  /// Kalau kamera live tidak bisa dipakai, buka kamera bawaan HP.
  void _onKameraPressed() {
    if (_scanning) return;
    if (_imageBytes != null) {
      // Foto sudah ada: kembali ke kamera live untuk foto ulang
      _clearImage();
      if (!_cameraUnavailable) return;
    }
    final cam = _camKey.currentState;
    if (!_cameraUnavailable && cam != null) {
      if (cam.isReady) cam.capture();
      return;
    }
    _pickImage(ImageSource.camera);
  }

  void _clearImage() {
    if (_scanning) return;
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _scanError = null;
      _scanInfo = null;
    });
  }

  void _resetForm() {
    for (final c in _ctrl.values) {
      c.clear();
    }
    setState(() {
      _ktpId = null;
      _metadata = {};
      _scanInfo = null;
    });
    _formKey.currentState?.reset();
  }

  // =========================================================
  // SCAN OCR  ->  POST /api/ocr/scan
  // =========================================================

  Future<void> _scan() async {
    final bytes = _imageBytes;
    if (bytes == null || _scanning) return;

    setState(() {
      _scanning = true;
      _scanError = null;
      _scanInfo = null;
    });

    try {
      final name = _imageName ?? 'ktp.jpg';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base$endpointScan'),
      )..files.add(
          http.MultipartFile.fromBytes(
            fieldFoto,
            bytes,
            filename: name,
            contentType: _mediaType(name),
          ),
        );

      final streamed =
          await request.send().timeout(const Duration(seconds: 130));
      final response = await http.Response.fromStream(streamed);
      final json = await _decode(response);

      final data = _toMap(json['data']);

      // Isi form dari hasil OCR
      _ctrl['nama']!.text = _str(data['nama']);
      _ctrl['nik']!.text = _str(data['nik']).replaceAll(RegExp(r'\D'), '');
      _ctrl['alamat']!.text = _str(data['alamat']);
      // no_kavling dikosongkan: diisi manual oleh petugas
      _ctrl['no_kavling']!.text = _str(data['no_kavling']);

      final id = _str(data['id']);
      final filled = ['nama', 'nik', 'alamat']
          .where((k) => _ctrl[k]!.text.isNotEmpty)
          .length;

      if (!mounted) return;
      setState(() {
        _ktpId = id.isEmpty ? null : id;
        _metadata = _toMap(data['metadata']);
        _scanInfo = id.isEmpty
            ? '$filled dari 3 kolom terbaca, tetapi server tidak mengembalikan ID. Hubungi admin.'
            : '$filled dari 3 kolom terbaca. Periksa, isi No. Kavling, lalu tekan Simpan.';
        _scanning = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });

      // Record sudah dibuat oleh backend (auto_save), segarkan daftar
      _fetchList();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = 'Waktu habis. Proses OCR terlalu lama, coba lagi';
      });
    } catch (e) {
      debugPrint('Error OCR: $e');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // =========================================================
  // SIMPAN  ->  PUT /api/ktp/{id}
  // =========================================================

  Future<void> _simpan() async {
    if (_saving) return;
    if (_ktpId == null) {
      _snack('Scan KTP dulu sebelum menyimpan');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final payload = <String, String>{
        for (final f in _fields) f.key: _ctrl[f.key]!.text.trim(),
      };

      final response = await http
          .put(
            Uri.parse('$_base$endpointKtp/$_ktpId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final json = await _decode(response);

      if (!mounted) return;
      _snack(_msg(json) ?? 'Data KTP berhasil disimpan', error: false);
      _resetForm();
      _clearImage();
      _fetchList();
    } on TimeoutException {
      _snack('Waktu habis saat menyimpan, coba lagi');
    } catch (e) {
      debugPrint('Error simpan KTP: $e');
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // =========================================================
  // DAFTAR  ->  GET /api/ktp?search=&page=&limit=
  // =========================================================

  Future<void> _fetchList({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });

    try {
      final uri = Uri.parse('$_base$endpointKtp').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': pageSize.toString(),
          if (_searchCtrl.text.trim().isNotEmpty)
            'search': _searchCtrl.text.trim(),
        },
      );
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      final json = await _decode(response);

      final data = _toMap(json['data']);
      final List list = data['items'] is List ? data['items'] as List : const [];
      final pagination = _toMap(data['pagination']);
      final int totalPages =
          int.tryParse('${pagination['total_pages'] ?? 1}') ?? 1;

      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _page = page;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _loadingList = false;
      });
    } catch (e) {
      debugPrint('Error ambil daftar KTP: $e');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // =========================================================
  // CHECKOUT  ->  POST /api/ktp/{id}/checkout
  // =========================================================

  Future<void> _checkout(Map<String, dynamic> item) async {
    final id = _str(item['id']);
    if (id.isEmpty || _busyIds.contains(id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout tamu?'),
        content: Text(
          'Catat jam keluar untuk ${_str(item['nama']).isEmpty ? 'tamu ini' : _str(item['nama'])} sekarang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyIds.add(id));
    try {
      final response = await http.post(
        Uri.parse('$_base$endpointKtp/$id/checkout'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final json = await _decode(response);
      _snack(_msg(json) ?? 'Checkout berhasil', error: false);
      await _fetchList(page: _page);
    } on TimeoutException {
      _snack('Waktu habis saat checkout, coba lagi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'OCR KTP',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= wideBreakpoint;

            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 20 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1400 : 560),
                  child: Column(
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 420, child: _buildScanSection()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildFormCard(wide: true)),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildScanSection(),
                            const SizedBox(height: 20),
                            _buildFormCard(wide: false),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _buildListCard(wide: wide),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SCAN SECTION
  // ---------------------------------------------------------

  Widget _buildScanSection() {
    return Column(
      children: [
        _buildPreview(),
        const SizedBox(height: 14),
        _buildPickButtons(),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_imageBytes == null || _scanning) ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: primaryColor,
                    ),
                  )
                : const Icon(Icons.document_scanner),
            label: Text(
              _scanning ? 'Membaca KTP...' : 'Baca KTP',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryColor,
              disabledBackgroundColor: Colors.white24,
              disabledForegroundColor: Colors.white54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildStatusCard(),
      ],
    );
  }

  Widget _buildPreview() {
    return AspectRatio(
      aspectRatio: 85.6 / 54, // rasio kartu KTP
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black26,
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                  : _cameraUnavailable
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined,
                                  size: 56, color: Colors.white70),
                              SizedBox(height: 8),
                              Text(
                                'Belum ada foto KTP',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      : KtpCameraView(
                          key: _camKey,
                          hint: '', // petunjuk ditampilkan di kartu status
                          onCaptured: (bytes) {
                            if (mounted) _setPhoto(bytes);
                          },
                          onError: (msg) {
                            if (!mounted) return;
                            setState(() {
                              _cameraUnavailable = true;
                              _scanError = msg;
                            });
                          },
                        ),
            ),
            if (_imageBytes != null && !_scanning)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Hapus foto',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _clearImage,
                  ),
                ),
              ),
            if (_scanning)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Membaca KTP...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Widget _buildPickButtons() {
    Widget button(String label, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _scanning ? null : onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(
          _imageBytes != null ? 'FOTO ULANG' : 'KAMERA',
          _imageBytes != null ? Icons.refresh : Icons.photo_camera,
          _onKameraPressed,
        ),
        const SizedBox(width: 8),
        button('PILIH FILE', Icons.upload_file,
            () => _pickImage(ImageSource.gallery)),
      ],
    );
  }

  Widget _buildStatusCard() {
    Color? color;
    IconData? icon;
    String? text;

    if (_scanError != null) {
      color = Colors.orange;
      icon = Icons.error;
      text = _scanError;
    } else if (_scanInfo != null) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = _scanInfo;
    }

    if (color == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _imageBytes == null && !_cameraUnavailable
              ? 'Posisikan seluruh KTP di dalam kotak kuning, pegang HP sejajar dengan kartu, lalu tekan KAMERA'
              : 'Foto KTP tegak lurus, cahaya cukup, tanpa pantulan, dan seluruh sisi kartu terlihat supaya hasil OCR akurat',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 8),
          Text(
            text ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color == Colors.green ? Colors.white : color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // FORM HASIL OCR
  // ---------------------------------------------------------

  Widget _buildFormCard({required bool wide}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hasil OCR KTP',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1B1B1F),
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                final double half = wide ? (w - 12) / 2 : w;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: _fields
                      .map((f) => _buildField(f, f.fullWidth ? w : half))
                      .toList(),
                );
              },
            ),
          ),
          if (_metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Data tambahan hasil OCR',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      _metadata.entries
                          .map((e) => '${e.key}: ${_str(e.value)}')
                          .join('\n'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: (_saving || _scanning) ? null : _resetForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Kosongkan'),
                ),
              ),
              SizedBox(
                width: 160,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_saving || _scanning) ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(_KtpField f, double width) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return SizedBox(
      width: width,
      child: TextFormField(
        controller: _ctrl[f.key],
        keyboardType: f.keyboard,
        maxLength: f.maxLength,
        maxLines: f.key == 'alamat' ? 2 : 1,
        minLines: 1,
        inputFormatters:
            f.key == 'nik' ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: f.label,
          counterText: '',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: border(Colors.grey.shade600),
          enabledBorder: border(Colors.grey.shade600),
          focusedBorder: border(primaryColor, 2),
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (f.key == 'nik') {
            if (t.isEmpty) return 'NIK wajib diisi';
            if (t.length != 16) {
              return 'NIK harus 16 digit (sekarang ${t.length})';
            }
          }
          if (f.key == 'nama' && t.isEmpty) return 'Nama wajib diisi';
          if (f.key == 'no_kavling' && t.isEmpty) {
            return 'No. Kavling tujuan wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // DAFTAR PENGUNJUNG
  // ---------------------------------------------------------

  // flex kolom tabel desktop
  static const int _fNik = 3;
  static const int _fNama = 3;
  static const int _fKavling = 2;
  static const int _fMasuk = 2;
  static const int _fKeluar = 2;
  static const int _fAksi = 2;

  Widget _buildListCard({required bool wide}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Data Pengunjung',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1B1B1F),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _fetchList(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau NIK',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loadingList ? null : () => _fetchList(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Cari',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildListContent(wide),
          const SizedBox(height: 16),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildListContent(bool wide) {
    Widget body;

    if (_loadingList) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    } else if (_listError != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Text(
                _listError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _fetchList(page: _page),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            'Belum ada data pengunjung',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    } else {
      body = wide
          ? Column(children: _items.map(_desktopRow).toList())
          : Column(children: _items.map(_mobileCard).toList());
    }

    if (!wide) return body;

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_desktopHeader(), body],
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    Widget cell(String text, int flex) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );

    return Container(
      color: primaryColor,
      child: Row(
        children: [
          cell('NIK', _fNik),
          cell('Nama', _fNama),
          cell('Kavling', _fKavling),
          cell('Jam Masuk', _fMasuk),
          cell('Jam Keluar', _fKeluar),
          cell('Aksi', _fAksi),
        ],
      ),
    );
  }

  Widget _checkoutButton(Map<String, dynamic> item) {
    final id = _str(item['id']);
    final busy = _busyIds.contains(id);
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: busy ? null : () => _checkout(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Checkout', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _desktopRow(Map<String, dynamic> item) {
    Widget cell(String text, int flex) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              text.isEmpty ? '-' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF222222)),
            ),
          ),
        );

    final keluar = _fmtTime(item['jam_keluar']);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          cell(_maskNik(_str(item['nik'])), _fNik),
          cell(_str(item['nama']), _fNama),
          cell(_str(item['no_kavling']), _fKavling),
          cell(_fmtTime(item['jam_masuk']), _fMasuk),
          cell(keluar, _fKeluar),
          Expanded(
            flex: _fAksi,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: keluar.isEmpty
                    ? _checkoutButton(item)
                    : const Text(
                        'Selesai',
                        style: TextStyle(fontSize: 13, color: Colors.black45),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileCard(Map<String, dynamic> item) {
    final nama = _str(item['nama']);
    final nik = _maskNik(_str(item['nik']));
    final kavling = _str(item['no_kavling']);
    final masuk = _fmtTime(item['jam_masuk']);
    final keluar = _fmtTime(item['jam_keluar']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama.isEmpty ? '-' : nama,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'NIK: ${nik.isEmpty ? '-' : nik}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kavling: ${kavling.isEmpty ? '-' : kavling}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masuk: ${masuk.isEmpty ? '-' : masuk}',
                  style:
                      const TextStyle(fontSize: 12.5, color: Colors.black45),
                ),
                Text(
                  'Keluar: ${keluar.isEmpty ? '-' : keluar}',
                  style:
                      const TextStyle(fontSize: 12.5, color: Colors.black45),
                ),
              ],
            ),
          ),
          if (keluar.isEmpty) _checkoutButton(item),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final bool canPrev = !_loadingList && _page > 1;
    final bool canNext = !_loadingList && _page < _totalPages;

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey.shade300,
      disabledForegroundColor: Colors.grey.shade500,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        ElevatedButton(
          style: style,
          onPressed: canPrev ? () => _fetchList(page: _page - 1) : null,
          child: const Text('Previous'),
        ),
        Text(
          'Halaman $_page dari $_totalPages',
          style: const TextStyle(fontSize: 15),
        ),
        ElevatedButton(
          style: style,
          onPressed: canNext ? () => _fetchList(page: _page + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}