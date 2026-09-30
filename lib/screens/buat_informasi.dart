import 'dart:convert';
import 'dart:io';

import 'package:another_flushbar/flushbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

//import 'package:firebase_messaging/firebase_messaging.dart';
class TambahInformasiPage extends StatefulWidget {
  @override
  _TambahInformasiPageState createState() => _TambahInformasiPageState();
}

class _TambahInformasiPageState extends State<TambahInformasiPage> {
  final TextEditingController _InformasiController = TextEditingController();
  final TextEditingController _1tanggalController = TextEditingController();
  final TextEditingController _2tanggalController = TextEditingController();
  DateTime? _selectedDate;
  String fileName = '';
  File? selectedFile;
  Uint8List? fileBytes;
  String? pdfUrl;

  @override
  void initState() {
    super.initState();
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

  Future<void> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
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
        message: "Tidak ada file yang dipilih",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> simpanInformasi() async {
    try {
      final uri = Uri.parse('${ApiUrls.baseUrl}buatInformasi.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['informasi'] = _InformasiController.text;
      request.fields['tanggal_awal'] = _1tanggalController.text;
      request.fields['tanggal_akhir'] = _2tanggalController.text;
      request.fields['id_rt'] = KodeRt.kodeRt;

      // File hanya dikirim jika ada
      if (kIsWeb && fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes!,
          filename: fileName,
        ));
      } else if (!kIsWeb && selectedFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          selectedFile!.path,
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        await Flushbar(
          message: "Informasi berhasil disimpan",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        await tambahLogAktivitas(
            aktivitas:
                'Membuat informasi dengan isi: ${_InformasiController.text} dan berlaku dari: ${_1tanggalController.text} sampai dengan: ${_2tanggalController.text}');
      } else {
        Flushbar(
          message: "Gagal mengunggah informasi",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: "Terjadi kesalahan: $e",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> _selectDate1(BuildContext context) async {
    // Pilih Tanggal
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 11, minute: 59),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _1tanggalController.text =
              DateFormat('dd-MM-yyyy-HH:mm').format(_selectedDate!);
        });
      }
    }
  }

  Future<void> _selectDate2(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 11, minute: 59),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          _2tanggalController.text =
              DateFormat('dd-MM-yyyy-HH:mm').format(_selectedDate!);
        });
      }
    }
  }

  void _showConfirmationDialog() {
    bool isSaving = false;
    if (_InformasiController.text.isEmpty) {
      Flushbar(
        message: "Informasi tidak boleh kosong",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }

    if (_1tanggalController.text.isEmpty || _2tanggalController.text.isEmpty) {
      Flushbar(
        message: "Tanggal tidak boleh kosong",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDECE8),
              title: Text(
                'Konfirmasi',
                style: GoogleFonts.lato(color: Colors.black),
              ),
              content: Text(
                isSaving
                    ? 'Sedang menyimpan data, mohon tunggu...'
                    : 'Apakah Anda yakin ingin menyimpan data ini?',
                style: GoogleFonts.lato(color: Colors.black),
              ),
              actions: <Widget>[
                if (!isSaving)
                  TextButton(
                    child: Text(
                      'Batal',
                      style: GoogleFonts.lato(
                        color: const Color(0xFF3D8D7A),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await simpanInformasi();

                            if (dialogContext.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MyApp()),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3D8D7A),
                          ),
                        )
                      : Text(
                          'Simpan',
                          style: GoogleFonts.lato(
                            color: const Color(0xFF3D8D7A),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _InformasiController.dispose();
    _1tanggalController.dispose();
    _2tanggalController.dispose();
    super.dispose();
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

  Widget _buildDesktopContent(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
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
                            icon:
                                Icon(Icons.arrow_back_ios, color: Colors.black),
                            onPressed: () => {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MenuPilihanPage(
                                        idMenu: 1,
                                      ),
                                    ),
                                  )
                                }),
                        Text(
                          'Buat Informasi Untuk Warga',
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
            Expanded(
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                child: SingleChildScrollView(
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// KIRI: Box informasi
                        Container(
                          width: 400,
                          height: 500,
                          decoration: BoxDecoration(
                            color: Color(0xFF3D8D7A).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Spacer(),
                              Text(
                                'Informasi 🛈',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Dari pengurus RT kepada Warga',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              Spacer(),
                            ],
                          ),
                        ),

                        SizedBox(width: 32),

                        /// KANAN: Form input
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Informasi yang akan disampaikan"),
                              SizedBox(height: 8),
                              _buildInputField(
                                context,
                                _InformasiController,
                                'Ketik informasi yang akan disampaikan...',
                                Icons.info_outline,
                              ),
                              SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth > 800) {
                                    return _buildDateRangeField(context);
                                  } else {
                                    return Column(
                                      children: [
                                        _buildSingleDateField(
                                            context,
                                            _1tanggalController,
                                            _selectDate1,
                                            'Berlaku dari'),
                                        SizedBox(height: 16),
                                        _buildSingleDateField(
                                            context,
                                            _2tanggalController,
                                            _selectDate2,
                                            'Sampai dengan'),
                                      ],
                                    );
                                  }
                                },
                              ),
                              SizedBox(height: 24),
                              Text("Nama File "),
                              SizedBox(height: 8),
                              _buildFilePickerBox(),
                              SizedBox(height: 32),
                              _buildSubmitButton(),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildMobileContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 232, 226, 226),
                  border: Border.all(
                    color: const Color.fromARGB(255, 58, 112, 50),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        idMenu: 1,
                                      ),
                                    ),
                                  )
                                }),
                        const Text(
                          'Buat Informasi Untuk Warga',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// BOX INFORMASI
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D8D7A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Informasi 🛈',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dari pengurus RT kepada Warga',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// FORM INPUT INFORMASI
              const Text(
                "Informasi yang akan disampaikan",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildInputField(
                context,
                _InformasiController,
                'Ketik informasi yang akan disampaikan...',
                Icons.info_outline,
              ),

              const SizedBox(height: 16),

              /// PILIH TANGGAL
              _buildSingleDateField(
                context,
                _1tanggalController,
                _selectDate1,
                'Berlaku dari',
              ),
              const SizedBox(height: 16),
              _buildSingleDateField(
                context,
                _2tanggalController,
                _selectDate2,
                'Sampai dengan',
              ),

              const SizedBox(height: 24),

              const Text("Nama File",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildFilePickerBox(),

              const SizedBox(height: 32),

              /// TOMBOL SUBMIT
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerBox() {
    return Container(
      width: double.infinity,
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
              controller: TextEditingController(text: fileName),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: 'Nama File',
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
              child: Icon(Icons.upload_file, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context,
      TextEditingController controller, String hintText, IconData icon) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 72,
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
          Icon(icon, color: Color(0xFF909090)),
          SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: hintText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeField(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 72,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFB7B9B6)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.calendar_today, color: Color(0xFF909090)),
                SizedBox(width: 12),
                Text('Berlaku dari'),
                SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate1(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _1tanggalController,
                        textAlign: TextAlign.center,
                        readOnly: true,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          hintText: 'Tanggal',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(Icons.calendar_today, color: Color(0xFF909090)),
          SizedBox(width: 16),
          Text('sampai dengan'),
          SizedBox(width: 16),
          Expanded(
            child: TextButton(
              onPressed: () => _selectDate2(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _2tanggalController,
                  textAlign: TextAlign.center,
                  readOnly: true,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: 'Tanggal',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDateField(BuildContext context,
      TextEditingController controller, Function onTap, String label) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 72,
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
          SizedBox(width: 12),
          Icon(Icons.calendar_today, color: Color(0xFF909090)),
          SizedBox(width: 12),
          Text(label),
          SizedBox(width: 16),
          Expanded(
            child: TextButton(
              onPressed: () => onTap(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  readOnly: true,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: 'Tanggal',
                  ),
                ),
              ),
            ),
          ),
        ],
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
            'Kirim',
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
