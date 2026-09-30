import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/screens/data_warga.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditDataWargaPage extends StatefulWidget {
  final int id;

  EditDataWargaPage({required this.id});

  @override
  _EditDataWargaPageState createState() => _EditDataWargaPageState();
}

class _EditDataWargaPageState extends State<EditDataWargaPage> {
  final TextEditingController _noKavlingController = TextEditingController();
  final TextEditingController _namaPenanggungJawabController =
      TextEditingController();
  final TextEditingController _namaPemilikRumahController =
      TextEditingController();
  final TextEditingController _alamatKavlingController =
      TextEditingController();
  final TextEditingController _noTelponPemilikRumahController =
      TextEditingController();
  final TextEditingController _noTelponPenanggungJawabController =
      TextEditingController();
  final TextEditingController _noKkPemilikRumahController =
      TextEditingController();
  final TextEditingController _noKkPenanggungJawabController =
      TextEditingController();
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchWargaData();
  }

  Future<void> fetchWargaData() async {
    final idRt = KodeRt.kodeRt;
    try {
      final response = await http.get(
        Uri.parse(
            "${ApiUrls.baseUrl}/getWarga.php?id=${widget.id}&id_rt=$idRt"),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] == 'success') {
          setState(() {
            _noKavlingController.text = json['data']['no_kavling'];
            _namaPenanggungJawabController.text =
                json['data']['nama_penanggung_jawab'];
            _namaPemilikRumahController.text =
                json['data']['nama_pemilik_rumah'];
            _alamatKavlingController.text = json['data']['alamat_kavling'];
            _noTelponPemilikRumahController.text =
                json['data']['no_telpon_pemilik_rumah'];
            _noTelponPenanggungJawabController.text =
                json['data']['no_telpon_penanggung_jawab'];
            _noKkPemilikRumahController.text =
                json['data']['no_kk_pemilik_rumah'];
            _noKkPenanggungJawabController.text =
                json['data']['no_kk_penanggung_jawab'];
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
  // Future<void> kirimNotifikasiWA() async {
  //   final urlNotifikasiWA = '${ApiUrls.baseUrl}/send_whatsapp_pengurus.php';
  //   try {
  //     final responseNotifikasiWA = await http.post(
  //       Uri.parse(urlNotifikasiWA),
  //       body: {
  //         'msg':
  //             "PENGUMUMAN IURAN RT ONLINE\nProfil Warga Anda telah diupdate",
  //         'id': widget.id.toString(),
  //       },
  //     );

  //     if (responseNotifikasiWA.statusCode == 200) {
  //       final jsonResponseNotifikasiWA = jsonDecode(responseNotifikasiWA.body);

  //       // Konversi status menjadi integer untuk memastikan kompatibilitas
  //       final status = jsonResponseNotifikasiWA['status'];
  //       final statusInt =
  //           status is int ? status : int.tryParse(status.toString()) ?? 0;

  //       if (statusInt == 1) {
  //         print('Notifikasi WhatsApp berhasil dikirim');
  //       } else {
  //         print(
  //             'Gagal mengirim notifikasi WhatsApp: ${jsonResponseNotifikasiWA['reason']}');
  //       }
  //     } else {
  //       print(
  //           'Gagal mengirim notifikasi WhatsApp: ${responseNotifikasiWA.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error: Gagal terhubung ke server WhatsApp $e');
  //   }
  // }
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

  Future<void> updateWargaData() async {
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/updateWarga.php"),
        body: {
          'id': widget.id.toString(),
          'no_kavling': _noKavlingController.text,
          'nama_penanggung_jawab': _namaPenanggungJawabController.text,
          'nama_pemilik_rumah': _namaPemilikRumahController.text,
          'alamat_kavling': _alamatKavlingController.text,
          'no_telpon_pemilik_rumah': _noTelponPemilikRumahController.text,
          'no_telpon_penanggung_jawab': _noTelponPenanggungJawabController.text,
          'no_kk_pemilik_rumah': _noKkPemilikRumahController.text,
          'no_kk_penanggung_jawab': _noKkPenanggungJawabController.text,
          'id_rt': KodeRt.kodeRt
        },
      );

      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        if (_noKavlingController.text.isEmpty &&
            _alamatKavlingController.text.isEmpty &&
            _namaPemilikRumahController.text.isEmpty &&
            _namaPenanggungJawabController.text.isEmpty &&
            _noKkPemilikRumahController.text.isEmpty &&
            _noKkPenanggungJawabController.text.isEmpty &&
            _noTelponPemilikRumahController.text.isEmpty &&
            _noTelponPenanggungJawabController.text.isEmpty) {
          Flushbar(
            message: "Tidak boleh kosong",
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);

          return;
        }
        Flushbar(
          message: "Update data warga berhasil",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        await tambahLogAktivitas(
            aktivitas: 'Mengupdate data warga: ${_noKavlingController.text}');
        fetchWargaData();

        Navigator.pop(context, {
          "status": true,
          "kavling": _noKavlingController.text,
        });
       
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(json['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update data: $e")),
      );
    }
  }

void _showConfirmationDialog() {
  bool isUpdatingWarga = false;
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
              style: GoogleFonts.lato(
                color: Colors.black,
              ),
            ),

            content: Text(
              isUpdatingWarga
                  ? 'Sedang memperbarui data warga, mohon tunggu...'
                  : 'Apakah Anda yakin ingin memperbarui data warga ini?',
              style: GoogleFonts.lato(
                color: Colors.black,
              ),
            ),

            actions: [
              TextButton(
                onPressed: isUpdatingWarga
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: Text(
                  'Batal',
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3D8D7A),
                  ),
                ),
              ),

              TextButton(
                onPressed: isUpdatingWarga
                    ? null
                    : () async {
                        setDialogState(() {
                          isUpdatingWarga = true;
                        });

                        try {
                          await updateWargaData();

                          if (dialogContext.mounted) {
                           Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DataPendudukPage()),
        );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isUpdatingWarga = false;
                          });

                          if (dialogContext.mounted) {
                            Flushbar(
                              message: "Gagal memperbarui data: $e",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(dialogContext);
                          }
                        }
                      },

                child: isUpdatingWarga
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3D8D7A),
                        ),
                      )
                    : Text(
                        'Ya',
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
                        'Ubah Data Warga',
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

          // ISI HALAMAN
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
                              "Ubah\nData Warga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Pengurus RT mengubah data warga secara manual\nsesuai permintaan warga",
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
                          child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Kavling',
                                      style: TextStyle(
                                          color: Color(0xFF909090),
                                          fontSize: 18)),
                                  Container(
                                    width: 1000,
                                    padding: const EdgeInsets.all(16),
                                    decoration: ShapeDecoration(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Color(0xFFB7B9B6)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // No Kavling
                                        Text(
                                          'No Kavling',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _noKavlingController,
                                                enabled: false,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'No Kavling',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 16),

                                        // Alamat Kavling
                                        Text(
                                          'Alamat Kavling',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.location_city,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _alamatKavlingController,
                                                enabled: false,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'Alamat Kavling',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text('Pemilik Rumah',
                                      style: TextStyle(
                                          color: Color(0xFF909090),
                                          fontSize: 18)),
                                  Container(
                                    width: 1000,
                                    padding: const EdgeInsets.all(16),
                                    decoration: ShapeDecoration(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Color(0xFFB7B9B6)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Nama
                                        Text(
                                          'Nama',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _namaPemilikRumahController,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'Nama',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 16),

                                        // No KK
                                        Text(
                                          'No KK',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                inputFormatters: [
                                                  LengthLimitingTextInputFormatter(
                                                      16)
                                                ],
                                                controller:
                                                    _noKkPemilikRumahController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'No KK',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 16),

                                        Text(
                                          'No Telpon',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.call,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                inputFormatters: [
                                                  LengthLimitingTextInputFormatter(
                                                      15)
                                                ],
                                                controller:
                                                    _noTelponPemilikRumahController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'No Telpon',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text('Penghuni',
                                      style: TextStyle(
                                          color: Color(0xFF909090),
                                          fontSize: 18)),
                                  Container(
                                    width: 1000,
                                    padding: const EdgeInsets.all(16),
                                    decoration: ShapeDecoration(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Color(0xFFB7B9B6)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Nama
                                        Text(
                                          'Nama',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _namaPenanggungJawabController,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'Nama',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 16),

                                        // No KK
                                        Text(
                                          'No KK',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                inputFormatters: [
                                                  LengthLimitingTextInputFormatter(
                                                      16)
                                                ],
                                                controller:
                                                    _noKkPenanggungJawabController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'No KK',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 16),

                                        Text(
                                          'No Telpon',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.call,
                                                color: Color(0xFF909090)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                inputFormatters: [
                                                  LengthLimitingTextInputFormatter(
                                                      15)
                                                ],
                                                controller:
                                                    _noTelponPenanggungJawabController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  hintText: 'No Telpon',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Center(
                                    child: Container(
                                      width: 600,
                                      height: 72,
                                      decoration: ShapeDecoration(
                                        color: Color(0xFF3D8D7A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: _showConfirmationDialog,
                                        child: Text(
                                          'Simpan',
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
                      )),
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
                        'Ubah Data Warga',
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
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Kavling',
                          style: TextStyle(
                              color: Color(0xFF909090), fontSize: 18)),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // No Kavling
                            Text(
                              'No Kavling',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _noKavlingController,
                                    enabled: false,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No Kavling',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // Alamat Kavling
                            Text(
                              'Alamat Kavling',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_city,
                                    color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _alamatKavlingController,
                                    enabled: false,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'Alamat Kavling',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Pemilik Rumah',
                          style: TextStyle(
                              color: Color(0xFF909090), fontSize: 18)),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama
                            Text(
                              'Nama',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _namaPemilikRumahController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'Nama',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // No KK
                            Text(
                              'No KK',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(16)
                                    ],
                                    controller: _noKkPemilikRumahController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No KK',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            Text(
                              'No Telpon',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.call, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(15)
                                    ],
                                    controller: _noTelponPemilikRumahController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No Telpon',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Penghuni',
                          style: TextStyle(
                              color: Color(0xFF909090), fontSize: 18)),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama
                            Text(
                              'Nama',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _namaPenanggungJawabController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'Nama',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // No KK
                            Text(
                              'No KK',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(16)
                                    ],
                                    controller: _noKkPenanggungJawabController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No KK',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            Text(
                              'No Telpon',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.call, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(15)
                                    ],
                                    controller:
                                        _noTelponPenanggungJawabController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No Telpon',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 600,
                          height: 72,
                          decoration: ShapeDecoration(
                            color: Color(0xFF3D8D7A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: TextButton(
                            onPressed: _showConfirmationDialog,
                            child: Text(
                              'Simpan',
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
          )),
        ],
      ),
    );
  }
}
