import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/drawer.dart';

class RekapKeuanganPage extends StatefulWidget {
  @override
  _RekapKeuanganPageState createState() => _RekapKeuanganPageState();
}

class _RekapKeuanganPageState extends State<RekapKeuanganPage> {
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
   final TextEditingController _1tanggalController = TextEditingController();
  final TextEditingController _2tanggalController = TextEditingController();
  DateTime? _selectedDate1;
  DateTime? _selectedDate2;
  String? noKavling;
  @override
  void initState() {
    super.initState();
    fetchKeluhanData();
  }

  
Future<void> fetchKeluhanData() async {
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {

    print("Tanggal 1 (sebelum dikirim): ${_1tanggalController.text}");
    print("Tanggal 2 (sebelum dikirim): ${_2tanggalController.text}");

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}histori_keluhan.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        
        'selectedDate1': _1tanggalController.text,
        'selectedDate2': _2tanggalController.text,
        'id_rt' : KodeRt.kodeRt
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        setState(() {
          _keluhanData = result['data'];
        });
        print("Data ditemukan: ${result['data']}");
      } else {
        setState(() {
          _keluhanData = [];
          errorMessage = 'Data tidak ditemukan';
        });
      }
    } else {
      setState(() {
        errorMessage = 'Gagal mengambil data dari server (Kode: ${response.statusCode})';
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
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          body:
              isMobile ? _buildMobileContent(context) : _buildDesktopContent(context),
        );
      },
    );
  }
Widget _buildMobileContent(BuildContext context) {
 
  Future.delayed(Duration(seconds: 1), () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MenuPilihanPage()),
    );
  });

  return Scaffold(
    body: Center(child: Text('Mengalihkan ke halaman menu pilihan...')),
  );
}
  
  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFDECE8),
        elevation: 0,
      ),
      drawer: MyDrawer(currentPage: 'RekapKeuanganPage'),
      backgroundColor: Color(0xFFFDECE8),
      body: Column(
        
        children: [
          Container(
            width: 700,
            height: 102,
            padding: const EdgeInsets.all(15),
            color: Color(0xFFFDECE8) ,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
               SvgPicture.asset(
                    'assets/images/ChartDonut.svg',
                    width: 30,
                    height: 31,
                    color: Colors.black,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Rekap Keuangan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF181C14),
                      fontSize: 24,
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
         Expanded(
  child: isLoading
      ? Center(child: CircularProgressIndicator())
      : errorMessage.isNotEmpty
          ? Center(child: Text(errorMessage))
          : ListView.builder(
              itemCount: _keluhanData.length,
              itemBuilder: (context, index) {
                var keluhan = _keluhanData[index];
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                  margin: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Tanggal Keluhan: ${keluhan['tanggal_keluhan'] ?? ''}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        keluhan['gambar_keluhan'] != null &&
                                keluhan['gambar_keluhan'].toString().isNotEmpty
                            ? Image.network(
                                "${ApiUrls.baseUrl}${keluhan['gambar_keluhan']}",
                                height: 150,
                                errorBuilder: (context, error, stackTrace) {
                                  print(
                                      "URL Gambar: ${ApiUrls.baseUrl}${keluhan['gambar_keluhan']}");
                                  return Text("Gagal memuat gambar");
                                },
                              )
                            : Text("Tidak ada gambar"),
                        SizedBox(height: 10),
                        Text(
                          "No Kavling: ${keluhan['identitas'] ?? 'Tanpa Nama'}",
                          style: TextStyle(fontWeight: FontWeight.normal),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Masukan/Keluhan Warga:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            keluhan['keluhan'] ?? '',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Tanggapan Pengurus RT:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            keluhan['jawaban']?.isNotEmpty == true
                                ? keluhan['jawaban']!
                                : '-',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
),

        ],
      ),
    );
  }


}
