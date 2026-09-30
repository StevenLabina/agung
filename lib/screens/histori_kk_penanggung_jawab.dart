import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:iuran_rt_web/menu_pilihan.dart';

import 'package:iuran_rt_web/screens/histori_kk_pemilik.dart';
import 'package:iuran_rt_web/url.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:universal_html/html.dart' as html;

class HistoriKkPenanggungJawabPage extends StatefulWidget {
  @override
  _HistoriKkPenanggungJawabPageState createState() =>
      _HistoriKkPenanggungJawabPageState();
}

class _HistoriKkPenanggungJawabPageState
    extends State<HistoriKkPenanggungJawabPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> historiKk = [];
  bool isLoading = false;
  int currentPage = 0;
  int rowsPerPage = 10;
  int get totalPages {
    if (historiKk.isEmpty) return 1;
    return (historiKk.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (historiKk.isEmpty) return [];

    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, historiKk.length);

    return historiKk.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    fetchIuranData();
  }

  Future<void> fetchIuranData([String query = ""]) async {
    setState(() {
      isLoading = true;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}historiKk.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'searchQuery': query,
        'id_rt': KodeRt.kodeRt,
        'kk': 'penanggung_jawab'
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success') {
        setState(() {
          historiKk = result['data'];
        });
      } else {
        setState(() {
          historiKk = [];
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
        historiKk = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Data KK Warga'];

    // Menambahkan header
    List<String> headers = [
      'No KK',
      'Nama Lengkap',
      'NIK',
      'Jenis Kelamin',
      'Tempat Lahir',
      'Tanggal Lahir',
      'Agama',
      'Pendidikan',
      'Jenis Pekerjaan'
    ];
    sheetObject.appendRow(headers);

    // Menambahkan data
    for (var item in historiKk) {
      final lokasi = [
        item['tanggal_lahir_provinsi'],
        item['tanggal_lahir_kota'],
        item['tanggal_lahir_kecamatan'],
      ]
          .where((e) =>
              e != null &&
              e.toString().trim().isNotEmpty &&
              e.toString() != '-')
          .map((e) => e.toString())
          .toList();
      List<String> row = [
        item['no_kk'] ?? '-',
        item['nama_lengkap'] ?? '-',
        item['nik'] ?? '-',
        item['jenis_kelamin'] ?? '-',
        lokasi.isEmpty ? '-' : lokasi.join(', '),
        item['tanggal_lahir'] ?? '-',
        item['agama'] ?? '-',
        item['pendidikan'] ?? '-',
        item['jenis_pekerjaan'] ?? '-',
      ];
      sheetObject.appendRow(row);
    }

    // Menyimpan file Excel untuk Web atau Mobile/Desktop
    if (kIsWeb) {
      // Convert Excel ke Uint8List dan trigger download file
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Histori KK Penghuni Rumah.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Histori KK Penghuni Rumah.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
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
                        'Rekap KK Warga (Penghuni)',
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
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 500,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Cari Berdasarkan No KK...',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF3D8D7A), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) {
                  fetchIuranData(value);
                },
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            width: 567,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HistoriKkPemilikPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'KK Pemilik Rumah',
                    style: TextStyle(
                      color: Color(0xFF3D8D7A),
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3D8D7A),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'KK Penghuni',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWideScreen = constraints.maxWidth > 800;
                      return SingleChildScrollView(
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
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3D8D7A),
                                  ),
                                  children: [
                                    _buildTableHeader('No KK'),
                                    _buildTableHeader('Pemilik Rumah'),
                                    _buildTableHeader('NIK'),
                                    _buildTableHeader('Jenis Kelamin'),
                                    _buildTableHeader('Tempat Lahir'),
                                    _buildTableHeader('Tanggal Lahir'),
                                    _buildTableHeader('Agama'),
                                    _buildTableHeader('Pendidikan'),
                                    _buildTableHeader('Jenis Pekerjaan'),
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
                                  },
                                  children: paginatedData.map((item) {
                                    return TableRow(
                                      children: [
                                        _buildTableCell(item['no_kk']),
                                        _buildTableCell(item['nama_lengkap']),
                                        _buildTableCell(item['nik']),
                                        _buildTableCell(item['jenis_kelamin']),
                                        _buildTableCell(
                                          (() {
                                            final lokasi = [
                                              item['tanggal_lahir_provinsi'],
                                              item['tanggal_lahir_kota'],
                                              item['tanggal_lahir_kecamatan'],
                                            ]
                                                .where((e) =>
                                                    e != null &&
                                                    e
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty &&
                                                    e != '-')
                                                .map((e) => e.toString())
                                                .toList();

                                            return lokasi.isEmpty
                                                ? '-'
                                                : lokasi.join(', ');
                                          })(),
                                        ),
                                        _buildTableCell(item['tanggal_lahir']),
                                        _buildTableCell(item['agama']),
                                        _buildTableCell(item['pendidikan']),
                                        _buildTableCell(
                                            item['jenis_pekerjaan']),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
           SizedBox(height: 12),
               paginatedData.isEmpty
              ? const SizedBox()
              : Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                     
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
                  onPressed: (currentPage + 1) * rowsPerPage < historiKk.length
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
                        'Rekap Kumpulan KK Warga (Penghuni)',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 500,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari Berdasarkan No KK...',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Color(0xFF3D8D7A), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (value) {
                      fetchIuranData(value);
                    },
                  ),
                ),
              ),
              SizedBox(width: 16), // Lebih rapi kalau kasih jarak 16
              Container(
                width: 567,
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HistoriKkPemilikPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'KK Pemilik Rumah',
                        style: TextStyle(
                          color: Color(0xFF3D8D7A),
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'KK Penghuni',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
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
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade100,
                                  ),
                                  children: [
                                    _buildTableHeader('No KK'),
                                    _buildTableHeader('Pemilik Rumah'),
                                    _buildTableHeader('NIK'),
                                    _buildTableHeader('Jenis Kelamin'),
                                    _buildTableHeader('Tempat Lahir'),
                                    _buildTableHeader('Tanggal Lahir'),
                                    _buildTableHeader('Agama'),
                                    _buildTableHeader('Pendidikan'),
                                    _buildTableHeader('Jenis Pekerjaan'),
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
                                  },
                                  children: paginatedData.map((item) {
                                    return TableRow(
                                      children: [
                                        _buildTableCell(item['no_kk']),
                                        _buildTableCell(item['nama_lengkap']),
                                        _buildTableCell(item['nik']),
                                        _buildTableCell(item['jenis_kelamin']),
                                        _buildTableCell(
                                          (() {
                                            final lokasi = [
                                              item['tanggal_lahir_provinsi'],
                                              item['tanggal_lahir_kota'],
                                              item['tanggal_lahir_kecamatan'],
                                            ]
                                                .where((e) =>
                                                    e != null &&
                                                    e
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty &&
                                                    e != '-')
                                                .map((e) => e.toString())
                                                .toList();

                                            return lokasi.isEmpty
                                                ? '-'
                                                : lokasi.join(', ');
                                          })(),
                                        ),
                                        _buildTableCell(item['tanggal_lahir']),
                                        _buildTableCell(item['agama']),
                                        _buildTableCell(item['pendidikan']),
                                        _buildTableCell(
                                            item['jenis_pekerjaan']),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                  onPressed: (currentPage + 1) * rowsPerPage < historiKk.length
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
