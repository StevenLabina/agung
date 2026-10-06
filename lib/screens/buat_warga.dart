import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/main.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/buat_warga_csv.dart';
import 'package:iuran_rt_web/screens/data_ipl.dart';
import 'package:iuran_rt_web/screens/data_iuran.dart' hide ThousandsSeparatorInputFormatter;
import 'dart:convert';

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuatWargaPage extends StatefulWidget {
  @override
  _BuatWargaPageState createState() => _BuatWargaPageState();
}

class _BuatWargaPageState extends State<BuatWargaPage> {
  final TextEditingController noKavlingController = TextEditingController();
  final TextEditingController alamatKavlingController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController namaPemilikController = TextEditingController();
  final TextEditingController noTelponPemilikController =
      TextEditingController();
  final TextEditingController nikPemilikController = TextEditingController();

  final TextEditingController tanggalLahirPemilikController =
      TextEditingController();

  final TextEditingController pekerjaanPemilikController =
      TextEditingController();
  final TextEditingController noKKPemilikController = TextEditingController();
  String? selectedAgamaPemilik;
  String? selectedJenisKelaminPemilik;
  final List<String> jenjangPendidikanOptions = [
    'SMA/SMK',
    'D1',
    'D2',
    'D3',
    'S1/D4',
    'S2',
    'S3'
  ];
  List<dynamic> provincesPemilik = [];
  List<dynamic> regenciesPemilik = [];
  List<dynamic> districtsPemilik = [];
  List<dynamic> provincesPenanggung = [];
  List<dynamic> regenciesPenanggung = [];
  List<dynamic> districtsPenanggung = [];
  final List<String> agamaOptions = [
    'Islam',
    'Katolik',
    'Kristen',
    'Hindu',
    'Budha',
    'Konghucu',
    'Lainnya'
  ];
  final List<String> jenisKelaminOptions = ['Laki-laki', 'Perempuan'];

  final TextEditingController noKKPenanggungJawabController =
      TextEditingController();
  final TextEditingController namaPenanggungJawabController =
      TextEditingController();

  final TextEditingController noTelponPenanggungJawabController =
      TextEditingController();
  final TextEditingController nikPenanggungJawabController =
      TextEditingController();
  final TextEditingController tempatLahirPenanggungJawabController =
      TextEditingController();
  final TextEditingController tanggalLahirPenanggungJawabController =
      TextEditingController();

  final TextEditingController pekerjaanPenanggungJawabController =
      TextEditingController();
  final TextEditingController nomIplController = TextEditingController();
  String? selectedAgamaPenanggungJawab;
  String? selectedJenisKelaminPenanggungJawab;
  String? selectedJenjangPendidikanPenanggungJawab;
  String? selectedJenjangPendidikanPenghuni;
  String? selectedProvincePemilik;
  String? selectedRegencyPemilik;
  String? selectedDistrictPemilik;
  String? selectedProvincePenanggungJawab;
  String? selectedRegencyPenanggungJawab;
  String? selectedDistrictPenanggungJawab;
  bool obscureText = true;
  @override
  void initState() {
    super.initState();
    getProvinces();
  }

  Future<void> getProvinces() async {
    final response = await http.get(
      Uri.parse("${ApiUrls.baseUrl}lokasi_id.php?type=provinces"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
        provincesPemilik = json['data'];
        provincesPenanggung = json['data'];
      });
    }
  }

  Future<void> getRegencies(String provinceCode, String user) async {
    final response = await http.get(
      Uri.parse(
          "${ApiUrls.baseUrl}lokasi_id.php?type=regencies&province=$provinceCode"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
        if (user == "Pemilik") {
          regenciesPemilik = json['data'];
          selectedRegencyPemilik = null;
          districtsPemilik.clear();
        }
        if (user == "Penanggung") {
          regenciesPenanggung = json['data'];
          selectedRegencyPenanggungJawab = null;
          districtsPenanggung.clear();
        }
      });
    }
  }

  Future<void> getDistricts(String regencyCode, String user) async {
    final response = await http.get(
      Uri.parse(
          "${ApiUrls.baseUrl}lokasi_id.php?type=districts&regency=$regencyCode"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
      
        if (user == "Pemilik") {
           districtsPemilik = json['data'];
          selectedDistrictPemilik = null;
          
        }
        if (user == "Penanggung") {
            districtsPenanggung = json['data'];
          selectedDistrictPenanggungJawab = null;
        }
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

  Future<void> submitData() async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/tambahDataWarga.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        //Akun
        'no_kavling': noKavlingController.text,
        'alamat_kavling': alamatKavlingController.text,
        'password': passwordController.text,

        //Pemilik Rumah
        'nama_pemilik_rumah': namaPemilikController.text,
        'no_telpon_pemilik': noTelponPemilikController.text,
        'nik_pemilik': nikPemilikController.text,
        'tempat_lahir_provinsi_pemilik': selectedProvincePemilik.toString(),
        'tempat_lahir_kota_pemilik': selectedRegencyPemilik.toString(),
        'tempat_lahir_kecamatan_pemilik': selectedDistrictPemilik.toString(),

        'status_pendidikan_pemilik':
            selectedJenjangPendidikanPenghuni.toString(),
        'jenis_pekerjaan_pemilik': pekerjaanPemilikController.text,
        'tanggal_lahir_pemilik': tanggalLahirPemilikController.text,
        'agama_pemilik': selectedAgamaPemilik.toString(),
        'jenis_kelamin_pemilik': selectedJenisKelaminPemilik.toString(),
        'no_kk_pemilik': noKKPemilikController.text,

        //Penanggung Jawab
        'nama_penanggung_jawab': namaPenanggungJawabController.text,
        'no_telpon_penanggung_jawab': noTelponPenanggungJawabController.text,
        'nik_penanggung_jawab': nikPenanggungJawabController.text,
        'tempat_lahir_provinsi_penanggung_jawab':
            selectedProvincePenanggungJawab.toString(),
        'tempat_lahir_kota_penanggung_jawab':
            selectedRegencyPenanggungJawab.toString(),
        'tempat_lahir_kecamatan_penanggung_jawab':
            selectedRegencyPenanggungJawab.toString(),

        'status_pendidikan_penanggung_jawab':
            selectedJenisKelaminPenanggungJawab.toString(),
        'jenis_pekerjaan_penanggung_jawab':
            pekerjaanPenanggungJawabController.text,
        'tanggal_lahir_penanggung_jawab':
            tanggalLahirPenanggungJawabController.text,
        'agama_penanggung_jawab': selectedAgamaPenanggungJawab.toString(),
        'jenis_kelamin_penanggung_jawab':
            selectedJenisKelaminPenanggungJawab.toString(),
        'no_kk_penanggung_jawab': noKKPenanggungJawabController.text,
        'nom_ipl': nomIplController.text,
        'id_rt': KodeRt.kodeRt
      },
    );

    final result = jsonDecode(response.body);
    if (result['result'] == 'success') {
      await tambahLogAktivitas(
          aktivitas:
              'Menambahkan data warga baru dengan no kavling: ${noKavlingController.text} secara manual');
      await Flushbar(
        message: "Data Warga Berhasil Disimpan",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      
    } else {
      Flushbar(
        message: "Gagal Data Warga Berhasil",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

 void _showConfirmationDialog() {
  bool isSubmitting = false;
  if (namaPemilikController.text.isEmpty ||
      namaPenanggungJawabController.text.isEmpty) {
    Flushbar(
      message: "Kolom Nama Lengkap tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (noTelponPemilikController.text.isEmpty ||
      noTelponPenanggungJawabController.text.isEmpty) {
    Flushbar(
      message: "Kolom No. Telepon tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (nikPemilikController.text.isEmpty ||
      nikPenanggungJawabController.text.isEmpty) {
    Flushbar(
      message: "Kolom NIK tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (noKavlingController.text.isEmpty ||
      alamatKavlingController.text.isEmpty ||
      passwordController.text.isEmpty) {
    Flushbar(
      message: "Kolom Akun tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (noKKPemilikController.text.isEmpty ||
      noKKPenanggungJawabController.text.isEmpty) {
    Flushbar(
      message: "Kolom no KK tidak boleh kosong",
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

    return;
  }

  if (nomIplController.text.isEmpty) {
    Flushbar(
      message: "Nom IPL boleh kosong",
      duration: const Duration(seconds: 2),
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
              style: GoogleFonts.lato(
                color: Colors.black,
              ),
            ),

            content: Text(
              isSubmitting
                  ? 'Sedang menyimpan data warga, mohon tunggu...'
                  : 'Apakah Anda yakin ingin menyimpan data warga ini?',
              style: GoogleFonts.lato(
                color: Colors.black,
              ),
            ),

            actions: <Widget>[
              TextButton(
                onPressed: isSubmitting
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
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          isSubmitting = true;
                        });

                        try {
                          await submitData();

                          if (dialogContext.mounted) {
                             Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
                          }

                          
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                          });

                          if (dialogContext.mounted) {
                            Flushbar(
                              message: "Gagal menyimpan data: $e",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                              flushbarPosition:
                                  FlushbarPosition.TOP,
                            ).show(dialogContext);
                          }
                        }
                      },

                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3D8D7A),
                        ),
                      )
                    : Text(
                        'Kirim',
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
                        'Buat Data Warga Secara Manual',
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
          Container(
            width: 567,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3D8D7A),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Manual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Tombol kedua
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BuatWargaPageCsv()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Excel',
                    style: TextStyle(
                      color: Color(0xFF3D8D7A),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
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
                      //Pemilik Rumah=========================================================================================================================================================
                      Container(
                        child: Center(
                          child: Text(
                            '__Akun__',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person,
                                        color: Color(0xFF909090)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        ],
                                        controller: noKavlingController,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          hintText: 'No Kavling',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '*Bersifat wajib',
                                  style: TextStyle(
                                    color: Color(0xFF3D8D7A),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.place, color: Color(0xFF909090)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: alamatKavlingController,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          hintText: 'Alamat Kavling',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '*Bersifat wajib',
                                  style: TextStyle(
                                    color: Color(0xFF3D8D7A),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                Row(
                                  children: [
                                    Icon(Icons.label, color: Color(0xFF909090)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        ],
                                        obscureText: obscureText,
                                        controller: passwordController,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          hintText: 'Password',
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
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            obscureText = !obscureText;
                                          });
                                        },
                                        child: Icon(
                                          obscureText
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "*Bersifat wajib",
                                    style: TextStyle(
                                      color: Color(0xFF3D8D7A),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        child: Center(
                          child: Text(
                            'Pemilik Rumah',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: namaPemilikController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Nama Lengkap',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.call, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(15),
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      controller: noTelponPemilikController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'No Telepon',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.credit_card,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(16),
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      controller: nikPemilikController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'NIK',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
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
                            // ===================== PROVINSI =====================
                            Row(
                              children: [
                                Icon(Icons.place, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    menuMaxHeight: 300,
                                    value: selectedProvincePemilik,
                                    decoration: InputDecoration(
                                      hintText: "Tempat Lahir (Provinsi)",
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: provincesPemilik
                                        .map<DropdownMenuItem<String>>(
                                            (provinsi) {
                                      return DropdownMenuItem<String>(
                                        value: provinsi['code'],
                                        child: Text(
                                          provinsi['name'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList(),
                                    selectedItemBuilder: (context) {
                                      return provincesPemilik.map<Widget>((provinsi) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            provinsi['name'],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    onChanged: (value) async {
                                      if (value == null) return;

                                      setState(() {
                                        selectedProvincePemilik = value;
                                        selectedRegencyPemilik = null;
                                        selectedDistrictPemilik = null;

                                        regenciesPemilik.clear();
                                        districtsPemilik.clear();
                                      });

                                      await getRegencies(value, "Pemilik");
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // ===================== KABUPATEN =====================
                            Row(
                              children: [
                                Icon(Icons.place, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    menuMaxHeight: 300,
                                    value: selectedRegencyPemilik,
                                    decoration: InputDecoration(
                                      hintText: "Tempat Lahir (Kab/Kota)",
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: regenciesPemilik
                                        .map<DropdownMenuItem<String>>((kab) {
                                      return DropdownMenuItem<String>(
                                        value: kab['code'],
                                        child: Text(
                                          kab['name'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList(),
                                    selectedItemBuilder: (context) {
                                      return regenciesPemilik.map<Widget>((kab) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            kab['name'],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    onChanged: (value) async {
                                      if (value == null) return;

                                      setState(() {
                                        selectedRegencyPemilik = value;
                                        selectedDistrictPemilik = null;

                                        districtsPemilik.clear();
                                      });

                                      await getDistricts(value, "Pemilik");
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // ===================== KECAMATAN =====================
                            Row(
                              children: [
                                Icon(Icons.place, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    menuMaxHeight: 300,
                                    value: selectedDistrictPemilik,
                                    decoration: InputDecoration(
                                      hintText: "Tempat Lahir (Kecamatan)",
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: districtsPemilik
                                        .map<DropdownMenuItem<String>>((kec) {
                                      return DropdownMenuItem<String>(
                                        value: kec['code'],
                                        child: Text(
                                          kec['name'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList(),
                                    selectedItemBuilder: (context) {
                                      return districtsPemilik.map<Widget>((kec) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            kec['name'],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        selectedDistrictPemilik = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.school,
                                            color: Color(0xFF909090)),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            value:
                                                selectedJenjangPendidikanPenghuni,
                                            items: jenjangPendidikanOptions
                                                .map((jenjangPen) =>
                                                    DropdownMenuItem(
                                                      value: jenjangPen,
                                                      child: Text(jenjangPen),
                                                    ))
                                                .toList(),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              hintText: 'Jenjang Pendidikan',
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                selectedJenjangPendidikanPenghuni =
                                                    value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.work,
                                            color: Color(0xFF909090)),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                pekerjaanPemilikController,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              hintText: 'Jenis Pekerjaan',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: tanggalLahirPemilikController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Tanggal Lahir',
                                      ),
                                      onTap: () async {
                                        DateTime? pickedDate =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            tanggalLahirPemilikController.text =
                                                "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.account_balance,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedAgamaPemilik,
                                      items: agamaOptions
                                          .map((agama) => DropdownMenuItem(
                                                value: agama,
                                                child: Text(agama),
                                              ))
                                          .toList(),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Agama',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedAgamaPemilik = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.person, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedJenisKelaminPemilik,
                                      items: jenisKelaminOptions
                                          .map((jenisKelamin) =>
                                              DropdownMenuItem(
                                                value: jenisKelamin,
                                                child: Text(jenisKelamin),
                                              ))
                                          .toList(),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Jenis Kelamin',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedJenisKelaminPemilik = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(height: 16),
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
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(16),
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^[a-zA-Z0-9\s]+$')),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    controller: noKKPemilikController,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No Kartu Keluarga',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5),
                            Text(
                              "*Bersifat wajib",
                              style: TextStyle(
                                color: Color(0xFF3D8D7A),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),
                      //Penanggung Jawab==============================================================================================================================================
                      Container(
                        child: Center(
                          child: Text(
                            'Penghuni',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: namaPenanggungJawabController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Nama Lengkap',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.call, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(15),
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      controller:
                                          noTelponPenanggungJawabController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'No Telpon',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.credit_card,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(16),
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[a-zA-Z0-9\s]+$')),
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      controller: nikPenanggungJawabController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'NIK',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.place,
                                            color: Color(0xFF909090)),
                                        SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          menuMaxHeight: 300,
                                          value:
                                              selectedProvincePenanggungJawab,
                                          decoration: InputDecoration(
                                            hintText: "Tempat Lahir (Provinsi)",
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          items: provincesPenanggung
                                              .map<DropdownMenuItem<String>>(
                                                  (provinsi) {
                                            return DropdownMenuItem<String>(
                                              value: provinsi['code'],
                                              child: Text(
                                                provinsi['name'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          }).toList(),
                                          selectedItemBuilder: (context) {
                                            return provincesPenanggung
                                                .map<Widget>((provinsi) {
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  provinsi['name'],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              );
                                            }).toList();
                                          },
                                          onChanged: (value) async {
                                            if (value == null) return;

                                            setState(() {
                                              selectedProvincePenanggungJawab =
                                                  value;
                                              selectedRegencyPenanggungJawab =
                                                  null;
                                              selectedDistrictPenanggungJawab =
                                                  null;

                                              regenciesPenanggung.clear();
                                              districtsPenanggung.clear();
                                            });

                                            await getRegencies(
                                                value, "Penanggung");
                                          },
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.place,
                                            color: Color(0xFF909090)),
                                        SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          menuMaxHeight: 300,
                                          value: selectedRegencyPenanggungJawab,
                                          decoration: InputDecoration(
                                            hintText:
                                                "Tempat Lahir (Kabupaten/Kota)",
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          items: regenciesPenanggung
                                              .map<DropdownMenuItem<String>>(
                                                  (kab) {
                                            return DropdownMenuItem<String>(
                                              value: kab['code'],
                                              child: Text(
                                                kab['name'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          }).toList(),
                                          selectedItemBuilder: (context) {
                                            return regenciesPenanggung.map<Widget>((kab) {
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  kab['name'],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              );
                                            }).toList();
                                          },
                                          onChanged: (value) async {
                                            if (value == null) return;

                                            setState(() {
                                              selectedRegencyPenanggungJawab =
                                                  value;
                                              selectedDistrictPenanggungJawab =
                                                  null;

                                              districtsPenanggung.clear();
                                            });

                                            await getDistricts(
                                                value, "Penanggung");
                                          },
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.place,
                                            color: Color(0xFF909090)),
                                        SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          menuMaxHeight: 300,
                                          value:
                                              selectedDistrictPenanggungJawab,
                                          decoration: InputDecoration(
                                            hintText:
                                                "Tempat Lahir (Kecamatan)",
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          items: districtsPenanggung
                                              .map<DropdownMenuItem<String>>(
                                                  (kec) {
                                            return DropdownMenuItem<String>(
                                              value: kec['code'],
                                              child: Text(
                                                kec['name'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          }).toList(),
                                          selectedItemBuilder: (context) {
                                            return districtsPenanggung.map<Widget>((kec) {
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  kec['name'],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              );
                                            }).toList();
                                          },
                                          onChanged: (value) {
                                            setState(() {
                                              selectedDistrictPenanggungJawab =
                                                  value;
                                            });
                                          },
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.school, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedJenjangPendidikanPenghuni,
                                      items: jenjangPendidikanOptions
                                          .map((jenjangPen) => DropdownMenuItem(
                                                value: jenjangPen,
                                                child: Text(jenjangPen),
                                              ))
                                          .toList(),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Jenjang Pendidikan',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedJenjangPendidikanPenghuni =
                                              value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.work, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                          pekerjaanPenanggungJawabController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Jenis Pekerjaan',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),

                      ///////////////
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                          tanggalLahirPenanggungJawabController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Tanggal Lahir',
                                      ),
                                      onTap: () async {
                                        DateTime? pickedDate =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            tanggalLahirPenanggungJawabController
                                                    .text =
                                                "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.account_balance,
                                      color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedAgamaPenanggungJawab,
                                      items: agamaOptions
                                          .map((agama) => DropdownMenuItem(
                                                value: agama,
                                                child: Text(agama),
                                              ))
                                          .toList(),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Agama',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedAgamaPenanggungJawab = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.person, color: Color(0xFF909090)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value:
                                          selectedJenisKelaminPenanggungJawab,
                                      items: jenisKelaminOptions
                                          .map((jenisKelamin) =>
                                              DropdownMenuItem(
                                                value: jenisKelamin,
                                                child: Text(jenisKelamin),
                                              ))
                                          .toList(),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        hintText: 'Jenis Kelamin',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedJenisKelaminPenanggungJawab =
                                              value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),

                      SizedBox(height: 16),
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
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people, color: Color(0xFF909090)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(16),
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^[a-zA-Z0-9\s]+$')),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    controller: noKKPenanggungJawabController,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hintText: 'No Kartu Keluarga',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5),
                            Text(
                              "*Bersifat wajib",
                              style: TextStyle(
                                color: Color(0xFF3D8D7A),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        child: Center(
                          child: Text(
                            'Nominal IPL',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: 1000,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Color(0xFFB7B9B6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Column(
                            children: [
                              TextFormField(
                                controller: nomIplController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  ThousandsSeparatorInputFormatter(),
                                ],
                                decoration: InputDecoration(
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  hintText: 'Nominal IPL',
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '*Bersifat wajib',
                                style: TextStyle(
                                  color: Color(0xFF3D8D7A),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(height: 16),
                      //Akun=======================================================================================================================

                      SizedBox(height: 20),
                      Center(
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
                        'Buat Data Warga Secara Manual',
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
          SizedBox(
            height: 16,
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            'Data Warga 🛈',
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 567,
                            height: 50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF3D8D7A),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  child: Text(
                                    'Manual',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                // Tombol kedua
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              BuatWargaPageCsv()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  child: Text(
                                    'Excel',
                                    style: TextStyle(
                                      color: Color(0xFF3D8D7A),
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: SingleChildScrollView(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      //Pemilik Rumah=========================================================================================================================================================
                                      Container(
                                        child: Center(
                                          child: Text(
                                            'Akun',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Row(
                                            children: [
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                          ],
                                                          controller:
                                                              noKavlingController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'No Kavling',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                              SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.place,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                          ],
                                                          controller:
                                                              alamatKavlingController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Alamat Kavling',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ))
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),

                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(
                                            16), // Sesuaikan padding
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.label,
                                                    color: Color(0xFF909090)),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .allow(RegExp(
                                                              r'^[a-zA-Z0-9\s]+$')),
                                                    ],
                                                    obscureText: obscureText,
                                                    controller:
                                                        passwordController,
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 20),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      hintText: 'Password',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: ShapeDecoration(
                                                    color: Color(0xFF3D8D7A),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  child: TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        obscureText =
                                                            !obscureText;
                                                      });
                                                    },
                                                    child: Icon(
                                                      obscureText
                                                          ? Icons.visibility_off
                                                          : Icons.visibility,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "*Bersifat wajib",
                                                style: TextStyle(
                                                  color: Color(0xFF3D8D7A),
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 16),
                                      Container(
                                        child: Center(
                                          child: Text(
                                            'Pemilik Rumah',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Row(
                                            children: [
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          controller:
                                                              namaPemilikController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Nama Lengkap',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                              SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.call,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            LengthLimitingTextInputFormatter(
                                                                15),
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          controller:
                                                              noTelponPemilikController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'No Telepon',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                              SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.credit_card,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            LengthLimitingTextInputFormatter(
                                                                16),
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          controller:
                                                              nikPemilikController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText: 'NIK',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ))
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.school,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedJenjangPendidikanPenghuni,
                                                            items:
                                                                jenjangPendidikanOptions
                                                                    .map((jenjangPen) =>
                                                                        DropdownMenuItem(
                                                                          value:
                                                                              jenjangPen,
                                                                          child:
                                                                              Text(jenjangPen),
                                                                        ))
                                                                    .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenjang Pendidikan',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedJenjangPendidikanPenghuni =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.work,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                pekerjaanPemilikController,
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenis Pekerjaan',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedProvincePemilik,
                                                          items: provincesPemilik.map<
                                                                  DropdownMenuItem<
                                                                      String>>(
                                                              (provinsi) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value: provinsi[
                                                                  'code'],
                                                              child: Text(
                                                                  provinsi[
                                                                      'name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Provinsi)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedProvincePemilik =
                                                                  value;
                                                            });
                                                            getRegencies(
                                                                selectedProvincePemilik
                                                                    .toString(),
                                                                "Pemilik");
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 16,
                                              ),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedRegencyPemilik,
                                                          items: regenciesPemilik.map<
                                                                  DropdownMenuItem<
                                                                      String>>(
                                                              (regency) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value: regency[
                                                                  'code'],
                                                              child: Text(
                                                                  regency[
                                                                      'name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Kab/Kota)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedRegencyPemilik =
                                                                  value;
                                                              getDistricts(
                                                                  selectedRegencyPemilik
                                                                      .toString(),
                                                                  "Pemilik");
                                                            });
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedDistrictPemilik,
                                                          items: districtsPemilik.map<
                                                              DropdownMenuItem<
                                                                  String>>((kec) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value:
                                                                  kec['code'],
                                                              child: Text(
                                                                  kec['name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Kecamatan)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedDistrictPemilik =
                                                                  value;
                                                            });
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .calendar_today,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                tanggalLahirPemilikController,
                                                            readOnly: true,
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Tanggal Lahir',
                                                            ),
                                                            onTap: () async {
                                                              DateTime?
                                                                  pickedDate =
                                                                  await showDatePicker(
                                                                context:
                                                                    context,
                                                                initialDate:
                                                                    DateTime
                                                                        .now(),
                                                                firstDate:
                                                                    DateTime(
                                                                        1900),
                                                                lastDate:
                                                                    DateTime
                                                                        .now(),
                                                              );
                                                              if (pickedDate !=
                                                                  null) {
                                                                setState(() {
                                                                  tanggalLahirPemilikController
                                                                          .text =
                                                                      "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .account_balance,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedAgamaPemilik,
                                                            items: agamaOptions
                                                                .map((agama) =>
                                                                    DropdownMenuItem(
                                                                      value:
                                                                          agama,
                                                                      child: Text(
                                                                          agama),
                                                                    ))
                                                                .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText: 'Agama',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedAgamaPemilik =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.person,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedJenisKelaminPemilik,
                                                            items:
                                                                jenisKelaminOptions
                                                                    .map((jenisKelamin) =>
                                                                        DropdownMenuItem(
                                                                          value:
                                                                              jenisKelamin,
                                                                          child:
                                                                              Text(jenisKelamin),
                                                                        ))
                                                                    .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenis Kelamin',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedJenisKelaminPemilik =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(
                                            16), // Ubah padding agar lebih rapi
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.people,
                                                    color: Color(0xFF909090)),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    inputFormatters: [
                                                      LengthLimitingTextInputFormatter(
                                                          16),
                                                      FilteringTextInputFormatter
                                                          .allow(RegExp(
                                                              r'^[a-zA-Z0-9\s]+$')),
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    controller:
                                                        noKKPemilikController,
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 20),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      hintText:
                                                          'No Kartu Keluarga',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              "*Bersifat wajib",
                                              style: TextStyle(
                                                color: Color(0xFF3D8D7A),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 16),
                                      //Penanggung Jawab==============================================================================================================================================
                                      Container(
                                        child: Center(
                                          child: Text(
                                            'Penghuni',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Row(
                                            children: [
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          controller:
                                                              namaPenanggungJawabController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Nama Lengkap',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                              SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.call,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            LengthLimitingTextInputFormatter(
                                                                15),
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          controller:
                                                              noTelponPenanggungJawabController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'No Telepon',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                              SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.credit_card,
                                                          color: Color(
                                                              0xFF909090)),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextFormField(
                                                          inputFormatters: [
                                                            LengthLimitingTextInputFormatter(
                                                                16),
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'^[a-zA-Z0-9\s]+$')),
                                                            FilteringTextInputFormatter
                                                                .digitsOnly,
                                                          ],
                                                          controller:
                                                              nikPenanggungJawabController,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText: 'NIK',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    '*Bersifat wajib',
                                                    style: TextStyle(
                                                      color: Color(0xFF3D8D7A),
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ))
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.school,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedJenjangPendidikanPenanggungJawab,
                                                            items:
                                                                jenjangPendidikanOptions
                                                                    .map((jenjangPen) =>
                                                                        DropdownMenuItem(
                                                                          value:
                                                                              jenjangPen,
                                                                          child:
                                                                              Text(jenjangPen),
                                                                        ))
                                                                    .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenjang Pendidikan',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedJenjangPendidikanPenanggungJawab =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.work,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                pekerjaanPenanggungJawabController,
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenis Pekerjaan',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedProvincePenanggungJawab,
                                                          items: provincesPenanggung.map<
                                                                  DropdownMenuItem<
                                                                      String>>(
                                                              (provinsi) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value: provinsi[
                                                                  'code'],
                                                              child: Text(
                                                                  provinsi[
                                                                      'name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Provinsi)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedProvincePenanggungJawab =
                                                                  value;
                                                            });
                                                            getRegencies(
                                                                selectedProvincePenanggungJawab
                                                                    .toString(),
                                                                "Penanggung");
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 16,
                                              ),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedRegencyPenanggungJawab,
                                                          items: regenciesPenanggung.map<
                                                                  DropdownMenuItem<
                                                                      String>>(
                                                              (regency) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value: regency[
                                                                  'code'],
                                                              child: Text(
                                                                  regency[
                                                                      'name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Kab/Kota)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedRegencyPenanggungJawab =
                                                                  value;
                                                              getDistricts(
                                                                  selectedRegencyPenanggungJawab
                                                                      .toString(),
                                                                  "Penanggung");
                                                            });
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.place,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child:
                                                                DropdownButtonFormField<
                                                                    String>(
                                                          value:
                                                              selectedDistrictPenanggungJawab,
                                                          items: districtsPenanggung.map<
                                                              DropdownMenuItem<
                                                                  String>>((kec) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value:
                                                                  kec['code'],
                                                              child: Text(
                                                                  kec['name']),
                                                            );
                                                          }).toList(),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            hintText:
                                                                'Tempat Lahir (Kecamatan)',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedDistrictPenanggungJawab =
                                                                  value;
                                                            });
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),

                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(20),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          return Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .calendar_today,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                tanggalLahirPenanggungJawabController,
                                                            readOnly: true,
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Tanggal Lahir',
                                                            ),
                                                            onTap: () async {
                                                              DateTime?
                                                                  pickedDate =
                                                                  await showDatePicker(
                                                                context:
                                                                    context,
                                                                initialDate:
                                                                    DateTime
                                                                        .now(),
                                                                firstDate:
                                                                    DateTime(
                                                                        1900),
                                                                lastDate:
                                                                    DateTime
                                                                        .now(),
                                                              );
                                                              if (pickedDate !=
                                                                  null) {
                                                                setState(() {
                                                                  tanggalLahirPenanggungJawabController
                                                                          .text =
                                                                      "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .account_balance,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedAgamaPenanggungJawab,
                                                            items: agamaOptions
                                                                .map((agama) =>
                                                                    DropdownMenuItem(
                                                                      value:
                                                                          agama,
                                                                      child: Text(
                                                                          agama),
                                                                    ))
                                                                .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText: 'Agama',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedAgamaPenanggungJawab =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.person,
                                                            color: Color(
                                                                0xFF909090)),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child:
                                                              DropdownButtonFormField<
                                                                  String>(
                                                            value:
                                                                selectedJenisKelaminPenanggungJawab,
                                                            items:
                                                                jenisKelaminOptions
                                                                    .map((jenisKelamin) =>
                                                                        DropdownMenuItem(
                                                                          value:
                                                                              jenisKelamin,
                                                                          child:
                                                                              Text(jenisKelamin),
                                                                        ))
                                                                    .toList(),
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          20),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              hintText:
                                                                  'Jenis Kelamin',
                                                            ),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                selectedJenisKelaminPenanggungJawab =
                                                                    value;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(16),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.people,
                                                    color: Color(0xFF909090)),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    inputFormatters: [
                                                      LengthLimitingTextInputFormatter(
                                                          16),
                                                      FilteringTextInputFormatter
                                                          .allow(RegExp(
                                                              r'^[a-zA-Z0-9\s]+$')),
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    controller:
                                                        noKKPenanggungJawabController,
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 20),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      hintText:
                                                          'No Kartu Keluarga',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              "*Bersifat wajib",
                                              style: TextStyle(
                                                color: Color(0xFF3D8D7A),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 16),
                                      Container(
                                        child: Center(
                                          child: Text(
                                            'Nominal IPL',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: 1000,
                                        padding: const EdgeInsets.all(16),
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Color(0xFFB7B9B6)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.money,
                                                    color: Color(0xFF909090)),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                      ThousandsSeparatorInputFormatter(),
                                                    ],
                                                    controller:
                                                        nomIplController,
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 20),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      hintText: 'Nominal IPL',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              "*Bersifat wajib",
                                              style: TextStyle(
                                                color: Color(0xFF3D8D7A),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      //Akun=======================================================================================================================

                                      SizedBox(height: 16),
                                      Center(
                                        child: Container(
                                          width: 500,
                                          height: 50,
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
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 
}
