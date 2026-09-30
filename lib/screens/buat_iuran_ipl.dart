import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';

import 'package:iuran_rt_web/screens/buat_iuran.dart';
import 'package:iuran_rt_web/screens/buat_iuran_17an.dart';
import 'package:iuran_rt_web/screens/buat_iuran_donasi.dart';
import 'package:iuran_rt_web/screens/buat_iuran_thr.dart';
import 'package:iuran_rt_web/screens/data_ipl.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TambahIuranPLPage extends StatefulWidget {
  @override
  _TambahIuranPLPageState createState() => _TambahIuranPLPageState();
}

class _TambahIuranPLPageState extends State<TambahIuranPLPage> {
  late int idMenu;
  final TextEditingController _batasTransaksiController =
      TextEditingController();
  List<String> nominalList = [];
  List<dynamic> dataIPL = [];
  Map<String, bool> isDisabled = {};
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
  Map<String, bool> isChecked = {
    for (var bulan in [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember"
    ])
      bulan: false
  };
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    fetchDataIPL();
    fetchKeluhanData();
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

  @override
  void dispose() {
    _batasTransaksiController.dispose();
    super.dispose();
  }

  Future<void> fetchKeluhanData() async {
    final idRt = KodeRt.kodeRt;
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}listKeluhan_admin.php"),
        body: {
          'id_rt': idRt,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] == 'success') {
          setState(() {
            _keluhanData = json['data'];
            isLoading = false;

            print("Data keluhan yang diterima: $_keluhanData");

            for (var keluhan in _keluhanData) {
              String idStr = keluhan['id'].toString();
              print("DEBUG: Menambahkan ID Keluhan: $idStr");
              jawabanControllers[idStr] = TextEditingController();
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<List<int>?> simpanIuran(
      String namaIuran, String batasPembayaran) async {
    final urlIuran = '${ApiUrls.baseUrl}buatIuranIpl.php';
    final bodyIuran = {
      'nama_iuran': namaIuran,
      'batas_pembayaran': batasPembayaran,
      'id_rt': KodeRt.kodeRt,
      'coa': '401',
      'kode_iuran': '02'
    };

    try {
      final responseIuran = await http.post(
        Uri.parse(urlIuran),
        body: bodyIuran,
      );

      final jsonResponse = jsonDecode(responseIuran.body);

      if (responseIuran.statusCode == 200 &&
          jsonResponse['result'] == 'success') {
        await Flushbar(
          message: "Iuran berhasil dibuat",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        await tambahLogAktivitas(
            aktivitas: 'Membuat iuran IPL dengan nama: $namaIuran');
        final List<dynamic> data = jsonResponse['data'];
        return data
            .map<int>((item) => int.parse(item['id'].toString()))
            .toList();
      } else {
        _showSnackBar('Error: ${jsonResponse['message']}');
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server');
    }

    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> simpanRekap(List<int> idIuranList) async {
    final urlRekap = '${ApiUrls.baseUrl}tambahRekap.php';

    final bodyRekap = {
      'id_iuran_list': jsonEncode(idIuranList),
      'id_rt': KodeRt.kodeRt,
    };

    try {
      final response = await http.post(
        Uri.parse(urlRekap),
        body: bodyRekap,
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['result'] != 'success') {
        _showSnackBar('Error: ${jsonResponse['message']}');
      }
    } catch (e) {
      _showSnackBar('Error: Gagal terhubung ke server');
    }
  }

  Future<void> fetchDataIPL([String query = ""]) async {
    setState(() {
      isLoading = true;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/list_data_ipl.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'id_rt': KodeRt.kodeRt,
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

  Future<void> _kirimIuranKeServer() async {
    setState(() {
      _isLoading = true;
    });

    final tahun = DateTime.now().year;

    for (var bulan in isChecked.keys) {
      if (isChecked[bulan] == true && isDisabled[bulan] != true) {
        final int monthIndex = [
              "Januari",
              "Februari",
              "Maret",
              "April",
              "Mei",
              "Juni",
              "Juli",
              "Agustus",
              "September",
              "Oktober",
              "November",
              "Desember"
            ].indexOf(bulan) +
            1;

        final DateTime tanggal = DateTime(tahun, monthIndex, 10, 11, 59);

        final String formattedTanggal =
            DateFormat('dd-MM-yyyy-11:59').format(tanggal);
        final String namaIuran = "IPL $bulan $tahun";

        final List<int>? idIuranList =
            await simpanIuran(namaIuran, formattedTanggal);

        if (idIuranList == null || idIuranList.isEmpty) {
          _showSnackBar("Gagal membuat iuran untuk bulan $bulan.");
          continue;
        }

        await simpanRekap(idIuranList);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showConfirmationDialog() {
    bool isSendingIuran = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDECE8),
              title: Text(
                'Konfirmasi',
                style: GoogleFonts.lato(
                  color: Colors.black,
                ),
              ),
              content: Text(
                isSendingIuran
                    ? 'Sedang menyimpan data, mohon tunggu...'
                    : 'Apakah Anda yakin ingin menyimpan data ini?',
                style: GoogleFonts.lato(
                  color: Colors.black,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSendingIuran
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(
                    'Batal',
                    style: GoogleFonts.lato(
                      color: const Color(0xFF3D8D7A),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isSendingIuran
                      ? null
                      : () async {
                          setDialogState(() {
                            isSendingIuran = true;
                          });

                          try {
                            await _kirimIuranKeServer();

                            if (dialogContext.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        MainScreen(keluhanData: _keluhanData)),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSendingIuran = false;
                            });

                            if (dialogContext.mounted) {
                              Flushbar(
                                message: "Gagal menyimpan data: $e",
                                duration: const Duration(seconds: 3),
                                backgroundColor: Colors.red,
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(dialogContext);
                            }
                          }
                        },
                  child: isSendingIuran
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3D8D7A),
                          ),
                        )
                      : Text(
                          'Simpan',
                          style: GoogleFonts.lato(
                            color: const Color(0xFF3D8D7A),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // void _ketentuanDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text("Kategori IPL Kavling"),
  //         content: SingleChildScrollView(
  //           child: Text(
  //             KodeRt.ketentuanIPL,
  //             style: TextStyle(fontSize: 14),
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text("Tutup"),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //         ],
  //       );
  //     },
  //   );
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
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 232, 226, 226),
                  border: Border.all(
                    color: const Color.fromARGB(255, 58, 112, 50),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                        idMenu: 1,
                                      ),
                                    ),
                                  )
                                }),
                        const Text(
                          'Buat IPL Warga',
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

              const SizedBox(height: 20),

              // INFO BOX
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D8D7A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'IPL 🛈',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dari pengurus RT kepada Warga',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // TAB MENU
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    // Iuran Khusus
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TambahIuranPage()),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          child: const Text(
                            'Iuran Khusus',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // IPL (aktif)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TambahIuranPLPage()),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D8D7A),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'IPL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TambahIuranDonasiPage()),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          child: const Text(
                            'Iuran Donasi',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TambahIuran17anPage()),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          child: const Text(
                            'Iuran 17an',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Iuran THR
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TambahIuranThrPage()),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          child: const Text(
                            'Iuran THR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // FORM INPUT
              _buildKategoriInfo(true, screenSize),
              const SizedBox(height: 16),

              _buildBulanChecklist(true),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildKirimButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // HEADER DI ATAS
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
                                      idMenu: 1,
                                    ),
                                  ),
                                )
                              }),
                      Text(
                        'Buat IPL Warga',
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

          // JARAK ANTARA HEADER DAN KONTEN
          SizedBox(height: 16),

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: SingleChildScrollView(
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 400,
                        height: 500,
                        decoration: BoxDecoration(
                          color: Color(0xFF3D8D7A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Spacer(),
                            Text(
                              'IPL 🛈',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dari pengurus RT kepada Warga',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Spacer(),
                          ],
                        ),
                      ),

                      SizedBox(width: 32),

                      /// KANAN: Form input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F1F1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: [
                                    // Tab Iuran Khusus (aktif)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TambahIuranPage()),
                                          );
                                        },
                                        child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Iuran Khusus',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Tab IPL
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TambahIuranPLPage()),
                                          );
                                        },
                                        child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3D8D7A),
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                          child: const Text(
                                            'IPL',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Tab Iuran 17an
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TambahIuran17anPage()),
                                          );
                                        },
                                        child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Iuran 17an',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Tab Iuran THR
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TambahIuranThrPage()),
                                          );
                                        },
                                        child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Iuran THR',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TambahIuranDonasiPage()),
                                          );
                                        },
                                        child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Iuran Donasi',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildKategoriInfo(isMobile, screenSize),
                            const SizedBox(height: 16),
                            _buildBulanChecklist(isMobile),
                            const SizedBox(height: 20),
                            _isLoading
                                ? CircularProgressIndicator()
                                : _buildKirimButton(),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriInfo(bool isMobile, Size screenSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Kategori IPL Kavling"),
            const SizedBox(width: 5),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DataIPLPage()),
                );
              },
              child: Text(
                'Klik Disini',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulanChecklist(bool isMobile) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: isMobile ? double.infinity : 567,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Wrap(
          spacing: 25,
          runSpacing: 20,
          children: isChecked.keys.map((bulan) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isChecked[bulan],
                  onChanged: isDisabled[bulan] == true
                      ? null
                      : (bool? value) {
                          setState(() {
                            isChecked[bulan] = value!;
                          });
                        },
                ),
                Text(
                  bulan,
                  style: TextStyle(
                    color:
                        isDisabled[bulan] == true ? Colors.grey : Colors.black,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKirimButton() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 500,
        height: 50,
        child: ElevatedButton(
          onPressed: _showConfirmationDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF3D8D7A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Kirim Ke Semua Warga',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Figtree',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
