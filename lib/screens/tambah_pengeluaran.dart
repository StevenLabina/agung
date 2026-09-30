import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_pengeluaran.dart';
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

class TambahPengeluaranPage extends StatefulWidget {
  @override
  _TambahPengeluaranPageState createState() => _TambahPengeluaranPageState();
}

class _TambahPengeluaranPageState extends State<TambahPengeluaranPage> {
  final TextEditingController _tanggalPengeluaranController =
      TextEditingController();

 
  List<Map<String, String>> recentPengeluaran = [];

  final TextEditingController _ketPengeluaranController =
      TextEditingController();
  final TextEditingController _saldoPengeluaranController =
      TextEditingController();
  TextEditingController _lainnyaRtKetController = TextEditingController();
  String? selectedMetode;
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

  List<Map<String, String>> rtCoaData = [];
  String? selectedRt;
  bool isLainnyaSelected = false;
  TextEditingController _lainnyaRtController = TextEditingController();

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
        message: 'Data COA berhasil disimpan',
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

  Future<void> fetchRtOptions() async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listCoa.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
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
            if (item['coa_pengeluaran'] != null &&
                item['coa_pengeluaran'] != '' &&
                item['ket_coa_pengeluaran'] != null &&
                item['ket_coa_pengeluaran'] != '') {
              rtOptions.add(
                  '${item['coa_pengeluaran']} - ${item['ket_coa_pengeluaran']}');

              rtCoaData.add({
                'coa': item['coa_pengeluaran'],
                'ket': item['ket_coa_pengeluaran'],
              });
            }
          }

          rtOptions.add('Lainnya');
        });
      } else {
        print('Gagal ambil data: ${decoded['message']}');
      }
    } else {
      print('Gagal ambil data RT, status: ${response.statusCode}');
    }
  }

  Future<void> tambahDataLaporan(String tanggal, String keterangan,
      String saldo, String noKavling, String metode) async {
    final String coaValue;
    if (selectedRt == 'Lainnya') {
      coaValue = _lainnyaRtController.text;
    } else if (selectedRt != null && selectedRt!.contains(' - ')) {
      coaValue = selectedRt!.split(' - ')[0];
    } else {
      coaValue = selectedRt ?? '';
    }
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambahPengeluaran.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "tanggal": tanggal,
        "keterangan": keterangan,
        "saldo": saldo,
        "coa": coaValue,
        "no_kavling": noKavling,
        'id_rt': KodeRt.kodeRt,
        'metode': metode
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] == 'success') {
     
      await tambahLogAktivitas(
        aktivitas:
            'Menambahkan pengeluaran dengan keterangan: $keterangan dan Nominal: $saldo',
      );
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
    if (_tanggalPengeluaranController.text.isEmpty ||
        _saldoPengeluaranController.text.isEmpty ||
        _tanggalPengeluaranController.text.isEmpty) {
      Flushbar(
        message: "Data tidak lengkap",
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    if (isLainnyaSelected) {
      final kode = _lainnyaRtController.text.trim();
      final ket = _lainnyaRtKetController.text.trim();

      if (kode.isEmpty || ket.isEmpty) {
        Fluttertoast.showToast(
          msg: "Kode COA dan keterangan tidak boleh kosong",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
        );
        return;
      }
      bool sudahAda =
          rtCoaData.any((item) => item['coa'] == kode || item['ket'] == ket);

      if (sudahAda) {
        Fluttertoast.showToast(
          msg: "Kode COA atau keterangan sudah terdaftar",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
        );
        return;
      }
      await tambahDataCOA(kode, ket, "Pengeluaran");
    }
    final prefs = await SharedPreferences.getInstance();
    String? noKavling = prefs.getString('noKavling');
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
              backgroundColor: Color(0xFFFDECE8),
              title: Text('Konfirmasi',
                  style: GoogleFonts.lato(color: Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal: ${_tanggalPengeluaranController.text}'
                      '\nRincian: ${_ketPengeluaranController.text}'
                      '\nKode COA: ${selectedRt} ${_lainnyaRtController.text.isNotEmpty ? ' (${_lainnyaRtController.text})' : ""}'
                      '\nNominal: Rp ${_saldoPengeluaranController.text}',
                      style: GoogleFonts.lato(color: Colors.black),
                    ),
                    const SizedBox(height: 15),
                    Text('Metode Pembayaran (Wajib):',
                        style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    // --- COMBOBOX / DROPDOWN METODE ---
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
                    const SizedBox(height: 10),
                    Text(
                        '\nApakah anda yakin ingin menyimpan data pengeluaran ini?',
                        style: GoogleFonts.lato(color: Colors.black)),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Batal',
                      style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
                  onPressed: () => Navigator.of(context).pop(),
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
                      _tanggalPengeluaranController.text,
                      _ketPengeluaranController.text,
                      _saldoPengeluaranController.text,
                      noKavling.toString(),
                      selectedMetode!,
                    );

                          
                            savedEntry = {
                              'tanggal': _tanggalPengeluaranController.text,
                              'keterangan':
                                _ketPengeluaranController.text,
                              'nominal':_saldoPengeluaranController.text,
                              'no_kavling': noKavling.toString(),
                            };

                            _tanggalPengeluaranController.clear();
                      _ketPengeluaranController.clear();
                      _saldoPengeluaranController.clear();
                      _lainnyaRtController.clear();
                      _lainnyaRtKetController.clear();
                      isLainnyaSelected = false;
                      selectedRt = null;
                      selectedMetode = null;

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
          recentPengeluaran.insert(0, savedEntry!);
        }
        isLainnyaSelected = false;
        selectedRt = null;
        selectedMetode = null;
        
        
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
                                        builder: (context) =>
                                            MenuPilihanPage(idMenu: 5),
                                      ),
                                    )
                                  }),
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
                      _buildDateField(
                          context,
                          _tanggalPengeluaranController,
                          'Tanggal Pengeluaran (dd-MM-yyyy-HH:mm)',
                          Icons.date_range),
                      SizedBox(height: 16),
                      _buildInputField(context, _ketPengeluaranController,
                          'Keterangan Pengeluaran', Icons.description),
                      SizedBox(height: 16),
                      _buildSaldoField(context, _saldoPengeluaranController,
                          'Saldo Pengeluaran', Icons.money),
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
                                }),
                        Text(
                          'Form Input Pengeluaran',
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
            SizedBox(height: 20),
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
                                "Tambah\nPengeluaran 🛈",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Pengurus RT menambahkan\npengeluaran secara manual",
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
                                child: recentPengeluaran.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "Belum ada data yang ditambahkan",
                                          style:
                                              TextStyle(color: Colors.white70),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: recentPengeluaran.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                color: Colors.white24),
                                        itemBuilder: (context, index) {
                                          final item = recentPengeluaran[index];
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
                                        _tanggalPengeluaranController,
                                        'Tanggal Pengeluaran (dd-MM-yyyy-HH:mm)',
                                        Icons.date_range),
                                    SizedBox(height: 16),
                                    _buildInputField(
                                        context,
                                        _ketPengeluaranController,
                                        'Keterangan Pengeluaran',
                                        Icons.description),
                                    SizedBox(height: 16),
                                    _buildSaldoField(
                                        context,
                                        _saldoPengeluaranController,
                                        'Saldo Pengeluaran',
                                        Icons.money),
                                    SizedBox(height: 16),
                                    _buildRtDropdownField(),
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

          // Set first date ke tanggal 1 bulan ini
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
    if (recentPengeluaran.isEmpty) {
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
      itemCount: recentPengeluaran.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
      itemBuilder: (context, index) {
        final item = recentPengeluaran[index];
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
