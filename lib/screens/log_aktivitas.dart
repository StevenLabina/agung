import 'dart:convert';
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/login.dart';

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LogAktivitasPage extends StatefulWidget {
  @override
  _LogAktivitasPageState createState() => _LogAktivitasPageState();
}

class _LogAktivitasPageState extends State<LogAktivitasPage> {
  String currentPage = "Log Aktivitas";
  bool isLoading = false;
  DateTime? _selectedDate1;
  DateTime? _selectedDate2;
  bool showFilter = false;
  String errorMessage = '';
  List<dynamic> dataLaporanLog = [];
  int currentPagee = 0;
  int rowsPerPage = 10;
  final TextEditingController _1tanggalController = TextEditingController();
  final TextEditingController _2tanggalController = TextEditingController();

  int get totalPages {
    if (dataLaporanLog.isEmpty) return 1;
    return (dataLaporanLog.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (dataLaporanLog.isEmpty) return [];

    final start = currentPagee * rowsPerPage;

    if (start >= dataLaporanLog.length) {
      return [];
    }

    final end = (start + rowsPerPage) > dataLaporanLog.length
        ? dataLaporanLog.length
        : (start + rowsPerPage);

    return dataLaporanLog.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    SpellCheckConfiguration.disabled();
    fetchLogAktivitas();
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

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tambahLogAktivitas(aktivitas: 'Logout dari aplikasi RT Digital');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MyLogin()),
      (route) => false,
    );
  }

  Future<void> fetchLogAktivitas() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      print("Tanggal 1 (sebelum dikirim): ${_1tanggalController.text}");
      print("Tanggal 2 (sebelum dikirim): ${_2tanggalController.text}");

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}list_log_aktivitas.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'Date1': _1tanggalController.text,
          'Date2': _2tanggalController.text,
          'id_rt': KodeRt.kodeRt
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['result'] == 'success') {
          setState(() {
            dataLaporanLog = result['data'];
          });
          print("Data ditemukan: ${result['data']}");
        } else {
          setState(() {
            dataLaporanLog = [];
            errorMessage = 'Data tidak ditemukan';
          });
        }
      } else {
        setState(() {
          errorMessage =
              'Gagal mengambil data dari server (Kode: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate1(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate1 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate1 = pickedDate;
        _selectedDate2 = _selectedDate1!.add(Duration(days: 7));

        _1tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate1!);
        _2tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate2!);
      });
    }
  }

  Future<void> _selectDate2(BuildContext context) async {
    // Pilih Tanggal
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate2 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate2 = pickedDate;
        _selectedDate1 = _selectedDate2!.subtract(Duration(days: 7));

        _2tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate2!);
        _1tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate1!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          body:
              isMobile ? _buildMobileContent(context) : _buildDesktopContent(),
        );
      },
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.white,
          ),
        ),

        // MAIN SCAFFOLD
        Scaffold(
          backgroundColor: Colors.transparent,

          // ================= DRAWER =================
          drawer: Drawer(
            backgroundColor: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Image.asset('assets/images/Logo4.png'),
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Beranda'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MyApp()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu),
                  title: const Text('Menu Pilihan'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MenuPilihanPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('Pusat Bantuan'),
                  onTap: () async {
                    final Uri url =
                        Uri.parse('https://helpcenter.rukuntetangga.online/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } else {
                      Flushbar(
                        message: "Tidak dapat membuka tautan",
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.red,
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('Log Aktivitas'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogAktivitasPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Keluar'),
                  onTap: () {
                    logout();
                  },
                ),
              ],
            ),
          ),

          // ================= APPBAR =================
          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.7),
            elevation: 0,
          ),

          // ================= BODY =================
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Center(
                    child: Text(
                      'Log Aktivitas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================= FILTER BUTTON =================
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(
                        showFilter ? Icons.filter_alt_off : Icons.filter_alt,
                        color: const Color(0xFF3D8D7A),
                        size: 18,
                      ),
                      label: Text(
                        showFilter ? "Sembunyikan Filter" : "Tampilkan Filter",
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

                  // ================= FILTER SECTION =================
                  if (showFilter)
                    Center(
                      child: Container(
                        width: 320, // diperkecil
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Filter berdasarkan tanggal",
                              style: TextStyle(
                                fontSize: 14, // diperkecil
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // DARI TANGGAL
                            SizedBox(
                              height: 50,
                              child: TextField(
                                controller: _1tanggalController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  labelText: "Dari Tanggal",
                                  labelStyle: const TextStyle(fontSize: 13),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                ),
                                readOnly: true,
                                onTap: () => _selectDate1(context),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // SAMPAI TANGGAL
                            SizedBox(
                              height: 50,
                              child: TextField(
                                controller: _2tanggalController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  labelText: "Sampai Tanggal",
                                  labelStyle: const TextStyle(fontSize: 13),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                ),
                                readOnly: true,
                                onTap: () => _selectDate2(context),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 42, // diperkecil
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3D8D7A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    showFilter = false;
                                  });

                                  fetchLogAktivitas();
                                },
                                child: Text(
                                  'Tampilkan',
                                  style: GoogleFonts.lato(
                                    color: Colors.white,
                                    fontSize: 15, // diperkecil
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ================= TABLE =================
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : dataLaporanLog.isEmpty
                            ? const Center(
                                child: Text('Tidak ada log aktivitas'),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 780,
                                  child: Column(
                                    children: [
                                      // HEADER
                                      Table(
                                        border: TableBorder.all(
                                          color: const Color(0xFF3D8D7A),
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(120),
                                          1: FixedColumnWidth(100),
                                          2: FixedColumnWidth(180),
                                          3: FixedColumnWidth(380),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.shade100,
                                            ),
                                            children: [
                                              _buildTableHeader('Tanggal'),
                                              _buildTableHeader('No Kavling'),
                                              _buildTableHeader('Nama Warga'),
                                              _buildTableHeader('Aktivitas'),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // BODY
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Table(
                                            border: TableBorder.all(
                                              color: Colors.grey,
                                            ),
                                            columnWidths: const {
                                              0: FixedColumnWidth(120),
                                              1: FixedColumnWidth(100),
                                              2: FixedColumnWidth(180),
                                              3: FixedColumnWidth(380),
                                            },
                                            children: paginatedData.map((item) {
                                              return TableRow(
                                                children: [
                                                  _buildTableCell(
                                                      item['tanggal']
                                                          .toString()),
                                                  _buildTableCell(
                                                      item['no_kavling']
                                                          .toString()),
                                                  _buildTableCell(
                                                      item['nama_pemilik_rumah']
                                                          .toString()),
                                                  _buildTableCell(
                                                      item['aktivitas']
                                                          .toString()),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),

                  const SizedBox(height: 16),

                  // ================= PAGINATION =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // PREVIOUS
                      ElevatedButton(
                        onPressed: currentPagee > 0
                            ? () {
                                setState(() {
                                  currentPagee--;
                                });
                              }
                            : null,
                        child: const Text('Previous'),
                      ),

                      const SizedBox(width: 16),

                      // PAGE INFO
                      Text(
                        'Halaman ${currentPagee + 1} dari $totalPages',
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(width: 16),

                      // NEXT
                      ElevatedButton(
                        onPressed: (currentPagee + 1) * rowsPerPage <
                                dataLaporanLog.length
                            ? () {
                                setState(() {
                                  currentPagee++;
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

          // ================= FLOATING BUTTON =================
        ),
      ],
    );
  }

  Widget _buildDesktopContent() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// ================= HEADER =================
            const SizedBox(height: 10),

            Center(
              child: Container(
                width: 1200,
                height: 80,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 232, 226, 226),
                  border: Border.all(
                    color: const Color.fromARGB(255, 58, 112, 50),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /// LOGO
                    Image.asset(
                      'assets/images/Logo4.png',
                      height: 40,
                    ),

                    /// MENU
                    Row(
                      children: [
                        _menuItem('Beranda', MyApp()),
                        const SizedBox(width: 16),

                        _menuItem(
                          'Menu Pilihan',
                          MenuPilihanPage(),
                        ),
                        const SizedBox(width: 16),

                        _menuItem('Pusat Bantuan', null),
                        const SizedBox(width: 16),

                        _menuItem(
                          'Log Aktivitas',
                          LogAktivitasPage(),
                        ),
                        const SizedBox(width: 16),

                        /// LOGOUT
                        ElevatedButton.icon(
                          onPressed: logout,
                          icon: const Icon(
                            Icons.logout,
                            size: 20,
                          ),
                          label: const Text(
                            'Keluar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3D8D7A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                                  const Text(
                                    "Filter berdasarkan tanggal",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _1tanggalController,
                                    readOnly: true,
                                    onTap: () => _selectDate1(context),
                                    decoration: InputDecoration(
                                      labelText: "Dari Tanggal",
                                      prefixIcon: const Icon(Icons.date_range),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _2tanggalController,
                                    readOnly: true,
                                    onTap: () => _selectDate2(context),
                                    decoration: InputDecoration(
                                      labelText: "Sampai Tanggal",
                                      prefixIcon: const Icon(Icons.date_range),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: fetchLogAktivitas,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3D8D7A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'Tampilkan',
                                        style: GoogleFonts.lato(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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
                                  const Text(
                                    'Log Aktivitas',
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
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: 900,
                                            child: Column(
                                              children: [
                                                /// HEADER
                                                Container(
                                                  color:
                                                      Colors.blueGrey.shade100,
                                                  child: Table(
                                                    border:
                                                        TableBorder.symmetric(
                                                      inside: BorderSide(
                                                        color: Colors
                                                            .grey.shade400,
                                                      ),
                                                    ),
                                                    columnWidths: const {
                                                      0: FixedColumnWidth(140),
                                                      1: FixedColumnWidth(120),
                                                      2: FixedColumnWidth(220),
                                                      3: FlexColumnWidth(),
                                                    },
                                                    children: [
                                                      TableRow(
                                                        children: [
                                                          _buildTableHeader(
                                                              'Tanggal'),
                                                          _buildTableHeader(
                                                              'No Kavling'),
                                                          _buildTableHeader(
                                                              'Nama Warga'),
                                                          _buildTableHeader(
                                                              'Aktivitas'),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                /// BODY
                                                Expanded(
                                                  child: SingleChildScrollView(
                                                    child: Table(
                                                      border:
                                                          TableBorder.symmetric(
                                                        inside: BorderSide(
                                                          color: Colors
                                                              .grey.shade300,
                                                        ),
                                                      ),
                                                      defaultVerticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      columnWidths: const {
                                                        0: FixedColumnWidth(
                                                            140),
                                                        1: FixedColumnWidth(
                                                            120),
                                                        2: FixedColumnWidth(
                                                            220),
                                                        3: FlexColumnWidth(),
                                                      },
                                                      children: paginatedData
                                                          .map((item) {
                                                        return TableRow(
                                                          children: [
                                                            _buildTableCell(
                                                                item['tanggal'] ??
                                                                    ''),
                                                            _buildTableCell(
                                                                item['no_kavling'] ??
                                                                    ''),
                                                            _buildTableCell(
                                                                item['nama_pemilik_rumah'] ??
                                                                    ''),
                                                            _buildTableCell(
                                                                item['aktivitas'] ??
                                                                    ''),
                                                          ],
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                                        onPressed: currentPagee > 0
                                            ? () {
                                                setState(() {
                                                  currentPagee--;
                                                });
                                              }
                                            : null,
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 20),
                                      Text(
                                        'Halaman ${currentPagee + 1} dari $totalPages',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      ElevatedButton(
                                        onPressed:
                                            (currentPagee + 1) * rowsPerPage <
                                                    dataLaporanLog.length
                                                ? () {
                                                    setState(() {
                                                      currentPagee++;
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

  Widget _menuItem(String title, Widget? destinationPage) {
    final bool isActive = currentPage == title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () async {
          if (title == 'Pusat Bantuan') {
            // buka link eksternal
            final Uri url =
                Uri.parse('https://helpcenter.rukuntetangga.online/');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          } else {
            // navigasi biasa
            setState(() {
              currentPage = title;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destinationPage!),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            if (isActive) const SizedBox(height: 4),
            if (isActive)
              Container(
                height: 2,
                width: 40,
                color: const Color(0xFF3D8D7A),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildNumberInputField(
  BuildContext context,
  TextEditingController controller,
  String hintText,
  IconData icon,
) {
  final formatter = NumberFormat.decimalPattern('id_ID');

  return Container(
    width: MediaQuery.of(context).size.width * 0.9,
    height: 72,
    padding: const EdgeInsets.all(20),
    decoration: ShapeDecoration(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFB7B9B6)),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: Color(0xFF909090)),
        SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              hintText: hintText,
            ),
            onChanged: (value) {
              // Hapus titik agar bisa di-parse
              String newValue = value.replaceAll('.', '');
              if (newValue.isEmpty) return;

              final number = int.tryParse(newValue);
              if (number == null) return;

              final formatted = formatter.format(number);
              controller.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            },
          ),
        ),
      ],
    ),
  );
}
