import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:another_flushbar/flushbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class BuatWargaPagePdf extends StatefulWidget {
  final String no_kk;

  BuatWargaPagePdf({required this.no_kk});

  @override
  _BuatWargaPagePdfState createState() => _BuatWargaPagePdfState();
}

class _BuatWargaPagePdfState extends State<BuatWargaPagePdf> {
  String fileName = '';
  File? selectedFile;
  Uint8List? fileBytes;
  String? pdfUrl;
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
  Future<void> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        fileName = result.files.single.name;
        if (kIsWeb) {
          fileBytes = result.files.single.bytes;
        } else {
          selectedFile = File(result.files.single.path!);
        }
      });
    } else {
        Flushbar(
        message: 'Tidak ada file yang dipilih.',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
     
    }
  }

  Future<void> uploadPdfToServer() async {
    if ((kIsWeb && fileBytes == null) || (!kIsWeb && selectedFile == null)) {

      Flushbar(
        message: 'Pilih file terlebih dahulu sebelum mengunggah.',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    try {
      final uri = Uri.parse('${ApiUrls.baseUrl}save_path_pdf_kk.php');
      final request = http.MultipartRequest('POST', uri)
        ..fields['no_kk'] = widget.no_kk
        ..fields['id_rt'] = KodeRt.kodeRt
        ..fields['kk'] = 'pemilik';

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes!,
          filename: fileName,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          selectedFile!.path,
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        //final responseBody = await response.stream.bytesToString();
        Flushbar(
          message: 'File PDF KK berhasil diunggah.',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
        await tambahLogAktivitas(aktivitas: "Mengubah/Menambahkan file PDF KK pemilik rumah dengan no KK: ${widget.no_kk}");
      } else {
        Flushbar(
          message: 'Gagal mengunggah file.',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> fetchPdfPath() async {
    final idRt = KodeRt.kodeRt;
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiUrls.baseUrl}/getPdfPath.php?no_kk=${widget.no_kk}&id_rt=${idRt}&kk=pemilik'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          pdfUrl = data['pdf_kk'];
        });
      } else {
        Flushbar(
          message: 'Gagal mengambil data PDF.',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: Duration(seconds: 2),
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
          title: Text("Ketentuan Upload/Update File Kartu Keluarga"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Scan kartu keluarga anda\n'
                  ' (Pastikan hasil scan terlihat jelas dan semua informasi dapat terbaca dengan baik)\n\n'
                  '2. Ubah hasil scan menjadi file berformat PDF\n'
                  ' (Gunakan aplikasi atau perangkat lunak untuk menyimpan hasil scan dalam format PDF)\n\n'
                  '3. Gunakan format penamaan file berikut:\n'
                  ' kartuKeluarga_noKK\n'
                  ' Contoh: kartuKeluarga_123456789113\n\n'
                  '4. Unggah file dengan mengklik tombol di sebelah kanan kolom input teks\n'
                  ' (Pilih file PDF yang sudah Anda buat)\n\n'
                  '5. Setelah memilih file, tekan tombol "Update File KK" untuk menyimpan\n',
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

  Future<void> openPdf() async {
    if (pdfUrl == null || pdfUrl!.isEmpty) {
      Flushbar(
        message: 'No PDF available.',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    final uri = Uri.parse(
        pdfUrl!.startsWith('http') ? pdfUrl! : '${ApiUrls.baseUrl}/$pdfUrl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Flushbar(
        message: 'Tidak dapat membuka PDF',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ketentuanDialog();
    });
    fetchPdfPath();
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
                        'File PDF Kartu Keluarga',
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
          Expanded(
              child: SingleChildScrollView(
            child: Padding(
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
                          Text("Ketentuan Upload/Update File Kartu Keluarga"),
                        ],
                      ),
                      SizedBox(height: 3),
                      InkWell(
                        onTap: _ketentuanDialog,
                        child: Text(
                          'Klik Disini',
                          style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
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
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                readOnly: true,
                                obscureText: false,
                                controller:
                                    TextEditingController(text: fileName),
                                decoration: InputDecoration(
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  hintText: 'Nama File Pdf',
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: ShapeDecoration(
                                color: Color(0xFF3D8D7A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: TextButton(
                                onPressed: pickPdfFile,
                                child: Icon(
                                  Icons.upload_file,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text('Buka File PDF:'),
                      TextButton(
                        onPressed: pdfUrl != null && pdfUrl!.isNotEmpty
                            ? openPdf
                            : null,
                        child: Text(
                          pdfUrl != null && pdfUrl!.isNotEmpty
                              ? pdfUrl!.split('/').last
                              : 'Tidak ada PDF tersedia',
                          style: TextStyle(
                            color: pdfUrl != null && pdfUrl!.isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
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
                            onPressed: () {
                              uploadPdfToServer();
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Update File KK',
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
            ),
          ))
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
                        'File PDF Kartu Keluarga',
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
          Expanded(
              child: SingleChildScrollView(
            child: Padding(
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
                          Text("Ketentuan Upload/Update File Kartu Keluarga"),
                          SizedBox(width: 3),
                          InkWell(
                            onTap: _ketentuanDialog,
                            child: Text(
                              'Klik Disini',
                              style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
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
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                readOnly: true,
                                obscureText: false,
                                controller:
                                    TextEditingController(text: fileName),
                                decoration: InputDecoration(
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  hintText: 'Nama File Pdf',
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: ShapeDecoration(
                                color: Color(0xFF3D8D7A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: TextButton(
                                onPressed: pickPdfFile,
                                child: Icon(
                                  Icons.upload_file,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text('Buka File PDF:'),
                      TextButton(
                        onPressed: pdfUrl != null && pdfUrl!.isNotEmpty
                            ? openPdf
                            : null,
                        child: Text(
                          pdfUrl != null && pdfUrl!.isNotEmpty
                              ? pdfUrl!.split('/').last
                              : 'Tidak ada PDF tersedia',
                          style: TextStyle(
                            color: pdfUrl != null && pdfUrl!.isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
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
                            onPressed: () {
                              uploadPdfToServer();
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Update File KK',
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
            ),
          ))
        ],
      ),
    );
  }
}
