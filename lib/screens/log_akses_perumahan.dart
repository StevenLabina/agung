import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/url.dart';
import 'web_qr_scanner.dart'; // taruh file ini di folder yang sama

enum ScanStatus { success, notResident, error }

class ScanResult {
  final ScanStatus status;
  final String message;
  final String? nama;
  final String? noKavling;
  final String? alamat;
  final String? waktu;

  const ScanResult({
    required this.status,
    required this.message,
    this.nama,
    this.noKavling,
    this.alamat,
    this.waktu,
  });
}

class LogAksesPerumahanPage extends StatefulWidget {
  const LogAksesPerumahanPage({super.key});

  @override
  State<LogAksesPerumahanPage> createState() => _LogAksesPerumahanPageState();
}

class _LogAksesPerumahanPageState extends State<LogAksesPerumahanPage> {
  static const Color primaryColor = Color(0xFF3D8D7A);
  static const Color bgColor = Color(0xFF3D8D7A);
  static const Duration cooldown = Duration(seconds: 3);
  static const double wideBreakpoint = 900;

  // Lokasi file suara -> assets/sounds/berhasil.mp3 & assets/sounds/gagal.mp3
  // (AssetSource otomatis diawali "assets/", jadi JANGAN pakai "/" di depan)
  static const String soundBerhasil = 'berhasil.mp3';
  static const String soundGagal = 'gagal.mp3';

  // Kamera depan/belakang (di laptop biasanya hanya ada satu kamera)
  bool _frontCamera = false;
  bool _isMirrored = false; 
  // Cegah QR yang sama tercatat berulang selama masih di depan kamera
  String? _lastRaw;
  DateTime? _lastScanAt;
  static const Duration sameQrWindow = Duration(seconds: 5);

  final AudioPlayer _player = AudioPlayer();

  // ---- state scan ----
  String? _mode; // null = belum pilih, 'masuk' | 'keluar'
  bool _isProcessing = false;
  ScanResult? _result;

  // ---- state tabel log ----
  List<Map<String, dynamic>> _logs = [];
  bool _loadingLog = false;
  String? _logError;
  int _page = 1;
  int _totalPages = 1;
  DateTime? _dari;
  DateTime? _sampai;

  @override
  void initState() {
    super.initState();
    _fetchLog();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // =========================================================
  // SUARA
  // =========================================================

  Future<void> _playSound(String file) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(file));
    } catch (e) {
      debugPrint('Gagal memutar suara: $e');
    }
  }

  // =========================================================
  // SCAN HANDLER
  // =========================================================

  Future<void> _onCode(String raw) async {
    if (_isProcessing) return;

    debugPrint('SCAN raw="$raw" | KodeRt=${KodeRt.kodeRt} | mode=$_mode');
    if (raw.trim().isEmpty) return;

    // User harus klik MASUK / KELUAR dulu -> beri tahu, jangan diam saja
    final String? modeSaatScan = _mode;
    if (modeSaatScan == null) {
      setState(() {
        _isProcessing = true;
        _result = const ScanResult(
          status: ScanStatus.error,
          message: 'Pilih MASUK atau KELUAR dulu, lalu scan lagi',
        );
      });
      _playSound(soundGagal);
      await Future.delayed(cooldown);
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = null;
      });
      return;
    }

    final now = DateTime.now();
    if (raw == _lastRaw &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < sameQrWindow) {
      return;
    }
    _lastRaw = raw;
    _lastScanAt = now;

    setState(() {
      _isProcessing = true;
      _result = null;
    });

    final result = await _validateAndRecord(raw, modeSaatScan);

    if (!mounted) return;
    setState(() => _result = result);

    if (result.status == ScanStatus.success) {
      _playSound(soundBerhasil);
      _fetchLog(); // refresh tabel
    } else {
      _playSound(soundGagal);
    }

    await Future.delayed(cooldown);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _result = null;
    });
  }

  Future<ScanResult> _validateAndRecord(String raw, String mode) async {
    // 1. Parse isi QR: {"id_rt": "...", "no_kavling": "..."}
    String idRt;
    String noKavling;
    final String cuplikan = raw.length > 40 ? '${raw.substring(0, 40)}...' : raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ScanResult(
          status: ScanStatus.notResident,
          message: 'QR bukan QR warga\n(isi: $cuplikan)',
        );
      }
      idRt = (decoded['id_rt'] ?? '').toString().trim();
      noKavling = (decoded['no_kavling'] ?? '').toString().trim();
    } catch (_) {
      return ScanResult(
        status: ScanStatus.notResident,
        message: 'QR bukan JSON warga\n(isi: $cuplikan)',
      );
    }

    if (idRt.isEmpty || noKavling.isEmpty) {
      return const ScanResult(
        status: ScanStatus.notResident,
        message: 'Data QR tidak lengkap',
      );
    }

    // 2. id_rt di QR harus sama dengan RT aplikasi ini
    if (idRt != KodeRt.kodeRt.toString().trim()) {
      return ScanResult(
        status: ScanStatus.notResident,
        message:
            'QR ini bukan milik RT ini\n(QR: $idRt, aplikasi: ${KodeRt.kodeRt})',
      );
    }

    // 3. Server cek no_kavling di RT ini + catat log
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}catat_akses_perumahan.php'),
        body: {
          'id_rt': idRt,
          'no_kavling': noKavling,
          'jenis': mode,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const ScanResult(
          status: ScanStatus.error,
          message: 'Gagal terhubung ke server',
        );
      }

      final json = jsonDecode(response.body);

      if (json['result'] == true) {
        final data = json['data'] ?? {};
        return ScanResult(
          status: ScanStatus.success,
          message: json['message']?.toString() ?? 'Berhasil dicatat',
          nama: data['nama']?.toString(),
          noKavling: data['no_kavling']?.toString(),
          alamat: data['alamat_kavling']?.toString(),
          waktu: data['waktu']?.toString(),
        );
      }

      if (json['terdaftar'] == false) {
        return ScanResult(
          status: ScanStatus.notResident,
          message:
              json['message']?.toString() ?? 'Tidak tercatat sebagai warga',
        );
      }

      return ScanResult(
        status: ScanStatus.error,
        message: json['message']?.toString() ?? 'Terjadi kesalahan',
      );
    } catch (e) {
      debugPrint('Error scan akses: $e');
      return const ScanResult(
        status: ScanStatus.error,
        message: 'Gagal terhubung ke server',
      );
    }
  }

  // =========================================================
  // TABEL LOG
  // =========================================================

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetchLog({int page = 1}) async {
    setState(() {
      _loadingLog = true;
      _logError = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}ambil_log_akses_perumahan.php'),
        body: {
          'id_rt': KodeRt.kodeRt.toString(),
          'dari': _dari == null ? '' : _fmtDate(_dari!),
          'sampai': _sampai == null ? '' : _fmtDate(_sampai!),
          'page': page.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Gagal terhubung ke server');
      }

      final json = jsonDecode(response.body);
      if (json['result'] != true) {
        throw Exception(json['message'] ?? 'Gagal memuat log');
      }

      if (!mounted) return;
      final int totalPages = int.tryParse('${json['total_pages']}') ?? 1;
      setState(() {
        _logs = (json['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _page = int.tryParse('${json['page']}') ?? page;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _loadingLog = false;
      });
    } catch (e) {
      debugPrint('Error ambil log: $e');
      if (!mounted) return;
      setState(() {
        _loadingLog = false;
        _logError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate({required bool isDari}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isDari ? _dari : _sampai) ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isDari) {
        _dari = picked;
      } else {
        _sampai = picked;
      }
    });
  }

  void _applyFilter() {
    if (_dari != null && _sampai != null && _dari!.isAfter(_sampai!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal "Dari" tidak boleh melebihi "Sampai"'),
        ),
      );
      return;
    }
    _fetchLog();
  }

  void _resetFilter() {
    setState(() {
      _dari = null;
      _sampai = null;
    });
    _fetchLog();
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
          'Scan Akses Perumahan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
     actions: [
  // Tombol Flip Mirror (Cermin)
  IconButton(
    icon: Icon(
      _isMirrored ? Icons.flip : Icons.flip_outlined,
      color: _isMirrored ? Colors.amber : Colors.white,
    ),
    tooltip: 'Mirror Kamera',
    onPressed: () => setState(() => _isMirrored = !_isMirrored),
  ),
  // Tombol Ganti Kamera Depan/Belakang
  IconButton(
    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
    tooltip: 'Ganti Kamera',
    onPressed: () => setState(() => _frontCamera = !_frontCamera),
  ),
],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= wideBreakpoint;

            if (wide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 420, child: _buildScanSection()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildLogCard(wide: true)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _buildScanSection(),
                      const SizedBox(height: 20),
                      _buildLogCard(wide: false),
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
        _buildModeToggle(),
        const SizedBox(height: 20),
        _buildScanner(),
        const SizedBox(height: 20),
        _buildResultCard(),
      ],
    );
  }

 Widget _buildModeToggle() {
  Widget button(
    String value,
    String label,
    IconData icon,
  ) {
    final bool selected = _mode == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isProcessing) return;

          setState(() {
            _mode = value;
            _result = null;
          });
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),

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
        'masuk',
        'MASUK',
        Icons.login,
      ),

      const SizedBox(width: 8),

      button(
        'keluar',
        'KELUAR',
        Icons.logout,
      ),
    ],
  );
}
 Widget _buildScanner() {
  return AspectRatio(
    aspectRatio: 1,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Key hanya bergantung kamera depan/belakang.
          // Mirror lewat CSS, jadi kamera tidak restart.
          WebQrScanner(
            key: ValueKey(_frontCamera),
            useFrontCamera: _frontCamera,
            mirrored: _isMirrored,
            paused: _isProcessing,
            onCode: _onCode,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_mode == null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Pilih MASUK atau KELUAR\nterlebih dahulu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
         
          if (_isProcessing && _result == null)
            Container(color: Colors.black45),
        ],
      ),
    ),
  );
}
  Widget _buildResultCard() {
    final result = _result;

    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _mode == null
              ? 'Pilih MASUK atau KELUAR, lalu scan QR warga'
              : 'Arahkan QR warga ke kamera untuk mencatat ${_mode!.toUpperCase()}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      );
    }

    late final Color color;
    late final IconData icon;

    switch (result.status) {
      case ScanStatus.success:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ScanStatus.notResident:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case ScanStatus.error:
        color = Colors.orange;
        icon = Icons.error;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 56),
          const SizedBox(height: 8),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (result.status == ScanStatus.success) ...[
            const SizedBox(height: 12),
            if (result.nama != null && result.nama!.isNotEmpty)
              Text(result.nama!,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 4),
          Text(
  'No. Kavling ${result.noKavling ?? '-'}',
  textAlign: TextAlign.center,
  style: const TextStyle(
    color: Colors.white70,
  ),
),

if (result.alamat != null && result.alamat!.isNotEmpty) ...[
  const SizedBox(height: 4),

  Text(
    result.alamat!,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: Colors.white70,
    ),
  ),
],
            const SizedBox(height: 4),
            Text(
              result.waktu ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // LOG CARD (filter + tabel + pagination)
  // ---------------------------------------------------------

  Widget _buildLogCard({required bool wide}) {
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
            'Log Akses Perumahan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1B1B1F),
            ),
          ),
          const SizedBox(height: 20),
          _buildFilter(wide),
          const SizedBox(height: 20),
          _buildLogContent(wide),
          const SizedBox(height: 16),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilter(bool wide) {
  Widget dateField(
    String label,
    DateTime? value,
    bool isDari,
    double width,
  ) {
    return SizedBox(
      width: width,
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _pickDate(isDari: isDari),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),

              // Jangan biarkan Text memaksa Row melebar
              Expanded(
                child: Text(
                  value == null ? label : _fmtDate(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        value == null ? Colors.black54 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;

      // MOBILE
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dateField(
              'Dari Tanggal',
              _dari,
              true,
              maxWidth,
            ),

            const SizedBox(height: 10),

            dateField(
              'Sampai Tanggal',
              _sampai,
              false,
              maxWidth,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: maxWidth,
              height: 48,
              child: ElevatedButton(
                onPressed: _loadingLog ? null : _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Tampilkan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            if (_dari != null || _sampai != null) ...[
              const SizedBox(height: 4),

              SizedBox(
                width: maxWidth,
                child: TextButton(
                  onPressed: _loadingLog ? null : _resetFilter,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ],
        );
      }

      // DESKTOP
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          dateField(
            'Dari Tanggal',
            _dari,
            true,
            200,
          ),

          dateField(
            'Sampai Tanggal',
            _sampai,
            false,
            200,
          ),

          SizedBox(
            width: 150,
            height: 48,
            child: ElevatedButton(
              onPressed: _loadingLog ? null : _applyFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Tampilkan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          if (_dari != null || _sampai != null)
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: _loadingLog ? null : _resetFilter,
                child: const Text('Reset'),
              ),
            ),
        ],
      );
    },
  );
}

  Widget _buildLogContent(bool wide) {
    Widget body;

    if (_loadingLog) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    } else if (_logError != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Text(_logError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _fetchLog(page: _page),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    } else if (_logs.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text('Belum ada log akses',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    } else {
      body = wide ? _buildDesktopRows() : _buildMobileCards();
    }

    if (!wide) return body;

    // Desktop: bingkai tabel dengan header hijau
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _desktopHeader(),
            body,
          ],
        ),
      ),
    );
  }

  // Lebar kolom desktop (flex)
  static const int _fTanggal = 3;
  static const int _fKavling = 2;
  static const int _fNama = 4;
  static const int _fAktivitas = 4;

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
          cell('Tanggal', _fTanggal),
          cell('No Kavling', _fKavling),
          cell('Nama Warga', _fNama),
          cell('Aktivitas', _fAktivitas),
        ],
      ),
    );
  }

  Widget _desktopRow(Map<String, dynamic> log) {
    final bool masuk = log['jenis'] == 'masuk';
    Widget cell(Widget child, int flex) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: child,
          ),
        );
    const style = TextStyle(fontSize: 13.5, color: Color(0xFF222222));

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          cell(Text('${log['waktu'] ?? '-'}', style: style), _fTanggal),
          cell(Text('${log['no_kavling'] ?? '-'}', style: style), _fKavling),
          cell(Text('${log['nama'] ?? '-'}', style: style), _fNama),
        cell(
  Row(
    children: [
      Icon(
        masuk ? Icons.login : Icons.logout,
        size: 16,
        color: masuk ? Colors.green : Colors.orange,
      ),

      const SizedBox(width: 6),

      Expanded(
        child: Text(
          masuk
              ? 'Masuk perumahan'
              : 'Keluar perumahan',
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            fontWeight: FontWeight.w600,
            color: masuk
                ? Colors.green.shade700
                : Colors.orange.shade800,
          ),
        ),
      ),
    ],
  ),
  _fAktivitas,
),
        ],
      ),
    );
  }

  Widget _buildDesktopRows() {
    return Column(children: _logs.map(_desktopRow).toList());
  }

  // Mobile: tiap log jadi kartu
  Widget _buildMobileCards() {
    return Column(
      children: _logs.map((log) {
        final bool masuk = log['jenis'] == 'masuk';
        final Color c = masuk ? Colors.green : Colors.orange;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(masuk ? Icons.login : Icons.logout,
                            size: 14, color: c),
                        const SizedBox(width: 4),
                        Text(
                          masuk ? 'Masuk' : 'Keluar',
                          style: TextStyle(
                              color: c,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
               Flexible(
  child: Text(
    '${log['waktu'] ?? '-'}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.right,
    style: const TextStyle(
      fontSize: 12.5,
      color: Colors.black54,
    ),
  ),
),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${log['nama'] ?? '-'}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'No Kavling: ${log['no_kavling'] ?? '-'}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPagination() {
    final bool canPrev = !_loadingLog && _page > 1;
    final bool canNext = !_loadingLog && _page < _totalPages;

    ButtonStyle style = ElevatedButton.styleFrom(
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
          onPressed: canPrev ? () => _fetchLog(page: _page - 1) : null,
          child: const Text('Previous'),
        ),
        Text('Halaman $_page dari $_totalPages',
            style: const TextStyle(fontSize: 15)),
        ElevatedButton(
          style: style,
          onPressed: canNext ? () => _fetchLog(page: _page + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}