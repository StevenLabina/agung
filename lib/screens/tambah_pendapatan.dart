import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_pendapatan.dart';

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';

//import 'package:shared_preferences/shared_preferences.dart';

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

class TambahPendapatanPage extends StatefulWidget {
  @override
  _TambahPendapatanPageState createState() => _TambahPendapatanPageState();
}

class _TambahPendapatanPageState extends State<TambahPendapatanPage> {
  final TextEditingController _tanggalPendapatanController =
      TextEditingController();
  List<String> noKavlingOptions = [];
  String? selectedNoKavling;
  bool isLainnyaKavlingSelected = true;

  List<Map<String, String>> recentPendapatan = []; // riwayat baru ditambahkan
  final TextEditingController _ketPendapatanControllerapatanController =
      TextEditingController();
  final TextEditingController _saldoPendapatanController =
      TextEditingController();
  final TextEditingController _noKavlingPendapatanController =
      TextEditingController();
  List<Map<String, String>> rtCoaData = [];
  String? selectedMetode;
  String? selectedRt;
  bool isLainnyaSelected = false;
  TextEditingController _lainnyaRtController = TextEditingController();
  TextEditingController _lainnyaRtKetController = TextEditingController();
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

  List<String> rtOptions = [];

  @override
  void initState() {
    super.initState();

    fetchRtOptions();
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

  Future<void> fetchRtOptions() async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listCoa.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'id_rt': KodeRt.kodeRt},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded['result'] == 'success') {
        final List<dynamic> data = decoded['data'];

        setState(() {
          rtOptions = [];
          rtCoaData = [];

          for (var item in data) {
            if (item['coa_pendapatan'] != null &&
                item['coa_pendapatan'] != '' &&
                item['ket_coa_pendapatan'] != null &&
                item['ket_coa_pendapatan'] != '') {
              rtOptions.add(
                  '${item['coa_pendapatan']} - ${item['ket_coa_pendapatan']}');

              rtCoaData.add({
                'coa': item['coa_pendapatan'],
                'ket': item['ket_coa_pendapatan'],
              });
            }
          }

          rtOptions.add('Lainnya');
        });
      } else {
        print('Gagal ambil data: ${decoded['message']}');
      }

      // No kavling diproses terpisah, tidak tergantung status COA
      final List<dynamic> kavlingData = decoded['no_kavling'] ?? [];
      setState(() {
        noKavlingOptions = kavlingData.map((e) => e.toString()).toList();
        noKavlingOptions.add('Lainnya');
        selectedNoKavling = 'Lainnya';
        isLainnyaKavlingSelected = true;
      });
    } else {
      print('Gagal ambil data RT, status: ${response.statusCode}');
    }
  }

  String generateKodeRef({
    required String namaRT,
    required String kodeIuran,
    required String alamatKavling,
    required String tanggalLunas,
    required String kodeTransaksi,
  }) {
    return '$namaRT$kodeIuran$alamatKavling$tanggalLunas$kodeTransaksi';
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
      // Fluttertoast.showToast(msg: 'Data berhasil disimpan');
    } else {
      Flushbar(
        message: 'Gagal menyimpan data: ${data['message']}',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> tambahDataLaporan(String tanggal, String keterangan,
      String saldo, String noKavling, String metode) async {
    String coaValue;
    if (selectedRt != null && selectedRt!.contains(' - ')) {
      coaValue = selectedRt!.split(' - ')[0];
    } else {
      coaValue = _lainnyaRtController.text;
    }

    String kodeRef = generateKodeRef(
      namaRT: KodeRt.kodeRt.toUpperCase(),
      kodeIuran: '001',
      alamatKavling: noKavling,
      tanggalLunas: tanggal,
      kodeTransaksi: coaValue,
    );

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambahPendapatan.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "tanggal": tanggal,
        "keterangan": keterangan,
        "saldo": saldo,
        "coa": coaValue,
        "no_kavling": noKavling,
        "kode_ref": kodeRef,
        'id_rt': KodeRt.kodeRt,
        'metode': metode,
        'is_lainnya_kavling': isLainnyaKavlingSelected, // ✅ flag baru
      }),
    );

    final data = jsonDecode(response.body);

    if (data['result'] == 'success') {
      await tambahLogAktivitas(
        aktivitas:
            'Menambahkan pendapatan dengan keterangan: $keterangan dan Nominal: $saldo',
      );
    } else {
      throw Exception(data['message'] ?? 'Gagal menyimpan data');
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_tanggalPendapatanController.text.isEmpty ||
        _saldoPendapatanController.text.isEmpty ||
        _noKavlingPendapatanController.text.isEmpty) {
      Flushbar(
        message: "Data tidak lengkap",
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    if (isLainnyaSelected) {
      final kode = _lainnyaRtController.text.trim();
      final ket = _lainnyaRtKetController.text.trim();

      if (kode.isEmpty || ket.isEmpty) {
        Flushbar(
          message: "Kode COA dan keterangan wajib diisi untuk opsi Lainnya",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
        return;
      }

      final bool sudahAda =
          rtCoaData.any((item) => item['coa'] == kode || item['ket'] == ket);

      if (sudahAda) {
        Flushbar(
          message:
              "Kode COA atau keterangan sudah ada. Silakan gunakan yang lain.",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
        return;
      }

      await tambahDataCOA(kode, ket, "Pendapatan");
    }

    final parentContext = context;
    Map<String, String>? savedEntry; 
    final bool? berhasil = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDECE8),
              title: Text('Konfirmasi',
                  style: GoogleFonts.lato(color: Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal: ${_tanggalPendapatanController.text}'
                      '\nRincian Pendapatan: ${_ketPendapatanControllerapatanController.text}'
                      '\nKode COA: ${selectedRt ?? ""}'
                      '${_lainnyaRtController.text.isNotEmpty ? ' (${_lainnyaRtController.text} - ${_lainnyaRtKetController.text})' : ""}'
                      '\nNo Kavling: ${_noKavlingPendapatanController.text}'
                      '\nNominal: Rp ${_saldoPendapatanController.text}'
                      '\n===================================',
                      style: GoogleFonts.lato(color: Colors.black),
                    ),
                    const SizedBox(height: 15),
                    Text('Metode Pembayaran (Wajib):',
                        style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedMetode,
                          hint: const Text("Pilih Metode"),
                          items: const [
                            DropdownMenuItem(
                                value: 'Bayar Tunai',
                                child: Text('Bayar Tunai')),
                            DropdownMenuItem(
                                value: 'Transfer', child: Text('Transfer')),
                          ],
                          onChanged: isSaving
                              ? null
                              : (newValue) {
                                  setDialogState(() {
                                    selectedMetode = newValue;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                        'Apakah anda yakin ingin menyimpan data pendapatan ini?',
                        style: GoogleFonts.lato(color: Colors.black)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          selectedMetode = null;
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: Text('Batal',
                      style: GoogleFonts.lato(color: const Color(0xFF3D8D7A))),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null // ✅ cegah double click saat sedang menyimpan
                      : () async {
                          if (selectedMetode == null) {
                            Flushbar(
                              message: "Silakan pilih metode pembayaran",
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.red,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(parentContext);
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await tambahDataLaporan(
                              _tanggalPendapatanController.text,
                              _ketPendapatanControllerapatanController.text,
                              _saldoPendapatanController.text,
                              _noKavlingPendapatanController.text,
                              selectedMetode!,
                            );

                          
                            savedEntry = {
                              'tanggal': _tanggalPendapatanController.text,
                              'keterangan':
                                  _ketPendapatanControllerapatanController.text,
                              'nominal': _saldoPendapatanController.text,
                              'no_kavling': _noKavlingPendapatanController.text,
                            };

                            _tanggalPendapatanController.clear();
                            _ketPendapatanControllerapatanController.clear();
                            _saldoPendapatanController.clear();
                            _noKavlingPendapatanController.clear();
                            _lainnyaRtController.clear();
                            _lainnyaRtKetController.clear();

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSaving = false;
                              });
                              Flushbar(
                                message: "Gagal menyimpan data: $e",
                                duration: const Duration(seconds: 3),
                                backgroundColor: Colors.red,
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(parentContext);
                            }
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
                      : Text('Simpan',
                          style:
                              GoogleFonts.lato(color: const Color(0xFF3D8D7A))),
                ),
              ],
            );
          },
        );
      },
    );

  
    if (berhasil == true && parentContext.mounted) {
      setState(() {
        if (savedEntry != null) {
          recentPendapatan.insert(0, savedEntry!);
        }
        isLainnyaSelected = false;
        selectedRt = null;
        selectedMetode = null;
        selectedNoKavling = 'Lainnya';
        isLainnyaKavlingSelected = true;
      });

      Flushbar(
        message: "Data pendapatan berhasil disimpan",
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(parentContext);
    }
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
                              icon: Icon(Icons.arrow_back_ios,
                                  color: Colors.black),
                              onPressed: () => {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MenuPilihanPage(
                                          idMenu: 5,
                                        ),
                                      ),
                                    )
                                  }),
                          Text(
                            'Form Input Pendapatan',
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
                      _buildDateField(
                          context,
                          _tanggalPendapatanController,
                          'Tanggal Pendapatan (dd-MM-yyyy-HH:mm)',
                          Icons.date_range),
                      SizedBox(height: 16),
                      _buildInputField(
                          context,
                          _ketPendapatanControllerapatanController,
                          'Keterangan Pendapatan',
                          Icons.description),
                      SizedBox(height: 16),
                      _buildNoKavlingDropdownField(),
                      SizedBox(height: 16),
                      _buildSaldoField(context, _saldoPendapatanController,
                          'Saldo Pendapatan', Icons.money),
                      SizedBox(height: 16),
                      _buildRtDropdownField(),
                      SizedBox(height: 16),
                      _buildSubmitButton(),
                       const SizedBox(height: 24),
                     
                      Container(
                        width: 500,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C9D8F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Riwayat Baru Ditambahkan",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildRecentList(shrinkWrap: true),
                          ],
                        ),
                      ),
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
        child: Column(
          children: [
            // HEADER
            Center(
              child: Container(
                width: 1200,
                height: 80,
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 232, 226, 226),
                  border: Border.all(
                    color: const Color.fromARGB(255, 58, 112, 50),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuPilihanPage(idMenu: 5),
                              ),
                            );
                          },
                        ),
                        const Text(
                          "Form Input Pendapatan",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Image.asset(
                      "assets/images/Logo4.png",
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tambah\nPendapatan 🛈",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Pengurus RT menambahkan\npendapatan secara manual",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white54),
                              const SizedBox(height: 8),
                              const Text(
                                "Riwayat Baru Ditambahkan",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: recentPendapatan.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "Belum ada data yang ditambahkan",
                                          style:
                                              TextStyle(color: Colors.white70),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: recentPendapatan.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                color: Colors.white24),
                                        itemBuilder: (context, index) {
                                          final item = recentPendapatan[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['keterangan'] ?? '-',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item['tanggal'] ?? '-'} • Kavling ${item['no_kavling'] ?? '-'}',
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12),
                                                ),
                                                Text(
                                                  'Rp ${item['nominal'] ?? '0'}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
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
                                    _buildDateField(
                                      context,
                                      _tanggalPendapatanController,
                                      'Tanggal Pendapatan',
                                      Icons.calendar_month,
                                    ),
                                    const SizedBox(height: 25),
                                    _buildInputField(
                                      context,
                                      _ketPendapatanControllerapatanController,
                                      'Keterangan Pendapatan',
                                      Icons.description,
                                    ),
                                    const SizedBox(height: 25),
                                    _buildNoKavlingDropdownField(),
                                    const SizedBox(height: 25),
                                    _buildSaldoField(
                                      context,
                                      _saldoPendapatanController,
                                      'Saldo Pendapatan',
                                      Icons.payments,
                                    ),
                                    const SizedBox(height: 25),
                                    _buildRtDropdownField(),
                                    const SizedBox(height: 40),
                                    SizedBox(
                                      width: 500,
                                      height: 60,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _showConfirmationDialog();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF43927C),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        child: const Text(
                                          "Tambah",
                                          style: TextStyle(
                                            fontSize: 24,
                                            color: Colors.white,
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
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context,
    TextEditingController controller,
    String hintText,
    IconData icon,
  ) {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB7B9B6)),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () async {
          DateTime now = DateTime.now();

          DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);

          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: firstDayOfMonth,
            lastDate: DateTime(2300),
          );

          if (pickedDate != null) {
            // Gabungkan jam dan menit saat ini
            DateTime finalDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              now.hour,
              now.minute,
            );

            controller.text =
                DateFormat('dd-MM-yyyy-HH:mm').format(finalDateTime);
          }
        },
        decoration: InputDecoration(
          icon: Icon(icon),
          hintText: hintText,
          border: InputBorder.none,
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
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
        ],
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

  Widget _buildRtDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 500,
          padding: const EdgeInsets.all(12),
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
              hintText: 'Pilih Kode COA',
            ),
            value: selectedRt,
            items: rtOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedRt = newValue;
                isLainnyaSelected = newValue == 'Lainnya';
                if (newValue != 'Lainnya') {
                  _lainnyaRtController.clear();
                }
              });
            },
            validator: (value) =>
                value == null ? 'Kode COA wajib dipilih' : null,
          ),
        ),
        if (isLainnyaSelected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 500,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFB7B9B6)),
              ),
              child: TextFormField(
                controller: _lainnyaRtController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Masukkan Kode COA Lainnya',
                ),
              ),
            ),
          ),
        if (isLainnyaSelected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 500,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFB7B9B6)),
              ),
              child: TextFormField(
                controller: _lainnyaRtKetController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Masukkan Keterangan COA',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoKavlingDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 500,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB7B9B6)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person, color: Colors.black),
              isDense: true,
              border: InputBorder.none,
              hintText: 'Pilih No Kavling',
            ),
            value: selectedNoKavling,
            items: noKavlingOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedNoKavling = newValue;
                isLainnyaKavlingSelected = newValue == 'Lainnya';
                if (newValue != null && newValue != 'Lainnya') {
                  _noKavlingPendapatanController.text = newValue;
                } else {
                  _noKavlingPendapatanController.clear();
                }
              });
            },
            validator: (value) =>
                value == null ? 'No Kavling wajib dipilih' : null,
          ),
        ),
        if (isLainnyaKavlingSelected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 500,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB7B9B6)),
              ),
              child: TextFormField(
                controller: _noKavlingPendapatanController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Masukkan No Kavling',
                ),
              ),
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
   Widget _buildRecentList({bool shrinkWrap = false}) {
    if (recentPendapatan.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            "Belum ada data yang ditambahkan",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: recentPendapatan.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
      itemBuilder: (context, index) {
        final item = recentPendapatan[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['nama'] ?? '-',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item['tanggal'] ?? '-'} • ${item['kategori'] ?? '-'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                'Jumlah: ${item['jumlah'] ?? '-'} • Sumber: ${item['sumber'] ?? '-'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                'Rp ${item['harga'] ?? '0'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
