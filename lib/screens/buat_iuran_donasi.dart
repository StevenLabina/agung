import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/buat_iuran.dart';
import 'package:iuran_rt_web/screens/buat_iuran_17an.dart';
import 'package:iuran_rt_web/screens/buat_iuran_ipl.dart';
import 'package:iuran_rt_web/screens/buat_iuran_thr.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TambahIuranDonasiPage extends StatefulWidget {
  @override
  _TambahIuranDonasiPageState createState() => _TambahIuranDonasiPageState();
}

class _TambahIuranDonasiPageState extends State<TambahIuranDonasiPage> {
  final TextEditingController _namaIuranController = TextEditingController();
  final TextEditingController _batasTransaksiController =
      TextEditingController();

  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

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

// Future<void> kirimNotifikasi(String idIuran) async {
//   final urlNotifikasi = '${ApiUrls.baseUrl}/kirimNotifikasi.php';

//   final bodyNotifikasi = {
//     'id_iuran': idIuran,
//     'judul': 'Iuran Baru Ditambahkan',
//     'pesan': 'Iuran ${_namaIuranController.text} telah ditambahkan.'
//   };

//   try {
//     final responseNotifikasi = await http.post(
//       Uri.parse(urlNotifikasi),
//       body: bodyNotifikasi,
//     );

//     if (responseNotifikasi.statusCode == 200) {
//       print('Notifikasi berhasil dikirim');
//       SnackBar(content: Text('Notifikasi dirikirim'));
//        print(' notifikasi: ${responseNotifikasi.body}');
//     } else {
//       print('Gagal mengirim notifikasi: ${responseNotifikasi.statusCode}');
//       print('Gagal mengirim notifikasi: ${responseNotifikasi.body}');
//       SnackBar(content: Text('Gagal mengirim notifikasi!'));
//     }
//   } catch (e) {
//     print('Error: Gagal terhubung ke server notifikasi $e');
//     SnackBar(content: Text('Gagal terhubung ke server!'));
//   }
// }
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

  Future<void> simpanIuran() async {
    if (_namaIuranController.text.isEmpty) {
      Flushbar(
        message: "Nama iuran tidak boleh kosong",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }

    if (_batasTransaksiController.text.isEmpty) {
      Flushbar(
        message: "Batas transaksi tidak boleh kosong",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }

    final urlIuran = '${ApiUrls.baseUrl}buatIuranDonasi.php';

    final bodyIuran = {
      'nama_iuran': _namaIuranController.text,
      'batas_pembayaran': _selectedDate != null
          ? (_selectedDate!.millisecondsSinceEpoch ~/ 1000).toString()
          : '',
      'id_rt': KodeRt.kodeRt,
      'coa': '402',
      'kode_iuran': '01'
    };

    try {
      final responseIuran = await http.post(
        Uri.parse(urlIuran),
        body: bodyIuran,
      );

      if (responseIuran.statusCode == 200) {
        final jsonResponseIuran = jsonDecode(responseIuran.body);
        if (jsonResponseIuran['result'] == 'success') {
          final idIuran = jsonResponseIuran['id'];
          await simpanRekap(idIuran);

          await tambahLogAktivitas(
              aktivitas: 'Membuat iuran Donasi: ${_namaIuranController.text}');
          await Flushbar(
            message: "Iuran berhasil disimpan",
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
         
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${jsonResponseIuran['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menyimpan data. Kode: ${responseIuran.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Gagal terhubung ke server')),
      );
    }
  }

  Future<void> simpanRekap(int idIuran) async {
    final urlRekap = '${ApiUrls.baseUrl}/tambahRekapKhusus.php';
    final bodyRekap = {'id_iuran': idIuran.toString(), 'id_rt': KodeRt.kodeRt};

    try {
      final responseRekap = await http.post(
        Uri.parse(urlRekap),
        body: bodyRekap,
      );

      if (responseRekap.statusCode == 200) {
        final jsonResponseRekap = jsonDecode(responseRekap.body);
        if (jsonResponseRekap['result'] == 'success') {
          // await kirimNotifikasi(idIuran.toString());
          //await kirimNotifikasiWA();
          // Navigator.of(context).pushReplacement(
          //   MaterialPageRoute(
          //       builder: (context) => MainScreen(keluhanData: _keluhanData)),
          // );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${jsonResponseRekap['message']}')),
          );
          print("id iuran: ${idIuran.toString()}");
          print("id rt: ${KodeRt.kodeRt}");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan rekap.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Gagal terhubung ke server')),
      );
      print("id iuran: ${idIuran.toString()}");
      print("id rt: ${KodeRt.kodeRt}");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate)
      setState(() {
        _selectedDate = picked;
        _batasTransaksiController.text =
            DateFormat('dd-MM-yyyy-11:59').format(_selectedDate!);
      });
  }

void _showConfirmationDialog() {
  bool isSavingIuran = false;
  if (_namaIuranController.text.isEmpty) {
    Flushbar(
      message: "Nama iuran tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (_batasTransaksiController.text.isEmpty) {
    Flushbar(
      message: "Batas transaksi tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

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
              isSavingIuran
                  ? 'Sedang menyimpan data, mohon tunggu...'
                  : 'Apakah Anda yakin ingin menyimpan data ini?',
              style: GoogleFonts.lato(
                color: Colors.black,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSavingIuran
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
                onPressed: isSavingIuran
                    ? null
                    : () async {
                        setDialogState(() {
                          isSavingIuran = true;
                        });

                        try {
                          await simpanIuran();

                          if (dialogContext.mounted) {
                              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSavingIuran = false;
                          });

                          if (dialogContext.mounted) {
                            Flushbar(
                              message: "Gagal menyimpan data: $e",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                              flushbarPosition:
                                  FlushbarPosition.TOP,
                            ).show(dialogContext);
                          }
                        }
                      },
                child: isSavingIuran
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
  //         title: Text("Penjelasan Iuran Khusus"),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 '"Iuran 17an" adalah iuran yang dikumpulkan dari warga dalam suatu Rukun Tetangga (RT)\n untuk keperluan acara perayan HUT RI. Iuran ini biasanya bersifat insidental dan\n ditetapkan berdasarkan musyawarah warga.',
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text("Ya"),
  //             onPressed: () {
  //               simpanIuran();
  //               // Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  void dispose() {
    _namaIuranController.dispose();
    _batasTransaksiController.dispose();
    super.dispose();
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== HEADER =====
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
                          'Buat Iuran Donasi',
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

              // ===== INFO BOX =====
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D8D7A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Iuran Donasi 🛈',
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

              // ===== TAB MENU =====
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

                    // IPL
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
                          child: const Text(
                            'IPL',
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
                                builder: (context) => TambahIuranDonasiPage()),
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
                            'Iuran Donasi',
                            style: TextStyle(
                              color: Colors.white,
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
                    // Iuran 17an (aktif)
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
              // ===== FORM INPUT =====

              _buildSingleDateField(context),
              const SizedBox(height: 16),

              _buildSubmitButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
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
                        'Buat Iuran Khusus Warga',
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
                              'Iuran Donasi 🛈',
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
                                          child: const Text(
                                            'IPL',
                                            style: TextStyle(
                                              color: Colors.black54,
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
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3D8D7A),
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Iuran Donasi',
                                            style: TextStyle(
                                              color: Colors.white,
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
                            _buildTextInputField(
                              context,
                              _namaIuranController,
                              'Ketik nama iuran...',
                              Icons.info_outline,
                            ),
                            SizedBox(height: 16),
                            _buildSingleDateField(context),
                            SizedBox(height: 16),
                            _buildSubmitButton(),
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

  Widget _buildSingleDateField(
    BuildContext context,
  ) {
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
          SizedBox(width: 12),
          Icon(Icons.calendar_today, color: Color(0xFF909090)),
          SizedBox(width: 12),
          Expanded(
            child: TextButton(
              onPressed: () => _selectDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _batasTransaksiController,
                  textAlign: TextAlign.center,
                  readOnly: true,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: 'Tanggal Batas Transaksi...',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: Container(
        width: 500,
        height: 50,
        decoration: ShapeDecoration(
          color: Color(0xFF3D8D7A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: TextButton(
          onPressed: _showConfirmationDialog,
          child: Text(
            'Kirim',
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

Widget _buildTextInputField(
  BuildContext context,
  TextEditingController controller,
  String hintText,
  IconData icon,
) {
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
            controller: controller,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              hintText: hintText,
            ),
          ),
        ),
      ],
    ),
  );
}
