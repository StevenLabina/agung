import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

import 'package:iuran_rt_web/screens/log_aktivitas.dart';
import 'package:web/web.dart' as web;


import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keluhan.dart';

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/screens/login.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  SpellCheckConfiguration.disabled();

  runApp(const MyApp());
}

class NoSelectionScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
      };

  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: NoSelectionScrollBehavior(),
      title: 'RT Digital-Pengurus RT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CheckLogin(),
    );
  }
}

class CheckLogin extends StatefulWidget {
  @override
  _CheckLoginState createState() => _CheckLoginState();
}

class _CheckLoginState extends State<CheckLogin> {
  String? username;
  bool? isAdmin;
  String? total;
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};

  @override
  void initState() {
    super.initState();
    checkLogin();
    fetchKeluhanData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      web.window.onpopstate = (event) {
        // Cegah error dengan delay pendek (kasih waktu engine update)
        Future.delayed(const Duration(milliseconds: 100), () {
          web.window.location.href = 'https://www.google.com';
        });
      } as web.EventHandler?;
    });
  
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

  Future<void> jawabKeluhan(int idKeluhan) async {
    final controller = jawabanControllers[idKeluhan.toString()];
    print(
        "DEBUG: Mengirim Jawaban -> ID: $idKeluhan, Jawaban: ${controller?.text}");

    if (controller == null || controller.text.isEmpty) {
      Flushbar(
        message: "Jawaban tidak boleh kosong",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("${ApiUrls.baseUrl}/jawabanKeluhan.php");
    final data = {
      'id': idKeluhan.toString(),
      'jawaban': controller.text,
      'id_rt': KodeRt.kodeRt
    };

    // Debugging: Lihat data yang dikirim
    print("DEBUG: Data yang dikirim ke API -> ${jsonEncode(data)}");

    try {
      final response = await http.post(
        url,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );

      print("DEBUG: Response dari server -> ${response.body}");

      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        Flushbar(
          message: "Jawaban berhasil dikirim",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        fetchKeluhanData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan jawaban: ${json['message']}')),
        );
      }
    } catch (e) {
      print("DEBUG: Error saat mengirim jawaban -> $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat menyimpan jawaban')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> deleteRevisiData(String id) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/deleteKeluhan.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id': id,
          'id_rt': KodeRt.kodeRt,
        }),
      );

      final json = jsonDecode(response.body);

      if (json['result'] == 'success') {
        setState(() {
          _keluhanData.removeWhere((item) => item['id'] == id);
        });
        Flushbar(
          message: "Keluhan/Saran warga terhapus",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(json['message'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to delete record: $e")));
    }
  }

  Future<void> sendToHistory(String keluhan, String tanggalKeluhan,
      String jawaban, String gambarKeluhan, String identitas) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/tambahRekapKeluhan.php'),
        body: {
          'r_keluhan': keluhan,
          'r_tanggal_keluhan': tanggalKeluhan,
          'r_jawaban': jawaban,
          'r_gambar_keluhan': gambarKeluhan,
          'r_identitas': identitas,
          'id_rt': KodeRt.kodeRt
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['result'] == 'success') {
          print('Data berhasil ditambahkan ke histori');
        } else {
          print('Gagal menambahkan ke histori: ${result['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saat mengirim data ke histori: $e');
    }
  }

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
      isAdmin = prefs.getBool('isAdmin');
      int? idUser = prefs.getInt('idUser');
      print("User ID: $idUser");

      if (isAdmin == null || isAdmin == false) {
        print("You do not have admin access.");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MyLogin()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (username == null) {
      return MyLogin();
    } else {
      if (isAdmin == true) {
        return MainScreen(keluhanData: _keluhanData);
      } else {
        return MainScreen(keluhanData: _keluhanData);
      }
    }
  }
}

class MainScreen extends StatefulWidget {
  final List<dynamic> keluhanData;
  
  const MainScreen({Key? key, required this.keluhanData}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String alamatKavling = '';
  String total = '';
  String username = '';
  List<dynamic> iuranList = [];
  TextEditingController totalController = TextEditingController();
  String currentPage = 'Beranda';
    bool _showSwipeHintKeluhan = true;
  late ScrollController _keluhanScrollController;
  @override
  void initState() {
    super.initState();
    _loadAlamatKavling();
    _jumlahKavling();
    _keluhanScrollController = ScrollController();

    _keluhanScrollController.addListener(() {
      if (_keluhanScrollController.offset > 5 && _showSwipeHintKeluhan) {
        setState(() {
          _showSwipeHintKeluhan = false;
        });
      }
    });
  }
 
  @override
  void dispose() {
    _keluhanScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAlamatKavling() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      alamatKavling = prefs.getString("alamatKavling") ?? '';
      username = prefs.getString("username") ?? '';
    });
  }

  Future<void> _jumlahKavling() async {
    try {
      total = totalController.text.isNotEmpty ? totalController.text : '0';

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/jumlahKavling.php'),
        body: {
          "total": total,
          'id_rt': KodeRt.kodeRt,
        },
      );
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'success' && data.containsKey('total_data')) {
          setState(() {
            total = data['total_data'].toString();
          });
        } else if (data['result'] == 'error' && data.containsKey('message')) {
          throw Exception('Server Error: ${data['message']}');
        } else {
          throw Exception('Unexpected server response');
        }
      } else {
        throw Exception(
            'Failed to connect to server with status code ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching iuran data: $e");
    }
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          body: isMobile
              ? _buildMobileContent(context, widget.keluhanData)
              : _buildDesktopContent(widget.keluhanData),
        );
      },
    );
  }

  Widget _buildMobileContent(BuildContext context, List keluhanList) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            KodeRt.gambarRt,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: Drawer(
            backgroundColor: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Image.asset('assets/images/Logo4.png'),
                ),
                ListTile(
                  leading: Icon(Icons.home_outlined),
                  title: Text('Beranda'),
                  onTap: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => MyApp()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.menu),
                  title: Text('Menu Pilihan'),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => MenuPilihanPage()));
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
                  leading: Icon(Icons.notes),
                  title: Text('Log Aktivitas'),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => LogAktivitasPage()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Keluar'),
                  onTap: () {
                    logout();
                  },
                ),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.7),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selamat datang di",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                Text(
                  KodeRt.alamatRt,
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  KodeRt.alamatDetailRt,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 400,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home_outlined, color: Color(0xFF3D8D7A)),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  KodeRt.alamatRt,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Total Kavling: $total'),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.tag_faces_outlined,
                                color: Color(0xFF3D8D7A)),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama Pengurus RT',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('$username'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Column(
                  children: [
                    if (keluhanList.isNotEmpty) ...[
                      Center(
                        child: Text(
                          'Keluhan dan Saran',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.center,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children:
                                  List.generate(keluhanList.length, (index) {
                                final keluhan = keluhanList[index];
                                final tanggal =
                                    keluhan['tanggal_keluhan']?.toString() ??
                                        '';
                                final identitas =
                                    keluhan['identitas']?.toString() ??
                                        'Tanpa Nama';
                                final isiKeluhan =
                                    keluhan['keluhan']?.toString() ?? '';

                                return Container(
                                  width: 400,
                                  margin: EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isiKeluhan,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 4),
                                        Text('Dibuat $tanggal',
                                            style: TextStyle(
                                                color: Colors.grey[600])),
                                        Text('No Unit : $identitas',
                                            style: TextStyle(
                                                color: Colors.black87)),
                                        SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      LaporanKeluhanPage(),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF3D8D7A),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('Balas',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopContent(List keluhanList) {
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(KodeRt.gambarRt),
            fit: BoxFit.cover,
          ),
        ),
      ),
      Container(
        color: Colors.black.withOpacity(0.5),
      ),
      Column(
        children: [
          SizedBox(height: 5),
          Center(
            child: Container(
              width: 1200,
              height: 80,
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
                children: [
                  Image.asset('assets/images/Logo4.png', height: 40),
                  Row(
                    children: [
                      _menuItem('Beranda', MyApp()),
                      SizedBox(width: 16),
                      _menuItem('Menu Pilihan', MenuPilihanPage()),
                      SizedBox(width: 16),
                      _menuItem('Pusat Bantuan', null),
                      SizedBox(width: 16),
                      _menuItem('Log Aktivitas', LogAktivitasPage()),
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          logout();
                        },
                        icon: Icon(Icons.logout, size: 20),
                        label: Text(
                          'Keluar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3D8D7A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          elevation: 2,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Konten utama kamu (welcome text, keluhan list, dll)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Konten kiri
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selamat datang di",
                                  style: TextStyle(
                                      fontSize: 40, color: Colors.white),
                                ),
                                Text(
                                  KodeRt.alamatRt,
                                  style: TextStyle(
                                      fontSize: 40, color: Colors.white),
                                ),
                                Text(
                                  KodeRt.alamatDetailRt,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontFamily: 'Figtree',
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 40),
                          // Konten kanan
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.home_outlined,
                                          color: Color(0xFF3D8D7A)),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            KodeRt.alamatRt,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Total Kavling: ${total}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 20),
                                  Row(
                                    children: [
                                      Icon(Icons.tag_faces_outlined,
                                          color: Color(0xFF3D8D7A)),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nama Pengurus RT',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '$username',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Column(
                        children: [
                          if (keluhanList.isNotEmpty) ...[
                            Center(
                              child: Text(
                                'Keluhan dan Saran',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                           Align(
  alignment: Alignment.center,
  child: LayoutBuilder(
    builder: (context, constraints) {

      // ==========================================
      // HITUNG PERKIRAAN LEBAR SEMUA CARD
      // ==========================================

      const double cardWidth = 300;
      const double cardMargin = 16;

      final double totalContentWidth =
          (keluhanList.length * (cardWidth + cardMargin)) + 16;

      final double availableWidth =
          constraints.maxWidth;

      // ==========================================
      // CEK APAKAH CONTENT MELEBIHI LAYAR
      // ==========================================

      final bool membutuhkanScroll =
          totalContentWidth > availableWidth;

      return Stack(
        alignment: Alignment.center,
        children: [

          ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              controller: _keluhanScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Row(
                children: List.generate(
                  keluhanList.length,
                  (index) {

                    final keluhan =
                        keluhanList[index];

                    final tanggal =
                        keluhan['tanggal_keluhan']
                                ?.toString() ??
                            '';

                    final identitas =
                        keluhan['identitas']
                                ?.toString() ??
                            'Tanpa Nama';

                    final isiKeluhan =
                        keluhan['keluhan']
                                ?.toString() ??
                            '';

                    return Container(
                      width: 300,
                      margin:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.1),
                            blurRadius: 6,
                            offset:
                                const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Text(
                              isiKeluhan,
                              style:
                                  const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Dibuat $tanggal',
                              style: TextStyle(
                                color:
                                    Colors.grey[600],
                              ),
                            ),

                            Text(
                              'No Unit : $identitas',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.black87,
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Align(
                              alignment:
                                  Alignment.centerRight,
                              child:
                                  ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              LaporanKeluhanPage(),
                                    ),
                                  );
                                },
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      const Color(
                                          0xFF3D8D7A),
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                8),
                                  ),
                                ),
                                child: const Text(
                                  'Balas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.white,
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
            ),
          ),

          // ==========================================
          // PETUNJUK HANYA JIKA TIDAK MUAT
          // ==========================================

          if (membutuhkanScroll &&
              _showSwipeHintKeluhan)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity:
                    _showSwipeHintKeluhan
                        ? 1.0
                        : 0.0,
                duration:
                    const Duration(
                  milliseconds: 500,
                ),
                child:
                    const SwipeHintKeluhan(),
              ),
            ),
        ],
      );
    },
  ),
)
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      )
    ]);
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

class SwipeHintKeluhan extends StatefulWidget {
  const SwipeHintKeluhan({super.key});

  @override
  State<SwipeHintKeluhan> createState() => _SwipeHintKeluhanState();
}

class _SwipeHintKeluhanState extends State<SwipeHintKeluhan>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -12,
      end: 12,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.keyboard_arrow_left,
            color: Colors.white,
            size: 22,
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _animation.value,
                  0,
                ),
                child: const Icon(
                  Icons.swipe,
                  color: Colors.white,
                  size: 25,
                ),
              );
            },
          ),
          const Icon(
            Icons.keyboard_arrow_right,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'Geser untuk melihat keluhan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
