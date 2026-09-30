import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/rekap_iuran_warga.dart';
import 'package:iuran_rt_web/url.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:universal_html/html.dart' as html;

class HistoriTransaksiPage extends StatefulWidget {
  final String numberMonth;
  final String month;
  final String year;
  final String alamatKavling;
  final double totalBelumLunas;
  final String metode;
  const HistoriTransaksiPage(
      {super.key,
      this.numberMonth = "",
      this.month = "",
      this.year = "",
      this.alamatKavling = "",
      this.totalBelumLunas = 0,
      this.metode = ""});
  @override
  _HistoriTransaksiPageState createState() => _HistoriTransaksiPageState();
}

class _HistoriTransaksiPageState extends State<HistoriTransaksiPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> dataIuran = [];
  bool isLoading = false;
  int currentPage = 0;
  int rowsPerPage = 10;

  List<dynamic> get paginatedData {
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage) > dataIuran.length
        ? dataIuran.length
        : (start + rowsPerPage);
    return dataIuran.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    fetchIuranData();
    print("📅 numberMonth: ${widget.numberMonth}");
    print("📆 month: ${widget.month}");
    print("🗓️ year: ${widget.year}");
    print("🏠 alamatKavling: ${widget.alamatKavling}");
    print("💰 totalBelumLunas: ${widget.totalBelumLunas}");
  }

  Future<void> fetchIuranData([String query = "", String bulan = ""]) async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/histori_all.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'searchQuery': query,
        'id_rt': KodeRt.kodeRt,
        if (widget.numberMonth.isNotEmpty) 'bulan': widget.numberMonth,
        if (widget.year.isNotEmpty) 'tahun': widget.year,
        'alamat': (widget.alamatKavling == "Semua Kavling")
            ? ""
            : widget.alamatKavling,
        
        if (widget.metode.isNotEmpty)
          'metode': widget.metode == "Transfer" ? "Transfer" : "Bayar Tunai",
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success') {
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
      setState(() {
        dataIuran = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> createAndUploadPdf() async {
    final formatter = NumberFormat('#,###', 'id_ID');

    // Filter data yang valid
    final filteredData = dataIuran.where((item) {
      final saldo = (item['r_nominal_iuran'] ?? '').toString().trim();
      return saldo.isNotEmpty && saldo.toLowerCase() != 'null';
    }).toList();

    const int chunkSize = 300;
    int totalChunks = (filteredData.length / chunkSize).ceil();
    if (filteredData.length <= chunkSize) totalChunks = 1;

    // Jika multiple PDF, konfirmasi
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
      // ===============================
      // 1 PDF saja
      // ===============================
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
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
          build: (context) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(KodeRt.namaRt, style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2),
                pw.Text(
                  'Total Saldo: Rp ${formatter.format(widget.totalBelumLunas)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
            pw.Table.fromTextArray(
              headers: [
                'No Kavling',
                'Nama Pemilik',
                'Penghuni',
                'Nama Iuran',
                'Nominal Iuran',
                'Tanggal Jatuh Tempo',
                'Tanggal Lunas',
                'Status',
                'Metode'
              ],
              data: filteredData.map((item) {
                return [
                  item['r_no_kavling'] ?? '-',
                  item['r_nama_pemilik'] ?? '-',
                  item['r_nama_penanggung_jawab'] ?? '-',
                  item['r_nama_iuran'] ?? '-',
                  'Rp ${item['r_nominal_iuran']}',
                  item['r_batas_pembayaran'] ?? '-',
                  item['r_tanggal_lunas'] ?? '-',
                  item['r_status'] ?? '-',
                  item['r_metode'] ?? '-',
                ];
              }).toList(),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FixedColumnWidth(70),
                5: const pw.FixedColumnWidth(80),
                6: const pw.FixedColumnWidth(80),
                7: const pw.FixedColumnWidth(50),
                8: const pw.FixedColumnWidth(60),
              },
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(5),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: pw.TableBorder.all(color: PdfColors.grey),
            ),
          ],
        ),
      );

      final Uint8List encoded = await pdf.save();
      final fileName =
          "Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}.pdf";

      if (kIsWeb) {
        final blob = html.Blob([encoded], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        io.Directory directory = await getApplicationDocumentsDirectory();
        String filePath = "${directory.path}/$fileName";
        io.File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(encoded);
      }
    } else {
      // ===============================
      // Multiple PDF → ZIP
      // ===============================
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
            build: (context) => [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year} (Part ${i + 1})',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(KodeRt.namaRt,
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 2),
                  pw.Text(
                    'Total Saldo: Rp ${formatter.format(widget.totalBelumLunas)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
              pw.Table.fromTextArray(
                headers: [
                  'No Kavling',
                  'Nama Pemilik',
                  'Penghuni',
                  'Nama Iuran',
                  'Nominal Iuran',
                  'Tanggal Jatuh Tempo',
                  'Tanggal Lunas',
                  'Status',
                  'Metode'
                ],
                data: chunkData.map((item) {
                  return [
                    item['r_no_kavling'] ?? '-',
                    item['r_nama_pemilik'] ?? '-',
                    item['r_nama_penanggung_jawab'] ?? '-',
                    item['r_nama_iuran'] ?? '-',
                    'Rp ${item['r_nominal_iuran']}',
                    item['r_batas_pembayaran'] ?? '-',
                    item['r_tanggal_lunas'] ?? '-',
                    item['r_status'] ?? '-',
                    item['r_metode'] ?? '-',
                  ];
                }).toList(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(50),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(80),
                  6: const pw.FixedColumnWidth(80),
                  7: const pw.FixedColumnWidth(50),
                  8: const pw.FixedColumnWidth(60),
                },
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(5),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                border: pw.TableBorder.all(color: PdfColors.grey),
              ),
            ],
          ),
        );

        final Uint8List encoded = await pdf.save();
        zip.addFile(ArchiveFile(
          "Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}_Part${i + 1}.pdf",
          encoded.length,
          encoded.toList(),
        ));
      }

      // Download ZIP (Web)
      if (kIsWeb) {
        final zipEncoder = ZipEncoder();
        final zipData = zipEncoder.encode(zip)!;
        final blob = html.Blob([zipData], 'application/zip');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}.zip")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: simpan masing-masing PDF
        io.Directory directory = await getApplicationDocumentsDirectory();
        for (int i = 0; i < totalChunks; i++) {
          final pdfData = zip.files[i].content as List<int>;
          String filePath =
              "${directory.path}/Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}_Part${i + 1}.pdf";
          io.File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(pdfData);
        }
      }
    }

    // Snackbar sukses
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: const Text(
            '✅ Semua PDF berhasil dibuat dan diunduh',
            style: TextStyle(color: Colors.black),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Data Iuran Warga'];

    // Menambahkan header
    List<String> headers = [
      'No Kavling',
      'Nama Pemilik',
      'Penghuni',
      'Nama Iuran',
      'Nominal Iuran',
      'Tanggal Jatuh Tempo',
      'Tanggal Lunas',
      'Status',
      'Metode'
    ];
    sheetObject.appendRow(headers);

    // Menambahkan data
    for (var item in dataIuran) {
      List<String> row = [
        item['r_no_kavling'] ?? '-',
        item['r_nama_pemilik'] ?? '-',
        item['r_nama_penanggung_jawab'] ?? '-',
        item['r_nama_iuran'] ?? '-',
        item['r_nominal_iuran'] ?? '-',
        item['r_batas_pembayaran'] ?? '-',
        item['r_tanggal_lunas'] ?? '-',
        item['r_status'] ?? '-',
        item['r_metode'] ?? '-',
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      // Convert Excel ke Uint8List dan trigger download file
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download",
            "Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Iuran Lunas ${widget.alamatKavling} ${widget.month} ${widget.year}.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
    }
  }
  Future<void> _showStatusCashOutDialog() async {
 showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFDECE8),

      title: Text(
        'Informasi Status Cash Out',
        style: GoogleFonts.lato(color: Colors.black),
      ),

      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            'PENDING:\n'
            'Transaksi berhasil, namun masih menunggu proses pencairan (disbursement) ke rekening RT.\n\n'

            'SUCCESS:\n'
            'Transaksi berhasil dan proses pencairan ke rekening RT telah selesai.\n\n'

            'NONE:\n'
            'Transaksi berhasil menggunakan metode pembayaran tunai.\n\n'

            '===================================\n\n'

            'Catatan:\n'
            'Jika status cash out sudah SUCCESS tetapi saldo belum masuk, kemungkinan:\n'
            '- Nominal transaksi di bawah Rp10.000, atau\n'
            '- Masih dalam proses (maksimal 1x24 jam).',

            style: GoogleFonts.lato(
              color: Colors.black,
              height: 1.5,
            ),
          ),
        ),
      ),

      actions: <Widget>[
        TextButton(
          child: Text(
            'Tutup',
            style: GoogleFonts.lato(
              color: const Color(0xFF3D8D7A),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  },
);
}
Future<void> _showBatchDialog() async {
 showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFDECE8),

      title: Text(
        'Informasi Batch Disbursement',
        style: GoogleFonts.lato(color: Colors.black),
      ),

      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: SingleChildScrollView(
          child: Text(
            'Batch 1:\n'
            'Waktu transaksi: 00:00 - 03:59\n'
            'Pencairan saldo: mulai pukul 06:00\n\n'

            'Batch 2:\n'
            'Waktu transaksi: 04:00 - 07:59\n'
            'Pencairan saldo: mulai pukul 09:00\n\n'

            'Batch 3:\n'
            'Waktu transaksi: 08:00 - 11:59\n'
            'Pencairan saldo: mulai pukul 13:00\n\n'

            'Batch 4:\n'
            'Waktu transaksi: 12:00 - 15:59\n'
            'Pencairan saldo: mulai pukul 17:00\n\n'

            'Batch 5:\n'
            'Waktu transaksi: 16:00 - 19:59\n'
            'Pencairan saldo: mulai pukul 21:00\n\n'

            'Batch 6:\n'
            'Waktu transaksi: 20:00 - 23:59\n'
            'Pencairan saldo: mulai pukul 06:00 (hari berikutnya)\n\n'

            '===================================\n\n'

            'Catatan:\n'
            'Pencairan saldo mengikuti jadwal batch dan dapat mengalami '
            'penyesuaian tergantung sistem.',

            style: GoogleFonts.lato(
              color: Colors.black,
              height: 1.5,
            ),
          ),
        ),
      ),

      actions: <Widget>[
        TextButton(
          child: Text(
            'Tutup',
            style: GoogleFonts.lato(
              color: const Color(0xFF3D8D7A),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
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
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 HEADER
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 226, 226),
                border: Border.all(
                  color: Color.fromARGB(255, 58, 112, 50),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                      onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => RekapIuranWargaPage()),
                );
              
              },
                  ),
                  Expanded(
                    child: Text(
                      'Laporan Iuran Lunas',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Laporan Iuran Lunas ${widget.month} ${widget.year}',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Total Saldo: ${_formatCurrencyTotal(widget.totalBelumLunas)}',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(height: 8),
            // 🔹 TABEL DATA
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataIuran.isEmpty
                      ? const Center(child: Text('Tidak ada data Iuran'))
                      : ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  border: TableBorder.all(
                                    color: Colors.grey.shade600,
                                    width: 1,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(130),
                                    1: FixedColumnWidth(140),
                                    2: FixedColumnWidth(140),
                                    3: FixedColumnWidth(140),
                                    4: FixedColumnWidth(120),
                                    5: FixedColumnWidth(140),
                                    6: FixedColumnWidth(140),
                                    7: FixedColumnWidth(100),
                                    8: FixedColumnWidth(100),
                                    9: FixedColumnWidth(100),
                                    10: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // 🔸 HEADER
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3D8D7A),
                                      ),
                                      children: [
                                        _buildTableHeader('No Kavling'),
                                        _buildTableHeader('Pemilik'),
                                        _buildTableHeader('Penghuni'),
                                        _buildTableHeader('Nama Iuran'),
                                        _buildTableHeader('Nominal'),
                                        _buildTableHeader('Jatuh Tempo'),
                                        _buildTableHeader('Tanggal Lunas'),
                                        _buildTableHeader('Status'),
                                       _buildTableHeadershowDialog('Status Cash out', _showStatusCashOutDialog),
                                          _buildTableHeadershowDialog('Batch', _showBatchDialog),
                                        _buildTableHeader('Metode'),
                                      ],
                                    ),

                                    // 🔸 DATA
                                    ...paginatedData.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildTableCell(item['r_no_kavling']),
                                          _buildTableCell(
                                              item['r_nama_pemilik_rumah']),
                                          _buildTableCell(
                                              item['r_nama_penghuni']),
                                          _buildTableCell(item['r_nama_iuran']),
                                        _buildTableCell(
  NumberFormat.decimalPattern('id').format(
    int.tryParse(
      item['r_nominal_iuran']
          ?.toString()
          .replaceAll('.', '') ?? '0',
    ) ?? 0,
  ),
),

                                          _buildTableCell(
                                              item['r_batas_pembayaran']),
                                          _buildTableCell(
                                              item['r_tanggal_lunas']),
                                          _buildTableCell(item['r_status']),
                                          _buildTableCell(item['r_status_cash_out']),
                                          _buildTableCell(item['r_batch']),
                                          _buildTableCell(item['r_metode']),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
   SizedBox(height: 8),
                            dataIuran.isEmpty
          ? const SizedBox()
          :Align(
                            alignment: Alignment.center,
                            child:    Row(
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
            SizedBox(height: 10),

            // 🔹 PAGINATION
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
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
                    'Halaman ${currentPage + 1} dari ${((dataIuran.length - 1) / rowsPerPage).ceil()}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        (currentPage + 1) * rowsPerPage < dataIuran.length
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
            ),
          ],
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
                           onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => RekapIuranWargaPage()),
                );
              
              },
                      ),
                      Text(
                        'Laporan Iuran Lunas',
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
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Laporan Iuran Lunas ${widget.month} ${widget.year}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Total Saldo: ${_formatCurrencyTotal(widget.totalBelumLunas)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : dataIuran.isEmpty
                    ? const Center(child: Text('Tidak ada data Iuran'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWideScreen = constraints.maxWidth > 800;
                          return ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
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
                                      0: FixedColumnWidth(140),
                                      1: FixedColumnWidth(140),
                                      2: FixedColumnWidth(140),
                                      3: FixedColumnWidth(140),
                                      4: FixedColumnWidth(140),
                                      5: FixedColumnWidth(140),
                                      6: FixedColumnWidth(140),
                                      7: FixedColumnWidth(140),
                                      8: FixedColumnWidth(140),
                                      9: FixedColumnWidth(140),
                                      10: FixedColumnWidth(140),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D8D7A),
                                        ),
                                        children: [
                                          _buildTableHeader('No Kavling'),
                                          _buildTableHeader(
                                              'Nama Pemilik Rumah'),
                                          _buildTableHeader('Nama Penghuni'),
                                          _buildTableHeader('Nama Iuran'),
                                          _buildTableHeader('Nominal Iuran'),
                                          _buildTableHeader(
                                              'Tanggal Jatuh Tempo'),
                                          _buildTableHeader('Tanggal Lunas'),
                                          _buildTableHeader('Status'),
                                        _buildTableHeadershowDialog('Status Cash out', _showStatusCashOutDialog),
                                          _buildTableHeadershowDialog('Batch', _showBatchDialog),
                                          _buildTableHeader('Metode'),
                                        ],
                                      ),
                                    ],
                                  ),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(140),
                                          1: FixedColumnWidth(140),
                                          2: FixedColumnWidth(140),
                                          3: FixedColumnWidth(140),
                                          4: FixedColumnWidth(140),
                                          5: FixedColumnWidth(140),
                                          6: FixedColumnWidth(140),
                                          7: FixedColumnWidth(140),
                                          8: FixedColumnWidth(140),
                                          9: FixedColumnWidth(140),
                                          10: FixedColumnWidth(140),
                                        },
                                        children: paginatedData.map((item) {
                                          return TableRow(
                                            children: [
                                              _buildTableCell(
                                                  item['r_no_kavling']),
                                              _buildTableCell(
                                                  item['r_nama_pemilik_rumah']),
                                              _buildTableCell(
                                                  item['r_nama_penghuni']),
                                              _buildTableCell(
                                                  item['r_nama_iuran']),
                                            _buildTableCell(
  NumberFormat.decimalPattern('id').format(
    int.tryParse(
      item['r_nominal_iuran']
          ?.toString()
          .replaceAll('.', '') ?? '0',
    ) ?? 0,
  ),
),
                                              _buildTableCell(
                                                  item['r_batas_pembayaran']),
                                              _buildTableCell(
                                                  item['r_tanggal_lunas']),
                                              _buildTableCell(item['r_status']),
                                              _buildTableCell(item['r_status_cash_out']),
                                              _buildTableCell(item['r_batch']),
                                              _buildTableCell(item['r_metode']),
                                            ],
                                          );
                                        }).toList(),
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
                    'Halaman ${currentPage + 1} dari ${((dataIuran.length - 1) / rowsPerPage).ceil()}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        (currentPage + 1) * rowsPerPage < dataIuran.length
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
      floatingActionButton: dataIuran.isEmpty
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
                    await createAndUploadPdf();
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
}
Widget _buildTableHeadershowDialog(String text, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 6),
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.blueGrey,
          ),
        ],
      ),
    ),
  );
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
