import 'dart:ui';
import 'package:another_flushbar/flushbar.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_aset.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_neraca.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan.dart';

import 'package:iuran_rt_web/screens/laporan_keuangan_pendapatan.dart';

import 'package:iuran_rt_web/screens/laporan_keuangan_pengeluaran.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';
import 'package:iuran_rt_web/screens/tambah_pendapatan.dart';

import 'package:iuran_rt_web/url.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganSurplusDefisitPage extends StatefulWidget {
  final String numberMonth;

  const LaporanKeuanganSurplusDefisitPage({
    super.key,
    this.numberMonth = "",
  });
  @override
  _LaporanKeuanganSurplusDefisitPageState createState() =>
      _LaporanKeuanganSurplusDefisitPageState();
}

class _LaporanKeuanganSurplusDefisitPageState
    extends State<LaporanKeuanganSurplusDefisitPage> {
  List<dynamic> dataLaporanKeu = [];
  bool isLoading = false;
  bool isDownload = false;
  double totalSaldoPendapatan = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoKeu = 0;
  double hasilAkhir = 0;
  String selectedMonth = 'Tahun';
  String monthNum = 'Tahun';

  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool isDefisit = false;
  late List<String> yearList;
  String? currentYear;
  // Jan, Feb, dst | '' = semua bulan
  String selectedMonthNumber = ''; // '01' - '12' | ''
  @override
  void initState() {
    super.initState();

    final now = DateTime.now().year;
    yearList = List.generate(
      5,
      (index) => (now - index).toString(),
    );

    // default value AMAN
    currentYear = yearList.first;
    fetchLaporanKeuangan(
      bulan: widget.numberMonth.isNotEmpty ? widget.numberMonth : null,
      tahun: currentYear,
    );
    //simulateLastYear();
    // checkTanggalPeringatan(context);
    // checkYearChangeAndTruncate();
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
          message: "Gagal menghapus data lama: ${json['message']}",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      
      }
    }
  }

  Future<void> fetchLaporanKeuangan({
    String? bulan,
    String? tahun,
  }) async {
    setState(() {
      isLoading = true;
    });

    final idRt = KodeRt.kodeRt;

    final Map<String, String> body = {'id_rt': idRt, 'status': 'VALID'};

    if ((widget.numberMonth.isNotEmpty) || bulan != null) {
      body['bulan'] =
          widget.numberMonth.isNotEmpty ? widget.numberMonth : bulan!;
    }

    if (tahun != null && tahun.isNotEmpty) {
      body['tahun'] = tahun;
    }

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        dataLaporanKeu = result['data'];

        final totalPendapatan = dataLaporanKeu.fold<double>(0, (sum, item) {
          final raw = item['saldo_pendapatan'].toString().replaceAll('.', '');
          return sum + (double.tryParse(raw) ?? 0);
        });

        final totalPengeluaran = dataLaporanKeu.fold<double>(0, (sum, item) {
          final raw = item['saldo_pengeluaran'].toString().replaceAll('.', '');
          return sum + (double.tryParse(raw) ?? 0);
        });

        setState(() {
          totalSaldoPendapatan = totalPendapatan;
          totalSaldoPengeluaran = totalPengeluaran;
          hasilAkhir = totalPendapatan - totalPengeluaran;
        });
      } else {
        setState(() {
          dataLaporanKeu = [];
          totalSaldoPendapatan = 0;
          totalSaldoPengeluaran = 0;
          hasilAkhir = 0;
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
        const SnackBar(content: Text('Gagal mengambil data dari server')),
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
    exc.Sheet sheetObject = excel['Laporan Keuangan Surplus Defisit'];

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
      String filePath =
          "${directory.path}/Laporan Keuangan Surplus Defisit.xlsx";
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

  Future<void> createAndUploadPdf({
    required String selectedMonth,
    required String currentYear,
    required String namaRt,
    required double totalSaldoPendapatan,
    required double totalSaldoPengeluaran,
    required double hasilAkhir,
    required bool isDefisit,
  }) async {
    final pdf = pw.Document();

    final ByteData imageData = await rootBundle.load('assets/images/Logo3.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ✅ Header
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Ringkasan Keuangan $selectedMonth $currentYear',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            namaRt,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Divider(thickness: 2),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // ✅ Table tanpa header
                    pw.Table(
                      border: pw.TableBorder.all(width: 1),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        // Pendapatan
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Pendapatan',
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(''),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${_formatCurrency(totalSaldoPendapatan)}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),

                        // Pengeluaran
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Pengeluaran',
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${_formatCurrency(totalSaldoPengeluaran)}',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(''),
                            ),
                          ],
                        ),

                        // Surplus / Defisit
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                isDefisit ? 'Defisit' : 'Surplus',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isDefisit
                                      ? PdfColors.red
                                      : PdfColors.green,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(''),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${_formatCurrency(hasilAkhir)}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isDefisit
                                      ? PdfColors.red
                                      : PdfColors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // =============================
              //            FOOTER
              // =============================
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  'Terima kasih telah menggunakan aplikasi RT Digital',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  "Created by RT Digital",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List encoded = await pdf.save();

    // ==================================
    // SIMPAN FILE
    // ==================================
    if (kIsWeb) {
      final blob = html.Blob([encoded], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "Laporan Keuangan Surplus Defisit ${selectedMonth} $currentYear.pdf",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Surplus Defisit ${selectedMonth} $currentYear.pdf";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan_Keuangan_Surplus_Defisit'];

    // HEADER UTAMA
    sheetObject.appendRow(['Tanggal', 'Keterangan', 'Saldo']);
    sheetObject.appendRow(['', 'PENDAPATAN', '']);

    sheetObject.appendRow(
        ['', 'Total Pendapatan', _formatCurrencyTotal(totalSaldoPendapatan)]);
    sheetObject.appendRow(['', '', '']);

    // --- PENGELUARAN ---
    sheetObject.appendRow(['', 'PENGELUARAN', '']);

    sheetObject.appendRow(
        ['', 'Total Pengeluaran', _formatCurrencyTotal(totalSaldoPengeluaran)]);
    sheetObject.appendRow(['', '', '']);
    sheetObject.appendRow([
      '',
      hasilAkhir >= 0 ? 'Surplus' : 'Defisit',
      _formatCurrencyTotal(hasilAkhir),
    ]);

    final encoded = excel.encode();
    if (encoded == null) {
      print("❌ Error: Excel encode gagal");
      return;
    }

    if (kIsWeb) {
      final blob = html.Blob([encoded],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download",
            "Laporan Keuangan Surplus Defisit ${selectedMonth} $currentYear.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Surplus Defisit ${selectedMonth} $currentYear.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Data berhasil diexport ke $filePath')),
      );
    }
  }

  // double _parseNumber(dynamic value) {
  //   if (value == null) return 0;
  //   String cleaned = value.toString().replaceAll(RegExp(r'[^0-9,-]'), '');
  //   if (cleaned.isEmpty) return 0;
  //   return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
  // }

  String _formatCurrencyTotal(dynamic number) {
    final formatter =
        NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    // Jika bukan angka, ubah ke 0
    if (number == null) return 'Rp 0';

    // pastikan numeric
    num value;
    if (number is num) {
      value = number;
    } else {
      value = double.tryParse(number.toString()) ?? 0;
    }

    return formatter.format(value);
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
      backgroundColor: Colors.white,
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
                         onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 3,),
                                        ),
                                        )
                          }
                      ),
                      Text(
                        'Laporan Surplus/Defisit',
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
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  // _buildFilterButton('Pendapatan', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPendapatanPage()),
                  //   );
                  // }),
                  // _buildFilterButton('Pengeluaran', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPengeluaranPage()),
                  //   );
                  // }),

                  // _buildFilterButton('Kas', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPage()),
                  //   );
                  // }),
                  _buildFilterButton('Surplus/Defisit',
                      isActive: true, onPressed: () {}),
                  _buildFilterButton('Utang', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganUtangPage()),
                    );
                  }),
                  _buildFilterButton('Aset', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganAsetPage()),
                    );
                  }),
                  _buildFilterButton('Neraca', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganNeracaPage()),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // ================= TAHUN =================
                    _buildMonthButton(
                      'Tahun',
                      isSelected: selectedMonth.isEmpty,
                      onPressed: () {
                        setState(() {
                          selectedMonth = '';
                          selectedMonthNumber = '';
                        });

                        fetchLaporanKeuangan(
                          bulan: null, // ⬅️ SEMUA BULAN
                          tahun: currentYear, // ⬅️ TAHUN TERPILIH
                        );
                      },
                    ),

                    // ================= BULAN =================
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
                      final monthNumber =
                          (index + 1).toString().padLeft(2, '0');

                      return _buildMonthButton(
                        monthNames[index],
                        isSelected: selectedMonth == monthNames[index],
                        onPressed: () {
                          setState(() {
                            selectedMonth = monthNames[index];
                            selectedMonthNumber = monthNumber;
                          });

                          fetchLaporanKeuangan(
                            bulan: selectedMonthNumber, // ⬅️ BULAN
                            tahun: currentYear, // ⬅️ TAHUN
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Dropdown Tahun
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pilih Tahun: "),
                  DropdownButton<String>(
                    value: yearList.contains(currentYear) ? currentYear : null,
                    items: yearList.map((year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (String? newYear) {
                      if (newYear == null) return;

                      setState(() {
                        currentYear = newYear;
                      });

                      fetchLaporanKeuangan(
                        bulan: selectedMonthNumber.isNotEmpty
                            ? selectedMonthNumber // ⬅️ bulan tetap
                            : null, // ⬅️ atau semua bulan
                        tahun: currentYear, // ⬅️ tahun baru
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          SingleChildScrollView(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataLaporanKeu.isEmpty
                      ? const Center(child: Text('Tidak ada data Transaksi'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return buildRingkasanKeuanganMobile(
                                pendapatan: totalSaldoPendapatan,
                                pengeluaran: totalSaldoPengeluaran,
                                hasilAkhir: hasilAkhir,
                                title:
                                    'Ringkasan Keuangan $selectedMonth $currentYear',
                                numberMonth: selectedMonthNumber,
                                month: selectedMonth,
                                year: currentYear.toString());
                          },
                        )),
        ],
      ),
      floatingActionButton: dataLaporanKeu.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Unduh PDF',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    await createAndUploadPdf(
                      currentYear: currentYear.toString(),
                      selectedMonth: selectedMonth,
                      namaRt: KodeRt.namaRt,
                      totalSaldoPendapatan: totalSaldoPendapatan,
                      totalSaldoPengeluaran: totalSaldoPengeluaran,
                      hasilAkhir: hasilAkhir,
                      isDefisit: isDefisit,
                    );
                  },
                ),
                SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Unduh Excel',
                      style: TextStyle(color: Colors.white)),
                  onPressed: exportToExcel,
                ),
              ],
            ),
    );
  }

  /// 🔹 Tombol kategori
  Widget _buildFilterButton(String title,
      {bool isActive = false, required VoidCallback onPressed}) {
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

  Widget _buildMonthButton(String label,
      {required VoidCallback onPressed, bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF3D8D7A) : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF3D8D7A)),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  // Widget _buildItemRow(String label, dynamic value) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 4.0),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Expanded(
  //           flex: 3,
  //           child: Text(
  //             '$label:',
  //             style: const TextStyle(
  //                 fontWeight: FontWeight.bold, color: Color(0xFF3D8D7A)),
  //           ),
  //         ),
  //         Expanded(
  //           flex: 5,
  //           child: Text(
  //             value != null ? value.toString() : '-',
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 3,),
                                        ),
                                        )
                          }
                      ),
                      Text(
                        'Laporan Keuangan SURPLUS/DEFISIT',
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
          Align(
            alignment: Alignment.center,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
               

                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Surplus/Defisit',
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
                              builder: (context) => LaporanKeuanganUtangPage()),
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
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LaporanKeuanganAsetPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Aset',
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
                                  LaporanKeuanganNeracaPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Neraca',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                  // ================= TOMBOL TAHUN =================
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedMonth.isEmpty
                          ? Colors.white
                          : Colors.transparent,
                      foregroundColor: selectedMonth.isEmpty
                          ? const Color(0xFF3D8D7A)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedMonth = '';
                        selectedMonthNumber = '';
                      });

                      fetchLaporanKeuangan(
                        bulan: null, // ⬅️ SEMUA BULAN
                        tahun: currentYear, // ⬅️ TAHUN TERPILIH
                      );
                    },
                    child: const Text(
                      'Tahun',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // ================= TOMBOL BULAN =================
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
                    final isSelected = selectedMonth == monthNames[index];

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isSelected ? Colors.white : Colors.transparent,
                        foregroundColor:
                            isSelected ? const Color(0xFF3D8D7A) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedMonth = monthNames[index];
                          selectedMonthNumber = monthNumber;
                        });

                        fetchLaporanKeuangan(
                          bulan: selectedMonthNumber, // ⬅️ BULAN
                          tahun: currentYear, // ⬅️ TAHUN
                        );
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pilih Tahun: "),
              DropdownButton<String>(
                value: yearList.contains(currentYear) ? currentYear : null,
                items: yearList.map((year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newYear) {
                  if (newYear == null) return;

                  setState(() {
                    currentYear = newYear;
                  });

                  fetchLaporanKeuangan(
                    bulan: selectedMonthNumber.isNotEmpty
                        ? selectedMonthNumber // ⬅️ bulan tetap
                        : null, // ⬅️ atau semua bulan
                    tahun: currentYear,
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : dataLaporanKeu.isEmpty
                    ? const Center(child: Text('Tidak ada data Transaksi'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          //bool isWideScreen = constraints.maxWidth > 800;

                          return buildRingkasanKeuangan(
                              pendapatan: totalSaldoPendapatan,
                              pengeluaran: totalSaldoPengeluaran,
                              hasilAkhir: hasilAkhir,
                              title:
                                  'Ringkasan Keuangan $selectedMonth $currentYear',
                              numberMonth: selectedMonthNumber,
                              month: selectedMonth,
                              year: currentYear.toString());
                        },
                      ),
          ),
          SizedBox(height: 16),
        ],
      ),
      floatingActionButton: dataLaporanKeu.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  heroTag: 'downloadPdf',
                  onPressed: () async {
                    await createAndUploadPdf(
                      currentYear: currentYear.toString(),
                      selectedMonth: selectedMonth,
                      namaRt: KodeRt.namaRt,
                      totalSaldoPendapatan: totalSaldoPendapatan,
                      totalSaldoPengeluaran: totalSaldoPengeluaran,
                      hasilAkhir: hasilAkhir,
                      isDefisit: isDefisit,
                    );
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Unduh PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  heroTag: 'downloadExcel',
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

// Widget _buildTableHeader(String text) {
//   return Padding(
//     padding: const EdgeInsets.all(8.0),
//     child: Text(
//       text,
//       style: const TextStyle(fontWeight: FontWeight.bold),
//       textAlign: TextAlign.center,
//     ),
//   );
// }

// Widget _buildTableCell(String? text,
//     {bool alignRight = false, bool bold = false, Color? color}) {
//   return Container(
//     color: color,
//     padding: const EdgeInsets.all(8.0),
//     child: Text(
//       text ?? '',
//       textAlign: alignRight ? TextAlign.right : TextAlign.left,
//       style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
//     ),
//   );
// }

String _formatCurrency(dynamic value) {
  if (value == null) return "Rp 0";
  String strValue = value.toString().replaceAll('.', '');
  final number = double.tryParse(strValue) ?? 0;

  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  return formatter.format(number);
}

Widget buildRingkasanKeuangan(
    {required double pendapatan,
    required double pengeluaran,
    required double hasilAkhir,
    required String title,
    required String numberMonth,
    required String month,
    required String year}) {
  bool isDefisit = hasilAkhir < 0;

  return LayoutBuilder(
    builder: (context, constraints) {
      double maxCardWidth =
          constraints.maxWidth > 600 ? 500 : constraints.maxWidth * 0.9;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.green.shade100),
            ),
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildCustomRow(
                    'Pendapatan',
                    '',
                    _formatCurrency(pendapatan),
                    onTitleTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LaporanKeuanganPendapatanPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCustomRow(
                    'Pengeluaran',
                    _formatCurrency(pengeluaran),
                    '',
                    onTitleTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LaporanKeuanganPengeluaranPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(thickness: 1.5, color: Colors.grey),
                  _buildCustomRow(
                    isDefisit ? 'Defisit' : 'Surplus',
                    '',
                    _formatCurrency(hasilAkhir),
                    isDefisit: isDefisit,
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

Widget _buildCustomRow(
  String title,
  dynamic leftValue,
  dynamic rightValue, {
  bool isDefisit = false,
  VoidCallback? onTitleTap,
}) {
  String formatValue(dynamic val) {
    if (val == '' || val == null) return '';
    if (val is double) return "Rp ${val.toStringAsFixed(0)}";
    return val.toString();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onTitleTap,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: (title == 'Surplus' || title == 'Defisit')
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: onTitleTap != null
                    ? Colors.blue
                    : (isDefisit ? Colors.red : Colors.black87),
                decoration: onTitleTap != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatValue(leftValue),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDefisit ? Colors.red : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatValue(rightValue),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: (title == 'Surplus' || title == 'Defisit')
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isDefisit ? Colors.red : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildRingkasanKeuanganMobile({
  required double pendapatan,
  required double pengeluaran,
  required double hasilAkhir,
  required String title,
  required String numberMonth,
  required String month,
  required String year,
}) {
  bool isDefisit = hasilAkhir < 0;

  return LayoutBuilder(
    builder: (context, constraints) {
      double maxWidth = constraints.maxWidth > 600 ? 500 : constraints.maxWidth;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.green.shade100),
            ),
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRowMobile(
                    title: 'Pendapatan',
                    leftValue: '',
                    rightValue: pendapatan,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LaporanKeuanganPendapatanPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildRowMobile(
                    title: 'Pengeluaran',
                    leftValue: pengeluaran,
                    rightValue: '',
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LaporanKeuanganPengeluaranPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildRowMobile(
                    title: isDefisit ? 'Defisit' : 'Surplus',
                    leftValue: '',
                    rightValue: hasilAkhir,
                    isBold: true,
                    valueColor: isDefisit ? Colors.red : Colors.green,
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

Widget _buildRowMobile({
  required String title,
  dynamic leftValue,
  dynamic rightValue,
  bool isBold = false,
  Color valueColor = Colors.black,
  VoidCallback? onTap,
}) {
  String formatValue(dynamic val) {
    if (val == null || val == '') return '';
    if (val is double || val is int) {
      return _formatCurrency(val.toDouble());
    }
    return val.toString();
  }

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          /// 🔹 TITLE
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: onTap != null ? Colors.blue : Colors.black87,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),

          /// 🔹 LEFT VALUE
          Expanded(
            flex: 2,
            child: Text(
              formatValue(leftValue),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),

          /// 🔹 RIGHT VALUE
          Expanded(
            flex: 2,
            child: Text(
              formatValue(rightValue),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
