import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:csv/csv.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';


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

class BuatWargaPageCsv extends StatefulWidget {
  @override
  _BuatWargaCsvPageState createState() => _BuatWargaCsvPageState();
}

class _BuatWargaCsvPageState extends State<BuatWargaPageCsv> {
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
    const excelPath = 'uploads/Template_Data_Warga.xlsx';

    final excelUrl = Uri.parse(excelPath.startsWith('https')
        ? excelPath
        : '${ApiUrls.baseUrl}$excelPath');

    if (await canLaunchUrl(excelUrl)) {
      await launchUrl(excelUrl, mode: LaunchMode.externalApplication);
       Flushbar(
          message: "Unduh Excel...",
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
          message: "Tidak ada data yang diimpor",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
     
      return;
    }

  
    String csvData = const ListToCsvConverter().convert(importedData!);

    // Upload CSV data to server
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}import_warga.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'csv_data': csvData,
        'id_rt': KodeRt.kodeRt
      },
    );

   final result = jsonDecode(response.body);

if (result['result'] == 'success') {
 await Flushbar(
    message: result['message']?.toString() ?? 'Data berhasil diimpor',
    duration: const Duration(seconds: 2),
    backgroundColor: Colors.green,
    flushbarPosition: FlushbarPosition.TOP,
  ).show(context);

  await tambahLogAktivitas(
    aktivitas: 'Menambahkan data warga baru melalui file Excel',
  );
   
} else {
  await Flushbar(
    message: result['message']?.toString() ?? 'Gagal mengimpor data',
    duration: const Duration(seconds: 3),
    backgroundColor: Colors.red,
    flushbarPosition: FlushbarPosition.TOP,
  ).show(context);
}
  }

  void _ketentuanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ketentuan Impor File Excel Data Warga"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Unduh file template Excel "Template Data Warga.xlsx" \n'
                  ' (File ini berisi format yang harus diikuti untuk memasukkan data warga)\n\n'
                  '2. Isi data warga ke dalam file Excel yang sudah diunduh\n'
                  ' (Tambahkan data sesuai format tabel yang tersedia)\n\n'
                  '3. Unggah file dengan mengklik tombol di sebelah kanan kolom input teks\n'
                  ' (Pilih file Excel yang sudah Anda isi)\n\n'
                  '4. Setelah memilih file, tekan tombol "Impor Excel" untuk memproses data\n\n'
                  'Catatan Penting:\n'
                  '-Dilarang menambahkan baris header/judul baru pada bagian atas tabel\n'
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

 bool isImporting = false;

void _showConfirmationDialog() {
  if (fileName!.isEmpty) {
    Flushbar(
      message: "Tidak ada file excel yang diimpor",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Konfirmasi"),
            content: Text(
              isImporting
                  ? "Sedang mengimpor data Excel, mohon tunggu..."
                  : "Apakah Anda yakin ingin mengimpor file Excel ini? "
                    "Pastikan file sudah sesuai dengan ketentuan yang tertera "
                    "sebelum melanjutkan.",
            ),
            actions: [
              TextButton(
                onPressed: isImporting
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: const Text("Tidak"),
              ),

              TextButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        setDialogState(() {
                          isImporting = true;
                        });

                        try {
                          await saveImportedData();

                          if (dialogContext.mounted) {
                            Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isImporting = false;
                          });

                          if (dialogContext.mounted) {
                            Flushbar(
                              message: "Gagal mengimpor data: $e",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(dialogContext);
                          }
                        }
                      },
                child: isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Ya"),
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
                                                 MenuPilihanPage(idMenu: 1,),
                                        ),
                                        )
                          }
                        ),
                        Text(
                          'Buat Data Warga Dengan Excel ',
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
                 
                    Container(
                      width: 567,
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tombol pertama
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => BuatWargaPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 10),
                            ),
                            child: Text(
                              'Manual',
                              style: TextStyle(
                                color: Color(0xFF3D8D7A),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          // Tombol kedua
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3D8D7A),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 10),
                            ),
                            child: Text(
                              'Excel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            'Template Data Warga.xlsx',
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
                                                 MenuPilihanPage(idMenu: 1,),
                                        ),
                                        )
                          }
                        ),
                        Text(
                          'Buat Data Warga Dengan Excel ',
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
          Expanded(child: SingleChildScrollView(child:    Padding(
            padding: const EdgeInsets.all(30),
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                 
                    Container(
                      width: 567,
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tombol pertama
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => BuatWargaPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Manual',
                              style: TextStyle(
                                color: Color(0xFF3D8D7A),
                                fontSize: 18,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          // Tombol kedua
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3D8D7A),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Excel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            'Template Data Warga.xlsx',
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
                  ],
                ),
              ),
            ),
          ), ))
       
        ],
      ),
    );
  }
}
