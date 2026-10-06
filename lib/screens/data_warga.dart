import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/edit_warga.dart';
import 'package:iuran_rt_web/screens/kk_pemilik_rumah.dart';
import 'package:iuran_rt_web/screens/kk_penanggung_jawab.dart';

import 'package:iuran_rt_web/screens/login.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kGreen = Color(0xFF3D8D7A);
const Color kTableBorder = Color(0xFF8A8A8A);

class DataPendudukPage extends StatefulWidget {
  @override
  _DataPendudukPageState createState() => _DataPendudukPageState();
}

class _DataPendudukPageState extends State<DataPendudukPage> {
  List<dynamic> dataPenduduk = [];
  bool isLoading = true;
  String errorMessage = '';
  TextEditingController searchController = TextEditingController();

  bool isSelectMode = false;
  List<String> selectedWargaId = [];
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  int currentPage = 0;
  int rowsPerPage = 10;

  int get totalPages {
    if (dataPenduduk.isEmpty) return 1;
    return (dataPenduduk.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (dataPenduduk.isEmpty) return [];
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, dataPenduduk.length);
    return dataPenduduk.sublist(start, end);
  }

  // Lebar relatif tiap kolom tabel (desktop)
  static const List<double> _colFlex = [
    1.0, // No Kavling
    1.7, // Alamat
    1.6, // Nama Pemilik
    1.5, // Telpon Pemilik
    1.6, // KK Pemilik
    1.6, // Nama Penghuni
    1.5, // Telpon Penghuni
    1.6, // KK Penghuni
    1.3, // Aksi
    1.8, // Hak Akses
  ];
  static const double _tableMinWidth = 1750;

  Map<int, TableColumnWidth> get _columnWidths => {
        for (int i = 0; i < _colFlex.length; i++)
          i: FlexColumnWidth(_colFlex[i]),
      };

  @override
  void initState() {
    super.initState();
    fetchPendudukData();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ===========================================================
  // HELPERS DATA
  // ===========================================================
  String _s(dynamic v) {
    if (v == null) return '-';
    final t = v.toString().trim();
    return t.isEmpty ? '-' : t;
  }

  bool _hasValue(dynamic v) => v != null && v.toString().trim().isNotEmpty;

  int _id(dynamic item) => int.tryParse(item['id'].toString()) ?? 0;

  bool _isPengurus(dynamic item) {
    final v = item['pengurus_rt'];
    return v == 1 || v == '1';
  }

  List<dynamic> get pengurusRtList {
    return dataPenduduk.where((item) => _isPengurus(item)).toList();
  }

  int get totalPengurusRt => pengurusRtList.length;

  // ===========================================================
  // API
  // ===========================================================
  Future<void> fetchPendudukData([String query = ""]) async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listWarga_android.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'searchQuery': query, 'id_rt': KodeRt.kodeRt},
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success' && result['data'] != null) {
        setState(() {
          dataPenduduk = result['data'];
        });
      } else {
        setState(() {
          dataPenduduk = [];
        });
        Flushbar(
          message: "Data Tidak Ditemukan",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> tambahLogAktivitas({
    required String aktivitas,
  }) async {
    final Uri url = Uri.parse('${ApiUrls.baseUrl}/tambah_log_aktivitas.php');
    final prefs = await SharedPreferences.getInstance();
    int? idUser = prefs.getInt("idUser");
    try {
      final response = await http.post(
        url,
        body: {
          'aktivitas': aktivitas,
          'id_warga': idUser.toString(),
          'id_rt': KodeRt.kodeRt
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal menambahkan data: ${result['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal koneksi ke server')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  Future<void> updatePengurusRt(
      int newId, String hakAkses, String noKavling) async {
    final prefs = await SharedPreferences.getInstance();
    int? idUser = prefs.getInt("idUser");
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/newRt.php"),
        body: {
          'id': newId.toString(),
          'id_rt': KodeRt.kodeRt,
          'id_pengurus_rt': idUser.toString(),
          'hak': hakAkses
        },
      );

      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        fetchPendudukData();
        if (hakAkses == "TUKAR") {
          await tambahLogAktivitas(
            aktivitas:
                'Mengalihkan hak akses Pengurus RT ke warga lain. Pengurus rt baru dengan warga no kavling: $noKavling ',
          );

          Flushbar(
            message:
                "Berhasil mengalihkan hak akses Pengurus RT. Silakan login ulang untuk melihat perubahan.",
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);

          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MyLogin()),
            (route) => false,
          );
        }

        if (hakAkses == "HAPUS") {
          await tambahLogAktivitas(
            aktivitas:
                'Menghapus hak akses Pengurus RT untuk warga no kavling $noKavling',
          );

          if (newId.toString() == idUser.toString()) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MyLogin()),
              (route) => false,
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DataPendudukPage(),
              ),
            );
            Flushbar(
              message:
                  "Berhasil menghapus hak akses Pengurus RT. Status pengguna telah diubah menjadi Warga",
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
              flushbarPosition: FlushbarPosition.TOP,
            ).show(context);
          }
        }

        if (hakAkses == "TAMBAH") {
          await tambahLogAktivitas(
            aktivitas:
                'Memberikan hak akses Pengurus RT kepada warga no kavling $noKavling',
          );

          Flushbar(
            message:
                "Berhasil memberikan hak akses Pengurus RT kepada warga yang dipilih",
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(json['message'],
                  style: GoogleFonts.lato(color: Colors.white))),
        );
      }
    } catch (e) {
      print('Error updating pengurus RT: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to update Pengurus RT",
                style: GoogleFonts.lato(color: Colors.white))),
      );
    }
  }

  // ===========================================================
  // AKSI BERSAMA (desktop & mobile)
  // ===========================================================
  void _showKkTidakTerdaftar() {
    Flushbar(
      message: "No KK tidak terdaftar",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  void _openKkPemilik(dynamic item, {bool replace = false}) {
    if (!_hasValue(item['no_kk_pemilik_rumah'])) {
      _showKkTidakTerdaftar();
      return;
    }
    final route = MaterialPageRoute(
      builder: (_) => KkPemilikRumahPage(no_kk: item['no_kk_pemilik_rumah']),
    );
    replace
        ? Navigator.pushReplacement(context, route)
        : Navigator.push(context, route);
  }

  void _openKkPenghuni(dynamic item, {bool replace = false}) {
    if (!_hasValue(item['no_kk_penanggung_jawab'])) {
      _showKkTidakTerdaftar();
      return;
    }
    final route = MaterialPageRoute(
      builder: (_) =>
          KkPenanggungJawabPage(no_kk: item['no_kk_penanggung_jawab']),
    );
    replace
        ? Navigator.pushReplacement(context, route)
        : Navigator.push(context, route);
  }

  Future<void> _openEdit(dynamic item, {bool replace = false}) async {
    final route = MaterialPageRoute(
      builder: (_) => EditDataWargaPage(id: _id(item)),
    );
    final result = replace
        ? await Navigator.pushReplacement(context, route)
        : await Navigator.push(context, route);

    if (result != null && result['status'] == true) {
      fetchPendudukData(result['kavling']);
    }
  }

  void _showBatasPengurusFlushbar() {
    Flushbar(
      message:
          "Batas maksimal Pengurus RT (5) sudah tercapai. Gunakan Tukar atau Hapus Hak Akses.",
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  void _showHapusHakAksesDialog(dynamic item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDECE8),
          title: Text('Konfirmasi',
              style: GoogleFonts.lato(color: Colors.black)),
          content: Text(
            'Hapus hak akses Pengurus RT untuk no kavling ${item["no_kavling"]}?',
            style: GoogleFonts.lato(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal', style: GoogleFonts.lato(color: kGreen)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                updatePengurusRt(
                    _id(item), "HAPUS", item['no_kavling'].toString());
              },
              child: Text('Hapus', style: GoogleFonts.lato(color: kGreen)),
            ),
          ],
        );
      },
    );
  }

  void _showHakAksesDialog(dynamic item) {
    final bool pengurus = _isPengurus(item);
    final String noKavling = _s(item['no_kavling']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDECE8),
          title: Text(
            'Konfirmasi Hak Akses Pengurus RT',
            style: GoogleFonts.lato(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Text(
                'Kavling $noKavling\n\n'
                'Pilih tindakan yang ingin dilakukan:\n\n'
                '• Tukar Hak Akses\n'
                '  Hak akses Pengurus RT Anda akan dipindahkan ke warga ini.\n'
                '  Anda akan menjadi warga biasa dan harus login ulang.\n\n'
                '• Tambah Hak Akses\n'
                '  Warga ini akan menjadi Pengurus RT tanpa mengubah hak akses Anda.\n\n'
                '• Hapus Hak Akses\n'
                '  Hak akses Pengurus RT warga ini akan dicabut.\n'
                '  Statusnya akan kembali menjadi warga biasa.\n',
                style: GoogleFonts.lato(color: Colors.black),
              ),
            ),
          ),
          actionsPadding:
              const EdgeInsets.only(bottom: 10, right: 10, left: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.lato(color: kGreen)),
            ),
            if (!pengurus)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      totalPengurusRt >= 5 ? Colors.grey : Colors.green,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (totalPengurusRt >= 5) {
                    _showBatasPengurusFlushbar();
                    return;
                  }
                  updatePengurusRt(_id(item), "TAMBAH", noKavling);
                },
                child: Text('Tambah Hak Akses',
                    style: GoogleFonts.lato(color: Colors.white)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(context);
                updatePengurusRt(_id(item), "TUKAR", noKavling);
              },
              child: Text('Tukar Hak Akses',
                  style: GoogleFonts.lato(color: Colors.white)),
            ),
            if (pengurus)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  updatePengurusRt(_id(item), "HAPUS", noKavling);
                },
                child: Text('Hapus Hak Akses',
                    style: GoogleFonts.lato(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }

  // ===========================================================
  // BUILD
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          backgroundColor: Colors.white,
          body: isMobile
              ? _buildMobileContent(context)
              : _buildDesktopContent(context),
        );
      },
    );
  }

  // ===========================================================
  // KOMPONEN UI BERSAMA
  // ===========================================================
  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildTopBar({required bool isMobile}) {
    return Container(
      width: double.infinity,
      height: isMobile ? 65 : 80,
      margin: EdgeInsets.fromLTRB(isMobile ? 0 : 16, 12, isMobile ? 0 : 16, 0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 232, 226, 226),
        border: Border.all(
          color: const Color.fromARGB(255, 58, 112, 50),
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24, vertical: isMobile ? 8 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: Colors.black, size: isMobile ? 20 : 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuPilihanPage(idMenu: 2),
                    ),
                  );
                },
              ),
              Text(
                'Data Warga',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          if (!isMobile)
            Image.asset(
              'assets/images/Logo4.png',
              height: 40,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField({String? hint}) {
    return TextField(
      controller: searchController,
      style: GoogleFonts.roboto(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint ?? 'No Kavling / Nama Penghuni / Pemilik',
        hintStyle: GoogleFonts.roboto(color: Colors.grey[700], fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: kGreen),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGreen, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGreen, width: 1.8),
        ),
      ),
      onChanged: (value) => fetchPendudukData(value),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    IconData? icon,
    double? width,
    double height = 34,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final bool hasPrev = currentPage > 0;
    final bool hasNext = (currentPage + 1) * rowsPerPage < dataPenduduk.length;

    ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: kGreen,
      disabledBackgroundColor: Colors.grey.shade400,
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white70,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          style: style,
          onPressed: hasPrev ? () => setState(() => currentPage--) : null,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 18),
        Text(
          'Halaman ${currentPage + 1} dari $totalPages',
          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 18),
        ElevatedButton(
          style: style,
          onPressed: hasNext ? () => setState(() => currentPage++) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildEmptyOrLoading() {
    return Center(
      child: isLoading
          ? const CircularProgressIndicator(color: kGreen)
          : Text(
              'Data tidak ditemukan',
              style: GoogleFonts.roboto(color: Colors.black, fontSize: 15),
            ),
    );
  }

  // ===========================================================
  // DESKTOP
  // ===========================================================
  Widget _buildDesktopContent(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(isMobile: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- PANEL KIRI ----------
                SizedBox(
                  width: 340,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: _cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pencarian',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSearchField(hint: 'No Kavling / Nama'),
                        const SizedBox(height: 28),
                        Text(
                          'Info Pengurus RT',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$totalPengurusRt dari 5 pengurus RT',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Kavling Pengurus RT',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pengurusRtList.isEmpty)
                          Text(
                            '-',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: pengurusRtList
                                .map<Widget>(
                                  (item) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: kGreen.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: kGreen),
                                    ),
                                    child: Text(
                                      _s(item['no_kavling']),
                                      style: GoogleFonts.roboto(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: kGreen,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // ---------- KARTU TABEL ----------
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                    decoration: _cardDecoration,
                    child: Column(
                      children: [
                        Text(
                          'Data Warga',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(child: _buildDesktopTable()),
                        const SizedBox(height: 16),
                        _buildPagination(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable() {
    if (isLoading || dataPenduduk.isEmpty) {
      return _buildEmptyOrLoading();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth > _tableMinWidth
            ? constraints.maxWidth
            : _tableMinWidth;

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    // ---------- HEADER ----------
                    Container(
                      color: kGreen,
                      child: Table(
                        columnWidths: _columnWidths,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _headerCell('No Kavling'),
                              _headerCell('Alamat Kavling'),
                              _headerCell('Nama Pemilik Rumah'),
                              _headerCell('No Telpon Pemilik'),
                              _headerCell('No KK Pemilik'),
                              _headerCell('Nama Penghuni'),
                              _headerCell('No Telpon Penghuni'),
                              _headerCell('No KK Penghuni'),
                              _headerCell('Aksi'),
                              _headerCell('Hak Akses'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ---------- BODY ----------
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          child: Table(
                            border: TableBorder.all(
                              color: kTableBorder,
                              width: 0.8,
                            ),
                            columnWidths: _columnWidths,
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: paginatedData
                                .map<TableRow>((item) => _buildDesktopRow(item))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Text(
        text,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _textCell(String? text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        (text == null || text.trim().isEmpty) ? '-' : text,
        style: GoogleFonts.roboto(fontSize: 13.5, color: Colors.black87),
      ),
    );
  }

  Widget _widgetCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Center(child: child),
    );
  }

  TableRow _buildDesktopRow(dynamic item) {
    final bool pengurus = _isPengurus(item);

    return TableRow(
      children: [
        _textCell(item['no_kavling']?.toString()),
        _textCell(item['alamat_kavling']?.toString()),
        _textCell(item['nama_pemilik_rumah']?.toString()),
        _textCell(item['no_telpon_pemilik_rumah']?.toString()),

        // NO KK PEMILIK
        _widgetCell(
          _pillButton(
            label: _s(item['no_kk_pemilik_rumah']),
            color: const Color(0xFF43A047),
            onPressed: () => _openKkPemilik(item),
          ),
        ),

        _textCell(item['nama_penanggung_jawab']?.toString()),
        _textCell(item['no_telpon_penanggung_jawab']?.toString()),

        // NO KK PENGHUNI
        _widgetCell(
          _pillButton(
            label: _s(item['no_kk_penanggung_jawab']),
            color: const Color(0xFF43A047),
            onPressed: () => _openKkPenghuni(item),
          ),
        ),

        // AKSI
        _widgetCell(
          _pillButton(
            label: 'Ubah Data',
            color: Colors.orange,
            icon: Icons.edit,
            onPressed: () => _openEdit(item),
          ),
        ),

        // HAK AKSES
        _widgetCell(
          pengurus
              ? _pillButton(
                  label: 'Hapus Hak Akses',
                  color: Colors.red,
                  icon: Icons.remove_moderator,
                  onPressed: () => _showHapusHakAksesDialog(item),
                )
              : _pillButton(
                  label: 'Jadi Pengurus RT',
                  color: const Color(0xFF43A047),
                  icon: Icons.add_moderator,
                  onPressed: () => _showHakAksesDialog(item),
                ),
        ),
      ],
    );
  }

  // ===========================================================
  // MOBILE
  // ===========================================================
  Widget _buildMobileContent(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(isMobile: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: _buildSearchField(
                hint: 'Cari No Kavling / Nama Penghuni / Pemilik'),
          ),
          Expanded(
            child: isLoading || dataPenduduk.isEmpty
                ? _buildEmptyOrLoading()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: paginatedData.length,
                    itemBuilder: (context, index) =>
                        _buildMobileCard(paginatedData[index]),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildPagination(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileSection({
    required String title,
    required IconData icon,
    required String nama,
    required String telpon,
    required String noKk,
    required VoidCallback onKkTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kGreen),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _mobileInfoRow('Nama', nama),
          _mobileInfoRow('No. Telepon', telpon),
          _mobileInfoRow('No. KK', noKk),
          const SizedBox(height: 8),
          _pillButton(
            label: 'Kartu Keluarga $title',
            color: const Color(0xFF43A047),
            icon: Icons.badge_outlined,
            onPressed: onKkTap,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(dynamic item) {
    final bool pengurus = _isPengurus(item);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- HEADER KARTU ----------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.home, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No. Kavling: ${_s(item['no_kavling'])}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (pengurus)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Pengurus RT',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kGreen,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _s(item['alamat_kavling']),
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ---------- PEMILIK RUMAH ----------
          _mobileSection(
            title: 'Pemilik Rumah',
            icon: Icons.person,
            nama: _s(item['nama_pemilik_rumah']),
            telpon: _s(item['no_telpon_pemilik_rumah']),
            noKk: _s(item['no_kk_pemilik_rumah']),
            onKkTap: () => _openKkPemilik(item, replace: true),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Divider(height: 1),
          ),

          // ---------- PENGHUNI ----------
          _mobileSection(
            title: 'Penghuni',
            icon: Icons.people,
            nama: _s(item['nama_penanggung_jawab']),
            telpon: _s(item['no_telpon_penanggung_jawab']),
            noKk: _s(item['no_kk_penanggung_jawab']),
            onKkTap: () => _openKkPenghuni(item, replace: true),
          ),

          // ---------- AKSI ----------
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _pillButton(
                    label: 'Ubah Data',
                    color: Colors.orange,
                    icon: Icons.edit,
                    height: 40,
                    onPressed: () => _openEdit(item, replace: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pillButton(
                    label: 'Hak Akses',
                    color: kGreen,
                    icon: Icons.admin_panel_settings,
                    height: 40,
                    onPressed: () => _showHakAksesDialog(item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: DataPendudukPage(),
  ));
}