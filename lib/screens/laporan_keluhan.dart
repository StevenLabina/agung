import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LaporanKeluhanPage extends StatefulWidget {
  @override
  _LaporanKeluhanPageState createState() => _LaporanKeluhanPageState();
}

class _LaporanKeluhanPageState extends State<LaporanKeluhanPage> {
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  int _limit = 5;

  bool isLoadingScroll = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  @override
  void initState() {
    super.initState();

    fetchKeluhanData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingMore &&
          hasMore) {
        fetchKeluhanData(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();

    for (var c in jawabanControllers.values) {
      c.dispose();
    }

    super.dispose();
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

  Future<void> fetchKeluhanData({bool loadMore = false}) async {
    if (loadMore && (!hasMore || isLoadingMore)) return;

    if (loadMore) {
      isLoadingMore = true;
    } else {
      isLoadingScroll = true;
      _page = 1;
    }

    setState(() {});

    final response = await http.post(
      Uri.parse("${ApiUrls.baseUrl}listKeluhan_admin.php"),
      body: {
        "id_rt": KodeRt.kodeRt,
        "page": loadMore ? (_page + 1).toString() : "1",
        "limit": "5",
      },
    );

    final json = jsonDecode(response.body);

    if (json["result"] == "success") {
      List data = json["data"];

      setState(() {
        if (loadMore) {
          _page++; // naikkan halaman setelah berhasil
          _keluhanData.addAll(data);
        } else {
          _keluhanData = data;
        }

        hasMore = data.isNotEmpty && data.length == 5;
      });
    } else {
      hasMore = false;
    }

    isLoadingScroll = false;
    isLoadingMore = false;
    setState(() {});
  }

  Future<void> jawabKeluhan(int idKeluhan) async {
    final controller = jawabanControllers[idKeluhan.toString()];
    print(
        "DEBUG: Mengirim Jawaban -> ID: $idKeluhan, Jawaban: ${controller?.text}");

    if (controller == null || controller.text.trim().isEmpty) {
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
      final response = await http.delete(
        Uri.parse("${ApiUrls.baseUrl}deleteKeluhan.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'id': id, 'id_rt': KodeRt.kodeRt}),
      );
      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        setState(() {
          _keluhanData.removeWhere((item) => item['id'] == id);
        });
        await fetchKeluhanData();
        await Flushbar(
          message: "Keluhan/Saran warga terhapus",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => MyApp()),
        // );
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
        Uri.parse('${ApiUrls.baseUrl}tambahRekapKeluhan.php'),
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
            // Header
            Container(
              width: double.infinity,
              height: 70,
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 232, 226, 226),
                border: Border.all(
                    color: Color.fromARGB(255, 58, 112, 50), width: 1.2),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: Colors.black, size: 20),
                      onPressed: () => {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MenuPilihanPage(
                                  idMenu: 4,
                                ),
                              ),
                            )
                          }),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pengajuan Keluhan/Saran',
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

            // Body utama
            Expanded(
                child: isLoadingScroll
                    ? Center(
                        child: Text(
                          "Tidak Ada Laporan Keluhan",
                          style: GoogleFonts.lato(
                              fontSize: 14, color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : errorMessage.isNotEmpty
                        ? Center(
                            child: Text(
                              errorMessage,
                              style: GoogleFonts.lato(color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _keluhanData.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _keluhanData.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              return _buildCardMobile(_keluhanData[index]);
                            },
                          )),
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
                          onPressed: () => {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MenuPilihanPage(
                                      idMenu: 4,
                                    ),
                                  ),
                                )
                              }),
                      Text(
                        'Pengajuan Keluhan/Saran Dari Warga',
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
            const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 500,
                        height: 580,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C9D8F),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.all(35),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pengajuan Keluhan/Saran\nDari Warga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Daftar data pengajuan\nkeluhan/saran dari warga",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 50),
                        Expanded(
                child: isLoadingScroll
                    ? Center(
                        child: Text(
                          "Tidak Ada Laporan Keluhan",
                          style: GoogleFonts.lato(
                              fontSize: 14, color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : errorMessage.isNotEmpty
                        ? Center(
                            child: Text(
                              errorMessage,
                              style: GoogleFonts.lato(color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _keluhanData.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _keluhanData.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              return _buildCard(_keluhanData[index]);
                            },
                          )),
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

  Widget _buildCardMobile(Map keluhan) {
    int idKeluhan = int.tryParse(keluhan['id'].toString()) ?? 0;
    // String idStr = keluhan['id']?.toString() ?? '';
     final idStr = idKeluhan.toString();

jawabanControllers.putIfAbsent(
  idStr,
  () => TextEditingController(),
);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: Color(0xFF3D8D7A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gambar keluhan
              if (keluhan['gambar_keluhan'] != null &&
                  keluhan['gambar_keluhan'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    "${ApiUrls.baseUrl}${keluhan['gambar_keluhan'] ?? ''}",
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 180,
                      alignment: Alignment.center,
                      color: Colors.white,
                      child: Text(
                        "Gambar tidak tersedia",
                        style: GoogleFonts.lato(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 10),

              // Tanggal & identitas
              Text(
                keluhan['tanggal_keluhan']?.toString() ?? '',
                style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 4),
              Text(
                'No Kavling: ${keluhan['identitas']?.toString() ?? 'Tanpa Nama'}',
                style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 6),

              // Keluhan
              Text(
                'Keluhan/Saran:',
                style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                keluhan['keluhan']?.toString() ?? '',
                style: GoogleFonts.lato(fontSize: 15, color: Colors.white),
              ),
              SizedBox(height: 10),

              // TextField untuk jawaban jika belum ada
        
if (keluhan['jawaban'] == null)
  TextField(
    controller: jawabanControllers[idStr],
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: "Masukan tanggapan...",
      border: OutlineInputBorder(),
    ),
  )
else
  Text(
    "Jawaban:\n${keluhan['jawaban']?.toString() ?? '-'}",
    style: GoogleFonts.lato(
      fontSize: 16,
      color: Colors.white,
    ),
  ),
              SizedBox(height: 10),

              // Tombol aksi
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (keluhan['jawaban'] == null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFC0C0),
                        minimumSize: Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () async {
                        if (idKeluhan > 0) {
                          jawabKeluhan(idKeluhan);
                          await tambahLogAktivitas(
                              aktivitas:
                                  'Menjawab keluhan: ${keluhan['keluhan'] ?? ''}');
                        } else {
                          Flushbar(
                            message: "ID tidak valid",
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
                            flushbarPosition: FlushbarPosition.TOP,
                          ).show(context);
                        }
                      },
                      child: Text(
                        'Sebarkan ke warga',
                        style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () async {
                        sendToHistory(
                          keluhan['keluhan']?.toString() ?? '',
                          keluhan['tanggal_keluhan']?.toString() ?? '',
                          keluhan['jawaban']?.toString() ?? '',
                          keluhan['gambar_keluhan']?.toString() ?? '',
                          keluhan['identitas']?.toString() ?? '',
                        );
                        deleteRevisiData(idStr);
                        await tambahLogAktivitas(
                            aktivitas:
                                'Menghapus keluhan: ${keluhan['keluhan'] ?? ''}');
                      },
                      icon: Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map keluhan) {
    int idKeluhan = int.tryParse(keluhan['id'].toString()) ?? 0;
    String idStr = keluhan['id']?.toString() ?? '';

    return Center(
      child: Container(
        width: 900,
        child: Card(
          color: Color(0xFF3D8D7A),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (keluhan['gambar_keluhan'] != null &&
                    keluhan['gambar_keluhan'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      Uri.parse(
                              "${ApiUrls.baseUrl}${keluhan['gambar_keluhan'] ?? ''}")
                          .toString(),
                      width: 320,
                      height: 320,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 320,
                          height: 320,
                          alignment: Alignment.center,
                          color: Colors.white,
                          child: Text(
                            "Gambar tidak tersedia",
                            style: GoogleFonts.lato(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(height: 8),
                      Text(
                        keluhan['tanggal_keluhan']?.toString() ?? '',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'No Kavling: ${keluhan['identitas']?.toString() ?? 'Tanpa Nama'}',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Keluhan/Saran:',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        keluhan['keluhan']?.toString() ?? '',
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      if (keluhan['jawaban'] == null)
                        TextField(
                          controller: jawabanControllers.containsKey(idStr)
                              ? jawabanControllers[idStr]
                              : TextEditingController(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: "Masukan tanggapan...",
                            border: OutlineInputBorder(),
                          ),
                        )
                      else
                        Text(
                          "Jawaban:\n${keluhan['jawaban']?.toString() ?? '-'}",
                          style: GoogleFonts.lato(
                              fontSize: 16, color: Colors.white),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          if (keluhan['jawaban'] == null)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 255, 192, 192),
                                  minimumSize: Size(double.infinity, 48),
                                ),
                                onPressed: () async {
                                  if (idKeluhan > 0) {
                                    await jawabKeluhan(idKeluhan);
                                    tambahLogAktivitas(
                                        aktivitas:
                                            'Menjawab keluhan: ${keluhan['keluhan'] ?? ''}');
                                  } else {
                                    Flushbar(
                                      message: "ID tidak valid",
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Colors.red,
                                      flushbarPosition: FlushbarPosition.TOP,
                                    ).show(context);
                                  }
                                },
                                child: Text(
                                  'Sebarkan ke warga',
                                  style: GoogleFonts.lato(color: Colors.black),
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              sendToHistory(
                                keluhan['keluhan']?.toString() ?? '',
                                keluhan['tanggal_keluhan']?.toString() ?? '',
                                keluhan['jawaban']?.toString() ?? '',
                                keluhan['gambar_keluhan']?.toString() ?? '',
                                keluhan['identitas']?.toString() ?? '',
                              );
                              deleteRevisiData(idStr);
                              tambahLogAktivitas(
                                  aktivitas:
                                      'Menghapus keluhan: ${keluhan['keluhan'] ?? ''}');
                            },
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              "Hapus",
                              style: GoogleFonts.lato(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
