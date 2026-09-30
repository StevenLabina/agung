import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:csv/csv.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:iuran_rt_web/menu_pilihan.dart';

import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/screens/buat_warga.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TambahTransisiDataIuran extends StatefulWidget {
  @override
  _TambahTransisiDataIuranPageState createState() => _TambahTransisiDataIuranPageState();
}

class _TambahTransisiDataIuranPageState extends State<TambahTransisiDataIuran> {
  String? fileName; 
  List<List<dynamic>>? importedData; 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ketentuanDialog();
    });
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
  Future<void> downloadExcel() async {
    const excelPath = 'uploads/Template_Data_Iuran.xlsx';

    final excelUrl = Uri.parse(excelPath.startsWith('https')
        ? excelPath
        : '${ApiUrls.baseUrl}$excelPath');

    if (await canLaunchUrl(excelUrl)) {
      await launchUrl(excelUrl, mode: LaunchMode.externalApplication);
      Flushbar(
        message: 'Unduh Excel...',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } else {
      Flushbar(
        message: 'Tidak Bisa Unduh Excel file.',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }


  Future<void> pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        fileName = result.files.single.name;
      });

      if (kIsWeb) {
        
        Uint8List fileBytes = result.files.single.bytes!;
        convertExcelToCsv(fileBytes);
      } else {
      
        String path = result.files.single.path!;
        convertExcelToCsvFromPath(path);
      }
    } else {
      Flushbar(
        message: 'Tidak ada file yang dipilih',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  // Method to convert Excel to CSV
  Future<void> convertExcelToCsv(Uint8List fileBytes) async {
    var excel = exc.Excel.decodeBytes(fileBytes);
    List<List<dynamic>> rows = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]?.rows ?? []) {
        List<dynamic> rowData = [];
        for (var cell in row) {
          if (cell != null) {
            rowData.add(cell
                .value); 
          } else {
            rowData.add(""); 
          }
        }
        rows.add(rowData);
      }
    }

    setState(() {
      importedData = rows;
    });
  }

// Method to convert Excel to CSV from path
  Future<void> convertExcelToCsvFromPath(String path) async {
    var bytes = File(path).readAsBytesSync();
    var excel = exc.Excel.decodeBytes(bytes);
    List<List<dynamic>> rows = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]?.rows ?? []) {
        List<dynamic> rowData = [];
        for (var cell in row) {
          if (cell != null) {
            rowData.add(cell.value);
          } else {
            rowData.add("");
          }
        }
        rows.add(rowData);
      }
    }

    setState(() {
      importedData = rows;
    });
  }

Future<void> saveImportedData() async {
  if (importedData == null || importedData!.isEmpty) {
    Flushbar(
      message: "Data yang diimpor kosong",
      duration: Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
    return;
  }

  String csvData = const ListToCsvConverter().convert(importedData!);

  try {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}import_transisi_iuran.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'csv_data': csvData,
        'id_rt': KodeRt.kodeRt,
      },
    );

    final body = response.body.trim();

    if (response.statusCode != 200) {
      throw Exception("Server error ${response.statusCode}\n$body");
    }

    final result = jsonDecode(body);

    if (result['result'] == 'success') {
        await Flushbar(
          message: 'Data iuran berhasil diimpor',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      await tambahLogAktivitas(
        aktivitas: 'Mengimpor data iuran dari file Excel dengan ${importedData!.length} baris data',
      );
        Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
    }  if (result['result'] == 'error') {
      Flushbar(
        message: result['message'] ?? 'Terjadi kesalahan',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }

  } catch (e) {
    Flushbar(
      message: "Terjadi kesalahan koneksi ke server",
      duration: Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kesalahan Server"),
        content: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () =>  Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}


  void _ketentuanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ketentuan Impor File Excel Data Iuran"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Unduh file template Excel "Template Data Iuran.xlsx" \n'
                  ' (File ini berisi format yang harus diikuti untuk memasukkan data iuran)\n\n'
                  '2. Isi data iuran ke dalam file Excel yang sudah diunduh\n'
                  ' (Tambahkan data sesuai format tabel yang tersedia)\n\n'
                  '3. Perhatikan format kolom-kolom tertentu seperti nominal iuran dan tanggal\n'
                   ' (Untuk input banyak cukup copy paste format sesuai contoh pada tiap rownya)\n\n'
                  '4. Unggah file dengan mengklik tombol di sebelah kanan kolom input teks\n'
                  ' (Pilih file Excel yang sudah Anda isi)\n\n'
                  '3. Unggah file dengan mengklik tombol di sebelah kanan kolom input teks\n'
                  ' (Pilih file Excel yang sudah Anda isi)\n\n'
                  '4. Unggah file dengan mengklik tombol di sebelah kanan kolom input teks\n'
                  ' (Pilih file PDF yang sudah Anda buat)\n\n'
                  '5. Setelah memilih file, tekan tombol "Impor Excel" untuk memproses data\n\n'
                  'Catatan Penting:\n'
                  '-Jangan menambahkan baris header/judul baru pada bagian atas tabel\n'
                  '-Pastikan semua data yang dimasukkan sesuai format',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Ya"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog() {
    if (TextEditingController(text: fileName).text.isEmpty) {
      Flushbar(
        message: "Tidak ada file excel yang diimpor",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }
   
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Konfirmasi"),
          content: Text(
              "Apakah Anda yakin ingin mengimpor file Excel ini? Pastikan file sudah sesuai dengan ketentuan yang tertera sebelum melanjutkan."),
          actions: [
            TextButton(
              child: Text("Tidak"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Ya"),
              onPressed: () {
                saveImportedData();
              
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                                 MenuPilihanPage(idMenu: 5),
                                        ),
                                        )
                          }
                        ),
                        Text(
                          'Input Transisi Data Iuran Dengan Excel ',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
          Expanded(child: SingleChildScrollView(child:    Padding(
            padding: const EdgeInsets.all(30),
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                 
               
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Ketentuan kolom excel"),
                        SizedBox(width: 3),
                         InkWell(
                          onTap: _ketentuanDialog, 
                          child: Text(
                            'Klik Disini',
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                       
                      ],
                    ),
                  
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Unduh Template Excel:"),
                        SizedBox(height: 3),
                         InkWell(
                          onTap: downloadExcel, 
                          child: Text(
                            'Template Data Iuran.xlsx',
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
        
                      ],
                    ),

                    SizedBox(height: 20),

                    Container(
                      width: 500,
                      height: 80,
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
                          // TextField di kiri
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              readOnly: true,
                              obscureText: false,
                              controller: TextEditingController(text: fileName),
                              decoration: InputDecoration(
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                hintText: 'Tidak Ada File Yang Dipilih',
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Tombol di kanan
                          Container(
                            width: 100,
                            height: 60,
                            decoration: ShapeDecoration(
                              color: Color(0xFF3D8D7A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: TextButton(
                              onPressed: pickExcelFile,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white, 
                              ),
                              child: Text("Pilih File"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    Center(
                      child: Container(
                        width: 480,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: Color(0xFF3D8D7A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: TextButton(
                          onPressed: _showConfirmationDialog,
                          child: Text(
                            'Impor Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Figtree',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), ))
       
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                                 MenuPilihanPage(idMenu: 5),
                                        ),
                                        )
                          }
                        ),
                        Text(
                          'Input Transisi Data Iuran Dengan Excel ',
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
            const SizedBox(height: 20,),
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
                              "Tambah\nData Iuran Dengan Excel 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Pengurus RT menambahkan\ndata iuran yang belum terdaftarkan pada sistem RT Digital",
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
                                Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Ketentuan kolom excel"),
                        SizedBox(width: 3),
                         InkWell(
                          onTap: _ketentuanDialog, 
                          child: Text(
                            'Klik Disini',
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                       
                      ],
                    ),
                  
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Unduh Template Excel:"),
                        SizedBox(width: 3),
                         InkWell(
                          onTap: downloadExcel, 
                          child: Text(
                            'Template Data Iuran.xlsx',
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
        
                      ],
                    ),

                    SizedBox(height: 20),

                    Container(
                      width: 500,
                      height: 80,
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
                          // TextField di kiri
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              readOnly: true,
                              obscureText: false,
                              controller: TextEditingController(text: fileName),
                              decoration: InputDecoration(
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                hintText: 'Tidak Ada File Yang Dipilih',
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Tombol di kanan
                          Container(
                            width: 100,
                            height: 60,
                            decoration: ShapeDecoration(
                              color: Color(0xFF3D8D7A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: TextButton(
                              onPressed: pickExcelFile,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white, 
                              ),
                              child: Text("Pilih File"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    Center(
                      child: Container(
                        width: 500,
                        height: 60,
                        decoration: ShapeDecoration(
                          color: Color(0xFF3D8D7A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: TextButton(
                          onPressed: _showConfirmationDialog,
                          child: Text(
                            'Impor Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Figtree',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
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
    );
  }
}
