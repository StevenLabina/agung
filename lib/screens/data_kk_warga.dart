import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:iuran_rt_web/menu_pilihan.dart';

import 'package:iuran_rt_web/url.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class DataKKWargaPage extends StatefulWidget {
  @override
  _DataKKWargaPageState createState() => _DataKKWargaPageState();
}

class _DataKKWargaPageState extends State<DataKKWargaPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> historiKk = [];
  bool isLoading = false;
  int? selectedMinUsia;
  int? selectedMaxUsia;
  String? selectedAgama;
  String? selectedTipe;
  String? selectedJenisKelamin;
  bool showFilter = false;

  List<dynamic> filteredHistori = [];
  int currentPage = 0;
  int rowsPerPage = 10;
  double totalSaldoBelumLunas = 0;
  List<dynamic> get paginatedData {
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage) > historiKk.length
        ? historiKk.length
        : (start + rowsPerPage);
    return historiKk.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    fetchIuranData();
  }

  int? _hitungUsiaInt(String? tanggalLahir) {
    if (tanggalLahir == null || tanggalLahir.isEmpty) return null;

    try {
      DateTime lahir = DateTime.parse(tanggalLahir);
      DateTime sekarang = DateTime.now();

      if (lahir.isAfter(sekarang)) return null;

      int usia = sekarang.year - lahir.year;

      if (sekarang.month < lahir.month ||
          (sekarang.month == lahir.month && sekarang.day < lahir.day)) {
        usia--;
      }

      return usia;
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchIuranData([String query = ""]) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listDataKKWarga.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'searchQuery': query,
          'id_rt': KodeRt.kodeRt,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['result'] == 'success' && result['data'] != null) {
          List<dynamic> cleanedData = (result['data'] as List).map((item) {
            return {
              'id': item['id'] ?? '',
              'no_kk': item['no_kk'] ?? '',
              'nama_lengkap': item['nama_lengkap'] ?? '',
              'nik': item['nik'] ?? '',
              'jenis_kelamin': (item['jenis_kelamin'] == null ||
                      item['jenis_kelamin'] == 'null')
                  ? ''
                  : item['jenis_kelamin'],
              'tempat_lahir_provinsi': item['tempat_lahir_provinsi'] ?? '',
              'tempat_lahir_kota': item['tempat_lahir_kota'] ?? '',
              'tempat_lahir_kecamatan': item['tempat_lahir_kecamatan'] ?? '',
              'tanggal_lahir': item['tanggal_lahir'] ?? '',
              'agama': (item['agama'] == null || item['agama'] == 'null')
                  ? ''
                  : item['agama'],
              'pendidikan': item['pendidikan'] ?? '',
              'jenis_pekerjaan': item['jenis_pekerjaan'] ?? '',
              'pdf_kk': item['pdf_kk'],
              'tipe': item['tipe'] ?? '',
            };
          }).toList();

          if (!mounted) return;
          setState(() {
            historiKk = cleanedData; 
            filteredHistori = List.from(cleanedData); 
            isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            historiKk = [];
            filteredHistori = [];
            isLoading = false;
          });
          Flushbar(
            message: "Data Tidak Ditemukan",
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }

        print(response.body);
        print("📊 FilteredHistori count: ${filteredHistori.length}");
      } else {
        if (!mounted) return;
        setState(() {
          historiKk = [];
          filteredHistori = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil data dari server')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        historiKk = [];
        filteredHistori = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  Future<void> applyFilter() async {
    List<dynamic> hasil = historiKk.where((item) {
      int? usia = _hitungUsiaInt(item['tanggal_lahir']);
      if (usia == null) return false;

      // Filter usia
      if (selectedMinUsia != null && usia < selectedMinUsia!) return false;
      if (selectedMaxUsia != null && usia > selectedMaxUsia!) return false;

      // Filter agama
      if (selectedAgama != null &&
          item['agama']?.toLowerCase() != selectedAgama!.toLowerCase()) {
        return false;
      }

      // Filter jenis kelamin
      if (selectedJenisKelamin != null &&
          item['jenis_kelamin']?.toLowerCase() !=
              selectedJenisKelamin!.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();

    setState(() {
      filteredHistori = hasil;
    });
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Data KK Warga'];
    
    List<String> headers = [
      'No KK',
      'Nama Lengkap',
      'NIK',
      'Jenis Kelamin',
      'Tempat Lahir',
      'Usia',
      'Agama',
      'Pendidikan',
      'Jenis Pekerjaan',
      'Tipe'
    ];
    sheetObject.appendRow(headers);

    for (var item in historiKk) {
       final lokasi = [
      item['tanggal_lahir_provinsi'],
      item['tanggal_lahir_kota'],
      item['tanggal_lahir_kecamatan'],
    ];
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
        item['tipe'] ?? '-'
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Histori KK Pemilik Rumah.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Histori KK Pemilik Rumah.xlsx";
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 232, 226, 226),
                    border: Border.all(
                      color: const Color.fromARGB(255, 58, 112, 50),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        builder: (context) => MenuPilihanPage(
                                          idMenu: 2,
                                        ),
                                      ),
                                    )
                                  }),
                          const Text(
                            'Data KK Warga',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text('Previous'),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Halaman ${currentPage + 1} dari ${((filteredHistori.length - 1) / rowsPerPage).ceil()}',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: (currentPage + 1) * rowsPerPage <
                                filteredHistori.length
                            ? () {
                                setState(() {
                                  currentPage++;
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3D8D7A),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text('Next'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Column(
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
                  ],
                ),

                if (showFilter)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search
                        TextField(
                          controller: searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Pencarian No KK...',
                            labelStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF3D8D7A), size: 20),
                            border: customBorder,
                            enabledBorder: customBorder,
                            focusedBorder: customBorder,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          onChanged: (value) {
                            fetchIuranData(
                                value); // 🔍 Ambil data sesuai input pencarian
                            applyFilter(); // 🧩 Langsung terapkan filter setelahnya
                          },
                        ),

                        const SizedBox(height: 10),

                        // Usia Minimum
                        DropdownButtonFormField<int>(
                          value: selectedMinUsia,
                          hint: const Text("Usia Minimum",
                              style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            border: customBorder,
                            enabledBorder: customBorder,
                            focusedBorder: customBorder,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: List.generate(
                            100,
                            (i) => DropdownMenuItem(
                                value: i,
                                child: Text("$i tahun",
                                    style: const TextStyle(fontSize: 13))),
                          ),
                          onChanged: (val) {
                            selectedMinUsia = val;
                            applyFilter();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF3D8D7A), size: 16),
                            label: const Text('Hapus Min',
                                style: TextStyle(
                                    color: Color(0xFF3D8D7A), fontSize: 12)),
                            onPressed: () =>
                                setState(() => selectedMinUsia = null),
                          ),
                        ),

                        // Usia Maksimum
                        DropdownButtonFormField<int>(
                          value: selectedMaxUsia,
                          hint: const Text("Usia Maksimum",
                              style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            border: customBorder,
                            enabledBorder: customBorder,
                            focusedBorder: customBorder,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: List.generate(
                            100,
                            (i) => DropdownMenuItem(
                                value: i,
                                child: Text("$i tahun",
                                    style: const TextStyle(fontSize: 13))),
                          ),
                          onChanged: (val) {
                            selectedMaxUsia = val;
                            applyFilter();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF3D8D7A), size: 16),
                            label: const Text('Hapus Max',
                                style: TextStyle(
                                    color: Color(0xFF3D8D7A), fontSize: 12)),
                            onPressed: () =>
                                setState(() => selectedMaxUsia = null),
                          ),
                        ),

                        // Agama
                        DropdownButtonFormField<String>(
                          value: selectedAgama,
                          hint: const Text("Filter Agama",
                              style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            border: customBorder,
                            enabledBorder: customBorder,
                            focusedBorder: customBorder,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: [
                            'Islam',
                            'Kristen',
                            'Katolik',
                            'Hindu',
                            'Buddha',
                            'Konghucu'
                          ]
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            selectedAgama = val;
                            applyFilter();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF3D8D7A), size: 16),
                            label: const Text('Hapus Agama',
                                style: TextStyle(
                                    color: Color(0xFF3D8D7A), fontSize: 12)),
                            onPressed: () =>
                                setState(() => selectedAgama = null),
                          ),
                        ),

                        // Jenis Kelamin
                        DropdownButtonFormField<String>(
                          value: selectedJenisKelamin,
                          hint: const Text("Filter Jenis Kelamin",
                              style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            border: customBorder,
                            enabledBorder: customBorder,
                            focusedBorder: customBorder,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: ['Laki-laki', 'Perempuan']
                              .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            selectedJenisKelamin = val;
                            applyFilter();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF3D8D7A), size: 16),
                            label: const Text('Hapus Gender',
                                style: TextStyle(
                                    color: Color(0xFF3D8D7A), fontSize: 12)),
                            onPressed: () =>
                                setState(() => selectedJenisKelamin = null),
                          ),
                        ),

                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.refresh,
                                color: Color(0xFF3D8D7A), size: 18),
                            label: const Text("Reset Semua",
                                style: TextStyle(
                                    color: Color(0xFF3D8D7A), fontSize: 13)),
                            onPressed: () {
                              setState(() {
                                selectedMinUsia = null;
                                selectedMaxUsia = null;
                                selectedAgama = null;
                                selectedJenisKelamin = null;
                                searchController.clear();
                                fetchIuranData('');
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Table(
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            border: TableBorder.all(
                              color: Colors.grey.shade500,
                              width: 1,
                            ),
                            columnWidths: const {
                              0: FixedColumnWidth(120),
                              1: FixedColumnWidth(150),
                              2: FixedColumnWidth(130),
                              3: FixedColumnWidth(100),
                              4: FixedColumnWidth(110),
                              5: FixedColumnWidth(60),
                              6: FixedColumnWidth(100),
                              7: FixedColumnWidth(120),
                              8: FixedColumnWidth(130),
                              9: FixedColumnWidth(80),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D8D7A),
                                ),
                                children: [
                                  _buildTableHeader('No KK'),
                                  _buildTableHeader('Nama Lengkap'),
                                  _buildTableHeader('NIK'),
                                  _buildTableHeader('Gender'),
                                  _buildTableHeader('Tempat Lahir'),
                                  _buildTableHeader('Usia'),
                                  _buildTableHeader('Agama'),
                                  _buildTableHeader('Pendidikan'),
                                  _buildTableHeader('Pekerjaan'),
                                  _buildTableHeader('Tipe'),
                                ],
                              ),
                              ...paginatedData.map((item) {
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
        .where((e) => e != null && e.toString().trim().isNotEmpty && e != '-')
        .map((e) => e.toString())
        .toList();

    return lokasi.isEmpty ? '-' : lokasi.join(', ');
  })(),
),
                                    _buildTableCell(
                                      _hitungUsiaInt("${item['tanggal_lahir_provinsi']}, ${item['tanggal_lahir_kota']}, ${item['tanggal_lahir_kecamatan']}")
                                              ?.toString() ??
                                          '-',
                                    ),
                                    _buildTableCell(item['agama']),
                                    _buildTableCell(item['pendidikan']),
                                    _buildTableCell(item['jenis_pekerjaan']),
                                    _buildTableCell(item['tipe']),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3D8D7A),
        onPressed: exportToExcel,
        tooltip: 'Export to Excel',
        child: SvgPicture.asset(
          'assets/images/MicrosoftExcelLogo.svg',
          color: Colors.white,
          width: 28,
          height: 28,
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    final InputBorder customBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Color(0xFF3D8D7A),
        width: 1.5,
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          // AppBar
          Center(
            child: Container(
              width: 1200,
              height: 80,
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 232, 226, 226),
                border: Border.all(
                  color: Color.fromARGB(255, 58, 112, 50),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        'Data KK Warga',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  Image.asset('assets/images/Logo4.png', height: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          /// ================= CONTENT =================
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
                                TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Pencarian Berdasarkan No KK...',
                                    prefixIcon: Icon(Icons.search,
                                        color: Color(0xFF3D8D7A)),
                                    border: customBorder,
                                    enabledBorder: customBorder,
                                    focusedBorder: customBorder,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  onChanged: (value) => fetchIuranData(value),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        value: selectedMinUsia,
                                        hint: Text("Usia Minimum"),
                                        decoration: InputDecoration(
                                          border: customBorder,
                                          enabledBorder: customBorder,
                                          focusedBorder: customBorder,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                        items: List.generate(
                                          100,
                                          (i) => DropdownMenuItem(
                                            value: i,
                                            child: Text("$i tahun"),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedMinUsia = val;
                                          });
                                          applyFilter();
                                        },
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Color(0xFF3D8D7A)),
                                      onPressed: () => setState(() {
                                        selectedMinUsia = null;
                                      }),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        value: selectedMaxUsia,
                                        hint: Text("Usia Maksimum"),
                                        decoration: InputDecoration(
                                          border: customBorder,
                                          enabledBorder: customBorder,
                                          focusedBorder: customBorder,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                        items: List.generate(
                                            100,
                                            (i) => DropdownMenuItem(
                                                value: i,
                                                child: Text("$i tahun"))),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedMaxUsia = val;
                                          });
                                          applyFilter();
                                        },
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Color(0xFF3D8D7A)),
                                      onPressed: () => setState(() {
                                        selectedMaxUsia = null;
                                      }),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 16),

                                // Agama
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: selectedAgama,
                                        hint: Text("Filter Agama"),
                                        decoration: InputDecoration(
                                          border: customBorder,
                                          enabledBorder: customBorder,
                                          focusedBorder: customBorder,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                        items: [
                                          'Islam',
                                          'Kristen',
                                          'Katolik',
                                          'Hindu',
                                          'Buddha',
                                          'Konghucu'
                                        ]
                                            .map((a) => DropdownMenuItem(
                                                value: a, child: Text(a)))
                                            .toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedAgama = val;
                                          });
                                          applyFilter();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Color(0xFF3D8D7A)),
                                      onPressed: () =>
                                          setState(() => selectedAgama = null),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value:
                                            selectedJenisKelamin, // ✅ gunakan variabel yang sama
                                        hint: Text("Filter Jenis Kelamin"),
                                        decoration: InputDecoration(
                                          border: customBorder,
                                          enabledBorder: customBorder,
                                          focusedBorder: customBorder,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                        items: ['Laki-laki', 'Perempuan']
                                            .map((t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(t),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedJenisKelamin = val;
                                          });
                                          applyFilter(); // ✅ panggil filter setelah update state
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Color(0xFF3D8D7A)),
                                      onPressed: () => setState(
                                          () => selectedJenisKelamin = null),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),

                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    icon: Icon(Icons.refresh,
                                        color: Color(0xFF3D8D7A)),
                                    label: Text("Reset Semua Filter",
                                        style: TextStyle(
                                            color: Color(0xFF3D8D7A))),
                                    onPressed: () {
                                      setState(() {
                                        selectedMinUsia = null;
                                        selectedMaxUsia = null;
                                        selectedAgama = null;
                                        selectedTipe = null;
                                        selectedJenisKelamin = null;
                                        searchController.clear();
                                        fetchIuranData('');
                                      });
                                    },
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
                                const Text(
                                  'Data KK Warga',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                /// TABLE
                               Expanded(
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
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
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
                    1: FixedColumnWidth(150),
                    2: FixedColumnWidth(140),
                    3: FixedColumnWidth(90),
                    4: FixedColumnWidth(120),
                    5: FixedColumnWidth(60),
                    6: FixedColumnWidth(90),
                    7: FixedColumnWidth(120),
                    8: FixedColumnWidth(150),
                    9: FixedColumnWidth(80),
                  },
                  children: [
                    // HEADER
                    TableRow(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D8D7A),
                      ),
                      children: [
                        _buildTableHeader('No KK'),
                        _buildTableHeader('Nama Lengkap'),
                        _buildTableHeader('NIK'),
                        _buildTableHeader('Jenis Kelamin'),
                        _buildTableHeader('Tempat Lahir'),
                        _buildTableHeader('Usia'),
                        _buildTableHeader('Agama'),
                        _buildTableHeader('Pendidikan'),
                        _buildTableHeader('Jenis Pekerjaan'),
                        _buildTableHeader('Tipe'),
                      ],
                    ),

                    // DATA
                    ...paginatedData.map((item) {
                      final usia = _hitungUsiaInt(
                        item['tanggal_lahir'],
                      )?.toString();

                      return TableRow(
                        children: [
                          _buildTableCell(
                            item['no_kk']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['nama_lengkap']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['nik']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['jenis_kelamin']?.toString() ?? '-',
                          ),
                          _buildTableCell(
  (() {
    final lokasi = [
      item['tanggal_lahir_provinsi'],
      item['tanggal_lahir_kota'],
      item['tanggal_lahir_kecamatan'],
    ]
        .where((e) => e != null && e.toString().trim().isNotEmpty && e != '-')
        .map((e) => e.toString())
        .toList();

    return lokasi.isEmpty ? '-' : lokasi.join(', ');
  })(),
),
                          _buildTableCell(
                            usia ?? '-',
                          ),
                          _buildTableCell(
                            item['agama']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['pendidikan']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['jenis_pekerjaan']?.toString() ?? '-',
                          ),
                          _buildTableCell(
                            item['tipe']?.toString() ?? '-',
                          ),
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
    ),
  ),
),

                                const SizedBox(height: 24),

                                /// PAGINATION
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
                                      child: const Text('Previous'),
                                    ),
                                    const SizedBox(width: 20),
                                    Text(
                                      'Halaman ${currentPage + 1} dari ${((filteredHistori.length - 1) / rowsPerPage).ceil()}',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 20),
                                    ElevatedButton(
                                      onPressed:
                                          (currentPage + 1) * rowsPerPage <
                                                  filteredHistori.length
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
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF3D8D7A),
        onPressed: exportToExcel,
        tooltip: 'Export to Excel',
        child: SvgPicture.asset(
          'assets/images/MicrosoftExcelLogo.svg',
          color: Colors.white,
          width: 30,
          height: 30,
        ),
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
      text?.isNotEmpty == true ? text! : '-',
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black87,
      ),
    ),
  );
}
