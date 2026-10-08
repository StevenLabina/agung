import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iuran_rt_web/screens/log_akses_perumahan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/utils/photo_quality.dart';
import 'package:iuran_rt_web/utils/web_image_ops.dart';
import 'package:iuran_rt_web/widgets/ktp_camera_view.dart';
import 'package:iuran_rt_web/widgets/ktp_crop_dialog.dart';
import 'package:universal_html/html.dart' as html;

/// Exception terstruktur untuk error API/jaringan/server
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

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
  // Batas file mentah. Foto diperkecil browser sebelum diunggah, jadi file besar
  // dari kamera HP resolusi tinggi tetap boleh.
  static const int maxImageBytes = 20 * 1024 * 1024;
  static const int pageSize = 10;
  void _openLogWarga() {
    if (_scanning || _saving) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LogAksesPerumahanPage()),
    );
  }

  Widget _buildTipeToggle() {
    Widget button(
      String label,
      IconData icon,
      bool selected,
      VoidCallback onTap,
    ) {
      final Color fg = selected ? primaryColor : Colors.white;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
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
        button('TAMU', Icons.badge, true, () {}),
        const SizedBox(width: 8),
        button('WARGA KAVLING', Icons.home, false, _openLogWarga),
      ],
    );
  }

  // =========================================================
  // KONFIGURASI API
  // =========================================================
  // Endpoint API OCR KTP (CRM Apikko)
  String get _crmOcrUrl => ApiUrls.crmOcrUrl;
  String get _crmApiKey => ApiUrls.crmApiKey;
  String get _crmFallbackApiKey => ApiUrls.crmFallbackApiKey;

  static const String endpointKtp = 'ktp.php';
  static const String fieldFoto = 'image';

  // Kolom yang ditampilkan di form (Nama, NIK, No. Kavling, Alamat)
  // Data OCR pendukung lainnya otomatis masuk ke metadata dan disimpan ke DB
  static const List<_KtpField> _fields = [
    _KtpField('nama', 'Nama Lengkap', fullWidth: true),
    _KtpField('nik', 'NIK', keyboard: TextInputType.number, maxLength: 16),
    _KtpField('no_kavling', 'No. Kavling Tujuan (Opsional)'),
    _KtpField('alamat', 'Alamat Lengkap', fullWidth: true),
  ];

  // ---- state scan ----
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<KtpCameraViewState> _camKey = GlobalKey<KtpCameraViewState>();
  bool _cameraUnavailable =
      false; // kamera live gagal -> pakai kamera bawaan HP
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrl = {
    for (final f in _fields) f.key: TextEditingController(),
  };

  Uint8List? _imageBytes;
  // Salinan resolusi lebih tinggi untuk fitur crop (supaya hasil potong tetap tajam)
  Uint8List? _cropSource;
  String? _imageName;
  bool _scanning = false;
  bool _preparing = false; // sedang mengolah foto (resize/crop)
  bool _saving = false;
  String? _scanError;
  String? _scanInfo;
  String? _ktpId; // id record hasil scan (dipakai untuk PUT)
  Map<String, dynamic> _metadata =
      {}; // data tambahan hasil OCR (TTL, agama, dll)

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

  /// Membersihkan alamat hasil OCR dari duplikasi kelurahan/kecamatan dan kebocoran teks agama/status
  static String _cleanAddress(String raw) {
    if (raw.trim().isEmpty) return '';
    var text = raw.trim();

    // 1. Buang kata-kata agama dan status perkawinan yang bocor di akhir teks alamat
    final bleedRegex = RegExp(
      r'[\s,\.\-:]*(?:ISLAM|KRISTEN|KATHOLIK|KATOLIK|HINDU|BUDHA|BUDDHA|KONGHUCU|PENGHAYAT|KAWIN|BELUM\s+KAWIN|CERAI\s+HIDUP|CERAI\s+MATI|WIRASWASTA|PEKERJAAN|AGAMA|STATUS)[\s\S]*$',
      caseSensitive: false,
    );
    text = text.replaceAll(bleedRegex, '');

    // 2. Buang label ALAMAT yang bocor di tengah
    text = text.replaceAll(RegExp(r'[\s,]+ALAMAT\b', caseSensitive: false), '');

    // 3. Dedup segmen koma (mis. KEC. A WONOASIH muncul 2 kali)
    final parts = text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final deduped = <String>[];
    final seen = <String>{};
    for (final p in parts) {
      final norm = p.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (norm.isNotEmpty && !seen.contains(norm)) {
        seen.add(norm);
        deduped.add(p);
      }
    }
    return deduped.join(', ');
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
      } on FormatException catch (e, stack) {
        debugPrint('Format JSON tidak valid pada _toMap: $e\n$stack');
      } catch (e, stack) {
        debugPrint('Gagal mengonversi string ke Map: $e\n$stack');
      }
    }
    return {};
  }

  Future<Map> _decode(http.Response response) async {
    dynamic json;
    try {
      json = jsonDecode(response.body);
    } on FormatException catch (e, stack) {
      debugPrint(
          'Gagal parse JSON dari respons server (HTTP ${response.statusCode}): $e\n$stack');
      throw ApiException(
        'Respons server tidak berupa JSON valid (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e, stack) {
      debugPrint('Kesalahan tidak terduga saat decode respons: $e\n$stack');
      throw ApiException(
        'Gagal membaca respons server',
        statusCode: response.statusCode,
      );
    }

    if (json is! Map) {
      throw ApiException(
        'Struktur data respons server tidak sesuai format (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (!_isOk(json)) {
      final msg = _msg(json) ??
          'Permintaan gagal diproses (HTTP ${response.statusCode})';
      throw ApiException(msg, statusCode: response.statusCode);
    }
    return json;
  }

  // =========================================================
  // PILIH FOTO
  // =========================================================

  Future<void> _pickImage(ImageSource source) async {
    if (_scanning || _preparing) return;
    try {
      // Di web, ambil resolusi asli (browser yang memperkecilnya, cepat) supaya
      // fitur crop punya detail. Di platform lain tetap diperkecil oleh picker.
      final bool useNative = kIsWeb && NativeImageOps.available;
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: useNative ? null : 1280,
        maxHeight: useNative ? null : 1280,
        imageQuality: useNative ? null : 85,
      );
      if (file == null) return;

      await _ingestPhoto(await file.readAsBytes());
    } on PlatformException catch (e, stack) {
      debugPrint(
          'PlatformException saat memilih foto: ${e.code} ${e.message}\n$stack');
      if (!mounted) return;
      setState(() {
        _scanError = source == ImageSource.camera
            ? 'Izin kamera ditolak atau tidak tersedia di perangkat ini.'
            : 'Izin akses galeri ditolak.';
      });
    } catch (e, stack) {
      debugPrint('Gagal memilih foto: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _scanError = source == ImageSource.camera
            ? 'Kamera tidak tersedia di perangkat ini, gunakan "Pilih File"'
            : 'Gagal memilih foto: $e';
      });
    }
  }

  /// Pasang foto ke preview secara instan tanpa memblokir thread UI.
  void _setPhoto(Uint8List bytes, {Uint8List? cropSource}) {
    setState(() {
      _imageBytes = bytes;
      _cropSource = cropSource ?? bytes;
      _imageName = 'ktp.jpg';
      _scanError = null;
      _scanInfo = null;
    });
  }

  /// Buka kamera HP secara langsung pada browser web (tanpa masuk ke file picker)
  Future<void> _pickImageDirectCameraWeb() async {
    if (_scanning) return;
    try {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.setAttribute(
          'capture', 'environment'); // Memicu aplikasi kamera belakang langsung
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        try {
          final files = uploadInput.files;
          if (files == null || files.isEmpty) return;
          final file = files[0];
          final reader = html.FileReader();

          reader.onError.listen((err) {
            debugPrint('FileReader error: $err');
            if (mounted) {
              setState(
                  () => _scanError = 'Gagal membaca berkas gambar kamera.');
            }
          });

          reader.onLoadEnd.listen((e) {
            try {
              final result = reader.result;
              if (result is List<int>) {
                final raw = Uint8List.fromList(result);
                unawaited(_ingestPhoto(raw));
              }
            } catch (err, stack) {
              debugPrint('Error saat memproses data gambar: $err\n$stack');
              if (mounted) {
                setState(
                    () => _scanError = 'Gagal memproses gambar kamera: $err');
              }
            }
          });

          reader.readAsArrayBuffer(file);
        } catch (err, stack) {
          debugPrint('Error onChange file input: $err\n$stack');
          if (mounted) {
            setState(() => _scanError = 'Gagal mengambil gambar dari kamera.');
          }
        }
      });
    } catch (e, stack) {
      debugPrint('Error direct camera web: $e\n$stack');
      _pickImage(ImageSource.camera);
    }
  }

  /// Tombol KAMERA: potret dari kamera live (dengan kotak panduan).
  /// Kalau kamera live tidak bisa dipakai (mis. browser web HTTP), buka kamera bawaan HP langsung.
  void _onKameraPressed() {
    if (_scanning) return;
    if (_imageBytes != null) {
      // Foto sudah ada: kembali ke kamera untuk foto ulang
      _clearImage();
      if (!_cameraUnavailable) return;
    }
    final cam = _camKey.currentState;
    if (!_cameraUnavailable && cam != null && cam.isReady) {
      cam.capture();
      return;
    }
    if (kIsWeb) {
      _pickImageDirectCameraWeb();
    } else {
      _pickImage(ImageSource.camera);
    }
  }

  /// Olah foto mentah dari file / kamera bawaan: perkecil untuk diunggah dan
  /// siapkan salinan resolusi lebih tinggi untuk crop. Di web dikerjakan browser
  /// (cepat, UI tidak membeku).
  Future<void> _ingestPhoto(Uint8List raw) async {
    if (raw.length > maxImageBytes) {
      if (!mounted) return;
      setState(() {
        _scanError = 'Ukuran foto terlalu besar (maks 20 MB)';
        _scanInfo = null;
      });
      return;
    }

    setState(() {
      _preparing = true;
      _scanError = null;
      _scanInfo = null;
    });
    try {
      final sw = Stopwatch()..start();
      final upload = await PhotoTools.prepareForUploadAsync(raw);
      final cropSrc = await PhotoTools.prepareForCropAsync(raw);
      debugPrint('Foto diolah: ${raw.length} B -> unggah ${upload.length} B, '
          'crop ${cropSrc.length} B (${sw.elapsedMilliseconds} ms, '
          'native=${NativeImageOps.available})');
      if (!mounted) return;
      _setPhoto(upload, cropSource: cropSrc);
    } catch (e, stack) {
      debugPrint('Gagal mengolah foto: $e\n$stack');
      if (mounted) {
        setState(() => _scanError = 'Gagal memproses foto, coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  /// Potong (crop) foto. Selalu dipotong dari salinan resolusi tinggi, jadi bisa
  /// diulang tanpa mengurangi kualitas.
  Future<void> _cropPhoto() async {
    final src = _cropSource ?? _imageBytes;
    if (src == null || _scanning || _preparing) return;

    final cropped = await showKtpCropDialog(context, src);
    if (cropped == null || !mounted) return;

    setState(() => _preparing = true);
    try {
      final bytes = await PhotoTools.prepareForUploadAsync(cropped);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _scanError = null;
        _scanInfo = null;
      });
    } catch (e, stack) {
      debugPrint('Gagal menyiapkan hasil crop: $e\n$stack');
      if (mounted) {
        setState(() => _scanError = 'Gagal memproses hasil potong, coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _clearImage() {
    if (_scanning) return;
    setState(() {
      _imageBytes = null;
      _cropSource = null;
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
  // SCAN OCR  ->  POST /api/ocr/ktp (CRM Apikko Backend)
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
      final mediaType = _mediaType(name);

      // Fungsi pengirim request HTTP Multipart ke endpoint CRM
      Future<http.Response> postOcrRequest(String apiKey) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_crmOcrUrl),
        );
        request.headers['Accept'] = 'application/json';
        if (apiKey.isNotEmpty) {
          request.headers['X-API-KEY'] = apiKey;
        }

        // Lampirkan file citra KTP
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldFoto,
            bytes,
            filename: name,
            contentType: mediaType,
          ),
        );

        final currentKavling = _ctrl['no_kavling']?.text.trim() ?? '';
        if (currentKavling.isNotEmpty) {
          request.fields['no_kavling'] = currentKavling;
        }
        request.fields['method'] = 'sharpen';

        final streamed =
            await request.send().timeout(const Duration(seconds: 90));
        return http.Response.fromStream(streamed);
      }

      // Kirim request pertama dengan API key utama
      http.Response response = await postOcrRequest(_crmApiKey);

      // Otomatis coba fallback API key jika server lokal/staging menghasilkan 401
      if (response.statusCode == 401 && _crmFallbackApiKey != _crmApiKey) {
        response = await postOcrRequest(_crmFallbackApiKey);
      }

      final json = await _decode(response);
      final data = _toMap(json['data']);

      // 1. Ekstraksi kolom utama untuk formulir
      _ctrl['nama']!.text = _str(data['nama']);
      _ctrl['nik']!.text = _str(data['nik']).replaceAll(RegExp(r'\D'), '');
      _ctrl['alamat']!.text = _cleanAddress(_str(data['alamat']));
      if (_ctrl['no_kavling'] != null &&
          _ctrl['no_kavling']!.text.isEmpty &&
          data['no_kavling'] != null) {
        _ctrl['no_kavling']!.text = _str(data['no_kavling']);
      }

      // 2. Simpan semua data pendukung hasil OCR ke dalam metadata
      final rawMeta = _toMap(data['metadata']);
      final meta = Map<String, dynamic>.from(rawMeta);
      meta['jenis_kelamin'] = _str(data['jenis_kelamin']);
      meta['tanggal_lahir'] = _str(data['tanggal_lahir']);
      meta['pekerjaan'] = _str(data['pekerjaan']);
      meta['kewarganegaraan'] = _str(data['kewarganegaraan']);
      meta['berlaku_hingga'] = _str(data['berlaku_hingga']);
      if (data['agama'] != null && _str(data['agama']).isNotEmpty) {
        meta['agama'] = _str(data['agama']);
      }
      if (data['status_perkawinan'] != null &&
          _str(data['status_perkawinan']).isNotEmpty) {
        meta['status_perkawinan'] = _str(data['status_perkawinan']);
      }

      if (!mounted) return;
      setState(() {
        _ktpId = null; // Record baru belum disimpan ke database
        _metadata = meta;
        _scanInfo = 'Data KTP berhasil diambil';
        _scanning = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    } on TimeoutException catch (e, stack) {
      debugPrint('TimeoutException OCR: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError =
            'Waktu habis. Proses OCR AI membutuhkan waktu lebih lama. Silakan coba lagi.';
      });
    } on http.ClientException catch (e, stack) {
      debugPrint('ClientException OCR: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError =
            'Gagal terhubung ke server OCR. Pastikan perangkat terhubung ke jaringan.';
      });
    } on ApiException catch (e, stack) {
      debugPrint(
          'ApiException OCR: ${e.message} (HTTP ${e.statusCode})\n$stack');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = e.message;
      });
    } on FormatException catch (e, stack) {
      debugPrint('FormatException OCR: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = 'Format respons OCR tidak sesuai format data.';
      });
    } catch (e, stack) {
      debugPrint('Error OCR tidak terduga: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError =
            'Terjadi kesalahan sistem saat memproses KTP. Silakan coba lagi.';
      });
    } finally {
      if (mounted && _scanning) {
        setState(() => _scanning = false);
      }
    }
  }

  // =========================================================
  // SIMPAN  ->  POST /api/ktp (Baru) atau PUT /api/ktp/{id}
  // =========================================================

  Future<void> _simpan() async {
    if (_saving) return;
    if (_ctrl['nama']!.text.trim().isEmpty &&
        _ctrl['nik']!.text.trim().isEmpty) {
      _snack('Scan KTP atau isi formulir sebelum menyimpan');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      String? fotoKtpPayload;
      if (_imageBytes != null) {
        try {
          final compactBytes = PhotoTools.prepareForStorage(_imageBytes!);
          fotoKtpPayload =
              'data:image/jpeg;base64,${base64Encode(compactBytes)}';
        } catch (e, stack) {
          debugPrint('Gagal menyiapkan foto untuk penyimpanan: $e\n$stack');
        }
      }

      final isUpdate = _ktpId != null && _ktpId!.isNotEmpty;

      final body = <String, String>{
        'set_kategori': isUpdate ? 'update' : 'insert',
        if (isUpdate) 'id': _ktpId!,
        for (final f in _fields) f.key: _ctrl[f.key]!.text.trim(),
        'metadata': jsonEncode(_metadata),
        if (fotoKtpPayload != null) 'foto_ktp': fotoKtpPayload,
        'id_rt': KodeRt.kodeRt,
      };

      final http.Response response = await http
          .post(
            Uri.parse('${ApiUrls.baseUrl}$endpointKtp'),
            headers: {'Accept': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      final json = await _decode(response);

      if (!mounted) return;
      _snack(_msg(json) ?? 'Data KTP berhasil disimpan', error: false);
      _resetForm();
      _clearImage();
      _fetchList();
    } on TimeoutException catch (e, stack) {
      debugPrint('TimeoutException simpan: $e\n$stack');
      _snack('Waktu koneksi habis saat menyimpan. Silakan coba lagi.');
    } on http.ClientException catch (e, stack) {
      debugPrint('ClientException simpan: $e\n$stack');
      _snack(
          'Gagal menghubungi server database. Periksa koneksi jaringan Anda.');
    } on ApiException catch (e, stack) {
      debugPrint(
          'ApiException simpan: ${e.message} (HTTP ${e.statusCode})\n$stack');
      _snack(e.message);
    } on FormatException catch (e, stack) {
      debugPrint('FormatException simpan: $e\n$stack');
      _snack('Format data penyimpanan tidak valid.');
    } catch (e, stack) {
      debugPrint('Error simpan KTP tidak terduga: $e\n$stack');
      _snack('Terjadi kesalahan sistem saat menyimpan data KTP.');
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
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}$endpointKtp'),
        headers: {'Accept': 'application/json'},
        body: {
          'set_kategori': 'select',
          'page': page.toString(),
          'limit': pageSize.toString(),
          'search': _searchCtrl.text.trim(),
          'id_rt': KodeRt.kodeRt,
        },
      ).timeout(const Duration(seconds: 20));
      final json = await _decode(response);

      final data = _toMap(json['data']);
      final List list =
          data['items'] is List ? data['items'] as List : const [];
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
    } on TimeoutException catch (e, stack) {
      debugPrint('TimeoutException fetch list: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = 'Waktu koneksi habis saat memuat daftar data.';
      });
    } on http.ClientException catch (e, stack) {
      debugPrint('ClientException fetch list: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError =
            'Koneksi ke server terputus. Pastikan perangkat terhubung.';
      });
    } on ApiException catch (e, stack) {
      debugPrint(
          'ApiException fetch list: ${e.message} (HTTP ${e.statusCode})\n$stack');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = e.message;
      });
    } on FormatException catch (e, stack) {
      debugPrint('FormatException fetch list: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = 'Data daftar tidak valid.';
      });
    } catch (e, stack) {
      debugPrint('Error ambil daftar KTP tidak terduga: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = 'Gagal memuat data pengunjung. Silakan coba lagi.';
      });
    } finally {
      if (mounted && _loadingList) {
        setState(() => _loadingList = false);
      }
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
        Uri.parse('${ApiUrls.baseUrl}$endpointKtp'),
        headers: {'Accept': 'application/json'},
        body: {
          'id_rt': KodeRt.kodeRt,
          'set_kategori': 'checkout',
          'id': id,
        },
      ).timeout(const Duration(seconds: 15));

      final json = await _decode(response);
      _snack(_msg(json) ?? 'Checkout berhasil', error: false);
      await _fetchList(page: _page);
    } on TimeoutException catch (e, stack) {
      debugPrint('TimeoutException checkout: $e\n$stack');
      _snack('Waktu koneksi habis saat checkout. Silakan coba lagi.');
    } on http.ClientException catch (e, stack) {
      debugPrint('ClientException checkout: $e\n$stack');
      _snack('Koneksi terputus saat checkout. Periksa jaringan Anda.');
    } on ApiException catch (e, stack) {
      debugPrint(
          'ApiException checkout: ${e.message} (HTTP ${e.statusCode})\n$stack');
      _snack(e.message);
    } on FormatException catch (e, stack) {
      debugPrint('FormatException checkout: $e\n$stack');
      _snack('Format respons checkout tidak valid.');
    } catch (e, stack) {
      debugPrint('Error checkout: $e\n$stack');
      _snack('Gagal memproses checkout tamu. Silakan coba lagi.');
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
                        Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: wide ? 420 : double.infinity,
        child: _buildTipeToggle(),
      ),
    ),
    const SizedBox(height: 20),
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
                      ? InkWell(
                          onTap: _onKameraPressed,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 42,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Ketuk untuk Buka Kamera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Atau gunakan tombol KAMERA di bawah',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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
                              // Tidak mengisi _scanError saat inisialisasi awal
                              // agar tidak memunculkan kesan error saat pengguna baru membuka halaman
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
            if (_imageBytes != null && !_scanning && !_preparing)
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Potong foto (crop)',
                    icon: const Icon(Icons.crop, color: Colors.white),
                    onPressed: _cropPhoto,
                  ),
                ),
              ),
            if (_scanning || _preparing)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _preparing
                          ? 'Menyiapkan foto...'
                          : 'Sedang Memindai KTP...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
          _imageBytes != null
              ? 'Foto siap diproses. Tekan "Baca KTP" di atas untuk memindai data.'
              : !_cameraUnavailable
                  ? 'Posisikan seluruh KTP di dalam kotak kuning, pegang HP sejajar dengan kartu, lalu tekan KAMERA'
                  : 'Pegang KTP tegak lurus, cahaya cukup. Tekan KAMERA untuk memotret atau PILIH FILE dari galeri',
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
          // no_kavling dan alamat opsional -> tidak memblokir simpan
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
                  style: const TextStyle(fontSize: 12.5, color: Colors.black45),
                ),
                Text(
                  'Keluar: ${keluar.isEmpty ? '-' : keluar}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black45),
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
