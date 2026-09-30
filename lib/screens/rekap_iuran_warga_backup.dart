import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/histori_transaksi.dart';
import 'package:iuran_rt_web/screens/histori_transaksi_belum_lunas.dart';
import 'package:path_provider/path_provider.dart';
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
  String monthNum = 'Tahun';
  List<String> alamatKavlingList = [];
  String? selectedAlamatKavling;
  @override
  void initState() {
    super.initState();
    fetchIuranDataBelumLunas();
    fetchIuranDataLunas();
  }

  Future<void> fetchIuranDataBelumLunas([String query = ""]) async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/histori_belum_lunas.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'searchQuery': query,
        'id_rt': KodeRt.kodeRt,
        'alamat_kavling': selectedAlamatKavling ?? '',
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        final List<dynamic> data = result['data'];

        // 🔹 Ambil alamat_kavling unik dari data
        final uniqueAlamat = data
            .map((item) => item['alamat_kavling'].toString())
            .toSet()
            .toList()
          ..sort();

        double totalBelumLunas = data.fold(0, (sum, item) {
          final rawSaldo = item['nominal_iuran'].toString().replaceAll('.', '');
          final saldo = double.tryParse(rawSaldo) ?? 0;
          return sum + saldo;
        });

        setState(() {
          dataIuran = data;
          totalSaldoBelumLunas = totalBelumLunas;
          alamatKavlingList = uniqueAlamat;
        });
      } else {
        setState(() {
          dataIuran = [];
          alamatKavlingList = [];
        });
        Fluttertoast.showToast(
          msg: "Data Tidak Ditemukan",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.black38,
          textColor: Colors.white,
        );
      }
    } else {
      setState(() {
        dataIuran = [];
        alamatKavlingList = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchIuranDataLunas([String query = ""]) async {
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
        'alamat_kavling': selectedAlamatKavling ?? '',
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        dataIuran = result['data'];
        final uniqueAlamat = dataIuran
            .map((item) => item['r_alamat_kavling'].toString())
            .toSet()
            .toList()
          ..sort();
        double totalLunas = dataIuran.fold(0, (sum, item) {
          final rawSaldo = item['r_nominal_iuran'].toString().replaceAll('.', '');
          final saldo = double.tryParse(rawSaldo) ?? 0;
          return sum + saldo;
        });

        setState(() {
          dataIuran = result['data'];
          totalSaldoLunas = totalLunas;
          alamatKavlingList = uniqueAlamat;
        });
      } else {
        setState(() {
          dataIuran = [];
          alamatKavlingList = [];
        });
        Fluttertoast.showToast(
            msg: "Data Tidak Ditemukan",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.TOP,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.black38,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    } else {
      setState(() {
        dataIuran = [];
        alamatKavlingList = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }
  // Future<void> fetchIuranData([String query = ""]) async {
  //   if (query.trim().isEmpty) return;

  //   setState(() {
  //     isLoading = true;
  //     currentPage = 0;
  //   });

  //   final response = await http.post(
  //     Uri.parse('${ApiUrls.baseUrl}/listWarga.php'),
  //     headers: {
  //       'Content-Type': 'application/x-www-form-urlencoded',
  //     },
  //     body: {'searchQuery': query, 'id_rt': KodeRt.kodeRt},
  //   );

  //   if (response.statusCode == 200) {
  //     final result = jsonDecode(response.body);
  //     if (result['result'] == 'success') {
  //       setState(() {
  //         dataIuran = result['data'];
  //       });
  //     } else {
  //       setState(() {
  //         dataIuran = [];
  //       });
  //       Fluttertoast.showToast(
  //         msg: "Data Tidak Ditemukan",
  //         toastLength: Toast.LENGTH_SHORT,
  //         gravity: ToastGravity.TOP,
  //       );
  //     }
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Gagal mengambil data dari server')),
  //     );
  //   }

  //   setState(() {
  //     isLoading = false;
  //   });
  // }

  Future<void> exportToExcel() async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Data Iuran Warga';

    // ✅ Header
    List<String> headers = [
      'No Kavling',
      'Nama Pemilik',
      'Penghuni',
      'No. Telp Pemilik Rumah',
      'No. Telp Penghuni',
      'Nama Iuran',
      'Nominal Iuran',
      'Status',
      'Tanggal Jatuh Tempo',
      'Kode COA'
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.wrapText = true;

      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }

    // ✅ Data Rows
    for (int i = 0; i < dataIuran.length; i++) {
      final row = i + 2;
      final item = dataIuran[i];

      List<String> rowData = [
        item['no_kavling'] ?? '-',
        item['nama_pemilik_rumah'] ?? '-',
        item['nama_penanggung_jawab'] ?? '-',
        item['no_telpon_pemilik'] ?? '-',
        item['no_telpon_penanggung_jawab'] ?? '-',
        item['nama_iuran'] ?? '-',
        item['nominal_iuran'] ?? '-',
        item['status'] ?? '-',
        item['batas_pembayaran'] ?? '-',
        item['coa'] ?? '-'
      ];

      for (int col = 0; col < rowData.length; col++) {
        final cell = sheet.getRangeByIndex(row, col + 1);
        cell.setText(rowData[col]);
        cell.cellStyle.wrapText = true;

        // Tambahkan border untuk data
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
    }

    // ✅ Total Iuran
    double totalIuran = 0;
    for (var item in dataIuran) {
      final nominal = double.tryParse(item['nominal_iuran']
                  ?.toString()
                  .replaceAll(RegExp(r'[^0-9]'), '') ??
              '0') ??
          0;
      totalIuran += nominal;
    }

    final totalRow = dataIuran.length + 3;

    sheet.getRangeByIndex(totalRow, 6).setText('Total');
    sheet.getRangeByIndex(totalRow, 6).cellStyle.bold = true;

    final totalCell = sheet.getRangeByIndex(totalRow, 7);
    totalCell.setNumber(totalIuran);
    totalCell.cellStyle.bold = true;
    totalCell.numberFormat = r'"Rp"#,##0';

    // ✅ Auto-fit semua kolom
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    // ✅ Simpan file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Laporan Transaksi Iuran Warga.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Laporan Transaksi Iuran Warga.xlsx";
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $path')),
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
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          'Laporan Iuran warga',
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
            // TextField(
            //   inputFormatters: [LengthLimitingTextInputFormatter(10)],
            //   controller: searchController,
            //   decoration: InputDecoration(
            //     labelText: 'Cari Berdasarkan No Kavling',
            //     labelStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
            //     prefixIcon: const Icon(Icons.search, color: Color(0xFF3D8D7A)),
            //     filled: true,
            //     fillColor: Colors.grey[100],
            //     contentPadding:
            //         const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            //     enabledBorder: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(12),
            //       borderSide:
            //           BorderSide(color: Colors.grey.shade400, width: 1.2),
            //     ),
            //     focusedBorder: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(12),
            //       borderSide:
            //           const BorderSide(color: Color(0xFF3D8D7A), width: 1.8),
            //     ),
            //   ),
            //   onChanged: (value) {
            //     fetchIuranDataBelumLunas(value);
            //     fetchIuranDataLunas(value);
            //   },
            // ),
            if (alamatKavlingList.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: selectedAlamatKavling,
                  isExpanded: true,
                  hint: const Text("Pilih Alamat Kavling"),
                  onChanged: (value) {
                    setState(() {
                      selectedAlamatKavling = value;
                    });
                    fetchIuranDataBelumLunas(searchController
                        .text); 
                    fetchIuranDataLunas(searchController.text);
                  },
                  items: alamatKavlingList.map((String alamat) {
                    return DropdownMenuItem<String>(
                      value: alamat,
                      child: Text(alamat),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // 🔹 Filter huruf A–Z (dibuat scrollable horizontal)
            // SizedBox(
            //   height: 50,
            //   child: ListView.builder(
            //     scrollDirection: Axis.horizontal,
            //     itemCount: 26,
            //     itemBuilder: (context, index) {
            //       String letter = String.fromCharCode(65 + index);
            //       return Padding(
            //         padding: const EdgeInsets.symmetric(horizontal: 4),
            //         child: ElevatedButton(
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Colors.white,
            //             foregroundColor: const Color(0xFF3D8D7A),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(8),
            //               side: const BorderSide(color: Color(0xFF3D8D7A)),
            //             ),
            //           ),
            //           onPressed: () {
            //             searchController.text = letter;
            //             fetchIuranData(letter);
            //           },
            //           child: Text(letter,
            //               style: const TextStyle(fontWeight: FontWeight.bold)),
            //         ),
            //       );
            //     },
            //   ),
            // ),

            // const SizedBox(height: 12),

            // 🔹 Konten Data
            // Expanded(
            //   child: isLoading
            //       ? const Center(child: CircularProgressIndicator())
            //       : dataIuran.isEmpty
            //           ? const Center(
            //               child: Text(
            //                 'Silakan cari berdasarkan No Kavling atau tekan tombol A-Z',
            //                 textAlign: TextAlign.center,
            //               ),
            //             )
            //           : LayoutBuilder(
            //             builder: (context, constraints) {
            //               return ScrollConfiguration(
            //                 behavior: ScrollConfiguration.of(context).copyWith(
            //                   scrollbars: true,
            //                   overscroll: false,
            //                   dragDevices: {
            //                     PointerDeviceKind.touch,
            //                     PointerDeviceKind.mouse,
            //                     PointerDeviceKind.trackpad,
            //                   },
            //                 ),
            //                 child: SingleChildScrollView(
            //                   scrollDirection: Axis.horizontal,
            //                   child: Column(
            //                     children: [
            //                       // HEADER TETAP
            //                       Table(
            //                         border: TableBorder.all(
            //                           color: Colors.grey.shade600,
            //                           width: 1,
            //                         ),
            //                         columnWidths: const {
            //                           0: FixedColumnWidth(65),
            //                           1: FixedColumnWidth(130),
            //                           2: FixedColumnWidth(130),
            //                           3: FixedColumnWidth(120),
            //                           4: FixedColumnWidth(120),
            //                           5: FixedColumnWidth(130),
            //                           6: FixedColumnWidth(130),
            //                           7: FixedColumnWidth(80),
            //                           8: FixedColumnWidth(150),
            //                           9: FixedColumnWidth(80),
            //                         },
            //                         children: [
            //                           TableRow(
            //                             decoration: BoxDecoration(
            //                               color: Colors.blueGrey.shade100,
            //                             ),
            //                             children: [
            //                               _buildTableHeader('No Kavling'),
            //                               _buildTableHeader('Pemilik Rumah'),
            //                               _buildTableHeader('Penghuni'),
            //                               _buildTableHeader(
            //                                   'No Telpon Pemilik Rumah'),
            //                               _buildTableHeader(
            //                                   'No Telpon Penghuni'),
            //                               _buildTableHeader('Nama Iuran'),
            //                               _buildTableHeader('Nominal Iuran'),
            //                               _buildTableHeader('Status'),
            //                               _buildTableHeader(
            //                                   'Tanggal Jatuh Tempo'),
            //                               _buildTableHeader('Kode COA'),
            //                             ],
            //                           ),
            //                         ],
            //                       ),

            //                       Expanded(
            //                         child: SingleChildScrollView(
            //                           scrollDirection: Axis.vertical,
            //                           child: Table(
            //                             defaultVerticalAlignment:
            //                                 TableCellVerticalAlignment.middle,
            //                             border: TableBorder.all(
            //                               color: Colors.grey.shade600,
            //                               width: 1,
            //                             ),
            //                             columnWidths: const {
            //                               0: FixedColumnWidth(65),
            //                               1: FixedColumnWidth(130),
            //                               2: FixedColumnWidth(130),
            //                               3: FixedColumnWidth(120),
            //                               4: FixedColumnWidth(120),
            //                               5: FixedColumnWidth(130),
            //                               6: FixedColumnWidth(130),
            //                               7: FixedColumnWidth(80),
            //                               8: FixedColumnWidth(150),
            //                               9: FixedColumnWidth(80),
            //                             },
            //                             children: paginatedData.map((item) {
            //                               return TableRow(
            //                                 children: [
            //                                   _buildTableCell(
            //                                       item['no_kavling']),
            //                                   _buildTableCell(
            //                                       item['nama_pemilik_rumah']),
            //                                   _buildTableCell(
            //                                       item['nama_penghuni']),
            //                                   _buildTableCell(item[
            //                                       'no_telpon_pemilik_rumah']),
            //                                   _buildTableCell(item[
            //                                       'no_telpon_penanggung_jawab']),
            //                                   _buildTableCell(
            //                                       item['nama_iuran']),
            //                                   _buildTableCell(
            //                                       item['nominal_iuran']),
            //                                   _buildTableCell(item['status']),
            //                                   _buildTableCell(
            //                                       item['batas_pembayaran']),
            //                                   _buildTableCell(item['coa']),
            //                                 ],
            //                               );
            //                             }).toList(),
            //                           ),
            //                         ),
            //                       ),
            //                     ],
            //                   ),
            //                 ),
            //               );
            //             },
            //           ),

            // ),
            Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dataIuran.isEmpty
                        ? const Center(
                            child: Text('Tidak ada data Iuran Warga'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final currentYear = DateTime.now().year;
                              hasilAkhir =
                                  totalSaldoLunas - totalSaldoBelumLunas;
                              return buildRingkasanKeuangan(
                                  nomLunas: totalSaldoLunas,
                                  nomBelumLunas: totalSaldoBelumLunas,
                                  hasilAkhir: hasilAkhir,
                                  title:
                                      'Ringkasan Iuran Warga $selectedMonth $currentYear\nAlamat Kavling: ',
                                  numberMonth: monthNum,
                                  month: selectedMonth,
                                  year: currentYear.toString());
                            },
                          )),
            // 🔹 Pagination
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     ElevatedButton(
            //       onPressed: currentPage > 0
            //           ? () => setState(() => currentPage--)
            //           : null,
            //       child: const Text('Previous'),
            //     ),
            //     const SizedBox(width: 16),
            //     Text(
            //       'Halaman ${currentPage + 1} dari ${((dataIuran.length - 1) / rowsPerPage).ceil()}',
            //       style: const TextStyle(fontSize: 14),
            //     ),
            //     const SizedBox(width: 16),
            //     ElevatedButton(
            //       onPressed: (currentPage + 1) * rowsPerPage < dataIuran.length
            //           ? () => setState(() => currentPage++)
            //           : null,
            //       child: const Text('Next'),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3D8D7A),
        onPressed: exportToExcel,
        child: SvgPicture.asset(
          'assets/images/MicrosoftExcelLogo.svg',
          color: Colors.white,
          width: 28,
          height: 28,
        ),
        tooltip: 'Export to Excel',
      ),
    );
  }

// 🔹 Helper kecil untuk menampilkan teks data
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'Laporan Transaksi Iuran warga',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Align(
              //   alignment: Alignment.center,
              //   child: Container(
              //     width: 500,
              //     child: TextField(
              //       inputFormatters: [LengthLimitingTextInputFormatter(10)],
              //       controller: searchController,
              //       decoration: InputDecoration(
              //         labelText: 'Cari Berdasarkan No Kavling',
              //         labelStyle: TextStyle(
              //           color: Colors.grey[700],
              //           fontSize: 14,
              //         ),
              //         prefixIcon: Icon(Icons.search, color: Color(0xFF3D8D7A)),
              //         filled: true,
              //         fillColor: Colors.grey[100],
              //         contentPadding:
              //             EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              //         enabledBorder: OutlineInputBorder(
              //           borderRadius: BorderRadius.circular(12),
              //           borderSide: BorderSide(
              //             color: Colors.grey.shade400,
              //             width: 1.2,
              //           ),
              //         ),
              //         focusedBorder: OutlineInputBorder(
              //           borderRadius: BorderRadius.circular(12),
              //           borderSide: BorderSide(
              //             color: Color(0xFF3D8D7A),
              //             width: 1.8,
              //           ),
              //         ),
              //       ),
              //       onChanged: (value) {
              //         fetchIuranDataBelumLunas(value);
              //         fetchIuranDataLunas();
              //       },
              //     ),
              //   ),
              // ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: selectedAlamatKavling,
                  isExpanded: true,
                  hint: const Text("Pilih Alamat Kavling"),
                  onChanged: (value) {
                    setState(() {
                      selectedAlamatKavling = value;
                    });
                    fetchIuranDataBelumLunas(searchController
                        .text); 
                    fetchIuranDataLunas(searchController.text);
                  },
                  items: alamatKavlingList.map((String alamat) {
                    return DropdownMenuItem<String>(
                      value: alamat,
                      child: Text(alamat),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Center(
              //   child: Container(
              //     padding: EdgeInsets.all(12),
              //     decoration: BoxDecoration(
              //       color: Color(0xFF3D8D7A),
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: Wrap(
              //       spacing: 8,
              //       runSpacing: 8,
              //       children: List.generate(26, (index) {
              //         String letter = String.fromCharCode(65 + index);
              //         return ElevatedButton(
              //           style: ElevatedButton.styleFrom(
              //             backgroundColor: Colors.white,
              //             foregroundColor: Color(0xFF3D8D7A),
              //             shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(8),
              //             ),
              //           ),
              //           onPressed: () {
              //             searchController.text = letter;
              //             fetchIuranData(letter);
              //           },
              //           child: Text(
              //             letter,
              //             style: TextStyle(fontWeight: FontWeight.bold),
              //           ),
              //         );
              //       }),
              //     ),
              //   ),
              // ),
            ],
          ),
          // SizedBox(height: 16),
          // Expanded(
          //   child: (searchController.text.isEmpty || dataIuran.isEmpty)
          //       ? Center(
          //           child: Text(
          //               'Silakan cari berdasarkan No Kavling atau tekan tombol A-Z'),
          //         )
          //       : isLoading
          //           ? Center(child: CircularProgressIndicator())
          //           : LayoutBuilder(
          //               builder: (context, constraints) {
          //                 return ScrollConfiguration(
          //                   behavior: ScrollConfiguration.of(context).copyWith(
          //                     scrollbars: true,
          //                     overscroll: false,
          //                     dragDevices: {
          //                       PointerDeviceKind.touch,
          //                       PointerDeviceKind.mouse,
          //                       PointerDeviceKind.trackpad,
          //                     },
          //                   ),
          //                   child: SingleChildScrollView(
          //                     scrollDirection: Axis.horizontal,
          //                     child: Column(
          //                       children: [
          //                         // HEADER TETAP
          //                         Table(
          //                           border: TableBorder.all(
          //                             color: Colors.grey.shade600,
          //                             width: 1,
          //                           ),
          //                           columnWidths: const {
          //                             0: FixedColumnWidth(65),
          //                             1: FixedColumnWidth(130),
          //                             2: FixedColumnWidth(130),
          //                             3: FixedColumnWidth(120),
          //                             4: FixedColumnWidth(120),
          //                             5: FixedColumnWidth(130),
          //                             6: FixedColumnWidth(130),
          //                             7: FixedColumnWidth(80),
          //                             8: FixedColumnWidth(150),
          //                             9: FixedColumnWidth(80),
          //                           },
          //                           children: [
          //                             TableRow(
          //                               decoration: BoxDecoration(
          //                                 color: Colors.blueGrey.shade100,
          //                               ),
          //                               children: [
          //                                 _buildTableHeader('No Kavling'),
          //                                 _buildTableHeader('Pemilik Rumah'),
          //                                 _buildTableHeader('Penghuni'),
          //                                 _buildTableHeader(
          //                                     'No Telpon Pemilik Rumah'),
          //                                 _buildTableHeader(
          //                                     'No Telpon Penghuni'),
          //                                 _buildTableHeader('Nama Iuran'),
          //                                 _buildTableHeader('Nominal Iuran'),
          //                                 _buildTableHeader('Status'),
          //                                 _buildTableHeader(
          //                                     'Tanggal Jatuh Tempo'),
          //                                 _buildTableHeader('Kode COA'),
          //                               ],
          //                             ),
          //                           ],
          //                         ),

          //                         Expanded(
          //                           child: SingleChildScrollView(
          //                             scrollDirection: Axis.vertical,
          //                             child: Table(
          //                               defaultVerticalAlignment:
          //                                   TableCellVerticalAlignment.middle,
          //                               border: TableBorder.all(
          //                                 color: Colors.grey.shade600,
          //                                 width: 1,
          //                               ),
          //                               columnWidths: const {
          //                                 0: FixedColumnWidth(65),
          //                                 1: FixedColumnWidth(130),
          //                                 2: FixedColumnWidth(130),
          //                                 3: FixedColumnWidth(120),
          //                                 4: FixedColumnWidth(120),
          //                                 5: FixedColumnWidth(130),
          //                                 6: FixedColumnWidth(130),
          //                                 7: FixedColumnWidth(80),
          //                                 8: FixedColumnWidth(150),
          //                                 9: FixedColumnWidth(80),
          //                               },
          //                               children: paginatedData.map((item) {
          //                                 return TableRow(
          //                                   children: [
          //                                     _buildTableCell(
          //                                         item['no_kavling']),
          //                                     _buildTableCell(
          //                                         item['nama_pemilik_rumah']),
          //                                     _buildTableCell(
          //                                         item['nama_penghuni']),
          //                                     _buildTableCell(item[
          //                                         'no_telpon_pemilik_rumah']),
          //                                     _buildTableCell(item[
          //                                         'no_telpon_penanggung_jawab']),
          //                                     _buildTableCell(
          //                                         item['nama_iuran']),
          //                                     _buildTableCell(
          //                                         item['nominal_iuran']),
          //                                     _buildTableCell(item['status']),
          //                                     _buildTableCell(
          //                                         item['batas_pembayaran']),
          //                                     _buildTableCell(item['coa']),
          //                                   ],
          //                                 );
          //                               }).toList(),
          //                             ),
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                   ),
          //                 );
          //               },
          //             ),
          // ),
          // SizedBox(height: 16),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     ElevatedButton(
          //       onPressed: currentPage > 0
          //           ? () {
          //               setState(() {
          //                 currentPage--;
          //               });
          //             }
          //           : null,
          //       child: Text('Previous'),
          //     ),
          //     SizedBox(width: 16),
          //     Text(
          //       'Halaman ${currentPage + 1} dari ${((dataIuran.length - 1) / rowsPerPage).ceil()}',
          //       style: TextStyle(fontSize: 16),
          //     ),
          //     SizedBox(width: 16),
          //     ElevatedButton(
          //       onPressed: (currentPage + 1) * rowsPerPage < dataIuran.length
          //           ? () {
          //               setState(() {
          //                 currentPage++;
          //               });
          //             }
          //           : null,
          //       child: Text('Next'),
          //     ),
          //   ],
          // ),
            Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dataIuran.isEmpty
                        ? const Center(
                            child: Text('Tidak ada data Iuran Warga'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final currentYear = DateTime.now().year;
                              hasilAkhir =
                                  totalSaldoLunas - totalSaldoBelumLunas;
                              return buildRingkasanKeuangan(
                                  nomLunas: totalSaldoLunas,
                                  nomBelumLunas: totalSaldoBelumLunas,
                                  hasilAkhir: hasilAkhir,
                                  title:
                                      'Ringkasan Iuran Warga $selectedMonth $currentYear\nAlamat Kavling: $selectedAlamatKavling',
                                  numberMonth: monthNum,
                                  month: selectedMonth,
                                  year: currentYear.toString());
                            },
                          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF3D8D7A),
        onPressed: exportToExcel,
        child: SvgPicture.asset(
          'assets/images/MicrosoftExcelLogo.svg',
          color: Colors.white,
          width: 30,
          height: 30,
        ),
        tooltip: 'Export to Excel',
      ),
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

Widget buildRingkasanKeuangan(
    {required double nomLunas,
    required double nomBelumLunas,
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
                    'Lunas',
                    '',
                    _formatCurrency(nomLunas),
                    onTitleTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriTransaksiPage(),
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
                          builder: (context) => HistoriTransaksiBelumPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(thickness: 1.5, color: Colors.grey),
                  _buildCustomRow(
                    'Total',
                    '',
                    _formatCurrency(hasilAkhir),
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
