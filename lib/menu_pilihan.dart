import 'dart:convert';
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/screens/buat_informasi.dart';
import 'package:iuran_rt_web/screens/buat_iuran.dart';
import 'package:iuran_rt_web/screens/buat_warga.dart';
import 'package:iuran_rt_web/screens/bukti_transaksi.dart';
import 'package:iuran_rt_web/screens/data_iuran.dart';
import 'package:iuran_rt_web/screens/data_kk_warga.dart';
import 'package:iuran_rt_web/screens/data_warga.dart';
import 'package:iuran_rt_web/screens/histori_kk_pemilik.dart';

import 'package:iuran_rt_web/screens/laporan_keluhan.dart';

import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
import 'package:iuran_rt_web/screens/laporan_revisi.dart';
import 'package:iuran_rt_web/screens/list_form_keterangan.dart';
import 'package:iuran_rt_web/screens/log_aktivitas.dart';
import 'package:iuran_rt_web/screens/login.dart';
import 'package:iuran_rt_web/screens/rekap_iuran_warga.dart';
import 'package:iuran_rt_web/screens/rekap_keluhan.dart';
import 'package:iuran_rt_web/screens/tambah_asset.dart';
import 'package:iuran_rt_web/screens/tambah_coa.dart';
import 'package:iuran_rt_web/screens/tambah_pendapatan.dart';
import 'package:iuran_rt_web/screens/tambah_pengeluaran.dart';
import 'package:iuran_rt_web/screens/tambah_saldo_awal.dart';
import 'package:iuran_rt_web/screens/tambah_transisi_data_iuran.dart';
import 'package:iuran_rt_web/screens/tambah_utang.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MenuPilihanPage extends StatefulWidget {
  final int idMenu;

  const MenuPilihanPage({
    super.key,
    this.idMenu = 0,
  });

  @override
  State<MenuPilihanPage> createState() => _MenuPilihanPageState();
}

class _MenuPilihanPageState extends State<MenuPilihanPage> {
  String currentPage = "Menu Pilihan";
    late int idMenu;
bool _showSwipeHint = true;
late ScrollController _menuScrollController;
  @override
  void initState() {
    super.initState();
    SpellCheckConfiguration.disabled();
    idMenu = widget.idMenu;
     _menuScrollController = ScrollController();

  _menuScrollController.addListener(() {
    if (_menuScrollController.offset > 5 && _showSwipeHint) {
      setState(() {
        _showSwipeHint = false;
      });
    }
  });
  
  }
  @override
void dispose() {
  _menuScrollController.dispose();
  super.dispose();
}
  Widget _getMenuContent(bool isMobile) {
  switch (idMenu) {
    case 1:
      return _MenuBuat();

    case 2:
      return _MenuDataWarga();

    case 3:
      return _MenuLaporan();
     case 4:
      return _MenuPengajuan();
    case 5:
      return _MenuTransaksi();
     default:
      return isMobile
          ? _buildMobileContent(context)
          : _buildDesktopContent();
    
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
        body: _getMenuContent(isMobile),
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
                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 24),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Menu Pilihan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          Align(
  alignment: Alignment.center,
  child: Stack(
    alignment: Alignment.center,
    children: [

      // ==========================================
      // MENU HORIZONTAL
      // ==========================================

      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          controller: _menuScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Row(
            children: [

              buildCard(
                title: "Menu Pembuatan",
                description:
                    "•buat infomasi untuk warga"
                    "\n•buat data warga"
                    "\n•buat iuran",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MenuPilihanPage(
                        idMenu: 1,
                      ),
                    ),
                  );
                },
              ),

              buildCard(
                title: "Menu Data Warga",
                description:
                    "•data warga\n"
                    "•data kk warga\n"
                    "•data iuran untuk warga\n"
                    "•rekap kumpulan data kk warga\n"
                    "•rekap kumpulan keluhan/saran dari warga",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MenuPilihanPage(
                        idMenu: 2,
                      ),
                    ),
                  );
                },
              ),

              buildCard(
                title: "Menu Laporan",
                description:
                    "•laporan transaksi iuran warga\n"
                    "•laporan keuangan\n",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MenuPilihanPage(
                        idMenu: 3,
                      ),
                    ),
                  );
                },
              ),

              buildCard(
                title: "Menu Pengajuan Dari Warga",
                description:
                    "•pengajuan keterangan dari warga\n"
                    "•pengajuan iuran tunai dari warga\n"
                    "•pengajuan revisi perubahan data warga\n"
                    "•pengajuan keluhan/saran dari warga",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MenuPilihanPage(
                        idMenu: 4,
                      ),
                    ),
                  );
                },
              ),

              buildCard(
                title: "Menu Transaksi RT",
                description:
                    "•input transaksi pendapatan\n"
                    "•input transaksi pengeluaran\n"
                    "•input transaksi utang\n"
                    "•input aset\n"
                    "•input saldo awal\n"
                    "•input transisi data iuran",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MenuPilihanPage(
                        idMenu: 5,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),


      // ==========================================
      // PETUNJUK GESER
      // ==========================================

      IgnorePointer(
        ignoring: !_showSwipeHint,
        child: AnimatedOpacity(
          opacity: _showSwipeHint ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: const SwipeHint(),
        ),
      ),
    ],
  ),
)
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
       
        ),
      ],
    );
  }

  Widget _buildDesktopContent() {
  
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Pilihan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                                                 buildCard(
                                      title: "Menu Pembuatan",
                                      description: "•buat infomasi untuk warga"
                                          "\n•buat data warga"
                                          "\n•buat iuran",
                                     
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  MenuPilihanPage(idMenu: 1,)),
                                        );
                                      },
                                    ),
                                    buildCard(
                                      title: "Menu Data Warga",
                                      description: "•data warga\n"
                                                   "•data kk warga\n"
                                                  "•data iuran untuk warga\n"
                                                   "•rekap kumpulan data kk warga\n"
                                                   "•rekap kumpulan keluhan/saran dari warga",
                                     
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  MenuPilihanPage(idMenu: 2,)),
                                        );
                                      },
                                    ),
                                    buildCard(
                                      title: "Menu Laporan",
                                      description:
                                          "•laporan transaksi iuran warga\n"
                                          "•laporan keuangan\n",
                                          // "•laporan iuran warga yang belum lunas\n"
                                          // "•laporan iuran warga yang sudah lunas\n",
                                  
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  MenuPilihanPage(idMenu: 3,)),
                                        );
                                      },
                                    ),
                                    buildCard(
                                      title: "Menu Pengajuan Dari Warga",
                                      description:
                                         "•pengajuan keterangan dari warga\n"
                                         "•pengajuan iuran tunai dari warga\n"
                                         "•pengajuan revisi perubahan data warga\n"
                                         "•pengajuan keluhan/saran dari warga\n",
                                         
                                
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  MenuPilihanPage(idMenu: 4,)),
                                        );
                                      },
                                    ),
                                     buildCard(
                                      title: "Menu Transaksi RT",
                                      description:
                                         "•input transaksi pendapatan\n"
                                         "•input transaksi pengeluaran\n"
                                         "•input transaksi utang\n"
                                         "•input aset\n"
                                         "•input saldo awal\n"
                                          "•input transisi data iuran\n",
                                         
                                     
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  MenuPilihanPage(idMenu: 5,)),
                                        );
                                      },
                                    ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

Widget buildCard({
  required String title,
  required String description,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 250,
      height: 280, // tinggi semua card dibuat sama
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(width: 8),
              Text(
                'RT DIGITAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF3D8D7A),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          IgnorePointer(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Deskripsi mengambil ruang yang tersedia
          Expanded(
            child: IgnorePointer(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),

       
          IgnorePointer(
            child: Text(
              'Detail ➜',
              style: const TextStyle(
                color: Color(0xFF3D8D7A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget subbuildCard({
  required String title,
  required String description,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: SelectionContainer.disabled(
      child: Container(
        width: 250,
        height: 280, // semua card sama tinggi
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.green.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'RT DIGITAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF3D8D7A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                decoration: TextDecoration.none,
              ),
            ),

            const SizedBox(height: 6),

            // Deskripsi mengisi ruang yang tersedia
            Expanded(
              child: SelectionContainer.disabled(
                child: ExcludeSemantics(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),

            // Detail selalu rata di bagian bawah
            Text(
              'Detail ➜',
              style: const TextStyle(
                color: Color(0xFF3D8D7A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
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

  Widget _MenuBuat() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                       onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(),
                                        ),
                                        )
                          }
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Image.asset('assets/images/Logo4.png'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Pembuatan',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            decoration: TextDecoration.none,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                subbuildCard(
                                  title: "Membuat Informasi Untuk Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk membuat informasi seputar lingkup rt yang akan disebarkan ke warga",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TambahInformasiPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Membuat Data Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengisi identitas data warga penghuni maupun warga pengunjung secara input manual atau menggunakan form excel",
                          
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              BuatWargaPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Membuat Iuran Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mendaftarkan iuran khusus atau ipl sebagai iuran wajib bayar bagi warga ",
                                
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TambahIuranPage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
  Widget _MenuDataWarga() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                      onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(),
                                        ),
                                        )
                          }
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Image.asset('assets/images/Logo4.png'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Data Warga',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            decoration: TextDecoration.none,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                subbuildCard(
                                  title: "Data Warga",
                                  description:
                                      "Menu ini digunakan untuk melihat data warga, mengubah data warga, mengelola Kartu Keluarga (KK), serta mengatur role atau hak akses pengurus RT.",
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              DataPendudukPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Data KK Warga",
                                  description:
                                      "Menu ini digunakan untuk melihat dan mengelola data kartu keluarga (KK)",
                               
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              DataKKWargaPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Data Iuran Untuk Warga",
                                  description:
                                      "Menu ini digunakan melihat dan mengelola data iuran warga",
                               
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              DataIuranPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Rekap Kumpulan KK Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui rekap kumpulan data kk warga sebelumnya",
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              HistoriKkPemilikPage()),
                                    );
                                  },
                                ),
                                   subbuildCard(
                                  title: "Rekap Kumpulan Keluhan/Saran Dari Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk rekap laporan keluhan/saran warga yang sudah pernah di respon oleh pengurus rt",
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              RekapKeluhanPage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
  Widget _MenuLaporan() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                       onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(),
                                        ),
                                        )
                          }
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Image.asset('assets/images/Logo4.png'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Laporan',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            decoration: TextDecoration.none,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                               
                                subbuildCard(
                                  title: "Laporan Transaksi Iuran Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui laporan transaksi iuran warga yang sudah didaftarkan oleh pengurus rt",
                                
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              RekapIuranWargaPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title:
                                      "Laporan Keuangan",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui laporan keuangan yang sudah dikelola dalam bentuk laporan pendapatan, pengeluaran, kas keuangan, surplus/defisit, utang, aset, neraca",
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              LaporanKeuanganSurplusDefisitPage()),
                                    );
                                  },
                                ),
                                //  subbuildCard(
                                //   title: "Laporan Iuran Warga Yang Belum Lunas",
                                //   description:
                                //       "Menu ini digunakan pengurus rt untuk mengetahui laporan iuran warga yang belum lunas",
                              
                                //   onTap: () {
                                //     Navigator.push(
                                //       context,
                                //       MaterialPageRoute(
                                //           builder: (context) =>
                                //               HistoriTransaksiBelumPage()),
                                //     );
                                //   },
                                // ),
                                // subbuildCard(
                                //   title: "Laporan Iuran Warga Yang Sudah Lunas",
                                //   description:
                                //       "Menu ini digunakan pengurus rt untuk mengetahui laporan iuran warga yang sudah lunas",
                                 
                                //   onTap: () {
                                //     Navigator.push(
                                //       context,
                                //       MaterialPageRoute(
                                //           builder: (context) =>
                                //               HistoriTransaksiPage()),
                                //     );
                                //   },
                                // ),
                            
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
    Widget _MenuPengajuan() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                       onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(),
                                        ),
                                        )
                          }
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Image.asset('assets/images/Logo4.png'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Pengajuan Dari Warga',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            decoration: TextDecoration.none,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                               
                               
                                 subbuildCard(
                                  title: "Pengajuan Keterangan Dari Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui pengajuan-pengajuan keterangan warga",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              ListFormKeteranganPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Pengajuan Iuran Tunai Dari Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui pengajuan transaksi warga yang menggunakan pembayaran tunai",
                              
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              BuktiTransaksiPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Pengajuan Perubahan Data Dari Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui revisi-revisi perubahan data warga yang diajukan/diisi oleh warga",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              LaporanRevisiDataPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Pengajuan Keluhan/Saran Dari Warga",
                                  description:
                                      "Menu ini digunakan pengurus rt untuk mengetahui keluhan/saran warga seputar lingkup rt",
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              LaporanKeluhanPage()),
                                    );
                                  },
                                ),
                              
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
  Widget _MenuTransaksi() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                        onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(),
                                        ),
                                        )
                          }
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Image.asset('assets/images/Logo4.png'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Menu Transaksi RT',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            decoration: TextDecoration.none,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
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
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                               
                               
                                 subbuildCard(
                                  title: "Input Transaksi Pendapatan",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data pendapatan RT secara manual",
  
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TambahPendapatanPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Input Transaksi Pengeluaran",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data pengeluaran RT secara manual",
                              
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TambahPengeluaranPage()),
                                    );
                                  },
                                ),
                                subbuildCard(
                                  title: "Input Transaksi Utang",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data utang RT secara manual",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                             TambahUtangPage()),
                                    );
                                  },
                                ),
                                 subbuildCard(
                                  title: "Input Aset",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data aset RT secara manual",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                             TambahAsetPage()),
                                    );
                                  },
                                ),
                                  subbuildCard(
                                  title: "Input Saldo Awal",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data saldo awal secara manual",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                             TambahSaldoAwalPage()),
                                    );
                                  },
                                ),
                                      subbuildCard(
                                  title: "Input Transisi Data Iuran ",
                                  description:
                                      "Menu ini digunakan pengurus RT untuk transisi data iuran warga sebelumnya dengan file excel",
                            
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                            TambahTransisiDataIuran()),
                                    );
                                  },
                                ),
                                // subbuildCard(
                                //   title: "Input Kode COA",
                                //   description:
                                //       "Menu ini digunakan pengurus RT untuk mencatat atau menambahkan data kode COA secara manual",
                            
                                //   onTap: () {
                                //     Navigator.push(
                                //       context,
                                //       MaterialPageRoute(
                                //           builder: (context) =>
                                //             TambahCOAPage()),
                                //     );
                                //   },
                                // ),
                              
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
class SwipeHint extends StatefulWidget {
  const SwipeHint({super.key});

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
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
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

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
                  size: 24,
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          const Text(
            'Geser kiri / kanan',
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