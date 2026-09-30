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

  @override
  void initState() {
    super.initState();

    fetchPendudukData();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  ButtonStyle tableButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size(140, 42),
    maximumSize: const Size(140, 42),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  );
  static const Map<int, TableColumnWidth> tableColumnWidths = {
    0: FixedColumnWidth(120),
    1: FixedColumnWidth(200),
    2: FixedColumnWidth(180),
    3: FixedColumnWidth(150),
    4: FixedColumnWidth(170),
    5: FixedColumnWidth(180),
    6: FixedColumnWidth(150),
    7: FixedColumnWidth(170),
    8: FixedColumnWidth(100),
    9: FixedColumnWidth(180),
  };
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
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  int get totalPengurusRt {
    return dataPenduduk.where((item) {
      final val = item['pengurus_rt'];
      return val == 1 || val == '1';
    }).length;
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

          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => DataPendudukPage(),
          //   ),
          // );
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          body: isMobile
              ? _buildMobileContent(context)
              : _buildDesktopContent(context),
        );
      },
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 65,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 232, 226, 226),
              border: Border.all(
                color: const Color.fromARGB(255, 58, 112, 50),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.black, size: 20),
                        onPressed: () => {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MenuPilihanPage(
                                    idMenu: 2,
                                  ),
                                ),
                              )
                            }),
                    const SizedBox(width: 4),
                    const Text(
                      'Data Warga',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BODY
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SEARCH BAR
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: screenWidth * 0.9,
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText:
                            'Cari No Kavling / Nama Penghuni / Pemilik Rumah',
                        labelStyle: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF3D8D7A)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF3D8D7A),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        fetchPendudukData(value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // LIST DATA
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : dataPenduduk.isEmpty
                          ? Center(
                              child: Text(
                                'Data tidak ditemukan',
                                style: GoogleFonts.lato(color: Colors.black),
                              ),
                            )
                          : ListView.builder(
                              itemCount: paginatedData.length,
                              itemBuilder: (context, index) {
                                final penduduk = paginatedData[index];
                                return _buildCard(
                                  penduduk['no_kavling'] ?? 'N/A',
                                  penduduk['alamat_kavling'] ?? 'N/A',
                                  penduduk['nama_pemilik_rumah'] ?? 'N/A',
                                  penduduk['nama_penanggung_jawab'] ?? 'N/A',
                                  penduduk['no_telpon_pemilik_rumah'] ?? 'N/A',
                                  penduduk['no_telpon_penanggung_jawab'] ??
                                      'N/A',
                                  penduduk['no_kk_pemilik_rumah'] ?? 'N/A',
                                  penduduk['no_kk_penanggung_jawab'] ?? 'N/A',
                                  penduduk['id'] ?? 0,
                                  penduduk['pengurus_rt'] ?? 0,
                                  screenWidth,
                                );
                              },
                            ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
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
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D8D7A),
                  disabledBackgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                ),
                onPressed: currentPage > 0
                    ? () {
                        setState(() {
                          currentPage--;
                        });
                      }
                    : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 20),
              Text(
                'Halaman ${currentPage + 1} dari $totalPages',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D8D7A),
                  disabledBackgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                ),
                onPressed: (currentPage + 1) * rowsPerPage < dataPenduduk.length
                    ? () {
                        setState(() {
                          currentPage++;
                        });
                      }
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        Center(
          child: Container(
            width: 1200,
            height: 80,
            margin: EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 232, 226, 226),
              border: Border.all(
                color: Color.fromARGB(255, 58, 112, 50),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                        onPressed: () => {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MenuPilihanPage(
                                    idMenu: 2,
                                  ),
                                ),
                              )
                            }),
                    Text(
                      'Data Warga',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
                Image.asset(
                  'assets/images/Logo4.png',
                  height: 40,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 20),
                child: Center(
                  child: SizedBox(
                    width: 600,
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText:
                            'Cari Berdasarkan No Kavling/Nama Penghuni/Nama Pemilik Rumah',
                        labelStyle: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        prefixIcon:
                            Icon(Icons.search, color: Color(0xFF3D8D7A)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Color(0xFF3D8D7A),
                            width: 1.8,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        fetchPendudukData(value);
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1300,
                      ),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade400,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ScrollConfiguration(
                                behavior:
                                    const MaterialScrollBehavior().copyWith(
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
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 1620,
                                      child: Scrollbar(
                                        controller: _verticalController,
                                        thumbVisibility: true,
                                        trackVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _verticalController,
                                          scrollDirection: Axis.vertical,
                                          child: Column(
                                            children: [
                                              Container(
                                                color: const Color(0xFF3D8D7A),
                                                child: Table(
                                                  border: TableBorder.symmetric(
                                                    inside: BorderSide(
                                                      color: const Color(
                                                          0xFF3D8D7A),
                                                    ),
                                                  ),
                                                  columnWidths:
                                                      tableColumnWidths,
                                                  children: [
                                                    TableRow(
                                                      children: [
                                                        _buildTableHeader(
                                                            'No Kavling'),
                                                        _buildTableHeader(
                                                            'Alamat Kavling'),
                                                        _buildTableHeader(
                                                            'Nama Pemilik Rumah'),
                                                        _buildTableHeader(
                                                            'No Telpon Pemilik Rumah'),
                                                        _buildTableHeader(
                                                            'No KK Pemilik Rumah'),
                                                        _buildTableHeader(
                                                            'Nama Penghuni'),
                                                        _buildTableHeader(
                                                            'No Telpon Penghuni'),
                                                        _buildTableHeader(
                                                            'No KK Penghuni'),
                                                        _buildTableHeader(
                                                            'Aksi'),
                                                        _buildTableHeader(
                                                            'Hak Akses'),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // ==========================
                                              // BODY
                                              // ==========================
                                              Table(
                                                border: TableBorder.symmetric(
                                                  inside: BorderSide(
                                                    color:
                                                        const Color(0xFF3D8D7A),
                                                  ),
                                                ),
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                columnWidths: tableColumnWidths,
                                                children:
                                                    paginatedData.map((item) {
                                                  return TableRow(
                                                    children: [
                                                      _buildTableCell(
                                                        item['no_kavling'] ??
                                                            '',
                                                      ),

                                                      _buildTableCell(
                                                        item['alamat_kavling'] ??
                                                            '',
                                                      ),

                                                      _buildTableCell(
                                                        item['nama_pemilik_rumah'] ??
                                                            '',
                                                      ),

                                                      _buildTableCell(
                                                        item['no_telpon_pemilik_rumah'] ??
                                                            '',
                                                      ),

                                                      // NO KK PEMILIK
                                                      Center(
                                                        child: SizedBox(
                                                          width: 140,
                                                          height: 42,
                                                          child: ElevatedButton(
                                                            style:
                                                                tableButtonStyle
                                                                    .copyWith(
                                                              backgroundColor:
                                                                  WidgetStateProperty
                                                                      .all(
                                                                Colors.green,
                                                              ),
                                                            ),
                                                            onPressed: () {
                                                              if (item[
                                                                      'no_kk_pemilik_rumah'] ==
                                                                  null) {
                                                                Flushbar(
                                                                  message:
                                                                      "No KK tidak terdaftar",
                                                                  duration:
                                                                      Duration(
                                                                          seconds:
                                                                              2),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  flushbarPosition:
                                                                      FlushbarPosition
                                                                          .TOP,
                                                                ).show(context);
                                                              } else {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) =>
                                                                        KkPemilikRumahPage(
                                                                      no_kk: item[
                                                                          'no_kk_pemilik_rumah'],
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: Text(
                                                              item['no_kk_pemilik_rumah']
                                                                      ?.toString() ??
                                                                  '-',
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      _buildTableCell(
                                                        item['nama_penanggung_jawab'] ??
                                                            '',
                                                      ),

                                                      _buildTableCell(
                                                        item['no_telpon_penanggung_jawab'] ??
                                                            '',
                                                      ),

                                                      // NO KK PENGHUNI
                                                      Center(
                                                        child: SizedBox(
                                                          width: 140,
                                                          height: 42,
                                                          child: ElevatedButton(
                                                            style:
                                                                tableButtonStyle
                                                                    .copyWith(
                                                              backgroundColor:
                                                                  WidgetStateProperty
                                                                      .all(
                                                                Colors.green,
                                                              ),
                                                            ),
                                                            onPressed: () {
                                                              if (item[
                                                                      'no_kk_penanggung_jawab'] ==
                                                                  null) {
                                                                Flushbar(
                                                                  message:
                                                                      "No KK tidak terdaftar",
                                                                  duration:
                                                                      Duration(
                                                                          seconds:
                                                                              2),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  flushbarPosition:
                                                                      FlushbarPosition
                                                                          .TOP,
                                                                ).show(context);
                                                              } else {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) =>
                                                                        KkPenanggungJawabPage(
                                                                            no_kk:
                                                                                item['no_kk_penanggung_jawab']),
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: Text(
                                                              item['no_kk_penanggung_jawab']
                                                                      ?.toString() ??
                                                                  '-',
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // UBAH DATA
                                                      Center(
                                                        child: SizedBox(
                                                          width: 140,
                                                          height: 42,
                                                          child: ElevatedButton(
                                                            style:
                                                                tableButtonStyle
                                                                    .copyWith(
                                                              backgroundColor:
                                                                  WidgetStateProperty
                                                                      .all(
                                                                Colors.orange,
                                                              ),
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              final result =
                                                                  await Navigator
                                                                      .push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (_) =>
                                                                      EditDataWargaPage(
                                                                    id: item[
                                                                        'id'],
                                                                  ),
                                                                ),
                                                              );

                                                              if (result !=
                                                                      null &&
                                                                  result['status'] ==
                                                                      true) {
                                                                fetchPendudukData(
                                                                  result[
                                                                      'kavling'],
                                                                );
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Ubah Data',
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // HAK AKSES
                                                      Center(
                                                        child:
                                                            item['pengurus_rt'] ==
                                                                    1
                                                                ? SizedBox(
                                                                    width: 180,
                                                                    height: 42,
                                                                    child:
                                                                        ElevatedButton
                                                                            .icon(
                                                                      icon:
                                                                          const Icon(
                                                                        Icons
                                                                            .remove_moderator,
                                                                        color: Colors
                                                                            .white,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      label:
                                                                          const Text(
                                                                        'Hapus Hak Akses',
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      style: ElevatedButton
                                                                          .styleFrom(
                                                                        backgroundColor:
                                                                            Colors.red,
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(20),
                                                                        ),
                                                                      ),
                                                                      onPressed:
                                                                          () async {
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            return AlertDialog(
                                                                              backgroundColor: Color(0xFFFDECE8),
                                                                              title: Text(
                                                                                'Konfirmasi',
                                                                                style: GoogleFonts.lato(color: Colors.black),
                                                                              ),
                                                                              content: Text(
                                                                                'Hapus hak akses Pengurus RT untuk no kavling ${item["no_kavling"]}?',
                                                                                style: GoogleFonts.lato(color: Colors.black),
                                                                              ),
                                                                              actions: [
                                                                                TextButton(
                                                                                  onPressed: () {
                                                                                    Navigator.of(context).pop();
                                                                                  },
                                                                                  child: Text(
                                                                                    'Batal',
                                                                                    style: GoogleFonts.lato(color: Color(0xFF3D8D7A)),
                                                                                  ),
                                                                                ),
                                                                                TextButton(
                                                                                  onPressed: () async {
                                                                                    Navigator.pop(context);

                                                                                    updatePengurusRt(item['id'], "HAPUS", item['no_kavling']);
                                                                                  },
                                                                                  child: Text(
                                                                                    'Hapus',
                                                                                    style: GoogleFonts.lato(color: Color(0xFF3D8D7A)),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            );
                                                                          },
                                                                        );
                                                                      },
                                                                    ),
                                                                  )
                                                                : SizedBox(
                                                                    width: 180,
                                                                    height: 42,
                                                                    child:
                                                                        ElevatedButton
                                                                            .icon(
                                                                      icon:
                                                                          const Icon(
                                                                        Icons
                                                                            .add_moderator,
                                                                        color: Colors
                                                                            .white,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      label:
                                                                          const Text(
                                                                        'Jadi Pengurus RT',
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      style: ElevatedButton
                                                                          .styleFrom(
                                                                        backgroundColor:
                                                                            Colors.green,
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(20),
                                                                        ),
                                                                      ),
                                                                      onPressed:
                                                                          () async {
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            return AlertDialog(
                                                                              backgroundColor: const Color(0xFFFDECE8),
                                                                              title: Text(
                                                                                'Konfirmasi Hak Akses',
                                                                                style: GoogleFonts.lato(
                                                                                  color: Colors.black,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              ),
                                                                              content: Text(
                                                                                'Kavling ${item['no_kavling']}\n\n'
                                                                                'Pilih tindakan yang ingin dilakukan:\n\n'
                                                                                '• Tukar Hak Akses\n'
                                                                                '  Hak akses Pengurus RT Anda akan dipindahkan ke warga ini.\n'
                                                                                '  Anda akan menjadi warga biasa dan harus login ulang.\n\n'
                                                                                '• Tambah Hak Akses\n'
                                                                                '  Warga ini akan menjadi Pengurus RT tanpa mengubah hak akses Anda.',
                                                                                style: GoogleFonts.lato(
                                                                                  color: Colors.black,
                                                                                ),
                                                                              ),
                                                                              actions: [
                                                                                TextButton(
                                                                                  onPressed: () {
                                                                                    Navigator.pop(context);
                                                                                  },
                                                                                  child: Text(
                                                                                    'Batal',
                                                                                    style: GoogleFonts.lato(
                                                                                      color: Colors.grey.shade700,
                                                                                    ),
                                                                                  ),
                                                                                ),

                                                                                // TAMBAH
                                                                                // TAMBAH
                                                                                ElevatedButton(
                                                                                  style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: totalPengurusRt >= 5 ? Colors.grey : Colors.green,
                                                                                  ),
                                                                                  onPressed: () {
                                                                                    if (totalPengurusRt >= 5) {
                                                                                      Navigator.pop(context);
                                                                                      Flushbar(
                                                                                        message: "Batas maksimal Pengurus RT (5) sudah tercapai. Gunakan Tukar atau Hapus Hak Akses.",
                                                                                        duration: const Duration(seconds: 3),
                                                                                        backgroundColor: Colors.red,
                                                                                        flushbarPosition: FlushbarPosition.TOP,
                                                                                      ).show(context);
                                                                                      return;
                                                                                    }
                                                                                    Navigator.pop(context);
                                                                                    updatePengurusRt(
                                                                                      item['id'],
                                                                                      "TAMBAH",
                                                                                      item['no_kavling'],
                                                                                    );
                                                                                  },
                                                                                  child: Text(
                                                                                    'Tambah Hak Akses',
                                                                                    style: GoogleFonts.lato(color: Colors.white),
                                                                                  ),
                                                                                ),

                                                                                // TUKAR
                                                                                ElevatedButton(
                                                                                  style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: Colors.orange,
                                                                                  ),
                                                                                  onPressed: () {
                                                                                    Navigator.pop(context);

                                                                                    updatePengurusRt(
                                                                                      item['id'],
                                                                                      "TUKAR",
                                                                                      item['no_kavling'],
                                                                                    );
                                                                                  },
                                                                                  child: Text(
                                                                                    'Tukar Hak Akses',
                                                                                    style: GoogleFonts.lato(
                                                                                      color: Colors.white,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            );
                                                                          },
                                                                        );

                                                                        fetchPendudukData(
                                                                          searchController
                                                                              .text,
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D8D7A),
                        disabledBackgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                      ),
                      onPressed: currentPage > 0
                          ? () {
                              setState(() {
                                currentPage--;
                              });
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'Halaman ${currentPage + 1} dari $totalPages',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D8D7A),
                        disabledBackgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                      ),
                      onPressed:
                          (currentPage + 1) * rowsPerPage < dataPenduduk.length
                              ? () {
                                  setState(() {
                                    currentPage++;
                                  });
                                }
                              : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _buildCard(
    String noKavling,
    String alamatKavling,
    String pemilik,
    String penanggungJawab,
    String noTelponPemilik,
    String noTelponPenanggungJawab,
    String noKkPemilikRumah,
    String noKkPenanggungJawab,
    dynamic id,
    int pengurusRt,
    double screenWidth,
  ) {
    int parsedId = int.tryParse(id.toString()) ?? 0;
    String no_kk_pemilik = noKkPemilikRumah.toString();
    String no_kk_penanggung_jawab = noKkPenanggungJawab.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Color(0xFF3D8D7A),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    width: 230,
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      color: Color(0xA3D1C6),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: [
                                const Icon(Icons.home, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit
                                        .scaleDown, // teks mengecil tapi tidak melar
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'No. Kavling: $noKavling',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '$alamatKavling',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pemilik Rumah:',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
              SizedBox(height: 8),
              (screenWidth > 800)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _buildInfoColumn(Icons.person, 'Nama: $pemilik'),
                        _buildInfoColumn(
                            Icons.person, 'No KK: $noKkPemilikRumah'),
                        _buildInfoColumn(
                            Icons.phone, 'No. Telepon: $noTelponPemilik'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person, 'Nama: $pemilik'),
                        _buildInfoRow(Icons.person, 'No KK: $noKkPemilikRumah'),
                        _buildInfoRow(
                            Icons.phone, 'No. Telepon: $noTelponPemilik'),
                      ],
                    ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9C4B9),
                    ),
                    onPressed: () {
                      if (no_kk_pemilik.isEmpty || no_kk_pemilik == "N/A") {
                        Flushbar(
                          message: "No KK tidak terdaftar",
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.red,
                          flushbarPosition: FlushbarPosition.TOP,
                        ).show(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                KkPemilikRumahPage(no_kk: no_kk_pemilik),
                          ),
                        );
                      }
                      ;
                    },
                    child: Text(
                      'Kartu Keluarga Pemilik Rumah',
                      style: GoogleFonts.lato(color: Colors.black),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Penghuni:',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
              SizedBox(height: 8),
              (screenWidth > 800)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _buildInfoColumn(
                            Icons.person, 'Nama: $penanggungJawab'),
                        _buildInfoColumn(
                            Icons.person, 'No KK: $noKkPenanggungJawab'),
                        _buildInfoColumn(Icons.phone,
                            'No. Telepon: $noTelponPenanggungJawab'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person, 'Nama: $penanggungJawab'),
                        _buildInfoRow(
                            Icons.person, 'No KK: $noKkPenanggungJawab'),
                        _buildInfoRow(Icons.phone,
                            'No. Telepon: $noTelponPenanggungJawab'),
                      ],
                    ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9C4B9),
                    ),
                    onPressed: () {
                      if (no_kk_penanggung_jawab.isEmpty ||
                          no_kk_penanggung_jawab == "N/A") {
                        Flushbar(
                          message: "No KK tidak terdaftar",
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.red,
                          flushbarPosition: FlushbarPosition.TOP,
                        ).show(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KkPenanggungJawabPage(
                                no_kk: no_kk_penanggung_jawab),
                          ),
                        );
                      }
                      ;
                    },
                    child: Text(
                      'Kartu Keluarga Penghuni',
                      style: GoogleFonts.lato(color: Colors.black),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF9C4B9),
                ),
                onPressed: () async {
                  final result = await Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditDataWargaPage(id: parsedId),
                    ),
                  );

                  if (result != null && result["status"] == true) {
                    fetchPendudukData(result["kavling"]);

                    print("Kavling hasil edit: ${result["kavling"]}");
                  }
                },
                child: Text(
                  'Ubah Data',
                  style: GoogleFonts.lato(color: Colors.black),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF9C4B9),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFFFDECE8),
                        title: Text(
                          'Konfirmasi Hak Akses Pengurus RT',
                          style: GoogleFonts.lato(color: Colors.black),
                        ),

                        // ✅ INI KUNCI FIX
                        content: SizedBox(
                          width: double.maxFinite,
                          child: SingleChildScrollView(
                            child: Text(
                              'Kavling ${noKavling}\n\n'
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

                        actionsPadding: const EdgeInsets.only(
                          bottom: 10,
                          right: 10,
                          left: 10,
                        ),

                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.lato(
                                  color: const Color(0xFF3D8D7A)),
                            ),
                          ),
                          if (pengurusRt != 1)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: totalPengurusRt >= 5
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                              onPressed: () {
                                if (totalPengurusRt >= 5) {
                                  Navigator.pop(context);
                                  Flushbar(
                                    message:
                                        "Batas maksimal Pengurus RT (5) sudah tercapai. Gunakan Tukar atau Hapus Hak Akses.",
                                    duration: const Duration(seconds: 3),
                                    backgroundColor: Colors.red,
                                    flushbarPosition: FlushbarPosition.TOP,
                                  ).show(context);
                                  return;
                                }
                                Navigator.pop(context);
                                updatePengurusRt(
                                    parsedId, "TAMBAH", noKavling.toString());
                              },
                              child: Text(
                                'Tambah Hak Akses',
                                style: GoogleFonts.lato(color: Colors.white),
                              ),
                            ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              updatePengurusRt(
                                  parsedId, "TUKAR", noKavling.toString());
                            },
                            child: Text(
                              'Tukar Hak Akses',
                              style: GoogleFonts.lato(color: Colors.white),
                            ),
                          ),
                          if (pengurusRt == 1)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                updatePengurusRt(
                                    parsedId, "HAPUS", noKavling.toString());
                              },
                              child: Text(
                                'Hapus Hak Akses',
                                style: GoogleFonts.lato(color: Colors.white),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
                child: Text(
                  'Pengaturan Hak Akses',
                  style: GoogleFonts.lato(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: DataPendudukPage(),
  ));
}

Widget _buildTableHeader(String text) {
  return Container(
    color: const Color(0xFF3D8D7A),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    ),
  );
}

Widget _buildTableCell(String? text) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text ?? '-',
      style: TextStyle(
        fontSize: 13,
        color: Colors.black87,
      ),
    ),
  );
}
