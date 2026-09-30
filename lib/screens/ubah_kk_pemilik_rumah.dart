import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ubahKkPemilikRumahPage extends StatefulWidget {
  final int id;

  ubahKkPemilikRumahPage({required this.id});

  @override
  _ubahKkPemilikRumahPageState createState() => _ubahKkPemilikRumahPageState();
}

class _ubahKkPemilikRumahPageState extends State<ubahKkPemilikRumahPage> {
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();

  final TextEditingController _tanggalLahirController = TextEditingController();
 
  final TextEditingController _jenisPekerjaanController =
      TextEditingController();
  String? selectedAgamaPemilik = "Pilih Agama";
  String? selectedJenisKelaminPemilik = "Pilih Jenis Kelamin";

  String? selectedPendidikan = "Pilih Pendidikan";
  final List<String> jenjangPendidikanOptions = [
    'Pilih Pendidikan',
    'SMA/SMK',
    'D1',
    'D2',
    'D3',
    'S1/D4',
    'S2',
    'S3'
  ];
  String? selectedLokasiProvinsi;
  String? selectedLokasiKota;
  String? selectedLokasiKecamatan;
  List<dynamic> provincesPemilik = [];
  List<dynamic> regenciesPemilik = [];
  List<dynamic> districtsPemilik = [];
  final List<String> agamaOptions = [
    'Pilih Agama',
    'Islam',
    'Katolik',
    'Kristen',
    'Hindu',
    'Budha',
    'Konghucu'
        'Lainnya',
  ];
  final List<String> jenisKelaminOptions = [
    'Pilih Jenis Kelamin',
    'Laki-laki',
    'Perempuan',
    'Lainnya',
  ];

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    await getProvinces();
    await fetchWargaData();
  }

  Future<void> getProvinces() async {
    final response = await http.get(
      Uri.parse("${ApiUrls.baseUrl}lokasi_id.php?type=provinces"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
        provincesPemilik = json['data'];
      });
    }
  }

  Future<void> getRegencies(String provinceCode) async {
    final response = await http.get(
      Uri.parse(
          "${ApiUrls.baseUrl}lokasi_id.php?type=regencies&province=$provinceCode"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
        regenciesPemilik = json['data'];

        districtsPemilik.clear();
      });
    }
  }

  Future<void> getDistricts(String regencyCode) async {
    final response = await http.get(
      Uri.parse(
          "${ApiUrls.baseUrl}lokasi_id.php?type=districts&regency=$regencyCode"),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      setState(() {
        districtsPemilik = json['data'];
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

  Future<void> fetchWargaData() async {
    final idRt = KodeRt.kodeRt;

    try {
      final response = await http.get(
        Uri.parse(
          "${ApiUrls.baseUrl}/getKk.php?id=${widget.id}&id_rt=$idRt&kk=pemilik",
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['result'] == 'success') {
          final data = json['data'];

          _namaLengkapController.text = data['nama_lengkap'];
          _nikController.text = data['nik'];

          selectedJenisKelaminPemilik =
              jenisKelaminOptions.contains(data['jenis_kelamin'])
                  ? data['jenis_kelamin']
                  : null;

          _tanggalLahirController.text = data['tanggal_lahir'];

          selectedAgamaPemilik =
              agamaOptions.contains(data['agama']) ? data['agama'] : null;

          selectedPendidikan =
              jenjangPendidikanOptions.contains(data['pendidikan'])
                  ? data['pendidikan']
                  : null;

          _jenisPekerjaanController.text = data['jenis_pekerjaan'];

          ///====================
          /// PROVINSI
          ///====================

          selectedLokasiProvinsi = data['tempat_lahir_provinsi'];

          final provinsi = provincesPemilik.firstWhere(
            (e) => e['name'] == selectedLokasiProvinsi,
            orElse: () => null,
          );

          if (provinsi != null) {
            await getRegencies(provinsi['code']);
          }

          ///====================
          /// KOTA
          ///====================

          selectedLokasiKota = data['tempat_lahir_kota'];

          final kota = regenciesPemilik.firstWhere(
            (e) => e['name'] == selectedLokasiKota,
            orElse: () => null,
          );

          if (kota != null) {
            await getDistricts(kota['code']);
          }

          ///====================
          /// KECAMATAN
          ///====================

          selectedLokasiKecamatan = data['tempat_lahir_kecamatan'];

          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed : $e";
        isLoading = false;
      });
    }
  }

  Future<void> updateWargaData() async {
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}updateKk.php"),
        body: {
          'id': widget.id.toString(),
          'nama_lengkap': _namaLengkapController.text,
          'nik': _nikController.text,
          'jenis_kelamin': selectedJenisKelaminPemilik.toString(),
          'tempat_lahir_provinsi': selectedLokasiProvinsi ?? '',
          'tempat_lahir_kota': selectedLokasiKota ?? '',
          'tempat_lahir_kecamatan': selectedLokasiKecamatan ?? '',
          'tanggal_lahir': _tanggalLahirController.text,
          'agama': selectedAgamaPemilik.toString(),
          'pendidikan': selectedPendidikan.toString(),
          'jenis_pekerjaan': _jenisPekerjaanController.text,
          'id_rt': KodeRt.kodeRt,
          'kk': 'pemilik'
        },
      );

      final json = jsonDecode(response.body);
      if (json['result'] == 'success') {
        Flushbar(
          message: "Update data KK berhasil",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        await tambahLogAktivitas(
          aktivitas:
              'Mengupdate data KK dengan nama: ${_namaLengkapController.text}',
        );
        Navigator.pop(context, true);
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFDECE8),
          title:
              Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
          content: Text('Apakah Anda yakin ingin memperbarui data KK ini?',
              style: GoogleFonts.lato(color: Colors.black)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Batal',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
            ),
            TextButton(
              onPressed: () async {
                updateWargaData();
              },
              child:
                  Text('Ya', style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
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
                        'Ubah Data Kartu Keluarga',
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
                              "Ubah Data Kartu Keluarga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Pengurus RT menambahkan\ndata kk secara manual",
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
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Nama Lengkap',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _namaLengkapController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'Nama Lengkap',
                                              ),
                                            ),
                                            SizedBox(height: 12),
                                            Text('NIK',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              inputFormatters: [
                                                LengthLimitingTextInputFormatter(
                                                    16)
                                              ],
                                              controller: _nikController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'NIK',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 20),
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Jenis Kelamin',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value:
                                                  selectedJenisKelaminPemilik ??
                                                      "Pilih Jenis Kelamin",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: jenisKelaminOptions
                                                  .map((jenisKelamin) {
                                                return DropdownMenuItem(
                                                  value: jenisKelamin,
                                                  child: Text(jenisKelamin),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedJenisKelaminPemilik =
                                                      value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Provinsi)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiProvinsi,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint:
                                                  const Text("Pilih Provinsi"),
                                              items: provincesPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (provinsi) {
                                                return DropdownMenuItem<String>(
                                                  value: provinsi['name'],
                                                  child: Text(provinsi['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) async {
                                                setState(() {
                                                  selectedLokasiProvinsi =
                                                      value;
                                                  selectedLokasiKota = null;
                                                  selectedLokasiKecamatan =
                                                      null;

                                                  regenciesPemilik.clear();
                                                  districtsPemilik.clear();
                                                });

                                                final code = provincesPemilik
                                                    .firstWhere((e) =>
                                                        e['name'] ==
                                                        value)['code'];

                                                await getRegencies(code);
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Kota)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiKota,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint: const Text("Pilih Kota"),
                                              items: regenciesPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (kota) {
                                                return DropdownMenuItem<String>(
                                                  value: kota['name'],
                                                  child: Text(kota['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) async {
                                                setState(() {
                                                  selectedLokasiKota = value;
                                                  selectedLokasiKecamatan =
                                                      null;

                                                  districtsPemilik.clear();
                                                });

                                                final code = regenciesPemilik
                                                    .firstWhere((e) =>
                                                        e['name'] ==
                                                        value)['code'];

                                                await getDistricts(code);
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Kecamatan)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiKecamatan,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint:
                                                  const Text("Pilih Kecamatan"),
                                              items: districtsPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (kecamatan) {
                                                return DropdownMenuItem<String>(
                                                  value: kecamatan['name'],
                                                  child:
                                                      Text(kecamatan['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedLokasiKecamatan =
                                                      value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tanggal Lahir',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _tanggalLahirController,
                                              readOnly: true,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
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
                                                    _tanggalLahirController
                                                            .text =
                                                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 20),
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Agama',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedAgamaPemilik ??
                                                  "Pilih Agama",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: agamaOptions.map((agama) {
                                                return DropdownMenuItem(
                                                  value: agama,
                                                  child: Text(agama),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedAgamaPemilik = value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Pendidikan Terakhir',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedPendidikan ??
                                                  "Pilih Jenjang Pendidikan",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: jenjangPendidikanOptions
                                                  .map((pen) {
                                                return DropdownMenuItem(
                                                  value: pen,
                                                  child: Text(pen),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedPendidikan = value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Jenis Pekerjaan',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _jenisPekerjaanController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'Jenis Pekerjaan',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                      ))
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
                        'Ubah Data Kartu Keluarga',
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
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Nama Lengkap',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _namaLengkapController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'Nama Lengkap',
                                              ),
                                            ),
                                            SizedBox(height: 12),
                                            Text('NIK',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              inputFormatters: [
                                                LengthLimitingTextInputFormatter(
                                                    16)
                                              ],
                                              controller: _nikController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'NIK',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 20),
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Jenis Kelamin',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value:
                                                  selectedJenisKelaminPemilik ??
                                                      "Pilih Jenis Kelamin",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: jenisKelaminOptions
                                                  .map((jenisKelamin) {
                                                return DropdownMenuItem(
                                                  value: jenisKelamin,
                                                  child: Text(jenisKelamin),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedJenisKelaminPemilik =
                                                      value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Provinsi)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiProvinsi,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint:
                                                  const Text("Pilih Provinsi"),
                                              items: provincesPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (provinsi) {
                                                return DropdownMenuItem<String>(
                                                  value: provinsi['name'],
                                                  child: Text(provinsi['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) async {
                                                setState(() {
                                                  selectedLokasiProvinsi =
                                                      value;
                                                  selectedLokasiKota = null;
                                                  selectedLokasiKecamatan =
                                                      null;

                                                  regenciesPemilik.clear();
                                                  districtsPemilik.clear();
                                                });

                                                final code = provincesPemilik
                                                    .firstWhere((e) =>
                                                        e['name'] ==
                                                        value)['code'];

                                                await getRegencies(code);
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Kota)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiKota,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint: const Text("Pilih Kota"),
                                              items: regenciesPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (kota) {
                                                return DropdownMenuItem<String>(
                                                  value: kota['name'],
                                                  child: Text(kota['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) async {
                                                setState(() {
                                                  selectedLokasiKota = value;
                                                  selectedLokasiKecamatan =
                                                      null;

                                                  districtsPemilik.clear();
                                                });

                                                final code = regenciesPemilik
                                                    .firstWhere((e) =>
                                                        e['name'] ==
                                                        value)['code'];

                                                await getDistricts(code);
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tempat lahir (Kecamatan)',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedLokasiKecamatan,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              hint:
                                                  const Text("Pilih Kecamatan"),
                                              items: districtsPemilik.map<
                                                      DropdownMenuItem<String>>(
                                                  (kecamatan) {
                                                return DropdownMenuItem<String>(
                                                  value: kecamatan['name'],
                                                  child:
                                                      Text(kecamatan['name']),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedLokasiKecamatan =
                                                      value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Tanggal Lahir',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _tanggalLahirController,
                                              readOnly: true,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
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
                                                    _tanggalLahirController
                                                            .text =
                                                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 20),
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Agama',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedAgamaPemilik ??
                                                  "Pilih Agama",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: agamaOptions.map((agama) {
                                                return DropdownMenuItem(
                                                  value: agama,
                                                  child: Text(agama),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedAgamaPemilik = value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Pendidikan Terakhir',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              value: selectedPendidikan ??
                                                  "Pilih Jenjang Pendidikan",
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              items: jenjangPendidikanOptions
                                                  .map((pen) {
                                                return DropdownMenuItem(
                                                  value: pen,
                                                  child: Text(pen),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedPendidikan = value;
                                                });
                                              },
                                            ),
                                            SizedBox(height: 12),
                                            Text('Jenis Pekerjaan',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12)),
                                            SizedBox(height: 4),
                                            TextFormField(
                                              controller:
                                                  _jenisPekerjaanController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                hintText: 'Jenis Pekerjaan',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                      ))
        ],
      ),
    );
  }
}
