import 'dart:ui';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:iuran_rt_web/screens/histori_transaksi.dart';
import 'package:iuran_rt_web/screens/histori_transaksi_belum_lunas.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

import 'package:iuran_rt_web/url.dart';

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

class RekapIuranWargaPage extends StatefulWidget {
  @override
  _RekapIuranWargaPageState createState() => _RekapIuranWargaPageState();
}

class _RekapIuranWargaPageState extends State<RekapIuranWargaPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> dataIuran = [];
  bool isLoading = false;
  int currentPage = 0;
  int rowsPerPage = 10;
  double totalSaldoLunas = 0;
  double totalSaldoBelumLunas = 0;
  double totalSaldoKeu = 0;
  double hasilAkhir = 0;
  String selectedMonth = 'Tahun';
  String monthNum = '';
  List<String> alamatKavlingList = [];
  String? filterAlamat;
  String alamat = "";
  String? currentYear;
  late List<String> yearList;
  String selectedMonthNumber = '';
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().year;
    yearList = List.generate(
      5,
      (index) => (now - index).toString(),
    );
    currentYear = yearList.first;

    fetchIuranData(tahun: currentYear);
  }

  Future<void> fetchIuranData(
      {String query = "", String bulan = "", String? tahun = ""}) async {
    setState(() {
      isLoading = true;
    });

    print("🔍 fetchIuranData dipanggil dengan:");
    print("➡️ query: $query");
    print("➡️ bulan: $bulan");
    print("➡️ filterAlamat: ${filterAlamat ?? 'Semua Alamat'}");

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listWarga.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'searchQuery': query,
        'id_rt': KodeRt.kodeRt,
        if (bulan.isNotEmpty) 'bulan': bulan,
        if (tahun!.isNotEmpty) 'tahun': tahun,
        'alamat_kavling': (filterAlamat == null || filterAlamat!.isEmpty)
            ? ''
            : filterAlamat!,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success') {
        final List<dynamic> allData = result['data'];

        alamatKavlingList = allData
            .map<String>((item) => item['alamat_kavling']?.toString() ?? '-')
            .toSet()
            .toList();

        List<dynamic> filteredData = allData;
        if (filterAlamat != null && filterAlamat!.isNotEmpty) {
          filteredData = allData
              .where((item) => item['alamat_kavling'] == filterAlamat)
              .toList();
        }

        double totalLunas = 0;
        double totalBelumLunas = 0;
        for (var item in filteredData) {
          final nominal = double.tryParse(
                item['nominal_iuran']
                        ?.toString()
                        .replaceAll(RegExp(r'[^0-9]'), '') ??
                    '0',
              ) ??
              0;

          if ((item['status'] ?? '').toUpperCase() == 'LUNAS') {
            totalLunas += nominal;
          } else if ((item['status'] ?? '').toUpperCase() == 'BELUM LUNAS') {
            totalBelumLunas += nominal;
          }
        }

        setState(() {
          dataIuran = filteredData;
          totalSaldoLunas = totalLunas;
          totalSaldoBelumLunas = totalBelumLunas;
          hasilAkhir = totalSaldoLunas - totalSaldoBelumLunas;
        });

        print(
            "✅ Data berhasil di-update untuk bulan: $bulan dan alamat: ${filterAlamat ?? 'Semua Alamat'}");
      } else {
        setState(() {
          dataIuran = [];
          alamatKavlingList = [];
          totalSaldoLunas = 0;
          totalSaldoBelumLunas = 0;
        });
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

  Future<void> createAndUploadPdf({
    required String selectedMonth,
    required String currentYear,
    required String namaRt,
    required String alamat,
    required double totalSaldoLunas,
    required double totalSaldoBelumLunas,
    required double hasilAkhir,
  }) async {
    final pdf = pw.Document();
    final String filterAlamat =
        (alamat == "null" || alamat.trim().isEmpty) ? "" : alamat;

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
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Ringkasan Transaksi Iuran Warga $filterAlamat $selectedMonth $currentYear',
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

                    // =====================
                    //         TABLE
                    // =====================
                    pw.Table(
                      border: pw.TableBorder.all(width: 1),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        // Baris Iuran Lunas
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Iuran Lunas',
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
                                '${_formatCurrency(totalSaldoLunas)}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),

                        // Baris Iuran Belum Lunas
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Iuran Belum Lunas',
                                style: pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${_formatCurrency(totalSaldoBelumLunas)}',
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

                        // Total
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                "Total",
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
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

              // =====================
              //         FOOTER
              // =====================
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
                  'Created by RT Digital',
                  style: const pw.TextStyle(
                    fontSize: 9,
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

    // =============================
    //           SAVE FILE
    // =============================
    if (kIsWeb) {
      final blob = html.Blob([encoded], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "Ringkasan Transaksi Iuran Warga $filterAlamat ${selectedMonth} $currentYear.pdf",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Ringkasan Transaksi Iuran Warga $filterAlamat ${selectedMonth} $currentYear.pdf";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);
    }
  }

  // Future<void> exportToExcel() async {
  //   final workbook = xlsio.Workbook();
  //   final sheet = workbook.worksheets[0];
  //   sheet.name = 'Data Iuran Warga';

  //   // ✅ Header
  //   List<String> headers = [
  //     'No Kavling',
  //     'Nama Pemilik',
  //     'Penghuni',
  //     'No. Telp Pemilik Rumah',
  //     'No. Telp Penghuni',
  //     'Nama Iuran',
  //     'Nominal Iuran',
  //     'Status',
  //     'Tanggal Jatuh Tempo',
  //     'Kode COA'
  //   ];

  //   for (int i = 0; i < headers.length; i++) {
  //     final cell = sheet.getRangeByIndex(1, i + 1);
  //     cell.setText(headers[i]);
  //     cell.cellStyle.bold = true;
  //     cell.cellStyle.wrapText = true;

  //     cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  //   }

  //   // ✅ Data Rows
  //   for (int i = 0; i < dataIuran.length; i++) {
  //     final row = i + 2;
  //     final item = dataIuran[i];

  //     List<String> rowData = [
  //       item['no_kavling'] ?? '-',
  //       item['nama_pemilik_rumah'] ?? '-',
  //       item['nama_penanggung_jawab'] ?? '-',
  //       item['no_telpon_pemilik'] ?? '-',
  //       item['no_telpon_penanggung_jawab'] ?? '-',
  //       item['nama_iuran'] ?? '-',
  //       item['nominal_iuran'] ?? '-',
  //       item['status'] ?? '-',
  //       item['batas_pembayaran'] ?? '-',
  //       item['coa'] ?? '-'
  //     ];

  //     for (int col = 0; col < rowData.length; col++) {
  //       final cell = sheet.getRangeByIndex(row, col + 1);
  //       cell.setText(rowData[col]);
  //       cell.cellStyle.wrapText = true;

  //       // Tambahkan border untuk data
  //       cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  //     }
  //   }

  //   // ✅ Total Iuran
  //   double totalIuran = 0;
  //   for (var item in dataIuran) {
  //     final nominal = double.tryParse(item['nominal_iuran']
  //                 ?.toString()
  //                 .replaceAll(RegExp(r'[^0-9]'), '') ??
  //             '0') ??
  //         0;
  //     totalIuran += nominal;
  //   }

  //   final totalRow = dataIuran.length + 3;

  //   sheet.getRangeByIndex(totalRow, 6).setText('Total');
  //   sheet.getRangeByIndex(totalRow, 6).cellStyle.bold = true;

  //   final totalCell = sheet.getRangeByIndex(totalRow, 7);
  //   totalCell.setNumber(totalIuran);
  //   totalCell.cellStyle.bold = true;
  //   totalCell.numberFormat = r'"Rp"#,##0';

  //   // ✅ Auto-fit semua kolom
  //   for (int i = 1; i <= headers.length; i++) {
  //     sheet.autoFitColumn(i);
  //   }

  //   // ✅ Simpan file
  //   final List<int> bytes = workbook.saveAsStream();
  //   workbook.dispose();

  //   if (kIsWeb) {
  //     final blob = html.Blob([Uint8List.fromList(bytes)],
  //         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  //     final url = html.Url.createObjectUrlFromBlob(blob);
  //     final anchor = html.AnchorElement(href: url)
  //       ..setAttribute("download", "Laporan Transaksi Iuran Warga.xlsx")
  //       ..click();
  //     html.Url.revokeObjectUrl(url);
  //   } else {
  //     final directory = await getApplicationDocumentsDirectory();
  //     final path = "${directory.path}/Laporan Transaksi Iuran Warga.xlsx";
  //     final file = File(path);
  //     await file.writeAsBytes(bytes, flush: true);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Data berhasil diexport ke $path')),
  //     );
  //   }
  // }
  Future<void> exportToExcel({
    required String alamat,
  }) async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Ringkasan Transaksi Iuran Warga'];

    // HEADER UTAMA
    sheetObject.appendRow(['Keterangan', 'Saldo']);
    sheetObject.appendRow(['PENDAPATAN', '']);

    sheetObject
        .appendRow(['Total Pendapatan', _formatCurrencyTotal(totalSaldoLunas)]);
    sheetObject.appendRow(['', '']);

    // --- PENGELUARAN ---
    sheetObject.appendRow(['PENGELUARAN', '']);

    sheetObject.appendRow(
        ['Total Pengeluaran', _formatCurrencyTotal(totalSaldoBelumLunas)]);
    sheetObject.appendRow(['', '']);
    sheetObject.appendRow([
      "Total",
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
            "Ringkasan Transaksi Iuran Warga ${alamat} ${selectedMonth} $currentYear.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Ringkasan Transaksi Iuran Warga ${alamat} ${selectedMonth} $currentYear.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Data berhasil diexport ke $filePath')),
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                          'Laporan Transaksi Iuran Warga',
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
            const SizedBox(height: 10),
       DropdownButton<String>(
  value: (() {
    final allItems = [
      'Semua Alamat',
      ...alamatKavlingList,
    ];

    if (filterAlamat == null ||
        filterAlamat!.isEmpty ||
        !allItems.contains(filterAlamat)) {
      return 'Semua Alamat';
    }

    return filterAlamat;
  })(),

  items: [
    const DropdownMenuItem<String>(
      value: 'Semua Alamat',
      child: Text('Semua Alamat'),
    ),

    ...alamatKavlingList.toSet().map((alamat) {
      return DropdownMenuItem<String>(
        value: alamat,
        child: Text(alamat),
      );
    }).toList(),
  ],

  onChanged: (value) {
    setState(() {
      filterAlamat =
          (value == 'Semua Alamat') ? '' : value!;
    });

    fetchIuranData(
      bulan: selectedMonthNumber,
      tahun: currentYear,
    );
  },
),

            const SizedBox(height: 8),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _buildMonthButton(
                    'Semua',
                    isSelected: selectedMonth.isEmpty,
                    onPressed: () {
                      setState(() {
                        selectedMonth = '';
                        selectedMonthNumber = '';
                      });

                      fetchIuranData(
                        tahun: currentYear,
                      );
                    },
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

                    return _buildMonthButton(
                      monthNames[index],
                      isSelected: selectedMonth == monthNames[index],
                      onPressed: () {
                        setState(() {
                          selectedMonth = monthNames[index];
                          selectedMonthNumber = monthNumber;
                        });

                        // 🔑 filter bulan + tahun
                      fetchIuranData(
  bulan: selectedMonthNumber,
  tahun: currentYear,
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

  fetchIuranData(
    bulan: selectedMonthNumber,
    tahun: currentYear,
  );
},
                ),
              ],
            ),

            SizedBox(height: 8),
            SingleChildScrollView(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataIuran.isEmpty
                      ? const Center(child: Text('Tidak ada data Transaksi'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                          
                            hasilAkhir = totalSaldoLunas - totalSaldoBelumLunas;
                            return buildRingkasanKeuanganMobile(
                                nomLunas: totalSaldoLunas,
                                nomBelumLunas: totalSaldoBelumLunas,
                                hasilAkhir: hasilAkhir,
                                title:
                                    'Ringkasan Transaksi Iuran Warga $selectedMonth $currentYear',
                                numberMonth: selectedMonthNumber,
                                month: selectedMonth,
                                year: currentYear.toString(),
                                alamatKavling:
                                    (alamat == "") ? "Semua Kavling" : alamat);
                          },
                        ),
            ),

            // 🔹 Pagination
          ],
        ),
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
                    await createAndUploadPdf(
                        currentYear: currentYear.toString(),
                        selectedMonth: selectedMonth,
                        namaRt: KodeRt.namaRt,
                        totalSaldoBelumLunas: totalSaldoBelumLunas,
                        totalSaldoLunas: totalSaldoLunas,
                        hasilAkhir: hasilAkhir,
                        alamat: (alamat == "") ? "Semua Alamat" : alamat);
                  },
                ),
                SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Unduh Excel',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    exportToExcel(
                        alamat: (alamat == "") ? "Semua Alamat" : alamat);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🔹 Header
          Center(
            child: Container(
              width: 1200,
              height: 80,
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 226, 226),
                border: Border.all(
                  color: const Color.fromARGB(255, 58, 112, 50),
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
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.black),
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
                      const Text(
                        'Laporan Transaksi Iuran Warga',
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

          const SizedBox(height: 16),

          DropdownButton<String>(
            value: (() {
              final allItems = [
                'Semua Alamat',
                ...alamatKavlingList,
              ];

              if (filterAlamat == null ||
                  filterAlamat!.isEmpty ||
                  !allItems.contains(filterAlamat)) {
                return 'Semua Alamat';
              }

              return filterAlamat;
            })(),
            items: [
              const DropdownMenuItem<String>(
                value: 'Semua Alamat',
                child: Text('Semua Alamat'),
              ),
              ...alamatKavlingList.toSet().map((alamat) {
                return DropdownMenuItem<String>(
                  value: alamat,
                  child: Text(alamat),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                filterAlamat = (value == 'Semua Alamat') ? '' : value!;
              });

              fetchIuranData(
                bulan: selectedMonthNumber,
                tahun: currentYear,
              );
            },
          ),

          const SizedBox(height: 8),
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

                      fetchIuranData(
                        tahun: currentYear,
                      );
                    },
                    child: const Text(
                      'Tahun',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // ==========================
                  // TOMBOL BULAN
                  // ==========================
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

                        fetchIuranData(
                          bulan: selectedMonthNumber,
                          tahun: currentYear,
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

                  fetchIuranData(
                    bulan: selectedMonthNumber,
                    tahun: currentYear,
                  );
                },
              ),
            ],
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : dataIuran.isEmpty
                    ? const Center(child: Text('Tidak ada data Transaksi'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          hasilAkhir = totalSaldoLunas - totalSaldoBelumLunas;
                          return buildRingkasanKeuangan(
                            nomLunas: totalSaldoLunas,
                            nomBelumLunas: totalSaldoBelumLunas,
                            hasilAkhir: hasilAkhir,
                            title:
                                'Ringkasan Transaksi Iuran Warga $selectedMonth $currentYear',
                            numberMonth: selectedMonthNumber,
                            month: selectedMonth,
                            year: currentYear.toString(),
                            alamatKavling:
                                (alamat == "") ? "Semua Kavling" : alamat,
                          );
                        },
                      ),
          ),

          const SizedBox(height: 10),
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
                    await createAndUploadPdf(
                        currentYear: currentYear.toString(),
                        selectedMonth: selectedMonth,
                        namaRt: KodeRt.namaRt,
                        totalSaldoBelumLunas: totalSaldoBelumLunas,
                        totalSaldoLunas: totalSaldoLunas,
                        hasilAkhir: hasilAkhir,
                        alamat: (alamat == "") ? "Semua Alamat" : alamat);
                  },
                ),
                SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Unduh Excel',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    exportToExcel(
                        alamat: (alamat == "") ? "Semua Alamat" : alamat);
                  },
                ),
              ],
            ),
    );
  }
}

Widget buildRingkasanKeuangan(
    {required double nomLunas,
    required double nomBelumLunas,
    required double hasilAkhir,
    required String title,
    required String numberMonth,
    required String month,
    required String year,
    required String alamatKavling}) {
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
                    'Lunas',
                    '',
                    _formatCurrency(nomLunas),
                    onTitleTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriTransaksiPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                            alamatKavling: alamatKavling,
                            totalBelumLunas: nomLunas,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCustomRow(
                    'Belum Lunas',
                    '',
                    _formatCurrency(nomBelumLunas),
                    onTitleTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriTransaksiBelumPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                            alamatKavling: alamatKavling,
                            totalBelumLunas: nomBelumLunas,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(thickness: 1.5, color: Colors.grey),
                  _buildRowMobile(
                    title: 'Total',
                    value: hasilAkhir,
                    isBold: true,
                    valueColor: isDefisit ? Colors.red : Colors.black,
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
    if (val is double) return "${val.toStringAsFixed(0)}";
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
  required double nomLunas,
  required double nomBelumLunas,
  required double hasilAkhir,
  required String title,
  required String numberMonth,
  required String month,
  required String year,
  required String alamatKavling,
}) {
  bool isDefisit = hasilAkhir < 0;

  return LayoutBuilder(
    builder: (context, constraints) {
      double maxWidth = constraints.maxWidth > 600 ? 500 : constraints.maxWidth;

      double titleSize = constraints.maxWidth < 400 ? 14 : 16;
      double valueSize = constraints.maxWidth < 400 ? 14 : 15;

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
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRowMobile(
                    title: 'Lunas',
                    value: nomLunas,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriTransaksiPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                            alamatKavling: alamatKavling,
                            totalBelumLunas: nomLunas,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildRowMobile(
                    title: 'Belum Lunas',
                    value: nomBelumLunas,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriTransaksiBelumPage(
                            numberMonth: numberMonth,
                            month: month,
                            year: year,
                            alamatKavling: alamatKavling,
                            totalBelumLunas: nomBelumLunas,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildRowMobile(
                    title: 'Total',
                    value: hasilAkhir,
                    isBold: true,
                    valueColor: isDefisit ? Colors.red : Colors.black,
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
  required double value,
  bool isBold = false,
  Color valueColor = Colors.black,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: onTap != null ? Colors.blue : Colors.black87,
            decoration: onTap != null ? TextDecoration.underline : null,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(value),
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

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
