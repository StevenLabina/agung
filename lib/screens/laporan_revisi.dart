import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LaporanRevisiDataPage extends StatefulWidget {
  @override
  _LaporanRevisiDataPageState createState() => _LaporanRevisiDataPageState();
}

class _LaporanRevisiDataPageState extends State<LaporanRevisiDataPage> {
  List<dynamic> _revisiData = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchRevisiData();
  }

Future<void> fetchRevisiData() async {
  final idRt = KodeRt.kodeRt;

  try {
    final response = await http.post(
      Uri.parse("${ApiUrls.baseUrl}/listRevisiData.php"),
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
          _revisiData = json['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = json['message'];
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = 'Failed to load data';
        isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Failed to connect to server';
      isLoading = false;
    });
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
  Future<void> kirimNotifikasiWA(String id) async {
    final urlNotifikasiWA = '${ApiUrls.baseUrl}/whatsapp_api_1.php';
    try {
      final responseNotifikasiWA = await http.post(
        Uri.parse(urlNotifikasiWA),
        body: {
        'msg':
              'Halo, data warga anda telah diperbarui ',
          'id': id,
        },
      );

      if (responseNotifikasiWA.statusCode == 200) {
        final jsonResponseNotifikasiWA = jsonDecode(responseNotifikasiWA.body);
        final status = jsonResponseNotifikasiWA['status'];
        final statusInt =
            status is int ? status : int.tryParse(status.toString()) ?? 0;

        if (statusInt == 1) {
          print('Notifikasi WhatsApp berhasil dikirim');
        } else {
          print(
              'Gagal mengirim notifikasi WhatsApp: ${jsonResponseNotifikasiWA['reason']}');
        }
      } else {
        print(
            'Gagal mengirim notifikasi WhatsApp: ${responseNotifikasiWA.statusCode}');
      }
    } catch (e) {
      print('Error: Gagal terhubung ke server WhatsApp $e');
    }
  }
 Future<void> deleteRevisiData(String id) async {
  try {
    final response = await http.post( 
      Uri.parse("${ApiUrls.baseUrl}/deleteLaporan.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(
        {
          'id': id,
          'id_rt' : KodeRt.kodeRt
        }), 
    );

    final json = jsonDecode(response.body);
    if (json['result'] == 'success') {
      setState(() {
        _revisiData.removeWhere(
            (item) => item['id'] == id); 
      });
      await fetchRevisiData();
      Flushbar(
        message: "Saran perubahan data warga terhapus",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
   
      await tambahLogAktivitas(aktivitas: "Menghapus laporan revisi perubahan data warga dengan id: $id");
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(json['message'])));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to delete record: $e")),
    );
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
  return Scaffold(
    body: Column(
      children: [
        // Header bar
        Container(
          width: double.infinity,
          height: 70,
          margin: EdgeInsets.only(top: 12, left: 8, right: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 232, 226, 226),
            border: Border.all(
              color: Color.fromARGB(255, 58, 112, 50),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
                  onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 4,),
                                        ),
                                        )
                          }
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengajuan Perubahan Data',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.none),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Body utama
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          errorMessage,
                          style: GoogleFonts.lato(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: _revisiData.length,
                      itemBuilder: (context, index) {
                        final revisi = _revisiData[index];
                        return _buildCardMobile(revisi, context);
                      },
                    ),
        ),
      ],
    ),
  );
}

Widget _buildCardMobile(Map revisi, BuildContext context) {
  String penanggungJawab = revisi['nama_penanggung_jawab'] ?? 'N/A';
  String noKavling = revisi['no_kavling'] ?? 'N/A';
  String noTelponPenanggungJawab =
      revisi['no_telpon_penanggung_jawab'] ?? 'N/A';

  return Container(
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Card(
      color: Color(0xFF3D8D7A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Revisi info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xA3D1C6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Revisi:',
                          style: GoogleFonts.lato(
                              fontSize: 14, color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${revisi['revisi']}',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Info tambahan
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.location_on, 'No Kavling: $noKavling'),
                SizedBox(height: 4),
                _buildInfoRow(Icons.person, 'Nama Penghuni: $penanggungJawab'),
                SizedBox(height: 4),
                _buildInfoRow(
                    Icons.phone, 'Telpon Penghuni: $noTelponPenanggungJawab'),
              ],
            ),

            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
              onPressed: () {
                deleteRevisiData(revisi['id'].toString());
              },
              child: Text('Hapus',
                  style: GoogleFonts.lato(color: Colors.black)),
            ),
          ],
        ),
      ),
    ),
  );
}


Widget _buildInfoRow(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, color: Colors.white),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 4,),
                                        ),
                                        )
                          }
                ),
                Text(
                  'Pengajuan Perubahan Data Dari Warga',
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
                              "Pengajuan Perubahan\nData Dari Warga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Daftar data pengajuan perubahan\ndata datari warga melalui sistem",
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
                            style: GoogleFonts.lato(color: Colors.black)))
                    : ListView.builder(
                        itemCount: _revisiData.length,
                        itemBuilder: (context, index) {
                          final revisi = _revisiData[index];
                        
                          return _buildCard(revisi);
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
  );
}



Widget _buildCard(Map revisi) {

  String penanggungJawab = revisi['nama_penanggung_jawab'] ?? 'N/A';
  String noKavling = revisi['no_kavling'] ?? 'N/A';
  String noTelponPenanggungJawab = revisi['no_telpon_penanggung_jawab'] ?? 'N/A';

 return Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 900),
    child: Container(
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
                    child: Card(
                      color: Color(0xA3D1C6),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: [
                                Icon(Icons.home, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Revisi:',
                                  style: GoogleFonts.lato(
                                      fontSize: 14, color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${revisi['revisi']}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (MediaQuery.of(context).size.width > 900) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'No Kavling: $noKavling',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Nama Penghuni: $penanggungJawab',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Telpon Penghuni: $noTelponPenanggungJawab',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (MediaQuery.of(context).size.width <= 900) ...[
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'No Kavling: $noKavling',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Nama Penghuni: $penanggungJawab',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Telpon Penghuni: $noTelponPenanggungJawab',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                ),
                onPressed: () {
                  deleteRevisiData(revisi['id'].toString());
                },
                child: Text('Hapus',
                    style: GoogleFonts.lato(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

}

void main() {
  runApp(MaterialApp(
    home: LaporanRevisiDataPage(),
  ));
}
}