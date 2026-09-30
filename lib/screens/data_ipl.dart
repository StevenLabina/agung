import 'dart:io' as io;
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_formatter/formatters/currency_input_formatter.dart';
import 'package:flutter_multi_formatter/formatters/money_input_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iuran_rt_web/screens/buat_iuran_ipl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

class DataIPLPage extends StatefulWidget {
  @override
  _DataIPLPageState createState() => _DataIPLPageState();
}

class _DataIPLPageState extends State<DataIPLPage> {
  bool isFilterVisible = true;

  bool showFilter = false;

  double totalSaldoBelumLunas = 0;
  Map<String, TextEditingController> _iplControllers = {};
  int currentPage = 0;
  int rowsPerPage = 10;
  TextEditingController searchController = TextEditingController();
  TextEditingController minIPLController = TextEditingController();
  TextEditingController maxIPLController = TextEditingController();
  List<dynamic> dataIPL = [];
  int get totalPages {
    if (dataIPL.isEmpty) return 1;
    return (dataIPL.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (dataIPL.isEmpty) return [];

    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, dataIPL.length);

    return dataIPL.sublist(start, end);
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

    fetchDataIPL();
  }

  Future<void> _showConfirmationDialog(
    String id,
    String saldo,
    String noKavling,
  ) async {
    if (saldo.trim().isEmpty) {
      await Flushbar(
        message: "Nominal IPL tidak boleh kosong",
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDECE8),
          title: Text(
            'Konfirmasi',
            style: GoogleFonts.lato(color: Colors.black),
          ),
          content: Text(
            '\nNo Kavling: $noKavling'
            '\nNominal IPL: $saldo'
            '\n==================================='
            '\nApakah anda yakin ingin merubah data IPL ini?',
            style: GoogleFonts.lato(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3D8D7A),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await updateNomIPL(id, saldo, noKavling);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DataIPLPage(),
                  ),
                );
              },
              child: Text(
                'Ubah',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3D8D7A),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateNomIPL(String id, String saldo, String noKavling) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/ubah_nominal_ipl.php"),
        body: {
          'id': id,
          'saldo': saldo,
          'no_kavling': noKavling,
          'id_rt': KodeRt.kodeRt
        },
      );

      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        Flushbar(
          message: "Update data warga berhasil",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        await tambahLogAktivitas(
            aktivitas:
                'Mengupdate Nominal IPL: ${noKavling} menjadi Rp $saldo');
        fetchDataIPL();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(json['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update data: $e")),
      );
    }
  }

  Future<void> fetchDataIPL([String query = ""]) async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/list_data_ipl.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'searchQuery': searchController.text,
        'id_rt': KodeRt.kodeRt,
        'min_ipl': minIPLController.text,
        'max_ipl': maxIPLController.text,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success' && result['data'] != null) {
        setState(() {
          dataIPL = result['data'];
        });
      } else {
        setState(() {
          dataIPL = [];
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

  Future<void> createAndUploadPdf() async {
    final pdf = pw.Document();
    final filteredData = dataIPL.where((item) {
      return (item['no_kavling'] ?? '').toString().trim().isNotEmpty ||
          (item['nom_ipl'] ?? '').toString().trim().isNotEmpty;
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
                    'Data IPL Warga ${KodeRt.namaRt}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 20),
                ],
              ),

              // ================================
              //  TABEL DATA (OPTIMIZED)
              // ================================
              pw.Table.fromTextArray(
                headers: [
                  'No Kavling',
                  'Nominal IPL',
                ],
                data: dataIPL.map((item) {
                  return [
                    item['no_kavling'] ?? '-',
                    "Rp ${item['nom_ipl']}",
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
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(100),
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
          ..setAttribute("download", "Data IPL ${KodeRt.namaRt}.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory directory = await getApplicationDocumentsDirectory();
        String filePath = "${directory.path}/Data IPL ${KodeRt.namaRt}.pdf";
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
                      'Data IPL ${KodeRt.namaRt}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // ================================
                //  TABEL DATA (OPTIMIZED)
                // ================================
                pw.Table.fromTextArray(
                  headers: [
                    'No Kavling',
                    'Nominal IPL',
                  ],

                  data: chunkData.map((item) {
                    return [
                      item['no_kavling'] ?? '-',
                      "Rp ${item['nom_ipl']}",
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
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(100),
                  },
                ),
              ];
            },
          ),
        );

        final Uint8List encoded = await pdf.save();
        zip.addFile(ArchiveFile("Data IPL ${KodeRt.namaRt}_Part${i + 1}.pdf",
            encoded.length, encoded.toList()));
      }
      if (kIsWeb) {
        final zipEncoder = ZipEncoder();
        final zipData = zipEncoder.encode(zip)!;
        final blob = html.Blob([zipData], 'application/zip');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Data IPL ${KodeRt.namaRt}.zip")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: simpan masing-masing PDF
        io.Directory directory = await getApplicationDocumentsDirectory();
        for (int i = 0; i < totalChunks; i++) {
          final pdfData = zip.files[i].content as List<int>;
          String filePath =
              "${directory.path}/Data IPL ${KodeRt.namaRt}_Part${i + 1}.pdf";
          io.File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(pdfData);
        }
      }
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Data IPL ${KodeRt.namaRt}'];

    List<String> headers = [
      'No Kavling',
      'Nominal IPL',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataIPL) {
      if ((item['no_kavling'] ?? '').toString().trim().isEmpty &&
          (item['nom_ipl'] ?? '').toString().trim().isEmpty) {
        continue;
      }

      List<String> row = [
        item['no_kavling'] ?? '-',
        item['nom_ipl'] ?? '-',

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
        ..setAttribute("download", "Data IPL.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Data IPL.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
    }
  }

  // Future<void> checkTanggalPeringatan(BuildContext context) async {
  //   final now = DateTime.now();
  //   final prefs = await SharedPreferences.getInstance();

  //   final keyPendapatan = "isDownload_${now.year}";
  //   isDownload = prefs.getBool(keyPendapatan) ?? false;

  //   if (now.month == 12 && now.day >= 27 && isDownload == false) {
  //     Future.delayed(Duration.zero, () {
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             title: Text("Peringatan Akhir Tahun"),
  //             content: Text(
  //               "Tanggal ${now.day}-${now.month}-${now.year}. "
  //               "Tahun akan segera berganti.\n\n"
  //               "Silakan download laporan keuangan tahun ${now.year} "
  //               "sebelum data dihapus pada awal tahun baru.",
  //             ),
  //             actions: [
  //               ElevatedButton(
  //                 onPressed: () async {
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(
  //                         builder: (context) =>
  //                             LaporanKeuanganPendapatanPage()),
  //                   );
  //                   await exportToExcel();
  //                   await prefs.setBool(keyPendapatan, true);
  //                   isDownload = true;
  //                 },
  //                 child: Text("Download"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     });
  //   }
  // }

  // void simulateLastYear() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(
  //       'last_saved_year', (DateTime.now().year - 1).toString());
  // }
  // Future<void> exportToExcelOnlySendPath(
  //   String tahun,
  //   String totalPendapatan,
  //   String totalPengeluaran,
  //   String totalSemua,
  // ) async {
  //   var excel = exc.Excel.createExcel();
  //   exc.Sheet sheetObject = excel['Laporan Keuangan Pendapatan'];

  //   List<String> headers = [
  //     'Tanggal Pendapatan',
  //     'COA Pendapatan',
  //     'Kode Ref Pendapatan',
  //     'No Kavling Pendapatan',
  //     'Keterangan Pendapatan',
  //     'Saldo Pendapatan',
  //     'Tanggal Pengeluaran',
  //     'COA Pengeluaran',
  //     'Kode Ref Pengeluaran',
  //     'No Kavling Pengeluaran',
  //     'Keterangan Pengeluaran',
  //     'Saldo Pengeluaran',
  //   ];
  //   sheetObject.appendRow(headers);

  //   for (var item in dataLaporanKeu) {
  //     List<String> row = [
  //       item['tanggal_pendapatan'] ?? '-',
  //       item['coa_pendapatan'] ?? '-',
  //       item['kode_ref_pendapatan'] ?? '-',
  //       item['no_kavling_pendapatan'] ?? '-',
  //       item['ket_pendapatan'] ?? '-',
  //       item['saldo_pendapatan'] ?? '-',
  //       item['tanggal_pengeluaran'] ?? '-',
  //       item['coa_pengeluaran'] ?? '-',
  //       item['kode_ref_pengeluaran'] ?? '-',
  //       item['no_kavling_pengeluaran'] ?? '-',
  //       item['ket_pengeluaran'] ?? '-',
  //       item['saldo_pengeluaran'] ?? '-',
  //     ];
  //     sheetObject.appendRow(row);
  //   }

  //   if (kIsWeb) {
  //     final bytes = excel.encode();
  //     final blob = html.Blob([bytes],
  //         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  //     final url = html.Url.createObjectUrlFromBlob(blob);
  //     final anchor = html.AnchorElement(href: url)
  //       ..setAttribute("download", "Laporan Keuangan Tahun $tahun.xlsx")
  //       ..click();
  //     html.Url.revokeObjectUrl(url);
  //   } else {
  //     Directory directory = await getApplicationDocumentsDirectory();
  //     String filePath = "${directory.path}/Laporan Keuangan Pendapatan.xlsx";
  //     File(filePath)
  //       ..createSync(recursive: true)
  //       ..writeAsBytesSync(excel.encode()!);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Data berhasil diexport ke $filePath')),
  //     );
  //     try {
  //       var response = await http.post(
  //         Uri.parse("${ApiUrls.baseUrl}/savePathExcelKeu.php"),
  //         body: {
  //           'tahun': tahun,
  //           'path': filePath,
  //           'totalPendapatan': totalPendapatan.toString(),
  //           'totalPengeluaran': totalPengeluaran.toString(),
  //           'totalSemua': totalSemua.toString(),
  //         },
  //       );

  //       if (response.statusCode == 200) {
  //         print("Path dan data berhasil dikirim ke server");
  //       } else {
  //         print("Gagal mengirim. Status: ${response.statusCode}");
  //       }
  //     } catch (e) {
  //       print("Error saat kirim path: $e");
  //     }
  //   }
  // }

  // String generateKodeRef({
  //   required String namaRT,
  //   required String kodeIuran,
  //   required String alamatKavling,
  //   required String tanggalLunas,
  //   required String kodeTransaksi,
  // }) {
  //   return '$namaRT$kodeIuran$alamatKavling$tanggalLunas$kodeTransaksi';
  // }

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
    final InputBorder customBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFF3D8D7A),
        width: 1.2,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(
                          showFilter ? Icons.filter_alt_off : Icons.filter_alt,
                          color: const Color(0xFF3D8D7A),
                          size: 18,
                        ),
                        label: Text(
                          showFilter
                              ? "Sembunyikan Filter"
                              : "Tampilkan Filter",
                          style: const TextStyle(
                            color: Color(0xFF3D8D7A),
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            showFilter = !showFilter;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (showFilter)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Pencarian",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                labelText: 'Berdasarkan No Kavling',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF3D8D7A),
                                ),
                                border: customBorder,
                                enabledBorder: customBorder,
                                focusedBorder: customBorder,
                              ),
                              onChanged: (_) => fetchDataIPL(),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Rentang Nominal IPL",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: minIPLController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                CurrencyInputFormatter(
                                  thousandSeparator: ThousandSeparator.Period,
                                  mantissaLength: 0,
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Min',
                                prefixIcon: const Icon(
                                  Icons.attach_money,
                                  color: Color(0xFF3D8D7A),
                                ),
                                border: customBorder,
                                enabledBorder: customBorder,
                                focusedBorder: customBorder,
                              ),
                              onChanged: (_) => fetchDataIPL(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: maxIPLController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                CurrencyInputFormatter(
                                  thousandSeparator: ThousandSeparator.Period,
                                  mantissaLength: 0,
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Max',
                                prefixIcon: const Icon(
                                  Icons.attach_money,
                                  color: Color(0xFF3D8D7A),
                                ),
                                border: customBorder,
                                enabledBorder: customBorder,
                                focusedBorder: customBorder,
                              ),
                              onChanged: (_) => fetchDataIPL(),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3D8D7A),
                                ),
                                onPressed: createAndUploadPdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text(
                                  "Unduh PDF",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3D8D7A),
                                ),
                                onPressed: exportToExcel,
                                icon: const Icon(
                                  Icons.table_chart,
                                ),
                                label: const Text(
                                  "Unduh Excel",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Data IPL Warga ${KodeRt.namaRt}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (dataIPL.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("Tidak ada data IPL"),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              // sesuaikan kebutuhan
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(
                                        label: Text("No Kavling"),
                                      ),
                                      DataColumn(
                                        label: Text("Nominal IPL"),
                                      ),
                                      DataColumn(
                                        label: Text("Aksi"),
                                      ),
                                    ],
                                    rows: paginatedData.map<DataRow>((item) {
                                      final id = item['id']?.toString() ?? '';

                                      _iplControllers.putIfAbsent(
                                        id,
                                        () => TextEditingController(
                                          text:
                                              (item['nom_ipl'] ?? 0).toString(),
                                        ),
                                      );

                                      final controller = _iplControllers[id]!;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              item['no_kavling']?.toString() ??
                                                  '',
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 120,
                                              child: _buildNumberInputFieldMob(
                                                controller,
                                                () {
                                                  if (!mounted) return;
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Builder(
                                              builder: (context) {
                                                final currentValue =
                                                    controller.text;

                                                final originalValue =
                                                    (item['nom_ipl'] ?? 0)
                                                        .toString();

                                                final isChanged =
                                                    currentValue.trim() !=
                                                        originalValue.trim();

                                                return ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    minimumSize: const Size(
                                                      80,
                                                      35,
                                                    ),
                                                  ),
                                                  onPressed: isChanged
                                                      ? () async {
                                                          await _showConfirmationDialog(
                                                            id,
                                                            currentValue,
                                                            item['no_kavling']
                                                                    ?.toString() ??
                                                                '',
                                                          );
                                                        }
                                                      : null,
                                                  child: Text(
                                                    'Ubah',
                                                    style: TextStyle(
                                                      color: isChanged
                                                          ? Colors.white
                                                          : Colors.white70,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                  )
                ],
              ),
              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
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
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
                                        disabledBackgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white70,
                                      ),
                                      onPressed:
                                          (currentPage + 1) * rowsPerPage <
                                                  dataIPL.length
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    final InputBorder customBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFF3D8D7A),
        width: 1.2,
      ),
    );
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
                                builder: (context) => TambahIuranPLPage()),
                          );
                        },
                      ),
                      Text(
                        'Data IPL Warga',
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
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1400,
                ),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// FILTER CARD
                        SizedBox(
                          width: 320,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Pencarian ",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Berdasarkan No Kavling',
                                    prefixIcon: Icon(Icons.search,
                                        color: Color(0xFF3D8D7A)),
                                    border: customBorder,
                                    enabledBorder: customBorder,
                                    focusedBorder: customBorder,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  onChanged: (_) => fetchDataIPL(),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Rentang Nominal IPL",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: minIPLController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    CurrencyInputFormatter(
                                      thousandSeparator:
                                          ThousandSeparator.Period,
                                      mantissaLength: 0,
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Min',
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Color(0xFF3D8D7A),
                                    ),
                                    border: customBorder,
                                    enabledBorder: customBorder,
                                    focusedBorder: customBorder,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (_) => fetchDataIPL(),
                                ),
                                const Text(
                                  "-",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextField(
                                  controller: maxIPLController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    CurrencyInputFormatter(
                                      thousandSeparator:
                                          ThousandSeparator.Period,
                                      mantissaLength: 0,
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Max',
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Color(0xFF3D8D7A),
                                    ),
                                    border: customBorder,
                                    enabledBorder: customBorder,
                                    focusedBorder: customBorder,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (_) => fetchDataIPL(),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Unduh Data IPL",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      FloatingActionButton.extended(
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
                                        heroTag: 'exportPdf',
                                        onPressed: createAndUploadPdf,
                                        icon: const Icon(Icons.picture_as_pdf,
                                            color: Colors.white),
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
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
                                        heroTag: 'exportExcel',
                                        onPressed: exportToExcel,
                                        icon: const Icon(Icons.table_chart,
                                            color: Colors.white),
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
                                )
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        /// TABLE AREA
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                /// TITLE
                                Text(
                                  'Data IPL Warga ${KodeRt.namaRt}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                /// TABLE
                                Expanded(
                                  child: isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : paginatedData.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  'Tidak ada data IPL Warga'),
                                            )
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                return ScrollConfiguration(
                                                  behavior:
                                                      MaterialScrollBehavior()
                                                          .copyWith(
                                                    dragDevices: {
                                                      PointerDeviceKind.touch,
                                                      PointerDeviceKind.mouse,
                                                      PointerDeviceKind
                                                          .trackpad,
                                                      PointerDeviceKind.stylus,
                                                    },
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      // HEADER TABEL
                                                      Table(
                                                        border: TableBorder.all(
                                                          color: Colors
                                                              .grey.shade600,
                                                          width: 1,
                                                        ),
                                                        columnWidths: const {
                                                          0: FixedColumnWidth(
                                                              200),
                                                          1: FixedColumnWidth(
                                                              200),
                                                          2: FixedColumnWidth(
                                                              200),
                                                        },
                                                        children: [
                                                          TableRow(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFF3D8D7A),
                                                            ),
                                                            children: [
                                                              _buildTableHeader(
                                                                  'No Kavling'),
                                                              _buildTableHeader(
                                                                  'Nominal IPL'),
                                                              _buildTableHeader(
                                                                  'Aksi'),
                                                            ],
                                                          ),
                                                        ],
                                                      ),

                                                      // BODY TABEL
                                                      Expanded(
                                                        child:
                                                            SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          child: SizedBox(
                                                            width: 600,
                                                            child:
                                                                SingleChildScrollView(
                                                              scrollDirection:
                                                                  Axis.vertical,
                                                              child: Table(
                                                                defaultVerticalAlignment:
                                                                    TableCellVerticalAlignment
                                                                        .middle,
                                                                border:
                                                                    TableBorder
                                                                        .all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                  width: 1,
                                                                ),
                                                                columnWidths: const {
                                                                  0: FixedColumnWidth(
                                                                      200),
                                                                  1: FixedColumnWidth(
                                                                      200),
                                                                  2: FixedColumnWidth(
                                                                      200),
                                                                },
                                                                children:
                                                                    paginatedData
                                                                        .map(
                                                                            (item) {
                                                                  final id = item[
                                                                          'id']
                                                                      .toString();

                                                                  if (!_iplControllers
                                                                      .containsKey(
                                                                          id)) {
                                                                    _iplControllers[
                                                                            id] =
                                                                        TextEditingController(
                                                                      text: (item['nom_ipl'] ??
                                                                              0)
                                                                          .toString(),
                                                                    );
                                                                  }

                                                                  return TableRow(
                                                                    children: [
                                                                      _buildTableCell(
                                                                        item['no_kavling']?.toString() ??
                                                                            '',
                                                                      ),
                                                                      _buildNumberInputField(
                                                                        context,
                                                                        _iplControllers[
                                                                            id]!,
                                                                        () => setState(
                                                                            () {}),
                                                                      ),
                                                                      Center(
                                                                        child:
                                                                            Builder(
                                                                          builder:
                                                                              (context) {
                                                                            final currentValue =
                                                                                _iplControllers[id]?.text ?? '';

                                                                            final originalValue =
                                                                                (item['nom_ipl'] ?? 0).toString();

                                                                            final isChanged =
                                                                                currentValue.trim() != originalValue.trim();

                                                                            return ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                backgroundColor: Colors.green,
                                                                                minimumSize: const Size(
                                                                                  80,
                                                                                  35,
                                                                                ),
                                                                              ),
                                                                              onPressed: isChanged
                                                                                  ? () {
                                                                                      _showConfirmationDialog(
                                                                                        id,
                                                                                        currentValue,
                                                                                        item['no_kavling'].toString(),
                                                                                      );
                                                                                    }
                                                                                  : null,
                                                                              child: Text(
                                                                                "Ubah",
                                                                                style: TextStyle(
                                                                                  color: isChanged ? Colors.white : Colors.white70,
                                                                                ),
                                                                              ),
                                                                            );
                                                                          },
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                ),

                                const SizedBox(height: 24),

                                /// PAGINATION
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
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
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
                                        disabledBackgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white70,
                                      ),
                                      onPressed:
                                          (currentPage + 1) * rowsPerPage <
                                                  dataIPL.length
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    )),
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

Widget _buildNumberInputField(
  BuildContext context,
  TextEditingController controller,
  VoidCallback onChanged,
) {
  final formatter = NumberFormat.decimalPattern('id_ID');

  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: (value) {
        final rawValue = value.replaceAll('.', '');

        if (rawValue.isEmpty) {
          onChanged();
          return;
        }

        final number = int.tryParse(rawValue);

        if (number == null) return;

        final formatted = formatter.format(number);

        if (formatted != controller.text) {
          controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(
              offset: formatted.length,
            ),
          );
        }

        onChanged();
      },
    ),
  );
}

Widget _buildNumberInputFieldMob(
  TextEditingController controller,
  VoidCallback onChanged,
) {
  final formatter = NumberFormat.decimalPattern('id_ID');

  return SizedBox(
    width: 120,
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (value) {
        final raw = value.replaceAll('.', '');

        if (raw.isEmpty) {
          controller.value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );

          onChanged();
          return;
        }

        final number = int.tryParse(raw);
        if (number == null) return;

        final formatted = formatter.format(number);

        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(
            offset: formatted.length,
          ),
        );

        onChanged();
      },
    ),
  );
}

Widget _buildHeader(BuildContext context) {
  return Container(
    height: 80,
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 232, 226, 226),
      border: Border.all(
        color: const Color.fromARGB(255, 58, 112, 50),
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TambahIuranPLPage(),
              ),
            );
          },
        ),
        const Text(
          "Data IPL Warga",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
