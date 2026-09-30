import 'dart:io' as io;
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';


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

class DataIuranPage extends StatefulWidget {
  @override
  _DataIuranPageState createState() => _DataIuranPageState();
}

class _DataIuranPageState extends State<DataIuranPage> {
  bool isFilterVisible = true;
 
    bool showFilter = false;
  int currentPage = 0;
  int rowsPerPage = 10;
  double totalSaldoBelumLunas = 0;
 TextEditingController searchController = TextEditingController();

  List<dynamic> dataIuran = [];
  int get totalPages {
    if (dataIuran.isEmpty) return 1;
    return (dataIuran.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (dataIuran.isEmpty) return [];

    final start = currentPage * rowsPerPage;

    if (start >= dataIuran.length) {
      return [];
    }

    final end = (start + rowsPerPage) > dataIuran.length
        ? dataIuran.length
        : (start + rowsPerPage);

    return dataIuran.sublist(start, end);
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


  @override
  void initState() {
    super.initState();

    fetchdataIuran();
  }

  Future<void> _showConfirmationDialog(
    String id,
    String nama,
    String saldo,
    String tanggal
  ) async {
  

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
            '\nNama Iuran: $nama'
            '\nNominal Iuran: $saldo'
            '\nBatas Pembayaran: $tanggal'
            '\n==================================='
            '\nApakah anda yakin ingin menghapus data iuran warga ini?',
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
                await hapusNomIuran(id, saldo, nama);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DataIuranPage(),
                  ),
                );
              },
              child: Text(
                'Hapus',
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

Future<void> hapusNomIuran(
    String id,
    String saldo,
    String namaIuran,
) async {
  try {
    final response = await http.post(
      Uri.parse("${ApiUrls.baseUrl}delete_iuran.php"),
      body: {
        'id': id,
        'id_rt': KodeRt.kodeRt,
        'nama_iuran': namaIuran,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Server error: ${response.statusCode}",
      );
    }

    final json = jsonDecode(response.body);

    if (json['result'] == 'success') {

      Flushbar(
        message: "Hapus data iuran telah berhasil",
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      await tambahLogAktivitas(
        aktivitas:
            'Menghapus data iuran: $namaIuran dan nominal iuran Rp $saldo',
      );

      fetchdataIuran();

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            json['message'] ?? 'Terjadi kesalahan',
          ),
        ),
      );

    }

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Failed to delete data: $e",
        ),
      ),
    );

  }
}

  Future<void> fetchdataIuran([String query = ""]) async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/list_data_iuran.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'searchQuery': searchController.text,
        'id_rt': KodeRt.kodeRt,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success' && result['data'] != null) {
        setState(() {
          dataIuran = result['data'];
        });
      } else {
        setState(() {
          dataIuran = [];
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
    final filteredData = dataIuran.where((item) {
      return (item['nama_iuran'] ?? '').toString().trim().isNotEmpty ||
          (item['nominal_iuran'] ?? '').toString().trim().isNotEmpty;
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
                    'Data Iuran Warga ${KodeRt.namaRt}',
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
                  'Nama Iuran',
                  'Nominal Iuran',
                  'Batas Pembayaran'
                ],
                data: paginatedData.map((item) {
                  return [
                    item['nama_iuran'] ?? '-',
                    "Rp ${item['nominal_iuran']}",
                    item['batas_pembayaran'] ?? '-',
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
                  2: const pw.FixedColumnWidth(100),
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
          ..setAttribute("download", "Data Iuran Warga ${KodeRt.namaRt}.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory directory = await getApplicationDocumentsDirectory();
        String filePath = "${directory.path}/Data Iuran Warga ${KodeRt.namaRt}.pdf";
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
                      'Data Iuran Warga ${KodeRt.namaRt}',
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
                    'Nama Iuran',
                    'Nominal Iuran',
                    'Batas Pembayaran'
                  ],

                  data: chunkData.map((item) {
                    return [
                      item['nama_iuran'] ?? '-',
                      "Rp ${item['nominal_iuran']}",
                      item['batas_pembayaran'] ?? '-',
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
                    2: const pw.FixedColumnWidth(100),
                  },
                ),
              ];
            },
          ),
        );

        final Uint8List encoded = await pdf.save();
        zip.addFile(ArchiveFile("Data Iuran Warga ${KodeRt.namaRt}_Part${i + 1}.pdf",
            encoded.length, encoded.toList()));
      }
      if (kIsWeb) {
        final zipEncoder = ZipEncoder();
        final zipData = zipEncoder.encode(zip)!;
        final blob = html.Blob([zipData], 'application/zip');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Data Iuran Warga ${KodeRt.namaRt}.zip")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: simpan masing-masing PDF
        io.Directory directory = await getApplicationDocumentsDirectory();
        for (int i = 0; i < totalChunks; i++) {
          final pdfData = zip.files[i].content as List<int>;
          String filePath =
              "${directory.path}/Data Iuran Warga ${KodeRt.namaRt}_Part${i + 1}.pdf";
          io.File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(pdfData);
        }
      }
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Data Iuran Warga ${KodeRt.namaRt}'];

    List<String> headers = [
      'Nama Iuran',
      'Nominal Iuran',
      'Batas Pembayaran',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataIuran) {
      if ((item['nama_iuran'] ?? '').toString().trim().isEmpty &&
          (item['nominal_iuran'] ?? '').toString().trim().isEmpty) {
        continue;
      }

      List<String> row = [
        item['nama_iuran'] ?? '-',
        item['nominal_iuran'] ?? '-',
        item['batas_pembayaran'] ?? '-',

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
        ..setAttribute("download", "Data Iuran Warga ${KodeRt.namaRt}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Data Iuran Warga ${KodeRt.namaRt}.xlsx";
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
  child: Column(
    children: [

      // FILTER TIDAK IKUT SCROLL
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: Icon(
            showFilter ? Icons.filter_alt_off : Icons.filter_alt,
            color: const Color(0xFF3D8D7A),
          ),
          label: Text(
            showFilter
                ? "Sembunyikan Filter"
                : "Tampilkan Filter",
            style: TextStyle(
              color: const Color(0xFF3D8D7A)
            ),
          ),
          onPressed: () {
            setState(() {
              showFilter = !showFilter;
            });
          },
        ),
      ),

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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: searchController,
          decoration: InputDecoration(
            labelText: 'Berdasarkan Nama Iuran',
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF3D8D7A),
            ),
            border: customBorder,
            enabledBorder: customBorder,
            focusedBorder: customBorder,
          ),
          onChanged: (_) => fetchdataIuran(),
        ),

        const SizedBox(height: 20),

        const Text(
          "Unduh Data Iuran Warga",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D8D7A),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: createAndUploadPdf,
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: exportToExcel,
            icon: const Icon(
              Icons.table_chart,
              color: Colors.white,
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

      // JUDUL TIDAK IKUT SCROLL
      Align(
        alignment: Alignment.center,
        child:    Text(
        'Data Iuran Untuk Warga ${KodeRt.namaRt}',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      ),

      

     

      const SizedBox(height: 10),

     
      Expanded(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : paginatedData.isEmpty
                ? const Center(
                    child: Text("Tidak ada data Iuran"),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        
                        columns: const [
                          DataColumn(
                              label: Text("Nama Iuran")),
                          DataColumn(
                              label: Text("Nominal Iuran")),
                          DataColumn(
                              label: Text("Batas Pembayaran")),
                          DataColumn(
                              label: Text("Aksi")),
                        ],
                        rows: paginatedData.map<DataRow>((item) {
                           final id = item[
                                                                          'id']
                                                                      .toString();
                                                                  final nom = item['nominal_iuran'].toString();
                                                                  final nama = item['nama_iuran'].toString();
                                                                  final tanggal = item['batas_pembayaran'].toString(); 
                          return DataRow(
                            cells: [
                              DataCell(
                                  Text(item['nama_iuran'])),
                              DataCell(
                                  Text(item['nominal_iuran'])),
                              DataCell(
                                  Text(item['batas_pembayaran'])),
                              DataCell(
                                ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                                                                backgroundColor: Colors.green,
                                                                                minimumSize: const Size(80, 35),
                                                                              ),
                                  onPressed: () {
                                    _showConfirmationDialog(
                                                                                        id,
                                                                                      nama,
                                                                                      nom,
                                                                                      tanggal
                                                                                      );
                                  },
                                  child: const Text("Hapus"),
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
              child:  Row(
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
                                                  dataIuran.length
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
                         Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 2,),
                                        ),
                                        );
                          
                        },
                      ),
                      Text(
                        'Data Iuran Warga',
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
                                    labelText: 'Berdasarkan Nama Iuran',
                                    prefixIcon: Icon(Icons.search,
                                        color: Color(0xFF3D8D7A)),
                                    border: customBorder,
                                    enabledBorder: customBorder,
                                    focusedBorder: customBorder,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  onChanged: (_) => fetchdataIuran(),
                                ),
                              
                                const SizedBox(height: 24),
                                const Text(
                                  "Unduh Data Iuran Warga",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FloatingActionButton.extended(
                                      backgroundColor: const Color(0xFF3D8D7A),
                                      heroTag: 'exportPdf',
                                      onPressed: createAndUploadPdf,
                                      icon: const Icon( Icons.picture_as_pdf,
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
                                      backgroundColor: const Color(0xFF3D8D7A),
                                      heroTag: 'exportExcel',
                                      onPressed: exportToExcel,
                                      icon: const Icon( 
                                        
                                        Icons.table_chart,
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
                                  'Data Iuran Warga ${KodeRt.namaRt}',
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
                                          child: CircularProgressIndicator())
                                      : paginatedData.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  'Tidak ada data Iuran Warga'))
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                // bool isWideScreen = constraints.maxWidth > 800;
                                                // final formatter = NumberFormat('#,###', 'id_ID');
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
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Column(
                                                      children: [
                                                        // HEADER TETAP
                                                        Table(
                                                          border:
                                                              TableBorder.all(
                                                            color: const Color(0xFF3D8D7A),
                                                            width: 1,
                                                          ),
                                                          columnWidths: const {
                                                            0: FixedColumnWidth(
                                                                200),
                                                            1: FixedColumnWidth(
                                                                200),
                                                            2: FixedColumnWidth(
                                                                200),
                                                               3: FixedColumnWidth(
                                                                200),
                                                          },
                                                          children: [
                                                            TableRow(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(0xFF3D8D7A),
                                                              ),
                                                              children: [
                                                                _buildTableHeader(
                                                                    'Nama Iuran'),
                                                                _buildTableHeader(
                                                                    'Nominal Iuran'),
                                                                  _buildTableHeader(
                                                                    'Batas Pembayaran'),
                                                                _buildTableHeader(
                                                                    'Aksi'),
                                                              ],
                                                            ),
                                                          ],
                                                        ),

                                                        Expanded(
                                                          child:
                                                              SingleChildScrollView(
                                                            scrollDirection: Axis
                                                                .horizontal, // bisa scroll ke samping
                                                            child:
                                                                SingleChildScrollView(
                                                              scrollDirection: Axis
                                                                  .vertical, // bisa scroll ke bawah
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
                                                                   3: FixedColumnWidth(
                                                                      200),
                                                                },
                                                                children:
                                                                    paginatedData.map(
                                                                        (item) {
                                                                  final id = item[
                                                                          'id']
                                                                      .toString();
                                                                  final nom = item['nominal_iuran'].toString();
                                                                  final nama = item['nama_iuran'].toString();
                                                                  final tanggal = item['batas_pembayaran'].toString();  
                                                                  return TableRow(
                                                                    children: [
                                                                      _buildTableCell(
                                                                        nama),
                                                                         _buildTableCell(
                                                                        nom),
                                                                            _buildTableCell(
                                                                        tanggal),
                                                                      Center(
                                                                        child:
                                                                            Builder(
                                                                          builder:
                                                                              (context) {
                                                                        

                                                                            return ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                foregroundColor: Colors.white,
                                                                                backgroundColor: Colors.green,
                                                                                minimumSize: const Size(80, 35),
                                                                              ),
                                                                              onPressed:  () {
                                                                                      _showConfirmationDialog(
                                                                                        id,
                                                                                      nama,
                                                                                      nom,
                                                                                      tanggal
                                                                                      );
                                                                                    },
                                                                                 
                                                                              child: Text(
                                                                                "Hapus",
                                                                                style: TextStyle(
                                                                                  color:  Colors.white,
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
                                                );
                                              },
                                            ),
                                ),

                                const SizedBox(height: 24),

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
                                                  dataIuran.length
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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 2,),
                                        ),
                                        );
          },
        ),
        const Text(
          "Data Iuran Warga Warga",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
