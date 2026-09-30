import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/screens/buat_kk_penanggung_jawab.dart';
import 'package:iuran_rt_web/screens/pdf_kk_penanggung_jawab.dart';
import 'package:iuran_rt_web/screens/ubah_kk_penanggung_jawab.dart';
import 'package:iuran_rt_web/url.dart';

class KkPenanggungJawabPage extends StatefulWidget {
  final String no_kk;

  KkPenanggungJawabPage({required this.no_kk});
  @override
  _KkPenanggungJawabPageState createState() => _KkPenanggungJawabPageState();
}

class _KkPenanggungJawabPageState extends State<KkPenanggungJawabPage> {
  List<dynamic> dataKkPenduduk = [];
  bool isLoading = true;
  String errorMessage = '';
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchKkData();
  }

  Future<void> fetchKkData() async {
    setState(() {
      isLoading = true;
    });

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}list_kk.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'no_kk': widget.no_kk.toString(),
        'id_rt': KodeRt.kodeRt,
        'kk': 'penanggung_jawab'
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'success') {
        setState(() {
          dataKkPenduduk = result['data'];
        });
      } else {
        setState(() {
          dataKkPenduduk = [];
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'KK Penghuni',
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
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Text(errorMessage,
                            style: GoogleFonts.lato(color: Colors.white)))
                    : ListView.builder(
                        itemCount: dataKkPenduduk.length,
                        itemBuilder: (context, index) {
                          final penduduk = dataKkPenduduk[index];
                          return _buildCardMobile(
                            penduduk['id'] ?? 0,
                            penduduk['no_kk'] ?? 'N/A',
                            penduduk['nama_lengkap'] ?? 'N/A',
                            penduduk['nik'] ?? 'N/A',
                            penduduk['jenis_kelamin'] ?? 'N/A',
                            penduduk['tempat_lahir'] ?? 'N/A',
                            penduduk['tanggal_lahir'] ?? 'N/A',
                            penduduk['agama'] ?? 'N/A',
                            penduduk['pendidikan'] ?? 'N/A',
                            penduduk['jenis_pekerjaan'] ?? 'N/A',
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 80,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 89, 19, 252),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => buatKkPenanggungJawabPage(
                        no_kk: widget.no_kk.toString()),
                  ),
                );
              },
              child: Icon(Icons.add),
              tooltip: 'Tambah Data KK',
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 207, 212, 78),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuatWargaPagePdfPenanggung(
                        no_kk: widget.no_kk.toString()),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/images/pdf.svg',
                color: Colors.white,
                width: 30,
                height: 30,
              ),
              tooltip: 'PDF File KK ',
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
                        'KK Penghuni',
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
                              "KK Penghuni 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Detail data kk penghuni yang terdaftar",
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
                        child: isLoading
                            ? Center(child: CircularProgressIndicator())
                            : errorMessage.isNotEmpty
                                ? Center(
                                    child: Text(errorMessage,
                                        style: GoogleFonts.lato(
                                            color: Colors.white)))
                                : ListView.builder(
                                    itemCount: dataKkPenduduk.length,
                                    itemBuilder: (context, index) {
                                      final penduduk = dataKkPenduduk[index];
                                      return _buildCard(
                                        penduduk['id'] ?? 0,
                                        penduduk['no_kk'] ?? 'N/A',
                                        penduduk['nama_lengkap'] ?? 'N/A',
                                        penduduk['nik'] ?? 'N/A',
                                        penduduk['jenis_kelamin'] ?? 'N/A',
                                        penduduk['tempat_lahir'] ?? 'N/A',
                                        penduduk['tanggal_lahir'] ?? 'N/A',
                                        penduduk['agama'] ?? 'N/A',
                                        penduduk['pendidikan'] ?? 'N/A',
                                        penduduk['jenis_pekerjaan'] ?? 'N/A',
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 80,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 89, 19, 252),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => buatKkPenanggungJawabPage(
                        no_kk: widget.no_kk.toString()),
                  ),
                );
              },
              child: Icon(Icons.add),
              tooltip: 'Tambah Data KK',
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 207, 212, 78),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuatWargaPagePdfPenanggung(
                        no_kk: widget.no_kk.toString()),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/images/pdf.svg',
                color: Colors.white,
                width: 30,
                height: 30,
              ),
              tooltip: 'PDF File KK ',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMobile(
    dynamic id,
    String noKk,
    String namaLengkap,
    String nik,
    String jenisKelamin,
    String tempatLahir,
    String tanggalLahir,
    String agama,
    String pendidikan,
    String jenisPekerjaan,
  ) {
    int parsedId = int.tryParse(id.toString()) ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        color: const Color(0xFF3D8D7A),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NAMA
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      namaLengkap,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // NIK
              Row(
                children: [
                  const Icon(Icons.credit_card, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NIK: $nik',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white54, height: 16),

              // DATA DETAIL (2 kolom rapi)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoItem('Jenis Kelamin', jenisKelamin),
                  _buildInfoItem('Agama', agama),
                  _buildInfoItem('Tempat Lahir', tempatLahir),
                  _buildInfoItem('Tanggal Lahir', tanggalLahir),
                  _buildInfoItem('Pendidikan', pendidikan),
                  _buildInfoItem('Pekerjaan', jenisPekerjaan),
                ],
              ),

              const SizedBox(height: 12),

              // Tombol
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C4B9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () async {
                    final result = await Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ubahKkPenanggungJawabPage(
                          id: parsedId,
                        ),
                      ),
                    );
                    if (result == true) {
                      fetchKkData();
                    }
                  },
                  icon: const Icon(Icons.edit, color: Colors.black, size: 18),
                  label: Text(
                    'Ubah Data KK',
                    style: GoogleFonts.lato(color: Colors.black, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      width: 150, // biar rapi di grid dua kolom
      child: Text(
        "$label: $value",
        style: const TextStyle(color: Colors.white, fontSize: 13),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildCard(
      dynamic id,
      String noKk,
      String namaLengkap,
      String nik,
      String jenisKelamin,
      String tempatLahir,
      String tanggalLahir,
      String agama,
      String pendidikan,
      String jenisPekerjaan) {
    int parsedId = int.tryParse(id.toString()) ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Color(0xFF3D8D7A),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(8.0),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Nama Lengkap: $namaLengkap',
                        style: TextStyle(color: Colors.white, fontSize: 30),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'NIK: $nik',
                        style: TextStyle(color: Colors.white, fontSize: 30),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      Text(
                        'Jenis Kelamin: $jenisKelamin',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Agama: $agama',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      Text(
                        'Tempat Lahir: $tempatLahir',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Pendidikan: $pendidikan',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      Text(
                        'Tanggal Lahir: $tanggalLahir',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Jenis Pekerjaan: $jenisPekerjaan',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF9C4B9),
                        ),
                        onPressed: () async {
                          final result = await Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ubahKkPenanggungJawabPage(
                                id: parsedId,
                              ),
                            ),
                          );
                          if (result == true) {
                            fetchKkData();
                          }
                        },
                        child: Text('Ubah Data KK',
                            style: GoogleFonts.lato(color: Colors.black)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
