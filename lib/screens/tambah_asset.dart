import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

class TambahAsetPage extends StatefulWidget {
  @override
  _TambahAsetPageState createState() => _TambahAsetPageState();
}

class _TambahAsetPageState extends State<TambahAsetPage> {
  final TextEditingController _namaAssetController = TextEditingController();
  final TextEditingController _jumlahAssetController = TextEditingController();
  final TextEditingController _tanggalDiterimaController =
      TextEditingController();
  final TextEditingController _hargaAssetController = TextEditingController();
  final TextEditingController _tahunPenyusutanController =
      TextEditingController();

  // Riwayat aset yang baru disimpan (di halaman ini)
  List<Map<String, String>> recentAset = [];

  final List<String> kategoriAssetList = [
    'Inventaris',
    'Peralatan',
    'Perabot',
    'Elektronik',
    'Bangunan',
    'Infrastruktur',
    'Kendaraan',
    'Aset Lingkungan',
    'Lainnya',
  ];

  final List<String> satuanAssetList = [
    'Unit',
    'Buah',
    'Set',
    'Paket',
    'Lembar',
    'Pasang',
    'Meter',
    'Meter Persegi (m²)',
    'Meter Kubik (m³)',
    'Box',
    'Dus',
  ];

  final List<String> sumberAssetList = [
    'Iuran Warga',
    'Kas RT',
    'Donasi Warga',
    'Donatur',
    'Sumbangan',
    'Bantuan Pemerintah',
    'Bantuan Kelurahan',
    'Bantuan CSR',
    'Hibah',
    'Lainnya',
  ];

  String? selectedKategoriAsset;
  String? selectedSatuanAsset;
  String? selectedSumberAsset;

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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal menambahkan data: ${result['message']}')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal koneksi ke server')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  /// Simpan aset ke server. Melempar Exception jika gagal,
  /// notifikasi & navigasi ditangani oleh dialog konfirmasi.
  Future<void> tambahDataAset(
      String nama,
      String jum,
      String kat,
      String satuan,
      String tanggal,
      String harga,
      String sumber,
      String tahunPenyusutan) async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambah_aset.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nama": nama,
        "jumlah": jum,
        "harga": harga,
        "kategori": kat,
        "satuan": satuan,
        "tanggal": tanggal,
        "sumber": sumber,
        'id_rt': KodeRt.kodeRt,
        "tahun_penyusutan": tahunPenyusutan
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] == 'success') {
      await tambahLogAktivitas(
          aktivitas:
              "Menambahkan aset: $nama, jumlah: $jum $satuan, dan harga: Rp $harga");
    } else {
      throw Exception(data['message'] ?? 'Gagal menyimpan data');
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_tanggalDiterimaController.text.isEmpty ||
        _hargaAssetController.text.isEmpty ||
        _jumlahAssetController.text.isEmpty ||
        _namaAssetController.text.isEmpty ||
        selectedKategoriAsset == null ||
        selectedSatuanAsset == null ||
        selectedSumberAsset == null ||
        _tahunPenyusutanController.text.isEmpty) {
      Flushbar(
        message: "Data tidak lengkap",
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
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
              title: Text(
                'Konfirmasi',
                style: GoogleFonts.lato(color: Colors.black),
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Nama Aset : ${_namaAssetController.text}'
                  '\nKategori : $selectedKategoriAsset'
                  '\nJumlah   : ${_jumlahAssetController.text} $selectedSatuanAsset'
                  '\nHarga    : Rp ${_hargaAssetController.text}'
                  '\nTanggal  : ${_tanggalDiterimaController.text}'
                  '\nSumber   : $selectedSumberAsset'
                  '\nTahun Penyusutan   : ${_tahunPenyusutanController.text}'
                  '\n\nApakah Anda yakin ingin menyimpan aset ini?',
                  style: GoogleFonts.lato(color: Colors.black),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.lato(color: const Color(0xFF3D8D7A)),
                  ),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null // cegah klik ganda
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await tambahDataAset(
                              _namaAssetController.text,
                              _jumlahAssetController.text,
                              selectedKategoriAsset.toString(),
                              selectedSatuanAsset.toString(),
                              _tanggalDiterimaController.text,
                              _hargaAssetController.text,
                              selectedSumberAsset.toString(),
                              _tahunPenyusutanController.text,
                            );

                            // snapshot data SEBELUM controller di-clear
                            savedEntry = {
                              'nama': _namaAssetController.text,
                              'jumlah':
                                  '${_jumlahAssetController.text} $selectedSatuanAsset',
                              'harga': _hargaAssetController.text,
                              'tanggal': _tanggalDiterimaController.text,
                              'kategori': selectedKategoriAsset ?? '-',
                              'sumber': selectedSumberAsset ?? '-',
                            };

                            _namaAssetController.clear();
                            _jumlahAssetController.clear();
                            _hargaAssetController.clear();
                            _tanggalDiterimaController.clear();
                            _tahunPenyusutanController.clear();

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
                      : Text(
                          'Simpan',
                          style:
                              GoogleFonts.lato(color: const Color(0xFF3D8D7A)),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    // Dialog sudah tertutup — tetap di halaman ini
    if (berhasil == true && parentContext.mounted) {
      setState(() {
        if (savedEntry != null) {
          recentAset.insert(0, savedEntry!);
        }
        selectedKategoriAsset = null;
        selectedSatuanAsset = null;
        selectedSumberAsset = null;
      });

      Flushbar(
        message: "Data aset berhasil disimpan",
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

  List<Widget> _formFields(BuildContext context) {
    return [
      _buildDateField(
          context,
          _tanggalDiterimaController,
          'Tanggal Menerima Aset (dd-MM-yyyy-HH:mm)',
          Icons.date_range),
      const SizedBox(height: 16),
      _buildInputField(
          context, _namaAssetController, 'Nama Aset', Icons.description),
      const SizedBox(height: 16),
      _buildInputFieldJum(
          context, _jumlahAssetController, 'Jumlah Aset', Icons.description),
      const SizedBox(height: 16),
      _buildSaldoField(
          context, _hargaAssetController, 'Harga Aset', Icons.money),
      const SizedBox(height: 16),
      _buildInputFieldJum(context, _tahunPenyusutanController,
          'Tahun Penyusutan', Icons.description),
      const SizedBox(height: 16),
      _buildKatDropdownField(),
      const SizedBox(height: 16),
      _buildSatDropdownField(),
      const SizedBox(height: 16),
      _buildSumDropdownField(),
      const SizedBox(height: 16),
      _buildSubmitButton(),
    ];
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.black),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Text(
                            'Form Input Aset',
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ..._formFields(context),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'Form Input Aset',
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
                        // CARD KIRI
                        Container(
                          width: 500,
                          height: 580,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C9D8F),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.all(35),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tambah\nAset 🛈",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Pengurus RT menambahkan\naset-aset pada sistem RT Digital",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
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
                              Expanded(child: _buildRecentList()),
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
                                    ..._formFields(context),
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

  /// Daftar aset yang baru disimpan
  Widget _buildRecentList({bool shrinkWrap = false}) {
    if (recentAset.isEmpty) {
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
      itemCount: recentAset.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
      itemBuilder: (context, index) {
        final item = recentAset[index];
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
        border: Border.all(color: const Color(0xFFB7B9B6)),
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

  Widget _buildInputFieldJum(BuildContext context,
      TextEditingController controller, String hintText, IconData icon) {
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

  Widget _buildSaldoField(BuildContext context,
      TextEditingController controller, String hintText, IconData icon) {
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

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String errorText,
  }) {
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
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.description, color: Colors.black),
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
            ),
            value: value,
            items: items.map((String v) {
              return DropdownMenuItem<String>(
                value: v,
                child: Text(v),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (v) => v == null ? errorText : null,
          ),
        ),
      ],
    );
  }

  Widget _buildKatDropdownField() {
    return _buildDropdown(
      hint: 'Pilih Kategori Aset',
      value: selectedKategoriAsset,
      items: kategoriAssetList,
      errorText: 'Kategori wajib dipilih',
      onChanged: (v) => setState(() => selectedKategoriAsset = v),
    );
  }

  Widget _buildSatDropdownField() {
    return _buildDropdown(
      hint: 'Pilih Satuan Aset',
      value: selectedSatuanAsset,
      items: satuanAssetList,
      errorText: 'Satuan aset wajib dipilih',
      onChanged: (v) => setState(() => selectedSatuanAsset = v),
    );
  }

  Widget _buildSumDropdownField() {
    return _buildDropdown(
      hint: 'Pilih Sumber Aset',
      value: selectedSumberAsset,
      items: sumberAssetList,
      errorText: 'Sumber aset wajib dipilih',
      onChanged: (v) => setState(() => selectedSumberAsset = v),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: Container(
        width: 500,
        height: 50,
        decoration: ShapeDecoration(
          color: const Color(0xFF3D8D7A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: TextButton(
          onPressed: _showConfirmationDialog,
          child: const Text(
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