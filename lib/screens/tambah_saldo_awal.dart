import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';

//import 'package:iuran_rt_web/screens/laporan_keuangan_pendapatan.dart';

import 'package:iuran_rt_web/url.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');
    final formatted = _formatter.format(int.parse(digitsOnly));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class TambahSaldoAwalPage extends StatefulWidget {
  @override
  _TambahSaldoAwalPageState createState() => _TambahSaldoAwalPageState();
}

class _TambahSaldoAwalPageState extends State<TambahSaldoAwalPage> {

       final TextEditingController _nominalSaldoAwalController =
      TextEditingController();
 String? selectedMetode;
String saldoAwal = "";



  @override
  void initState() {
    super.initState();
    fetchSaldoAwal();
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
Future<void> fetchSaldoAwal() async {
  final response = await http.get(
    Uri.parse(
      '${ApiUrls.baseUrl}getSaldoAwal.php?id_rt=${KodeRt.kodeRt}',
    ),
  );

  final data = jsonDecode(response.body);

  if (data['result'] == 'success') {
    final saldo = data['data']['saldo_awal'];

    setState(() {
    saldoAwal = 
          NumberFormat.decimalPattern('id').format(int.parse(saldo));
    });
  }
}

Future<void> tambahDataLaporan(
  String tanggalCreate,
  String tanggalUpdate,
  String saldo,
  String metode
) async {
    final prefs = await SharedPreferences.getInstance();
    String? noKavling = prefs.getString('noKavling');
  try {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambahSaldoAwal.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "create_date": tanggalCreate,
        "update_date": tanggalUpdate,
        "saldo_awal": saldo.replaceAll('.', ''), 
        "id_rt": KodeRt.kodeRt,
        "no_kavling": noKavling.toString(),
        "metode": metode
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
     
 
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(data['message']),
    duration: Duration(seconds: 8), 
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: 'OK',
      onPressed: () {

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
    ),
  ),
);

    
      if (data['result'] == 'success') {
        await tambahLogAktivitas(
          aktivitas: 'Menambahkan saldo awal dengan Nominal: $saldo',
        );
       await fetchSaldoAwal();
       setState(() {
        _nominalSaldoAwalController.clear();
      });
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (context) => TambahSaldoAwalPage()),
       );
      }
    } else {
      Flushbar(
        message: "Terjadi kesalahan koneksi server",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  } catch (e) {
    Flushbar(
      message: "Error: $e",
      duration: Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }
}

  Future<void> _showConfirmationDialog() async {
   
      final String nowFormatted =
    DateFormat('dd-MM-yyyy-HH:mm').format(DateTime.now());
       final String updateFormatted =
    DateFormat('dd-MM-yyyy-HH:mm').format(DateTime.now());


 if (_nominalSaldoAwalController.text.isEmpty ) {
      Flushbar(
        message: "Data tidak lengkap",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }
  
  showDialog(
  context: context,
  builder: (context) {
 
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDECE8),
          title: Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal Dibuat: $nowFormatted'),
                Text('Tanggal Diperbarui: $updateFormatted'),
                Text('Nominal Saldo Awal: ${_nominalSaldoAwalController.text}'),
                const Divider(thickness: 1, color: Colors.grey),
                const SizedBox(height: 10),
                Text('Metode Pembayaran (Wajib):',
                    style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedMetode,
                      hint: const Text("Pilih Metode"),
                      items: <String>['Bayar Tunai', 'Transfer'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                    
                        setDialogState(() {
                          selectedMetode = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text('Apakah anda yakin ingin menyimpan data pendapatan ini?',
                    style: GoogleFonts.lato(color: Colors.black, fontSize: 13)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal', style: GoogleFonts.lato(color: const Color(0xFF3D8D7A))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Simpan', style: GoogleFonts.lato(color: const Color(0xFF3D8D7A))),
              onPressed: () async {
                if (selectedMetode == null) {
                
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pilih metode pembayaran!")),
                  );
                  return;
                }

                await tambahDataLaporan(
                  nowFormatted, 
                  updateFormatted, 
                  _nominalSaldoAwalController.text,
                  selectedMetode!,
                );

                if (mounted) {
                  setState(() {
                    _nominalSaldoAwalController.clear();
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => TambahSaldoAwalPage()),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  },
);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        return Scaffold(
          body: isMobile
              ? _buildDesktopContent(context)
              : _buildMobileContent(context),
        );
      },
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 1200,
                  height: 80,
                  margin: EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 232, 226, 226),
                    border: Border.all(
                      color: Color.fromARGB(255, 58, 112, 50),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon:
                                Icon(Icons.arrow_back_ios, color: Colors.black),
                         onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 5),
                                        ),
                                        )
                          }

                          ),
                          Text(
                            'Form Input Saldo Awal',
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
              SizedBox(height: 20),
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
                      // CARD KIRI
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
                              "Tambah\nSaldo Awal 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Pengurus RT menambahkan\nsaldo awal saat menggunakan sistem RT Digital",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 50),

                      // FORM KANAN
                      Expanded(
                        child: SizedBox(
                          height: 580,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Text(
                            'Saldo Awal: Rp ${saldoAwal}',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              decoration: TextDecoration.none,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                      _buildSaldoField(context, _nominalSaldoAwalController,
                          'Saldo Awal', Icons.money),
                      SizedBox(height: 16),
                      _buildSubmitButton(),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
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
        
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 1200,
                  height: 80,
                  margin: EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 232, 226, 226),
                    border: Border.all(
                      color: Color.fromARGB(255, 58, 112, 50),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon:
                                Icon(Icons.arrow_back_ios, color: Colors.black),
                              onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 5),
                                        ),
                                        )
                          }

                          ),
                          Text(
                            'Form Input Saldo Awal',
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
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                          Text(
                            'Saldo Awal: Rp ${saldoAwal}',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              decoration: TextDecoration.none,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        _buildSaldoField(context, _nominalSaldoAwalController,
                          'Saldo Awal', Icons.money),
                      SizedBox(height: 16),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }






  Widget _buildSaldoField(BuildContext context,
      TextEditingController controller, String hintText, IconData icon) {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFB7B9B6)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(),
        ],
        decoration: InputDecoration(
          icon: Icon(icon),
          hintText: hintText,
          border: InputBorder.none,
        ),
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
            'Tambah',
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
