import 'dart:io' as io;
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';

// import 'package:iuran_rt_web/screens/laporan_keuangan.dart';

// import 'package:iuran_rt_web/screens/laporan_keuangan_pengeluaran.dart';
// import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
// import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';

import 'package:iuran_rt_web/url.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganPendapatanPage extends StatefulWidget {
  final String numberMonth;
  final String month;
  final String year;

  const LaporanKeuanganPendapatanPage(
      {super.key, this.numberMonth = "", this.month = "", this.year = ""});
  @override
  _LaporanKeuanganPendapatanPageState createState() =>
      _LaporanKeuanganPendapatanPageState();
}

class _LaporanKeuanganPendapatanPageState
    extends State<LaporanKeuanganPendapatanPage> {
  List<dynamic> dataLaporanKeu = [];
  int currentPage = 0;
  int rowsPerPage = 10;
  double totalSaldoBelumLunas = 0;
  List<dynamic> get filteredData {
    return dataLaporanKeu.where((item) {
      final saldoPengeluaran = item['saldo_pengeluaran'];

      return saldoPengeluaran == null ||
          saldoPengeluaran.toString().toLowerCase() == 'null' ||
          saldoPengeluaran.toString().isEmpty;
    }).toList();
  }

  int get totalPages {
    if (filteredData.isEmpty) return 1;
    return (filteredData.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (filteredData.isEmpty) return [];

    final start = currentPage * rowsPerPage;

    if (start >= filteredData.length) {
      return [];
    }

    final end = (start + rowsPerPage) > filteredData.length
        ? filteredData.length
        : (start + rowsPerPage);

    return filteredData.sublist(start, end);
  }

  bool isLoading = false;
  bool isDownload = false;
  double totalSaldoPendapatan = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoKeu = 0;
  final currentYear = DateTime.now().year;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  double saldobalance = 0;
  double runningBalance = 0;
  String getMonthShortName(int month) {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des"
    ];
    return months[month - 1];
  }

  @override
  void initState() {
    super.initState();
    print("month: ${widget.numberMonth}");
    print("tahun: ${widget.year}");
    fetchLaporanKeuangan();
    //simulateLastYear();
    checkTanggalPeringatan(context);
    checkYearChangeAndTruncate();
  }

  // Future<void> _showConfirmationDialog(String tanggal, String saldo,
  //     String noKavling, String ket, String coa, int id) async {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         backgroundColor: Color(0xFFFDECE8),
  //         title:
  //             Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
  //         content: Text(
  //             'Tanggal: ${tanggal}'
  //             '\nRincian Pendapatan: $ket'
  //             '\nKode COA: $coa'
  //             '\nNo Kavling: $noKavling'
  //             '\nNominal:Rp $saldo'
  //             '\n==================================='
  //             '\nApakah anda yakin ingin menghapus data pendapatan ini?',
  //             style: GoogleFonts.lato(color: Colors.black)),
  //         actions: <Widget>[
  //           TextButton(
  //             child: Text('Batal',
  //                 style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
            // TextButton(
            //   child: Text('Hapus',
            //       style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
            //   onPressed: () async {
            //     DateTime parsedDate =
            //         DateFormat('dd-MM-yyyy-HH:mm').parse(tanggal);

            //     String monthShort = getMonthShortName(parsedDate.month);
            //     int numberMonth = parsedDate.month;
            //     await deleteDataPendapatan(id);
            //     Navigator.pop(context);
            //     Navigator.pop(context);
            //     Navigator.pushReplacement(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => LaporanKeuanganPendapatanPage(
            //           month: monthShort,
            //           numberMonth: numberMonth.toString(),
            //         ),
            //       ),
            //     );
            //   },
            // ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<String?> fetchKetCoa({
    required String coa,
    required String idRt,
    required String jenis,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/detail_kode_coa.php'),
        body: {
          'coa': coa,
          'id_rt': idRt,
          'jenis': jenis,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'success') {
          return data['data'].values.first.toString();
        } else {
          return 'Keterangan COA Lainnya';
        }
      } else {
        return 'Gagal memanggil server';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  void showCoaDialog(
      BuildContext context, String coa, String idRt, String jenis) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final ketCoa = await fetchKetCoa(coa: coa, idRt: idRt, jenis: jenis);

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detail COA"),
          content: Text("COA: $coa\nKeterangan: $ketCoa"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  Future<void> createAndUploadPdf() async {
    final pdf = pw.Document();
    final filteredData = dataLaporanKeu.where((item) {
      final saldo = (item['saldo_pendapatan'] ?? '').toString().trim();
      final ket = (item['ket_pendapatan'] ?? '').toString().trim();
      return saldo.isNotEmpty &&
          saldo.toLowerCase() != 'null' &&
          ket.isNotEmpty &&
          ket.toLowerCase() != 'null';
    }).toList();
    const int chunkSize = 300;
    int totalChunks = (filteredData.length / chunkSize).ceil();
    if (totalChunks > 1) {
      List<int> chunkLengths = [];
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > filteredData.length)
            ? filteredData.length
            : start + chunkSize;
        chunkLengths.add(end - start);
      }

      bool proceed = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Konfirmasi Multiple PDF"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Data melebihi $chunkSize baris, sehingga akan dibuat $totalChunks file PDF."),
                    const SizedBox(height: 8),
                    const Text("Jumlah baris per PDF:"),
                    ...List.generate(
                        totalChunks,
                        (index) => Text(
                            "• Part ${index + 1}: ${chunkLengths[index]} baris")),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Lanjutkan"),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) return;
    }

    // Tampilkan loading dialog

    if (totalChunks == 1) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),

          // ======================================================
          //  FOOTER (DIGABUNG MENJADI 2 BARIS SESUAI PERMINTAAN)
          // ======================================================
          footer: (context) => pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Terima kasih telah menggunakan aplikasi RT Digital',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 2),
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
          ),

          build: (pw.Context context) {
            //double runningBalance = 0;

            return [
              // ================================
              //  HEADER LAPORAN
              // ================================
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Laporan Pendapatan ${widget.month} ${widget.year}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    KodeRt.namaRt,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 2),
                  pw.Text(
                    'Total Saldo Pendapatan: ${_formatCurrencyTotal(totalSaldoPendapatan)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

              // ================================
              //  TABEL DATA (OPTIMIZED)
              // ================================
              pw.Table.fromTextArray(
                headers: [
                  'Tanggal',
                  'COA',
                  'No Kavling',
                  'Rincian Pendapatan',
                  'Nominal',
                ],
                data: filteredData.map((item) {
                  final double pendapatan = double.tryParse(
                        (item['saldo_pendapatan'] ?? '0')
                            .toString()
                            .replaceAll('.', ''),
                      ) ??
                      0;

                  runningBalance += pendapatan;

                  return [
                    item['tanggal_pendapatan'] ?? '-',
                    item['coa_pendapatan'] ?? '-',
                    item['no_kavling_pendapatan'] ?? '-',
                    item['ket_pendapatan'] ?? '-',
                    "Rp ${item['saldo_pendapatan']}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(color: PdfColors.grey),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(120),
                  4: const pw.FixedColumnWidth(70),
                },
              ),
            ];
          },
        ),
      );

      final Uint8List encoded = await pdf.save();
      if (kIsWeb) {
        final blob = html.Blob([encoded], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "Laporan_Pendapatan_${widget.month}_${widget.year}.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory directory = await getApplicationDocumentsDirectory();
        String filePath =
            "${directory.path}/Laporan Pendapatan ${widget.month} ${widget.year}.pdf";
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(encoded);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ PDF berhasil disimpan di $filePath')),
          );
        }
      }
    } else {
      final Archive zip = Archive();
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > filteredData.length)
            ? filteredData.length
            : start + chunkSize;
        final chunkData = filteredData.sublist(start, end);

        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),

            // ======================================================
            //  FOOTER (DIGABUNG MENJADI 2 BARIS SESUAI PERMINTAAN)
            // ======================================================
            footer: (context) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Terima kasih telah menggunakan aplikasi RT Digital',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 2),
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
            ),

            build: (pw.Context context) {
              //double runningBalance = 0;

              return [
                // ================================
                //  HEADER LAPORAN
                // ================================
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Laporan Pendapatan ${widget.month} ${widget.year}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      KodeRt.namaRt,
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 2),
                    pw.Text(
                      'Total Saldo Pendapatan: ${_formatCurrencyTotal(totalSaldoPendapatan)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),

                // ================================
                //  TABEL DATA (OPTIMIZED)
                // ================================
                pw.Table.fromTextArray(
                  headers: [
                    'Tanggal',
                    'COA',
                    'No Kavling',
                    'Rincian Pendapatan',
                    'Nominal',
                  ],

                  data: chunkData.map((item) {
                    final double pendapatan = double.tryParse(
                          (item['saldo_pendapatan'] ?? '0')
                              .toString()
                              .replaceAll('.', ''),
                        ) ??
                        0;

                    runningBalance += pendapatan;

                    return [
                      item['tanggal_pendapatan'] ?? '-',
                      item['coa_pendapatan'] ?? '-',
                      item['no_kavling_pendapatan'] ?? '-',
                      item['ket_pendapatan'] ?? '-',
                      "Rp ${item['saldo_pendapatan']}",
                    ];
                  }).toList(),

                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey700,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  border: pw.TableBorder.all(color: PdfColors.grey),

                  // **MUAT BANYAK DATA TANPA CRASH**
                  columnWidths: {
                    0: const pw.FixedColumnWidth(60),
                    1: const pw.FixedColumnWidth(60),
                    2: const pw.FixedColumnWidth(60),
                    3: const pw.FixedColumnWidth(120),
                    4: const pw.FixedColumnWidth(70),
                  },
                ),
              ];
            },
          ),
        );

        final Uint8List encoded = await pdf.save();
        zip.addFile(ArchiveFile(
            "Laporan Pendapatan ${widget.month} ${widget.year}_Part${i + 1}.pdf",
            encoded.length,
            encoded.toList()));
      }
      if (kIsWeb) {
        final zipEncoder = ZipEncoder();
        final zipData = zipEncoder.encode(zip)!;
        final blob = html.Blob([zipData], 'application/zip');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "Laporan Pendapatan ${widget.month} ${widget.year}.zip")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: simpan masing-masing PDF
        io.Directory directory = await getApplicationDocumentsDirectory();
        for (int i = 0; i < totalChunks; i++) {
          final pdfData = zip.files[i].content as List<int>;
          String filePath =
              "${directory.path}/Laporan Iuran Belum Lunas ${widget.month} ${widget.year}_Part${i + 1}.pdf";
          io.File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(pdfData);
        }
      }
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Keuangan Pendapatan'];
    final formatter = NumberFormat('#,###', 'id_ID');
    double runningBalance = 0;
    List<String> headers = [
      'Tanggal',
      'COA',
      'No Kavling',
      'Rincian Pendapatan',
      'Nominal',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataLaporanKeu) {
      if ((item['tanggal_pendapatan'] ?? '').toString().trim().isEmpty &&
          (item['coa_pendapatan'] ?? '').toString().trim().isEmpty &&
          (item['kode_ref_pendapatan'] ?? '').toString().trim().isEmpty &&
          (item['no_kavling_pendapatan'] ?? '').toString().trim().isEmpty &&
          (item['ket_pendapatan'] ?? '').toString().trim().isEmpty &&
          (item['saldo_pendapatan'] ?? '').toString().trim().isEmpty) {
        continue;
      }
      final double pendapatan = double.tryParse(
              (item['saldo_pendapatan'] ?? '0')
                  .toString()
                  .replaceAll('.', '')) ??
          0;
      runningBalance += pendapatan;
      List<String> row = [
        item['tanggal_pendapatan'] ?? '-',
        item['coa_pendapatan'] ?? '-',
        item['no_kavling_pendapatan'] ?? '-',
        item['ket_pendapatan'] ?? '-',
        item['saldo_pendapatan'] ?? '-',
        // formatter.format(runningBalance),
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download",
            "Laporan Keuangan Pendapatan ${widget.month} ${widget.year}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Pendapatan ${widget.month} ${widget.year}.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
    }
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

  // Future<void> deleteDataPendapatan(int id) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('${ApiUrls.baseUrl}delete_pendapatan_biaya.php'),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({
  //         'id': id,
  //         'id_rt': KodeRt.kodeRt,
  //       }),
  //     );

  //     final data = jsonDecode(response.body);
  //     if (data['result'] == 'success') {
  //       Flushbar(
  //         message: "Data pendapatan berhasil dihapus",
  //         duration: Duration(seconds: 2),
  //         backgroundColor: Colors.green,
  //         flushbarPosition: FlushbarPosition.TOP,
  //       ).show(context);
  //     } else {
  //       Flushbar(
  //         message: 'Gagal menghapus data: ${data['message']}',
  //         duration: Duration(seconds: 2),
  //         backgroundColor: Colors.red,
  //         flushbarPosition: FlushbarPosition.TOP,
  //       ).show(context);
  //     }
  //   } catch (e) {
  //     Flushbar(
  //       message: 'Terjadi kesalahan: $e',
  //       duration: Duration(seconds: 2),
  //       backgroundColor: Colors.red,
  //       flushbarPosition: FlushbarPosition.TOP,
  //     ).show(context);
  //   }
  // }

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

  Future<void> fetchLaporanKeuangan({String? bulan, String? tahun}) async {
    setState(() {
      isLoading = true;
    });

    final idRt = KodeRt.kodeRt;

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'id_rt': idRt, 'bulan': widget.numberMonth, 'tahun': widget.year},
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
          saldobalance = totalPendapatan;
          currentPage = 0;
        });

        print("Pendapatan bulan $bulan: $totalPendapatan");
      } else {
        setState(() {
          dataLaporanKeu = [];
          totalSaldoPendapatan = 0;
          saldobalance = 0;
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
    exc.Sheet sheetObject = excel['Laporan Keuangan Pendapatan'];

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
      String filePath = "${directory.path}/Laporan Keuangan Pendapatan.xlsx";
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    LaporanKeuanganSurplusDefisitPage()),
                          );
                        },
                      ),
                      Text(
                        'Laporan Pendapatan',
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
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Wrap(
          //     spacing: 8,
          //     runSpacing: 8,
          //     alignment: WrapAlignment.center,
          //     children: [
          //       _buildFilterButton('Pendapatan', isActive: true, onPressed: () {}),
          //       _buildFilterButton('Pengeluaran', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganPengeluaranPage()),
          //         );
          //       }),
          //       _buildFilterButton('Utang', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganUtangPage()),
          //         );
          //       }),
          //       _buildFilterButton('Kas', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganPage()),
          //         );
          //       }),
          //       _buildFilterButton('Surplus/Defisit', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganSurplusDefisitPage()),
          //         );
          //       }),
          //     ],
          //   ),
          // ),

          // const SizedBox(height: 8),

          // Filter bulan
          // SingleChildScrollView(
          //   scrollDirection: Axis.horizontal,
          //   padding: const EdgeInsets.symmetric(horizontal: 8),
          //   child: Row(
          //     children: [
          //       _buildMonthButton('All', onPressed: fetchLaporanKeuangan),
          //       ...List.generate(12, (index) {
          //         final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
          //         final monthNumber = (index + 1).toString().padLeft(2, '0');
          //         return _buildMonthButton(monthNames[index], onPressed: () {
          //           fetchLaporanKeuangan(bulan: monthNumber);
          //         });
          //       }),
          //     ],
          //   ),
          // ),

          // const SizedBox(height: 8),

          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   child: Text(
          //     'Total Pendapatan: ${currencyFormat.format(totalSaldoPendapatan)}',
          //     style: const TextStyle(
          //       fontSize: 16,
          //       fontWeight: FontWeight.bold,
          //       color: Color(0xFF3D8D7A),
          //     ),
          //   ),
          // ),

          // const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Laporan Keuangan Pendapatan ${widget.month} ${widget.year}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Total Saldo Pendapatan: ${_formatCurrencyTotal(totalSaldoPendapatan)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredData.isEmpty
                      ? const Center(child: Text('Tidak ada data pendapatan'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // final formatter = NumberFormat('#,###', 'id_ID');

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
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Column(
                                    children: [
                                      // HEADER
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
                                          // 5: FixedColumnWidth(200),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3D8D7A),
                                            ),
                                            children: [
                                              _buildTableHeader('Tanggal'),
                                              _buildTableHeader('COA'),
                                              _buildTableHeader('No Kavling'),
                                              _buildTableHeader(
                                                  'Rincian Pendapatan'),
                                              _buildTableHeader('Nominal'),
                                              // _buildTableHeader('Aksi'),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // DATA
                                      Table(
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
                                          // 5: FixedColumnWidth(200),
                                        },
                                        children: paginatedData.map((item) {
                                          final double pendapatan =
                                              double.tryParse(
                                                      (item['saldo_pendapatan'] ??
                                                              '0')
                                                          .toString()
                                                          .replaceAll(
                                                              '.', '')) ??
                                                  0;
                                          runningBalance += pendapatan;

                                          return TableRow(
                                            children: [
                                              _buildTableCell(
                                                  item['tanggal_pendapatan']),
                                              InkWell(
                                                onTap: () {
                                                  showCoaDialog(
                                                      context,
                                                      item['coa_pendapatan'],
                                                      KodeRt.kodeRt,
                                                      'pendapatan');
                                                },
                                                child: _buildTableCell(
                                                    item['coa_pendapatan']),
                                              ),
                                              _buildTableCell(item[
                                                  'no_kavling_pendapatan']),
                                              _buildTableCell(
                                                  item['ket_pendapatan']),
                                              _buildTableCell(
                                                  "Rp ${item['saldo_pendapatan']}"),
                                              // Center(
                                              //   child: ElevatedButton(
                                              //     style:
                                              //         ElevatedButton.styleFrom(
                                              //       backgroundColor:
                                              //           Colors.green,
                                              //       minimumSize:
                                              //           const Size(80, 35),
                                              //     ),
                                              //     onPressed: () async {
                                              //       var id = item['id'];
                                              //       var tanggal =
                                              //           item['tanggal_pendapatan']
                                              //                   ?.toString() ??
                                              //               '-';
                                              //       var saldo =
                                              //           item['saldo_pendapatan']
                                              //                   ?.toString() ??
                                              //               '0';
                                              //       var noKavling =
                                              //           item['no_kavling_pendapatan']
                                              //                   ?.toString() ??
                                              //               '-';
                                              //       var ket =
                                              //           item['ket_pendapatan']
                                              //                   ?.toString() ??
                                              //               '-';
                                              //       var coa =
                                              //           item['coa_pendapatan']
                                              //                   ?.toString() ??
                                              //               '-';

                                              //       try {
                                              //         // Pastikan fungsi _showConfirmationDialog menerima parameter String
                                              //         _showConfirmationDialog(
                                              //             tanggal,
                                              //             saldo,
                                              //             noKavling,
                                              //             ket,
                                              //             coa,
                                              //             id);
                                              //       } catch (e) {
                                              //         print(
                                              //             "Error detail: $e"); // Debugging di konsol
                                              //         Flushbar(
                                              //           message:
                                              //               'Terjadi kesalahan data: $e',
                                              //           duration: Duration(
                                              //               seconds: 2),
                                              //           backgroundColor:
                                              //               Colors.red,
                                              //           flushbarPosition:
                                              //               FlushbarPosition
                                              //                   .TOP,
                                              //         ).show(context);
                                              //       }
                                              //     },
                                              //     child: const Text(
                                              //       "Hapus",
                                              //       style: TextStyle(
                                              //           color: Colors.white),
                                              //     ),
                                              //   ),
                                              // )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          SizedBox(height: 8),
          filteredData.isEmpty
              ? const SizedBox()
              : Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton.extended(
                        backgroundColor: const Color(0xFF3D8D7A),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Unduh PDF',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: createAndUploadPdf,
                      ),
                      const SizedBox(width: 12), // jarak horizontal
                      FloatingActionButton.extended(
                        backgroundColor: const Color(0xFF3D8D7A),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Unduh Excel',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: exportToExcel,
                      ),
                    ],
                  ),
                ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                ElevatedButton(
                    onPressed: currentPage > 0
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Previous'),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Halaman ${currentPage + 1} dari ${((dataLaporanKeu.length - 1) / rowsPerPage).ceil()}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        (currentPage + 1) * rowsPerPage < dataLaporanKeu.length
                            ? () {
                                setState(() {
                                  currentPage++;
                                });
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Next'),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildFilterButton(String title,
  //     {bool isActive = false, required VoidCallback onPressed}) {
  //   return ElevatedButton(
  //     onPressed: onPressed,
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: isActive ? const Color(0xFF3D8D7A) : Colors.white,
  //       foregroundColor: isActive ? Colors.white : const Color(0xFF3D8D7A),
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //     ),
  //     child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  //   );
  // }

  // Widget _buildMonthButton(String label, {required VoidCallback onPressed}) {
  //   return Padding(
  //     padding: const EdgeInsets.only(right: 8),
  //     child: ElevatedButton(
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: Colors.white,
  //         foregroundColor: const Color(0xFF3D8D7A),
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //       ),
  //       onPressed: onPressed,
  //       child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
  //     ),
  //   );
  // }

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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    LaporanKeuanganSurplusDefisitPage()),
                          );
                        },
                      ),
                      Text(
                        'Laporan Pendapatan',
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
          // Column(
          //   children: [
          //     Row(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         ElevatedButton(
          //           onPressed: () {},
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.white,
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Pendapatan',
          //             style: TextStyle(
          //               color: Color(0xFF3D8D7A),
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganPengeluaranPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Pengeluaran',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),

          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganUtangPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Utang',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) => LaporanKeuanganPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Laporan Kas Keuangan',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganSurplusDefisitPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Surplus/Defisit',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         //    SizedBox(width: 16),
          //         //  ElevatedButton(
          //         //   onPressed: () {
          //         //     Navigator.pushReplacement(
          //         //       context,
          //         //       MaterialPageRoute(
          //         //           builder: (context) =>
          //         //               LaporanKeuanganNeracaPage()),
          //         //     );
          //         //   },
          //         //   style: ElevatedButton.styleFrom(
          //         //     backgroundColor: Color(0xFF3D8D7A),
          //         //     padding:
          //         //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //         //   ),
          //         //   child: Text(
          //         //     'Neraca',
          //         //     style: TextStyle(
          //         //       color: Colors.white,
          //         //       fontSize: 18,
          //         //     ),
          //         //   ),
          //         // ),
          //       ],
          //     ),
          //   ],
          // ),
          // SizedBox(height: 16),
          // Center(
          //   child: Container(
          //     padding: const EdgeInsets.all(12),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF3D8D7A),
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Wrap(
          //       spacing: 8,
          //       runSpacing: 8,
          //       children: [
          //         ElevatedButton(
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.white,
          //             foregroundColor: const Color(0xFF3D8D7A),
          //             shape: RoundedRectangleBorder(
          //               borderRadius: BorderRadius.circular(8),
          //             ),
          //           ),
          //           onPressed: () {
          //             fetchLaporanKeuangan();
          //           },
          //           child: const Text(
          //             'All',
          //             style: TextStyle(fontWeight: FontWeight.bold),
          //           ),
          //         ),
          //         ...List.generate(12, (index) {
          //           final monthNames = [
          //             'Jan',
          //             'Feb',
          //             'Mar',
          //             'Apr',
          //             'Mei',
          //             'Jun',
          //             'Jul',
          //             'Agu',
          //             'Sep',
          //             'Okt',
          //             'Nov',
          //             'Des'
          //           ];
          //           final monthNumber = (index + 1).toString().padLeft(2, '0');

          //           return ElevatedButton(
          //             style: ElevatedButton.styleFrom(
          //               backgroundColor: Colors.white,
          //               foregroundColor: const Color(0xFF3D8D7A),
          //               shape: RoundedRectangleBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //               ),
          //             ),
          //             onPressed: () {
          //               fetchLaporanKeuangan(bulan: monthNumber);
          //             },
          //             child: Text(
          //               monthNames[index],
          //               style: const TextStyle(fontWeight: FontWeight.bold),
          //             ),
          //           );
          //         }),
          //       ],
          //     ),
          //   ),
          // ),
          // SizedBox(height: 16),
          // Text(
          //   'Total Pendapatan: ${currencyFormat.format(totalSaldoPendapatan)}',
          //   style: TextStyle(
          //     fontSize: 16,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Laporan Keuangan Pendapatan ${widget.month} ${widget.year}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Total Saldo Pendapatan: ${_formatCurrencyTotal(totalSaldoPendapatan)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredData.isEmpty
                    ? const Center(child: Text('Tidak ada data pendapatan'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // bool isWideScreen = constraints.maxWidth > 800;
                          // final formatter = NumberFormat('#,###', 'id_ID');
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
                                  // HEADER TETAP
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
                                      // 5: FixedColumnWidth(200),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D8D7A),
                                        ),
                                        children: [
                                          _buildTableHeader('Tanggal'),
                                          _buildTableHeader('COA'),
                                          _buildTableHeader('No Kavling'),
                                          _buildTableHeader(
                                              'Rincian Pendapatan'),
                                          _buildTableHeader('Nominal'),
                                          // _buildTableHeader('Aksi'),
                                        ],
                                      ),
                                    ],
                                  ),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis
                                          .horizontal, // bisa scroll ke samping
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis
                                            .vertical, // bisa scroll ke bawah
                                        child: Table(
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
                                            // 5: FixedColumnWidth(200),
                                          },
                                          children: paginatedData.map((item) {
                                            final double pendapatan =
                                                double.tryParse(
                                                        (item['saldo_pendapatan'] ??
                                                                '0')
                                                            .toString()
                                                            .replaceAll(
                                                                '.', '')) ??
                                                    0;
                                            runningBalance += pendapatan;

                                            return TableRow(
                                              children: [
                                                _buildTableCell(
                                                    item['tanggal_pendapatan']),
                                                InkWell(
                                                  onTap: () {
                                                    showCoaDialog(
                                                        context,
                                                        item['coa_pendapatan'],
                                                        KodeRt.kodeRt,
                                                        'pendapatan');
                                                  },
                                                  child: _buildTableCell(
                                                      item['coa_pendapatan']),
                                                ),
                                                _buildTableCell(item[
                                                    'no_kavling_pendapatan']),
                                                _buildTableCell(
                                                    item['ket_pendapatan']),
                                                _buildTableCell(
                                                    "Rp ${item['saldo_pendapatan']}"),
                                                // Center(
                                                //   child: ElevatedButton(
                                                //     style: ElevatedButton
                                                //         .styleFrom(
                                                //       backgroundColor:
                                                //           Colors.green,
                                                //       minimumSize:
                                                //           const Size(80, 35),
                                                //     ),
                                                //     onPressed: () async {
                                                //       var id = item['id'];
                                                //       var tanggal = item[
                                                //           'tanggal_pendapatan'];
                                                //       var saldo = item[
                                                //           'saldo_pendapatan'];
                                                //       var noKavling = item[
                                                //           'no_kavling_pendapatan'];
                                                //       var ket = item[
                                                //           'ket_pendapatan'];
                                                //       var coa = item[
                                                //           'coa_pendapatan'];

                                                //       try {
                                                //         _showConfirmationDialog(
                                                //             tanggal,
                                                //             saldo,
                                                //             noKavling,
                                                //             ket,
                                                //             coa,
                                                //             id);
                                                //       } catch (e) {
                                                //         Flushbar(
                                                //           message:
                                                //               'Terjadi kesalahan: $e',
                                                //           duration: Duration(
                                                //               seconds: 2),
                                                //           backgroundColor:
                                                //               Colors.red,
                                                //           flushbarPosition:
                                                //               FlushbarPosition
                                                //                   .TOP,
                                                //         ).show(context);
                                                //       }
                                                //     },
                                                //     child: const Text(
                                                //       "Hapus",
                                                //       style: TextStyle(
                                                //           color: Colors.white),
                                                //     ),
                                                //   ),
                                                // )
                                              ],
                                            );
                                          }).toList(),
                                        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               ElevatedButton(
                    onPressed: currentPage > 0
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Previous'),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Halaman ${currentPage + 1} dari ${((dataLaporanKeu.length - 1) / rowsPerPage).ceil()}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        (currentPage + 1) * rowsPerPage < dataLaporanKeu.length
                            ? () {
                                setState(() {
                                  currentPage++;
                                });
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D8D7A),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Next'),
                  ),
            ],
          ),
        ],
      ),
      floatingActionButton: filteredData.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // if (dataLaporanKeu.isEmpty)
                //   FloatingActionButton(
                //     backgroundColor: Color(0xFF3D8D7A),
                //     heroTag: 'isi saldo',
                //     onPressed: () {
                //       _showSaldoAwalDialog(context);
                //     },
                //     child: Icon(
                //       Icons.add,
                //       color: Colors.white,
                //     ),
                //     tooltip: 'Isi Saldo Awal Tahun',
                //   ),
                // SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  heroTag: 'exportPdf',
                  onPressed: createAndUploadPdf,
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

                SizedBox(height: 12),
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
