import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_neraca.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_pendapatan.dart';

import 'package:iuran_rt_web/screens/laporan_keuangan_pengeluaran.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';
import 'package:iuran_rt_web/url.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganPage extends StatefulWidget {
  @override
  _LaporanKeuanganPageState createState() => _LaporanKeuanganPageState();
}

class _LaporanKeuanganPageState extends State<LaporanKeuanganPage> {
  List<dynamic> dataLaporanKeu = [];
  bool isLoading = false;
  bool isDownload = false;
  double totalSaldoPendapatan = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoKeu = 0;
  final currentYear = DateTime.now().year;
  final formatter = NumberFormat('#,###', 'id_ID');
  @override
  void initState() {
    super.initState();
    fetchLaporanKeuangan();
    //simulateLastYear();
    checkTanggalPeringatan(context);
    checkYearChangeAndTruncate();
  }

  Future<void> checkTanggalPeringatan(BuildContext context) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final keyPendapatan = "isDownload_${now.year}";
    isDownload = prefs.getBool(keyPendapatan) ?? false;

    if (now.month == 12 && now.day >= 27 && isDownload == false) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Peringatan Akhir Tahun"),
              content: Text(
                "Tanggal ${now.day}-${now.month}-${now.year}. "
                "Tahun akan segera berganti.\n\n"
                "Silakan download laporan keuangan tahun ${now.year} "
                "sebelum data dihapus pada awal tahun baru.",
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              LaporanKeuanganPendapatanPage()),
                    );
                    await exportToExcel();
                    await prefs.setBool(keyPendapatan, true);
                    isDownload = true;
                  },
                  child: Text("Download"),
                ),
              ],
            );
          },
        );
      });
    }
  }

  void simulateLastYear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_saved_year', (DateTime.now().year - 1).toString());
  }

  Future<void> checkYearChangeAndTruncate() async {
    final prefs = await SharedPreferences.getInstance();
    String currentYear1 = currentYear.toString();
    final lastSavedYear = prefs.getString('last_saved_year') ?? currentYear1;

    if (lastSavedYear != currentYear1) {
      // await exportToExcelOnlySendPath(
      //   lastSavedYear,
      //   totalSaldoPendapatan.toString(),
      //   totalSaldoPengeluaran.toString(),
      //   totalSaldoKeu.toString(),
      // );

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}deleteListLaporanKeu.php'),
        body: {
          'id_rt': KodeRt.kodeRt,
        },
      );

      final json = jsonDecode(response.body);

      if (json['result'] == 'success') {
        await prefs.setString('last_saved_year', currentYear1);
        print(
            "Data tahun $lastSavedYear berhasil di-export & dihapus. Tahun aktif: $currentYear1");
      } else {
        Flushbar(
          message: 'Gagal menghapus data lama: ${json['message']}',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    }
  }

  Future<void> fetchLaporanKeuangan({String? bulan}) async {
    final idRt = KodeRt.kodeRt;

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
       body: {
        'id_rt': idRt,
        if (bulan != null) 'bulan': bulan,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        dataLaporanKeu = result['data'];

        double totalPendapatan = dataLaporanKeu.fold(0, (sum, item) {
          final rawSaldo =
              item['saldo_pendapatan'].toString().replaceAll('.', '');
          final saldo = double.tryParse(rawSaldo) ?? 0;
          return sum + saldo;
        });

        setState(() {
          totalSaldoPendapatan = totalPendapatan;
        });

        print("Pendapatan: $totalPendapatan");
      } else {
        setState(() {
          dataLaporanKeu = [];
          totalSaldoPendapatan = 0;
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

  Future<void> tambahDataLaporan(String tanggal, String keterangan,
      String saldo, String coa, String kodeRef, String noKavling) async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambahPendapatan.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "tanggal": tanggal,
        "keterangan": keterangan,
        "saldo": saldo,
        "coa": coa,
        "kode_ref": kodeRef,
        "no_kavling": noKavling,
        'id_rt': KodeRt.kodeRt
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] == 'success') {
      Flushbar(
        message: 'Data berhasil disimpan',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } else {
      Flushbar(
        message: 'Gagal menyimpan data: ${data['message']}',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> exportToExcelOnlySendPath(
    String tahun,
    String totalPendapatan,
    String totalPengeluaran,
    String totalSemua,
  ) async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Kas Keuangan'];

    List<String> headers = [
      'Tanggal Pendapatan',
      'COA Pendapatan',
      'Kode Ref Pendapatan',
      'No Kavling Pendapatan',
      'Keterangan Pendapatan',
      'Saldo Pendapatan',
      'Tanggal Pengeluaran',
      'COA Pengeluaran',
      'Kode Ref Pengeluaran',
      'No Kavling Pengeluaran',
      'Keterangan Pengeluaran',
      'Saldo Pengeluaran',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataLaporanKeu) {
      List<String> row = [
        item['tanggal_pendapatan'] ?? '-',
        item['coa_pendapatan'] ?? '-',
        item['kode_ref_pendapatan'] ?? '-',
        item['no_kavling_pendapatan'] ?? '-',
        item['ket_pendapatan'] ?? '-',
        item['saldo_pendapatan'] ?? '-',
        item['tanggal_pengeluaran'] ?? '-',
        item['coa_pengeluaran'] ?? '-',
        item['kode_ref_pengeluaran'] ?? '-',
        item['no_kavling_pengeluaran'] ?? '-',
        item['ket_pengeluaran'] ?? '-',
        item['saldo_pengeluaran'] ?? '-',
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Laporan Keuangan Tahun $tahun.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Laporan Kas Keuangan.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
      try {
        var response = await http.post(
          Uri.parse("${ApiUrls.baseUrl}/savePathExcelKeu.php"),
          body: {
            'tahun': tahun,
            'path': filePath,
            'totalPendapatan': totalPendapatan.toString(),
            'totalPengeluaran': totalPengeluaran.toString(),
            'totalSemua': totalSemua.toString(),
          },
        );

        if (response.statusCode == 200) {
          print("Path dan data berhasil dikirim ke server");
        } else {
          print("Gagal mengirim. Status: ${response.statusCode}");
        }
      } catch (e) {
        print("Error saat kirim path: $e");
      }
    }
  }

  Future<void> exportToExcel() async {
  var excel = exc.Excel.createExcel();
  exc.Sheet sheetObject = excel['Laporan Kas Keuangan'];

  List<String> headers = [
    'Tanggal',
    'Keterangan',
    'No Kavling',
    'Pendapatan',
    'Pengeluaran',
    'Saldo Balance',
  ];
  sheetObject.appendRow(headers);

  double runningBalance = 0;
  final formatter = NumberFormat('#,###', 'id_ID');

  for (var item in dataLaporanKeu.where((item) =>
      item['tanggal_pendapatan'] != null ||
      item['tanggal_pengeluaran'] != null ||
      item['ket_pendapatan'] != null ||
      item['ket_pengeluaran'] != null ||
      item['no_kavling_pendapatan'] != null ||
      item['no_kavling_pengeluaran'] != null ||
      item['saldo_pendapatan'] != null ||
      item['saldo_pengeluaran'] != null)) {
    
    String pendapatanRaw =
        (item['saldo_pendapatan'] ?? '0').toString().replaceAll('.', '');
    String pengeluaranRaw =
        (item['saldo_pengeluaran'] ?? '0').toString().replaceAll('.', '');

    final double pendapatan = double.tryParse(pendapatanRaw) ?? 0;
    final double pengeluaran = double.tryParse(pengeluaranRaw) ?? 0;

    runningBalance += pendapatan - pengeluaran;

    List<dynamic> row = [
      (item['tanggal_pendapatan'] ??
              item['tanggal_pengeluaran'] ??
              '')
          .toString(),
      (item['ket_pendapatan'] ??
              item['ket_pengeluaran'] ??
              '')
          .toString(),
      (item['no_kavling_pendapatan'] ??
              item['no_kavling_pengeluaran'] ??
              '')
          .toString(),
      pendapatan == 0 ? '' : 'Rp ${formatter.format(pendapatan)}',
      pengeluaran == 0 ? '' : 'Rp ${formatter.format(pengeluaran)}',
      runningBalance == 0
          ? ''
          : 'Rp ${formatter.format(runningBalance)}',
    ];

    sheetObject.appendRow(row);
  }
  if (kIsWeb) {
    final bytes = excel.encode();
    final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Laporan Kas Keuangan.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    Directory directory = await getApplicationDocumentsDirectory();
    String filePath = "${directory.path}/Laporan Kas Keuangan.xlsx";
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data berhasil diexport ke $filePath')),
    );
  }
}


  String generateKodeRef({
    required String namaRT,
    required String kodeIuran,
    required String alamatKavling,
    required String tanggalLunas,
    required String kodeTransaksi,
  }) {
    return '$namaRT$kodeIuran$alamatKavling$tanggalLunas$kodeTransaksi';
  }

  void _showSaldoAwalDialog(BuildContext context) async {
    final TextEditingController saldoAwalController = TextEditingController();
    final prefs = await SharedPreferences.getInstance();
    String? noKavling = prefs.getString('noKavling');

    String currentDate = DateFormat('dd-MM-yyyy-HH:mm').format(DateTime.now());
    final now = DateTime.now();
    final tanggalRef = DateFormat('yyMMdd').format(now);

    String kodeRef = generateKodeRef(
      namaRT: KodeRt.kodeRt.toUpperCase(),
      kodeIuran: '003',
      alamatKavling: noKavling.toString(),
      tanggalLunas: tanggalRef,
      kodeTransaksi: '0000',
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Saldo awal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: saldoAwalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Saldo Awal Tahun',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Batal'),
                ),
                TextButton(
                  onPressed: () async {
                    await tambahDataLaporan(
                      currentDate,
                      "Saldo Awal Tahun",
                      saldoAwalController.text,
                      "800",
                      kodeRef.toString(),
                      noKavling.toString(),
                    );

                    Navigator.of(context).pop();

                    await fetchLaporanKeuangan();

                    setState(() {});
                  },
                  child: Text('Cek'),
                ),
              ],
            );
          },
        );
      },
    );
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
  return Scaffold(
    backgroundColor: Colors.grey[100],
   
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MenuPilihanPage()),
                          );
                        },
                      ),
                      Text(
                        'Laporan Kas Keuangan',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
             
                ],
              ),
            ),
          ),
         const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFilterButton('Pendapatan', onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LaporanKeuanganPendapatanPage()),
                );
              }),
              _buildFilterButton('Pengeluaran', onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LaporanKeuanganPengeluaranPage()),
                );
              }),
              _buildFilterButton('Utang', onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LaporanKeuanganUtangPage()),
                );
              }),
               _buildFilterButton('Kas', isActive: true, onPressed: () {}),
              _buildFilterButton('Surplus/Defisit', onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LaporanKeuanganSurplusDefisitPage()),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _buildMonthButton('All', onPressed: () {
fetchLaporanKeuangan(bulan: "Tahun");
              } ),
              ...List.generate(12, (index) {
                final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                final monthNumber = (index + 1).toString().padLeft(2, '0');
                return _buildMonthButton(monthNames[index], onPressed: () {
                  fetchLaporanKeuangan(bulan: monthNumber);
                });
              }),
            ],
          ),
        ),

       

        const SizedBox(height: 8),

        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : dataLaporanKeu.isEmpty
                  ? const Center(child: Text('Tidak ada data kas keuangan'))
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWideScreen = constraints.maxWidth > 800;
                      return ScrollConfiguration(
                        behavior: MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              // Header Table
                              Table(
                                border: TableBorder.all(
                                  color: Colors.grey.shade600,
                                  width: 1,
                                ),
                                columnWidths: const {
                                  0: FixedColumnWidth(200),
                                  1: FixedColumnWidth(200),
                                  2: FixedColumnWidth(200),
                                  3: FixedColumnWidth(200),
                                  4: FixedColumnWidth(200),
                                  5: FixedColumnWidth(200),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade100,
                                    ),
                                    children: [
                                      _buildTableHeader('Tanggal'),
                                      _buildTableHeader('Keterangan'),
                                      _buildTableHeader('No Kavling'),
                                      _buildTableHeader('Pendapatan'),
                                      _buildTableHeader('Pengeluaran'),
                                      _buildTableHeader('Saldo Balance'),
                                    ],
                                  ),
                                ],
                              ),

                              // Body Table
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Builder(
                                    builder: (context) {
                                      double runningBalance = 0;
                                      final formatter =
                                          NumberFormat('#,###', 'id_ID');

                                      final rows = dataLaporanKeu
                                          .where((item) =>
                                              item['tanggal_pendapatan'] !=
                                                  null ||
                                              item['tanggal_pengeluaran'] !=
                                                  null ||
                                              item['ket_pendapatan'] != null ||
                                              item['ket_pengeluaran'] != null ||
                                              item['no_kavling_pendapatan'] !=
                                                  null ||
                                              item['no_kavling_pengeluaran'] !=
                                                  null ||
                                              item['saldo_pendapatan'] !=
                                                  null ||
                                              item['saldo_pengeluaran'] != null)
                                          .map((item) {
                                        
                                        String pendapatanRaw =
                                            (item['saldo_pendapatan'] ?? '0')
                                                .toString()
                                                .replaceAll('.', '');
                                        String pengeluaranRaw =
                                            (item['saldo_pengeluaran'] ?? '0')
                                                .toString()
                                                .replaceAll('.', '');

                                       
                                        final double pendapatan =
                                            double.tryParse(pendapatanRaw) ?? 0;
                                        final double pengeluaran =
                                            double.tryParse(pengeluaranRaw) ??
                                                0;

                                        
                                        runningBalance +=
                                            pendapatan - pengeluaran;

                                        return TableRow(
                                          children: [
                                            _buildTableCell(
                                              (item['tanggal_pendapatan'] ??
                                                      item[
                                                          'tanggal_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              (item['ket_pendapatan'] ??
                                                      item['ket_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              (item['no_kavling_pendapatan'] ??
                                                      item[
                                                          'no_kavling_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              pendapatan == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(pendapatan)}',
                                            ),
                                            _buildTableCell(
                                              pengeluaran == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(pengeluaran)}',
                                            ),
                                            _buildTableCell(
                                              runningBalance == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(runningBalance)}',
                                            ),
                                          ],
                                        );
                                      }).toList();

                                      return Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(200),
                                        },
                                        children: rows,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    ),

    floatingActionButton: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
         FloatingActionButton.extended(
          backgroundColor: const Color(0xFF3D8D7A),
          icon: const Icon(Icons.download, color: Colors.white),
          label: const Text('Unduh PDF', style: TextStyle(color: Colors.white)),
          onPressed: exportToExcel,
        ),
        FloatingActionButton.extended(
          backgroundColor: const Color(0xFF3D8D7A),
          icon: const Icon(Icons.download, color: Colors.white),
          label: const Text('Unduh Excel', style: TextStyle(color: Colors.white)),
          onPressed: exportToExcel,
        ),
      ],
    ),
  );
}

/// 🔹 Tombol kategori
Widget _buildFilterButton(String title, {bool isActive = false, required VoidCallback onPressed}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: isActive ? const Color(0xFF3D8D7A) : Colors.white,
      foregroundColor: isActive ? Colors.white : const Color(0xFF3D8D7A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}


Widget _buildMonthButton(String label, {required VoidCallback onPressed}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3D8D7A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}


Widget _buildItemRow(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3D8D7A)),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value != null ? value.toString() : '-',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MenuPilihanPage()),
                          );
                        },
                      ),
                      Text(
                        'Laporan Kas Keuangan',
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
          SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LaporanKeuanganPendapatanPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Pendapatan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LaporanKeuanganPengeluaranPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Pengeluaran',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LaporanKeuanganUtangPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Utang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Laporan Kas Keuangan',
                      style: TextStyle(
                        color: Color(0xFF3D8D7A),
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LaporanKeuanganSurplusDefisitPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Surplus/Defisit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // SizedBox(width: 16),
                  // ElevatedButton(
                  //   onPressed: () {
                  //     Navigator.pushReplacement(
                  //       context,
                  //       MaterialPageRoute(
                  //           builder: (context) => LaporanKeuanganNeracaPage()),
                  //     );
                  //   },
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Color(0xFF3D8D7A),
                  //     padding:
                  //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  //   ),
                  //   child: Text(
                  //     'Neraca',
                  //     style: TextStyle(
                  //       color: Colors.white,
                  //       fontSize: 18,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
            SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3D8D7A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3D8D7A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      fetchLaporanKeuangan(bulan: "Tahun");
                    },
                    child: const Text(
                      'All',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...List.generate(12, (index) {
                    final monthNames = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'Mei',
                      'Jun',
                      'Jul',
                      'Agu',
                      'Sep',
                      'Okt',
                      'Nov',
                      'Des'
                    ];
                    final monthNumber = (index + 1).toString().padLeft(2, '0');

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF3D8D7A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        fetchLaporanKeuangan(bulan: monthNumber);
                      },
                      child: Text(
                        monthNames[index],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
         
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWideScreen = constraints.maxWidth > 800;
                      return ScrollConfiguration(
                        behavior: MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              // Header Table
                              Table(
                                border: TableBorder.all(
                                  color: Colors.grey.shade600,
                                  width: 1,
                                ),
                                columnWidths: const {
                                  0: FixedColumnWidth(200),
                                  1: FixedColumnWidth(200),
                                  2: FixedColumnWidth(200),
                                  3: FixedColumnWidth(200),
                                  4: FixedColumnWidth(200),
                                  5: FixedColumnWidth(200),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade100,
                                    ),
                                    children: [
                                      _buildTableHeader('Tanggal'),
                                      _buildTableHeader('Keterangan'),
                                      _buildTableHeader('No Kavling'),
                                      _buildTableHeader('Pendapatan'),
                                      _buildTableHeader('Pengeluaran'),
                                      _buildTableHeader('Saldo Balance'),
                                    ],
                                  ),
                                ],
                              ),

                              // Body Table
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Builder(
                                    builder: (context) {
                                      double runningBalance = 0;
                                      final formatter =
                                          NumberFormat('#,###', 'id_ID');

                                      final rows = dataLaporanKeu
                                          .where((item) =>
                                              item['tanggal_pendapatan'] !=
                                                  null ||
                                              item['tanggal_pengeluaran'] !=
                                                  null ||
                                              item['ket_pendapatan'] != null ||
                                              item['ket_pengeluaran'] != null ||
                                              item['no_kavling_pendapatan'] !=
                                                  null ||
                                              item['no_kavling_pengeluaran'] !=
                                                  null ||
                                              item['saldo_pendapatan'] !=
                                                  null ||
                                              item['saldo_pengeluaran'] != null)
                                          .map((item) {
                                        
                                        String pendapatanRaw =
                                            (item['saldo_pendapatan'] ?? '0')
                                                .toString()
                                                .replaceAll('.', '');
                                        String pengeluaranRaw =
                                            (item['saldo_pengeluaran'] ?? '0')
                                                .toString()
                                                .replaceAll('.', '');

                                       
                                        final double pendapatan =
                                            double.tryParse(pendapatanRaw) ?? 0;
                                        final double pengeluaran =
                                            double.tryParse(pengeluaranRaw) ??
                                                0;

                                        
                                        runningBalance +=
                                            pendapatan - pengeluaran;

                                        return TableRow(
                                          children: [
                                            _buildTableCell(
                                              (item['tanggal_pendapatan'] ??
                                                      item[
                                                          'tanggal_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              (item['ket_pendapatan'] ??
                                                      item['ket_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              (item['no_kavling_pendapatan'] ??
                                                      item[
                                                          'no_kavling_pengeluaran'] ??
                                                      '')
                                                  .toString(),
                                            ),
                                            _buildTableCell(
                                              pendapatan == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(pendapatan)}',
                                            ),
                                            _buildTableCell(
                                              pengeluaran == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(pengeluaran)}',
                                            ),
                                            _buildTableCell(
                                              runningBalance == 0
                                                  ? ''
                                                  : 'Rp ${formatter.format(runningBalance)}',
                                            ),
                                          ],
                                        );
                                      }).toList();

                                      return Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(200),
                                        },
                                        children: rows,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 16),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
           FloatingActionButton.extended(
          backgroundColor: const Color(0xFF3D8D7A),
          icon: const Icon(Icons.download, color: Colors.white),
          label: const Text('Unduh PDF', style: TextStyle(color: Colors.white)),
          onPressed: exportToExcel,
        ),
          FloatingActionButton.extended(
            backgroundColor: const Color(0xFF3D8D7A),
            heroTag: 'exportExcel',
            onPressed: exportToExcel,
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text(
              'Unduh Excel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final formatted = _formatter.format(int.parse(digitsOnly));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Widget _buildTableHeader(String text) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
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
