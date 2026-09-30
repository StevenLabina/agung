import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


import 'package:iuran_rt_web/url.dart';



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

class TambahCOAPage extends StatefulWidget {
  @override
  _TambahCOAPageState createState() => _TambahCOAPageState();
}

class _TambahCOAPageState extends State<TambahCOAPage> {
  final TextEditingController _coaController =
      TextEditingController();

  final TextEditingController _ketcoaController =
      TextEditingController();
  
  String getMonthShortName(int month) {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des"
    ];
    return months[month - 1];
  }

  String? jenisCoa;

 
  List<String> rtOptions = [
    "Pendapatan", 
    "Pengeluaran", 
    "Utang"
  ];

  @override
  void initState() {
    super.initState();
   
  }

  
    Future<void> tambahDataCOA(
      String coa, String keterangan, String jenis) async {
 
  
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambah_coa.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "coa": coa,
        "ket_coa": keterangan,
        "jenis_coa": jenis,
       
        'id_rt': KodeRt.kodeRt
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] == 'success') {
        Flushbar(
        message: 'Data berhasil disimpan',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } else {
      Flushbar(
        message: 'Gagal menyimpan data: ${data['message']}',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_coaController.text.isEmpty ||
        _ketcoaController.text.isEmpty ||
        jenisCoa.toString().isEmpty || jenisCoa == null) {
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
        return AlertDialog(
          backgroundColor: Color(0xFFFDECE8),
          title:
              Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
            content:    Text('${jenisCoa}'
              '\nKeterangan COA: ${_coaController.text}'
           

          
              '\nKode COA: ${_ketcoaController.text}'
              '\n==================================='
               '\nApakah anda yakin ingin menyimpan data COA ini?',
              style: GoogleFonts.lato(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: Text('Batal',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Simpan',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
              onPressed: () async {
                await tambahDataCOA(_coaController.text, _ketcoaController.text, jenisCoa.toString());
                // Navigator.pushReplacement(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => LaporanKeuanganPengeluaranPage(
                //       month: monthShort,
                //       numberMonth: numberMonth.toString(),
                //     ),
                //   ),
                // );
                
                setState(() {
                  _coaController.clear();
                  _ketcoaController.clear();
                  
                  jenisCoa = null;
                });
              },
            ),
          ],
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Text(
                            'Form Input Biaya',
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildRtDropdownField(),
                      SizedBox(height: 16),
                      _buildInputField(context, _ketcoaController,
                          'Keterangan COA', Icons.description),
                      SizedBox(height: 16),
                      _buildSaldoField(context, _coaController,
                          'Kode COA', Icons.margin),
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Text(
                            'Form Input Kode COA',
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
                      _buildRtDropdownField(),
                      SizedBox(height: 16),
                      _buildInputField(context, _ketcoaController,
                          'Keterangan COA', Icons.description),
                      SizedBox(height: 16),
                      _buildSaldoField(context, _coaController,
                          'Kode COA', Icons.margin),
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




  Widget _buildInputField(BuildContext context,
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
        decoration: InputDecoration(
          icon: Icon(icon),
          hintText: hintText,
          border: InputBorder.none,
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
        
        ],
        decoration: InputDecoration(
          icon: Icon(icon),
          hintText: hintText,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildRtDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 500,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFFB7B9B6)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.home, color: Colors.black),
              isDense: true,
              border: InputBorder.none,
              hintText: 'Pilih Jenis COA',
            ),
            value: jenisCoa,
            items: rtOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                jenisCoa = newValue;
             
            
              });
            },
            validator: (value) =>
                value == null ? 'Kode COA wajib dipilih' : null,
          ),
        ),
    
      ],
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
