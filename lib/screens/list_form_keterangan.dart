import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';

class ListFormKeteranganPage extends StatefulWidget {
  @override
  _ListFormKeteranganPageState createState() => _ListFormKeteranganPageState();
}

class _ListFormKeteranganPageState extends State<ListFormKeteranganPage> {
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchKetData();
  }

  Future<void> fetchKetData() async {
    final idRt = KodeRt.kodeRt;

    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}listKeterangan.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
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
          });
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
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
          // Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16, left: 12, right: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 232, 226, 226),
              border: Border.all(
                color: const Color.fromARGB(255, 58, 112, 50),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                                    idMenu: 4,
                                  ),
                                ),
                              )
                            }),
                    const SizedBox(width: 4),
                    const Text(
                      'Pengajuan Keterangan',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List Content
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            errorMessage,
                            style: GoogleFonts.lato(color: Colors.black),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _keluhanData.length,
                          itemBuilder: (context, index) {
                            final keluhan = _keluhanData[index];
                            return _buildMobileCard(keluhan);
                          },
                        ),
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
                                      idMenu: 4,
                                    ),
                                  ),
                                )
                              }),
                      Text(
                        'Pengajuan Keterangan Dari Warga',
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
                              "Pengajuan Keterangan\nDari Warga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Data pengajuan keterangan\ndari warga ke pengurus rt",
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
                        child: Container(
                          width: 800,
                          padding: const EdgeInsets.all(16.0),
                          child: isLoading
                              ? Center(child: CircularProgressIndicator())
                              : errorMessage.isNotEmpty
                                  ? Center(
                                      child: Text(
                                        errorMessage,
                                        style: GoogleFonts.lato(
                                            color: Colors.black),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _keluhanData.length,
                                      itemBuilder: (context, index) {
                                        final keluhan = _keluhanData[index];
                                        return _buildCard(keluhan);
                                      },
                                    ),
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
    );
  }

  Widget _buildMobileCard(Map keluhan) {
    return Card(
      color: const Color(0xFF3D8D7A),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul
            Row(
              children: [
                const Icon(Icons.report_problem, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keluhan['tujuan'] ?? 'Tidak ada tujuan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Isi Informasi
            _buildMobileInfoRow("Keperluan", keluhan['keperluan']),
            _buildMobileInfoRow("Keterangan", keluhan['keterangan']),
            _buildMobileInfoRow(
              "Alamat",
              "${keluhan['alamat_kavling'] ?? '-'} No. ${keluhan['no_kavling'] ?? '-'}",
            ),
            _buildMobileInfoRow(
                "Nama Pemilik Rumah", keluhan['nama_pemilik_rumah']),
            _buildMobileInfoRow(
                "Nama Penghuni", keluhan['nama_penanggung_jawab']),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInfoRow(String label, dynamic value,
      {String defaultValue = "-"}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : defaultValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map keluhan) {
    return Card(
      color: Color(0xFF3D8D7A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoRow("Tujuan", keluhan['tujuan']),
                    buildInfoRow("Keperluan", keluhan['keperluan'],
                        defaultValue: "Tanpa Nama"),
                    buildInfoRow("Keterangan Lainnya", keluhan['keterangan']),
                    buildInfoRow("Alamat",
                        "${keluhan['alamat_kavling'] ?? 'Tanpa Nama'} no ${keluhan['no_kavling']}"),
                    buildInfoRow(
                        "Nama Pemilik Rumah", keluhan['nama_pemilik_rumah'],
                        defaultValue: "Tanpa Nama"),
                    buildInfoRow(
                        "Nama Penghuni", keluhan['nama_penanggung_jawab'],
                        defaultValue: "Tanpa Nama"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildInfoRow(String label, dynamic value, {String defaultValue = ''}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.lato(fontSize: 14, color: Colors.white),
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value?.toString() ?? defaultValue,
          ),
        ],
      ),
    ),
  );
}
