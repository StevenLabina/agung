import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_neraca.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';

// import 'package:iuran_rt_web/screens/laporan_keuangan.dart';

// import 'package:iuran_rt_web/screens/laporan_keuangan_pengeluaran.dart';
// import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
// import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';

import 'package:iuran_rt_web/url.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganAsetPage extends StatefulWidget {
  final String numberMonth;
  final String month;
  final String year;

  const LaporanKeuanganAsetPage(
      {super.key, this.numberMonth = "", this.month = "", this.year = ""});
  @override
  _LaporanKeuanganAsetPageState createState() =>
      _LaporanKeuanganAsetPageState();
}

class _LaporanKeuanganAsetPageState extends State<LaporanKeuanganAsetPage> {
  List<dynamic> dataLaporanKeu = [];
  bool isLoading = false;
  bool isDownload = false;
  double totalHargaAset = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoKeu = 0;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  double saldobalance = 0;
  double runningBalance = 0;
  String selectedMonth = 'Tahun';
  String monthNum = 'Tahun';
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

  int currentPage = 0;
  int rowsPerPage = 10;
  int get totalPages {
    if (dataLaporanKeu.isEmpty) return 1;
    return (dataLaporanKeu.length / rowsPerPage).ceil();
  }

  List<dynamic> get paginatedData {
    if (dataLaporanKeu.isEmpty) return [];

    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, dataLaporanKeu.length);

    return dataLaporanKeu.sublist(start, end);
  }

  // '' = semua bulan
  String selectedMonthNumber = ''; // '01' - '12'
  late List<String> yearList;
  String? currentYear;
  @override
  void initState() {
    super.initState();

    final now = DateTime.now().year;
    yearList = List.generate(
      5,
      (index) => (now - index).toString(),
    );

    currentYear = yearList.first;

    // default load → semua bulan di tahun sekarang
    fetchLaporanKeuangan();
  }

  Future<void> _showConfirmationDialog(
      String tanggal,
      String nama,
      String jum,
      String harga,
      String kategori,
      int id,
      String sumber,
      String satuan) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFDECE8),
          title:
              Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
          content: Text(
              'Tanggal Diterima: ${tanggal}'
              '\nNama Aset: $nama'
              '\nJumlah: $jum'
              '\nSatuan: $satuan'
              '\nHarga:Rp $harga'
              '\nKategori: $kategori'
              '\nSumber: $sumber'
              '\n==================================='
              '\nApakah anda yakin ingin menghapus data aset ini?',
              style: GoogleFonts.lato(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: Text('Batal',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Hapus',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
              onPressed: () async {
                DateTime parsedDate =
                    DateFormat('dd-MM-yyyy-HH:mm').parse(tanggal);

                String monthShort = getMonthShortName(parsedDate.month);
                int numberMonth = parsedDate.month;
                await deleteDataAsset(id);
                await tambahLogAktivitas(
                    aktivitas: 'Menghapus data aset: $nama');
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LaporanKeuanganAsetPage(
                      month: monthShort,
                      numberMonth: numberMonth.toString(),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDetailDialog(
      String tanggal,
      String nama,
      String jum,
      String hargaDiterima,
      String hargaSaatIni,
      String nominalPenyusutan,
      String tahunPenyusutan,
      String tahunAkumulasiPenyusutan,
      String kategori,
      String sumber,
      String satuan) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFDECE8),
          title:
              Text('Konfirmasi', style: GoogleFonts.lato(color: Colors.black)),
          content: Text(
              'Tanggal Diterima: ${tanggal}'
              '\nNama Aset: $nama'
              '\nJumlah: $jum'
              '\nSatuan: $satuan'
              '\nHarga aset Diterima:Rp $hargaDiterima'
              '\nHarga aset Saat ini:Rp $hargaSaatIni'
              '\nNominal Penyusutan:Rp $nominalPenyusutan'
              '\nTahun Penyusutan: $tahunPenyusutan'
              '\nTahun Akumulasi Penyusutan: $tahunAkumulasiPenyusutan'
              '\nKategori: $kategori'
              '\nSumber: $sumber',
              style: GoogleFonts.lato(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: Text('Tutup',
                  style: GoogleFonts.lato(color: Color(0xFF3D8D7A))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> createAndUploadPdf() async {
    final filteredData = paginatedData.where((item) {
      final saldo = (item['harga_asset'] ?? '').toString().trim();
      final ket = (item['nama_asset'] ?? '').toString().trim();
      return saldo.isNotEmpty &&
          saldo.toLowerCase() != 'null' &&
          ket.isNotEmpty &&
          ket.toLowerCase() != 'null';
    }).toList();

    const int chunkSize = 300;
    final int totalChunks = (filteredData.length / chunkSize).ceil();

    // =========================================================
    // CASE 1 — DATA <= 300 → LANGSUNG PDF
    // =========================================================
    if (filteredData.length <= chunkSize) {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          footer: (context) => _buildFooter(),
          build: (context) => [
            _buildHeader(),
            _buildTable(filteredData),
          ],
        ),
      );

      final Uint8List encoded = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([encoded], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download",
              "Laporan Keuangan Aset ${selectedMonth} ${currentYear}.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      return;
    }

    // =========================================================
    // CASE 2 — DATA > 300 → KONFIRMASI
    // =========================================================
    bool proceed = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Konfirmasi Multiple PDF"),
            content: Text(
              "Data melebihi $chunkSize baris.\n"
              "Akan dibuat $totalChunks file PDF "
              "dan digabung menjadi 1 file ZIP.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Lanjutkan"),
              ),
            ],
          ),
        ) ??
        false;

    if (!proceed) return;

    // =========================================================
    // CASE 3 — MULTIPLE PDF → ZIP (FIXED)
    // =========================================================
    final Archive zip = Archive();

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = math.min(start + chunkSize, filteredData.length);

      final chunkData = filteredData.sublist(start, end);
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          footer: (context) => _buildFooter(),
          build: (context) => [
            _buildHeader(),
            _buildTable(chunkData),
          ],
        ),
      );

      final Uint8List encoded = await pdf.save();

      zip.addFile(
        ArchiveFile(
          "Laporan Keuangan Aset ${selectedMonth} ${currentYear}_Part${i + 1}.pdf",
          encoded.length,
          encoded, // ✅ FIX UTAMA (JANGAN toList)
        ),
      );
    }

    if (kIsWeb) {
      final zipData = ZipEncoder().encode(zip)!;
      final blob = html.Blob([zipData], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download",
            "Laporan Keuangan Aset ${selectedMonth} ${currentYear}.zip")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Terima kasih telah menggunakan aplikasi RT Digital',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Created by RT Digital',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Laporan Keuangan Aset ${selectedMonth} ${currentYear}',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(KodeRt.namaRt, style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildTable(List<dynamic> data) {
    return pw.Table.fromTextArray(
      headers: [
        'Tanggal',
        'Nama Aset',
        'Jumlah Aset',
        'Harga Diterima',
        'Harga Saat Ini',
        'Nom Penyusutan',
        'Thn Penyusutan',
        'Thn Akm Penyusutan',
      ],
      data: data.map((item) {
        final double harga = double.tryParse(
              (item['harga_asset'] ?? '0').toString().replaceAll('.', ''),
            ) ??
            0;
        final double hargaSaatIni = double.tryParse(
              (item['harga_asset_sekarang'] ?? '0')
                  .toString()
                  .replaceAll('.', ''),
            ) ??
            0;
        final double nomPenyusutan = double.tryParse(
              (item['penyusutan_tahunan'] ?? '0')
                  .toString()
                  .replaceAll('.', ''),
            ) ??
            0;

        return [
          item['tanggal_diterima'] ?? '-',
          item['nama_asset'] ?? '-',
          item['jumlah_asset'] ?? '0',
          'Rp ${formatRupiah(harga)}',
          'Rp ${formatRupiah(hargaSaatIni)}',
          'Rp ${formatRupiah(nomPenyusutan)}',
          '${item['tahun_penyusutan']} tahun',
          '${item['tahun_akm_penyusutan']} tahun',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(70),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(70),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(60),
      },
    );
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject =
        excel['Laporan Keuangan Aset $selectedMonth $currentYear'];

    int row = 0;

// ================= JUDUL =================
    sheetObject.merge(
      exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      exc.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );

    sheetObject
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'Laporan Keuangan Aset $selectedMonth $currentYear';

    row++;

// ================= HEADER TABLE =================
    List<String> headers = [
      'Tanggal',
      'Nama Aset',
      'Jumlah Aset',
      'Harga Diterima',
      'Harga Saat Ini',
      'Nom Penyusutan',
      'Thn Penyusutan',
      'Thn Akm Penyusutan',
    ];

// appendRow selalu nambah baris otomatis
    sheetObject.appendRow(headers);
    row++;

// ================= DATA =================
    for (var item in paginatedData) {
      if ((item['nama_asset'] ?? '').toString().trim().isEmpty &&
          (item['kategori_asset'] ?? '').toString().trim().isEmpty &&
          (item['jumlah_asset'] ?? '').toString().trim().isEmpty &&
          (item['satuan_asset'] ?? '').toString().trim().isEmpty &&
          (item['tanggal_diterima'] ?? '').toString().trim().isEmpty &&
          (item['harga_asset'] ?? '').toString().trim().isEmpty &&
          (item['harga_asset_sekarang'] ?? '').toString().trim().isEmpty &&
          (item['penyusutan_tahunan'] ?? '').toString().trim().isEmpty &&
          (item['sumber_asset'] ?? '').toString().trim().isEmpty &&
          (item['tahun_penyusutan'] ?? '').toString().trim().isEmpty &&
          (item['tahun_akm_penyusutan'] ?? '').toString().trim().isEmpty) {
        continue;
      }

      final double harga = double.tryParse(
            (item['harga_asset'] ?? '0').toString().replaceAll('.', ''),
          ) ??
          0;
      final double hargaSaatIni = double.tryParse(
            (item['harga_asset_sekarang'] ?? '0')
                .toString()
                .replaceAll('.', ''),
          ) ??
          0;

      final int jumlah = int.tryParse(item['jumlah_asset'].toString()) ?? 0;
      final double nomPenyusutan = double.tryParse(
            (item['penyusutan_tahunan'] ?? '0').toString().replaceAll('.', ''),
          ) ??
          0;
      List<String> rowData = [
        item['tanggal_diterima'] ?? '-',
        item['nama_asset'] ?? '-',
        jumlah.toString(),
        'Rp ${formatRupiah(harga)}',
        'Rp ${formatRupiah(hargaSaatIni)}',
        'Rp ${formatRupiah(nomPenyusutan)}',
        '${item['tahun_penyusutan']} tahun',
        '${item['tahun_akm_penyusutan']} tahun',
      ];

      sheetObject.appendRow(rowData);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download",
            "Laporan Keuangan Aset ${selectedMonth} ${currentYear}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Aset ${selectedMonth} ${currentYear}.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
    }
  }

  // Future<void> checkTanggalPeringatan(BuildContext context) async {
  //   final now = DateTime.now();
  //   final prefs = await SharedPreferences.getInstance();

  //   final keyPendapatan = "isDownload_${now.year}";
  //   isDownload = prefs.getBool(keyPendapatan) ?? false;

  //   if (now.month == 12 && now.day >= 27 && isDownload == false) {
  //     Future.delayed(Duration.zero, () {
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             title: Text("Peringatan Akhir Tahun"),
  //             content: Text(
  //               "Tanggal ${now.day}-${now.month}-${now.year}. "
  //               "Tahun akan segera berganti.\n\n"
  //               "Silakan download laporan keuangan tahun ${now.year} "
  //               "sebelum data dihapus pada awal tahun baru.",
  //             ),
  //             actions: [
  //               ElevatedButton(
  //                 onPressed: () async {
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(
  //                         builder: (context) => LaporanKeuanganAsetPage()),
  //                   );
  //                   await exportToExcel();
  //                   await prefs.setBool(keyPendapatan, true);
  //                   isDownload = true;
  //                 },
  //                 child: Text("Download"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     });
  //   }
  // }

  // void simulateLastYear() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(
  //       'last_saved_year', (DateTime.now().year - 1).toString());
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

  Future<void> deleteDataAsset(int id) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}delete_aset.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id': id,
          'id_rt': KodeRt.kodeRt,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['result'] == 'success') {
        Flushbar(
          message: "Data aset berhasil dihapus",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        Flushbar(
          message: 'Gagal menghapus data: ${data['message']}',
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

  // Future<void> checkYearChangeAndTruncate() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   String currentYear1 = currentYear.toString();
  //   final lastSavedYear = prefs.getString('last_saved_year') ?? currentYear1;

  //   if (lastSavedYear != currentYear1) {
  //     // await exportToExcelOnlySendPath(
  //     //   lastSavedYear,
  //     //   totalSaldoPendapatan.toString(),
  //     //   totalSaldoPengeluaran.toString(),
  //     //   totalSaldoKeu.toString(),
  //     // );

  //     final response = await http.post(
  //       Uri.parse('${ApiUrls.baseUrl}deleteListLaporanKeu.php'),
  //       body: {
  //         'id_rt': KodeRt.kodeRt,
  //       },
  //     );

  //     final json = jsonDecode(response.body);

  //     if (json['result'] == 'success') {
  //       await prefs.setString('last_saved_year', currentYear1);
  //       print(
  //           "Data tahun $lastSavedYear berhasil di-export & dihapus. Tahun aktif: $currentYear1");
  //     } else {
  //       Fluttertoast.showToast(
  //         msg: 'Gagal menghapus data lama: ${json['message']}',
  //       );
  //     }
  //   }
  // }

  Future<void> fetchLaporanKeuangan({String? bulan}) async {
    setState(() {
      isLoading = true;
    });

    final idRt = KodeRt.kodeRt;

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl.endsWith('/') ? ApiUrls.baseUrl : '${ApiUrls.baseUrl}/'}list_aset.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'id_rt': idRt,
        if (bulan != null && bulan.isNotEmpty) 'bulan': bulan,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        dataLaporanKeu = result['data'];

        double totalAsset = dataLaporanKeu.fold(0.0, (sum, item) {
          final rawSaldo = item['harga_asset'].toString().replaceAll('.', '');
          final saldo = double.tryParse(rawSaldo) ?? 0;
          return sum + saldo;
        });

        setState(() {
          totalHargaAset = totalAsset;
        });
      } else {
        setState(() {
          dataLaporanKeu = [];
          totalHargaAset = 0;
        });

        Flushbar(
          message: "Data Tidak Ditemukan",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  // void _showSaldoAwalDialog(BuildContext context) async {
  //   final TextEditingController saldoAwalController = TextEditingController();
  //   final prefs = await SharedPreferences.getInstance();
  //   String? noKavling = prefs.getString('noKavling');

  //   String currentDate = DateFormat('dd-MM-yyyy-HH:mm').format(DateTime.now());
  //   final now = DateTime.now();
  //   final tanggalRef = DateFormat('yyMMdd').format(now);

  //   String kodeRef = generateKodeRef(
  //     namaRT: KodeRt.kodeRt.toUpperCase(),
  //     kodeIuran: '003',
  //     alamatKavling: noKavling.toString(),
  //     tanggalLunas: tanggalRef,
  //     kodeTransaksi: '0000',
  //   );
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           return AlertDialog(
  //             title: Text('Saldo awal'),
  //             content: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 TextField(
  //                   controller: saldoAwalController,
  //                   keyboardType: TextInputType.number,
  //                   inputFormatters: [
  //                     FilteringTextInputFormatter.digitsOnly,
  //                     ThousandsSeparatorInputFormatter(),
  //                   ],
  //                   decoration: InputDecoration(
  //                     hintText: 'Saldo Awal Tahun',
  //                     border: OutlineInputBorder(),
  //                   ),
  //                 ),
  //                 SizedBox(height: 10),
  //               ],
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: Text('Batal'),
  //               ),
  //               TextButton(
  //                 onPressed: () async {
  //                   await tambahDataLaporan(
  //                     currentDate,
  //                     "Saldo Awal Tahun",
  //                     saldoAwalController.text,
  //                     "800",
  //                     kodeRef.toString(),
  //                     noKavling.toString(),
  //                   );

  //                   Navigator.of(context).pop();

  //                   await fetchLaporanKeuangan();

  //                   setState(() {});
  //                 },
  //                 child: Text('Cek'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MenuPilihanPage(
                                idMenu: 3,
                              ),
                            ),
                          );
                        },
                      ),
                      Text(
                        'Laporan Aset',
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  // _buildFilterButton('Pendapatan', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPendapatanPage()),
                  //   );
                  // }),
                  // _buildFilterButton('Pengeluaran', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPengeluaranPage()),
                  //   );
                  // }),

                  // _buildFilterButton('Kas', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => LaporanKeuanganPage()),
                  //   );
                  // }),
                  _buildFilterButton('Surplus/Defisit', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              LaporanKeuanganSurplusDefisitPage()),
                    );
                  }),
                  _buildFilterButton('Utang', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganUtangPage()),
                    );
                  }),

                  _buildFilterButton('Aset', isActive: true, onPressed: () {}),
                  _buildFilterButton('Neraca', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganNeracaPage()),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Wrap(
          //     spacing: 8,
          //     runSpacing: 8,
          //     alignment: WrapAlignment.center,
          //     children: [
          //       _buildFilterButton('Pendapatan', isActive: true, onPressed: () {}),
          //       _buildFilterButton('Pengeluaran', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganPengeluaranPage()),
          //         );
          //       }),
          //       _buildFilterButton('Utang', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganUtangPage()),
          //         );
          //       }),
          //       _buildFilterButton('Kas', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganPage()),
          //         );
          //       }),
          //       _buildFilterButton('Surplus/Defisit', onPressed: () {
          //         Navigator.pushReplacement(
          //           context,
          //           MaterialPageRoute(builder: (context) => LaporanKeuanganSurplusDefisitPage()),
          //         );
          //       }),
          //     ],
          //   ),
          // ),

          // const SizedBox(height: 8),

          // Filter bulan
          // SingleChildScrollView(
          //   scrollDirection: Axis.horizontal,
          //   padding: const EdgeInsets.symmetric(horizontal: 8),
          //   child: Row(
          //     children: [
          //       _buildMonthButton('All', onPressed: fetchLaporanKeuangan),
          //       ...List.generate(12, (index) {
          //         final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
          //         final monthNumber = (index + 1).toString().padLeft(2, '0');
          //         return _buildMonthButton(monthNames[index], onPressed: () {
          //           fetchLaporanKeuangan(bulan: monthNumber);
          //         });
          //       }),
          //     ],
          //   ),
          // ),

          // const SizedBox(height: 8),

          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   child: Text(
          //     'Total Pendapatan: ${currencyFormat.format(totalSaldoPendapatan)}',
          //     style: const TextStyle(
          //       fontSize: 16,
          //       fontWeight: FontWeight.bold,
          //       color: Color(0xFF3D8D7A),
          //     ),
          //   ),
          // ),

          // const SizedBox(height: 8),

          Align(
            alignment: Alignment.center,
            child: Text(
              'Total Harga Aset $selectedMonth $currentYear: ${_formatCurrencyTotal(totalHargaAset)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildMonthButton(
                  'Semua',
                  isSelected: selectedMonth.isEmpty,
                  onPressed: () {
                    setState(() {
                      selectedMonth = '';
                      selectedMonthNumber = '';
                    });

                    fetchLaporanKeuangan();
                  },
                ),
                ...List.generate(12, (index) {
                  final monthNames = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'Mei',
                    'Jun',
                    'Jul',
                    'Agu',
                    'Sep',
                    'Okt',
                    'Nov',
                    'Des'
                  ];
                  final monthNumber = (index + 1).toString().padLeft(2, '0');

                  return _buildMonthButton(
                    monthNames[index],
                    isSelected: selectedMonth == monthNames[index],
                    onPressed: () {
                      setState(() {
                        selectedMonth = monthNames[index];
                        selectedMonthNumber = monthNumber;
                      });

                      // 🔑 filter bulan + tahun
                      fetchLaporanKeuangan(
                        bulan: monthNumber,
                      );
                    },
                  );
                }),
              ],
            ),
          ),

          SizedBox(height: 8),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paginatedData.isEmpty
                      ? const Center(child: Text('Tidak ada data aset'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // final formatter = NumberFormat('#,###', 'id_ID');

                            return ScrollConfiguration(
                              behavior: MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Column(
                                    children: [
                                      // HEADER
                                      Table(
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(100),
                                          2: FixedColumnWidth(150),
                                          3: FixedColumnWidth(150),
                                          4: FixedColumnWidth(150),
                                          5: FixedColumnWidth(150),
                                          6: FixedColumnWidth(100),
                                          7: FixedColumnWidth(100),
                                          8: FixedColumnWidth(150),
                                          9: FixedColumnWidth(150),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3D8D7A),
                                            ),
                                            children: [
                                              _buildTableHeader(
                                                  'Tanggal Diterima'),
                                              _buildTableHeader('Nama'),
                                              _buildTableHeader('Jumlah'),
                                              _buildTableHeader(
                                                  'Harga Diterima'),
                                              _buildTableHeader(
                                                  'Harga Saat Ini'),
                                              _buildTableHeader(
                                                  'Nom Penyusutan'),
                                              _buildTableHeader(
                                                  'Thn Penyusutan'),
                                              _buildTableHeader(
                                                  'Thn Akm Penyusutan'),
                                              _buildTableHeader('Aksi'),
                                              _buildTableHeader('Info'),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // DATA
                                      Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(100),
                                          2: FixedColumnWidth(150),
                                          3: FixedColumnWidth(150),
                                          4: FixedColumnWidth(150),
                                          5: FixedColumnWidth(150),
                                          6: FixedColumnWidth(100),
                                          7: FixedColumnWidth(100),
                                          8: FixedColumnWidth(150),
                                          9: FixedColumnWidth(150),
                                        },
                                        children: paginatedData
                                            .where((item) =>
                                                item['nama_asset'] != null &&
                                                item['tanggal_diterima'] !=
                                                    null)
                                            .map((item) {
                                          // final double harga = double.tryParse(
                                          //         (item['harga_asset'] ?? '0')
                                          //             .toString()
                                          //             .replaceAll('.', '')) ??
                                          //     0;

                                          // final int jumlah = int.tryParse(
                                          //         item['jumlah_asset']
                                          //             .toString()) ??
                                          //     0;

                                          // final double totalNilai =
                                          //     harga * jumlah;

                                          return TableRow(
                                            children: [
                                              _buildTableCell(
                                                  item['tanggal_diterima']),
                                              _buildTableCell(
                                                  item['nama_asset']),
                                              _buildTableCell(
                                                  '${item['jumlah_asset']}'),
                                              _buildTableCell(
                                                  'Rp ${item['harga_asset']}'),
                                              _buildTableCell(
                                                  'Rp ${item['harga_asset_sekarang']}'),
                                              _buildTableCell(item[
                                                          'penyusutan_tahunan'] !=
                                                      null
                                                  ? 'Rp ${item['penyusutan_tahunan']}'
                                                  : '-'),
                                              _buildTableCell(
                                                  '${item['tahun_penyusutan']} tahun'),
                                              _buildTableCell(
                                                  '${item['tahun_akm_penyusutan']} tahun'),
                                              Center(
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    minimumSize:
                                                        const Size(80, 35),
                                                  ),
                                                  onPressed: () async {
                                                    var id = item['id'];
                                                    var tanggal = item[
                                                        'tanggal_diterima'];
                                                    var nama =
                                                        item['nama_asset'];
                                                    var harga =
                                                        item['harga_asset'];
                                                    var kategori =
                                                        item['kategori_asset'];
                                                    var jumlah =
                                                        item['jumlah_asset'];
                                                    var satuan =
                                                        item['satuan_asset'];
                                                    var sumber =
                                                        item['sumber_asset'];

                                                    try {
                                                      _showConfirmationDialog(
                                                          tanggal,
                                                          nama,
                                                          jumlah,
                                                          harga,
                                                          kategori,
                                                          id,
                                                          sumber,
                                                          satuan);
                                                    } catch (e) {
                                                      Flushbar(
                                                        message:
                                                            'Terjadi kesalahan: $e',
                                                        duration: Duration(
                                                            seconds: 2),
                                                        backgroundColor:
                                                            Colors.red,
                                                        flushbarPosition:
                                                            FlushbarPosition
                                                                .TOP,
                                                      ).show(context);
                                                    }
                                                  },
                                                  child: const Text(
                                                    "Hapus",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blueAccent,
                                                    minimumSize:
                                                        const Size(80, 35),
                                                  ),
                                                  onPressed: () async {
                                                    var tanggal = item[
                                                        'tanggal_diterima'];
                                                    var nama =
                                                        item['nama_asset'];
                                                    var hargaDit =
                                                        item['harga_asset'];
                                                    var hargaSek = item[
                                                        'harga_asset_sekarang'];
                                                    var nomPenyu = item[
                                                        'penyusutan_tahunan'];
                                                    var tahunPenyu = item[
                                                        'tahun_penyusutan'];
                                                    var tahunAkmPenyu = item[
                                                        'tahun_akm_penyusutan'];
                                                    var kategori =
                                                        item['kategori_asset'];
                                                    var jumlah =
                                                        item['jumlah_asset'];
                                                    var satuan =
                                                        item['satuan_asset'];
                                                    var sumber =
                                                        item['sumber_asset'];
                                                    try {
                                                      _showDetailDialog(
                                                        tanggal.toString(),
                                                        nama.toString(),
                                                        jumlah.toString(),
                                                        hargaDit.toString(),
                                                        hargaSek.toString(),
                                                        nomPenyu.toString(),
                                                        tahunPenyu.toString(),
                                                        tahunAkmPenyu
                                                            .toString(),
                                                        kategori.toString(),
                                                        sumber.toString(),
                                                        satuan.toString(),
                                                      );
                                                    } catch (e) {
                                                      Flushbar(
                                                        message:
                                                            'Terjadi kesalahan: $e',
                                                        duration: Duration(
                                                            seconds: 2),
                                                        backgroundColor:
                                                            Colors.red,
                                                        flushbarPosition:
                                                            FlushbarPosition
                                                                .TOP,
                                                      ).show(context);
                                                      print(e);
                                                    }
                                                  },
                                                  child: const Text(
                                                    "Detail",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          SizedBox(height: 8),
          dataLaporanKeu.isEmpty
              ? const SizedBox()
              : Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton.extended(
                        backgroundColor: const Color(0xFF3D8D7A),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Unduh PDF',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: createAndUploadPdf,
                      ),
                      const SizedBox(width: 12), // jarak horizontal
                      FloatingActionButton.extended(
                        backgroundColor: const Color(0xFF3D8D7A),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Unduh Excel',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: exportToExcel,
                      ),
                    ],
                  ),
                ),
                  SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D8D7A),
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: currentPage > 0
                      ? () {
                          setState(() {
                            currentPage--;
                          });
                        }
                      : null,
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 20),
                Text(
                  'Halaman ${currentPage + 1} dari $totalPages',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D8D7A),
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: (currentPage + 1) * rowsPerPage < dataLaporanKeu.length
                      ? () {
                          setState(() {
                            currentPage++;
                          });
                        }
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MenuPilihanPage(
                                idMenu: 3,
                              ),
                            ),
                          );
                        },
                      ),
                      Text(
                        'Laporan Keuangan Aset',
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
          Align(
            alignment: Alignment.center,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.pushReplacement(
                    //       context,
                    //       MaterialPageRoute(
                    //           builder: (context) =>
                    //               LaporanKeuanganPendapatanPage()),
                    //     );
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Color(0xFF3D8D7A),
                    //     padding:
                    //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    //   ),
                    //   child: Text(
                    //     'Pendapatan',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 18,
                    //     ),
                    //   ),
                    // ),
                    // SizedBox(width: 16),
                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.pushReplacement(
                    //       context,
                    //       MaterialPageRoute(
                    //           builder: (context) =>
                    //               LaporanKeuanganPengeluaranPage()),
                    //     );
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Color(0xFF3D8D7A),
                    //     padding:
                    //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    //   ),
                    //   child: Text(
                    //     'Pengeluaran',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 18,
                    //     ),
                    //   ),
                    // ),
                    // SizedBox(width: 16),

                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.pushReplacement(
                    //       context,
                    //       MaterialPageRoute(
                    //           builder: (context) => LaporanKeuanganPage()),
                    //     );
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Color(0xFF3D8D7A),
                    //     padding:
                    //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    //   ),
                    //   child: Text(
                    //     'Laporan Kas Keuangan',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 18,
                    //     ),
                    //   ),
                    // ),
                    // SizedBox(width: 16),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  LaporanKeuanganSurplusDefisitPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Surplus/Defisit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LaporanKeuanganUtangPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Utang',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Aset',
                        style: TextStyle(
                          color: Color(0xFF3D8D7A),
                          fontSize: 18,
                        ),
                      ),
                    ),

                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  LaporanKeuanganNeracaPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Neraca',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3D8D7A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // ==========================
                  // TOMBOL TAHUN (SEMUA BULAN)
                  // ==========================
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedMonth.isEmpty
                          ? Colors.white
                          : Colors.transparent,
                      foregroundColor: selectedMonth.isEmpty
                          ? const Color(0xFF3D8D7A)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedMonth = '';
                        selectedMonthNumber = '';
                      });

                      fetchLaporanKeuangan();
                    },
                    child: const Text(
                      'Tahun',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // ==========================
                  // TOMBOL BULAN
                  // ==========================
                  ...List.generate(12, (index) {
                    final monthNames = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'Mei',
                      'Jun',
                      'Jul',
                      'Agu',
                      'Sep',
                      'Okt',
                      'Nov',
                      'Des'
                    ];
                    final monthNumber = (index + 1).toString().padLeft(2, '0');
                    final isSelected = selectedMonth == monthNames[index];

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isSelected ? Colors.white : Colors.transparent,
                        foregroundColor:
                            isSelected ? const Color(0xFF3D8D7A) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedMonth = monthNames[index];
                          selectedMonthNumber = monthNumber;
                        });

                        fetchLaporanKeuangan(bulan: monthNumber);
                      },
                      child: Text(
                        monthNames[index],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dropdown Tahun

          // Column(
          //   children: [
          //     Row(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         ElevatedButton(
          //           onPressed: () {},
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.white,
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Pendapatan',
          //             style: TextStyle(
          //               color: Color(0xFF3D8D7A),
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganPengeluaranPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Pengeluaran',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),

          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganUtangPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Utang',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) => LaporanKeuanganPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Laporan Kas Keuangan',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         SizedBox(width: 16),
          //         ElevatedButton(
          //           onPressed: () {
          //             Navigator.pushReplacement(
          //               context,
          //               MaterialPageRoute(
          //                   builder: (context) =>
          //                       LaporanKeuanganSurplusDefisitPage()),
          //             );
          //           },
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Color(0xFF3D8D7A),
          //             padding:
          //                 EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //           ),
          //           child: Text(
          //             'Surplus/Defisit',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //             ),
          //           ),
          //         ),
          //         //    SizedBox(width: 16),
          //         //  ElevatedButton(
          //         //   onPressed: () {
          //         //     Navigator.pushReplacement(
          //         //       context,
          //         //       MaterialPageRoute(
          //         //           builder: (context) =>
          //         //               LaporanKeuanganNeracaPage()),
          //         //     );
          //         //   },
          //         //   style: ElevatedButton.styleFrom(
          //         //     backgroundColor: Color(0xFF3D8D7A),
          //         //     padding:
          //         //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //         //   ),
          //         //   child: Text(
          //         //     'Neraca',
          //         //     style: TextStyle(
          //         //       color: Colors.white,
          //         //       fontSize: 18,
          //         //     ),
          //         //   ),
          //         // ),
          //       ],
          //     ),
          //   ],
          // ),
          // SizedBox(height: 16),
          // Center(
          //   child: Container(
          //     padding: const EdgeInsets.all(12),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF3D8D7A),
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Wrap(
          //       spacing: 8,
          //       runSpacing: 8,
          //       children: [
          //         ElevatedButton(
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.white,
          //             foregroundColor: const Color(0xFF3D8D7A),
          //             shape: RoundedRectangleBorder(
          //               borderRadius: BorderRadius.circular(8),
          //             ),
          //           ),
          //           onPressed: () {
          //             fetchLaporanKeuangan();
          //           },
          //           child: const Text(
          //             'All',
          //             style: TextStyle(fontWeight: FontWeight.bold),
          //           ),
          //         ),
          //         ...List.generate(12, (index) {
          //           final monthNames = [
          //             'Jan',
          //             'Feb',
          //             'Mar',
          //             'Apr',
          //             'Mei',
          //             'Jun',
          //             'Jul',
          //             'Agu',
          //             'Sep',
          //             'Okt',
          //             'Nov',
          //             'Des'
          //           ];
          //           final monthNumber = (index + 1).toString().padLeft(2, '0');

          //           return ElevatedButton(
          //             style: ElevatedButton.styleFrom(
          //               backgroundColor: Colors.white,
          //               foregroundColor: const Color(0xFF3D8D7A),
          //               shape: RoundedRectangleBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //               ),
          //             ),
          //             onPressed: () {
          //               fetchLaporanKeuangan(bulan: monthNumber);
          //             },
          //             child: Text(
          //               monthNames[index],
          //               style: const TextStyle(fontWeight: FontWeight.bold),
          //             ),
          //           );
          //         }),
          //       ],
          //     ),
          //   ),
          // ),
          // SizedBox(height: 16),
          // Text(
          //   'Total Pendapatan: ${currencyFormat.format(totalSaldoPendapatan)}',
          //   style: TextStyle(
          //     fontSize: 16,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // SizedBox(height: 16),

          SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Total Harga Aset $selectedMonth $currentYear: ${_formatCurrencyTotal(totalHargaAset)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paginatedData.isEmpty
                      ? const Center(child: Text('Tidak ada data aset'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // final formatter = NumberFormat('#,###', 'id_ID');

                            return ScrollConfiguration(
                              behavior: MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Column(
                                    children: [
                                      // HEADER
                                      Table(
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(100),
                                          2: FixedColumnWidth(150),
                                          3: FixedColumnWidth(150),
                                          4: FixedColumnWidth(150),
                                          5: FixedColumnWidth(150),
                                          6: FixedColumnWidth(100),
                                          7: FixedColumnWidth(100),
                                          8: FixedColumnWidth(150),
                                          9: FixedColumnWidth(150),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3D8D7A),
                                            ),
                                            children: [
                                              _buildTableHeader(
                                                  'Tanggal Diterima'),
                                              _buildTableHeader('Nama'),
                                              _buildTableHeader('Jumlah'),
                                              _buildTableHeader(
                                                  'Harga Diterima'),
                                              _buildTableHeader(
                                                  'Harga Saat Ini'),
                                              _buildTableHeader(
                                                  'Nom Penyusutan'),
                                              _buildTableHeader(
                                                  'Thn Penyusutan'),
                                              _buildTableHeader(
                                                  'Thn Akm Penyusutan'),
                                              _buildTableHeader('Aksi'),
                                              _buildTableHeader('Info'),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // DATA
                                      Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(100),
                                          2: FixedColumnWidth(150),
                                          3: FixedColumnWidth(150),
                                          4: FixedColumnWidth(150),
                                          5: FixedColumnWidth(150),
                                          6: FixedColumnWidth(100),
                                          7: FixedColumnWidth(100),
                                          8: FixedColumnWidth(150),
                                          9: FixedColumnWidth(150),
                                        },
                                        children: paginatedData
                                            .where((item) =>
                                                item['nama_asset'] != null &&
                                                item['tanggal_diterima'] !=
                                                    null)
                                            .map((item) {
                                          // final double harga = double.tryParse(
                                          //         (item['harga_asset'] ?? '0')
                                          //             .toString()
                                          //             .replaceAll('.', '')) ??
                                          //     0;

                                          // final int jumlah = int.tryParse(
                                          //         item['jumlah_asset']
                                          //             .toString()) ??
                                          //     0;

                                          // final double totalNilai =
                                          //     harga * jumlah;

                                          return TableRow(
                                            children: [
                                              _buildTableCell(
                                                  item['tanggal_diterima']),
                                              _buildTableCell(
                                                  item['nama_asset']),
                                              _buildTableCell(
                                                  '${item['jumlah_asset']}'),
                                              _buildTableCell(
                                                  'Rp ${item['harga_asset']}'),
                                              _buildTableCell(
                                                  'Rp ${item['harga_asset_sekarang']}'),
                                              _buildTableCell(item[
                                                          'penyusutan_tahunan'] !=
                                                      null
                                                  ? 'Rp ${item['penyusutan_tahunan']}'
                                                  : '-'),
                                              _buildTableCell(
                                                  '${item['tahun_penyusutan']} tahun'),
                                              _buildTableCell(
                                                  '${item['tahun_akm_penyusutan']} tahun'),
                                              Center(
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    minimumSize:
                                                        const Size(80, 35),
                                                  ),
                                                  onPressed: () async {
                                                    var id = item['id'];
                                                    var tanggal = item[
                                                        'tanggal_diterima'];
                                                    var nama =
                                                        item['nama_asset'];
                                                    var harga =
                                                        item['harga_asset'];
                                                    var kategori =
                                                        item['kategori_asset'];
                                                    var jumlah =
                                                        item['jumlah_asset'];
                                                    var satuan =
                                                        item['satuan_asset'];
                                                    var sumber =
                                                        item['sumber_asset'];

                                                    try {
                                                      _showConfirmationDialog(
                                                          tanggal,
                                                          nama,
                                                          jumlah,
                                                          harga,
                                                          kategori,
                                                          id,
                                                          sumber,
                                                          satuan);
                                                    } catch (e) {
                                                      Flushbar(
                                                        message:
                                                            'Terjadi kesalahan: $e',
                                                        duration: Duration(
                                                            seconds: 2),
                                                        backgroundColor:
                                                            Colors.red,
                                                        flushbarPosition:
                                                            FlushbarPosition
                                                                .TOP,
                                                      ).show(context);
                                                      print(e);
                                                    }
                                                  },
                                                  child: const Text(
                                                    "Hapus",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blueAccent,
                                                    minimumSize:
                                                        const Size(80, 35),
                                                  ),
                                                  onPressed: () async {
                                                    var tanggal = item[
                                                        'tanggal_diterima'];
                                                    var nama =
                                                        item['nama_asset'];
                                                    var hargaDit =
                                                        item['harga_asset'];
                                                    var hargaSek = item[
                                                        'harga_asset_sekarang'];
                                                    var nomPenyu = item[
                                                        'penyusutan_tahunan'];
                                                    var tahunPenyu = item[
                                                        'tahun_penyusutan'];
                                                    var tahunAkmPenyu = item[
                                                        'tahun_akm_penyusutan'];
                                                    var kategori =
                                                        item['kategori_asset'];
                                                    var jumlah =
                                                        item['jumlah_asset'];
                                                    var satuan =
                                                        item['satuan_asset'];
                                                    var sumber =
                                                        item['sumber_asset'];
                                                    try {
                                                      _showDetailDialog(
                                                        tanggal.toString(),
                                                        nama.toString(),
                                                        jumlah.toString(),
                                                        hargaDit.toString(),
                                                        hargaSek.toString(),
                                                        nomPenyu.toString(),
                                                        tahunPenyu.toString(),
                                                        tahunAkmPenyu
                                                            .toString(),
                                                        kategori.toString(),
                                                        sumber.toString(),
                                                        satuan.toString(),
                                                      );
                                                    } catch (e) {
                                                      Flushbar(
                                                        message:
                                                            'Terjadi kesalahan: $e',
                                                        duration: Duration(
                                                            seconds: 2),
                                                        backgroundColor:
                                                            Colors.red,
                                                        flushbarPosition:
                                                            FlushbarPosition
                                                                .TOP,
                                                      ).show(context);
                                                      print(e);
                                                    }
                                                  },
                                                  child: const Text(
                                                    "Detail",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D8D7A),
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: currentPage > 0
                      ? () {
                          setState(() {
                            currentPage--;
                          });
                        }
                      : null,
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 20),
                Text(
                  'Halaman ${currentPage + 1} dari $totalPages',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D8D7A),
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed:
                      (currentPage + 1) * rowsPerPage < dataLaporanKeu.length
                          ? () {
                              setState(() {
                                currentPage++;
                              });
                            }
                          : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: dataLaporanKeu.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // if (dataLaporanKeu.isEmpty)
                //   FloatingActionButton(
                //     backgroundColor: Color(0xFF3D8D7A),
                //     heroTag: 'isi saldo',
                //     onPressed: () {
                //       _showSaldoAwalDialog(context);
                //     },
                //     child: Icon(
                //       Icons.add,
                //       color: Colors.white,
                //     ),
                //     tooltip: 'Isi Saldo Awal Tahun',
                //   ),
                // SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  heroTag: 'exportPdf',
                  onPressed: createAndUploadPdf,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Unduh PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),

                SizedBox(height: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF3D8D7A),
                  heroTag: 'exportExcel',
                  onPressed: exportToExcel,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Unduh Excel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final formatted = _formatter.format(int.parse(digitsOnly));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Widget _buildTableHeader(String text) {
  return Container(
    color: const Color(0xFF3D8D7A),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    ),
  );
}

Widget _buildTableCell(String? text) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text ?? '-',
      style: TextStyle(
        fontSize: 13,
        color: Colors.black87,
      ),
    ),
  );
}

String _formatCurrencyTotal(dynamic number) {
  final formatter =
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  // Jika bukan angka, ubah ke 0
  if (number == null) return 'Rp 0';

  // pastikan numeric
  num value;
  if (number is num) {
    value = number;
  } else {
    value = double.tryParse(number.toString()) ?? 0;
  }

  return formatter.format(value);
}

Widget _buildFilterButton(String title,
    {bool isActive = false, required VoidCallback onPressed}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: isActive ? const Color(0xFF3D8D7A) : Colors.white,
      foregroundColor: isActive ? Colors.white : const Color(0xFF3D8D7A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}

Widget _buildMonthButton(String label,
    {required VoidCallback onPressed, bool isSelected = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF3D8D7A) : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF3D8D7A)),
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}
