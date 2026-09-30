import 'dart:ui';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_aset.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_neraca.dart';

import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';

import 'package:iuran_rt_web/url.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganUtangPage extends StatefulWidget {
  @override
  _LaporanKeuanganUtangPageState createState() =>
      _LaporanKeuanganUtangPageState();
}

class _LaporanKeuanganUtangPageState extends State<LaporanKeuanganUtangPage> {
  List<dynamic> dataLaporanKeu = [];
  bool isLoading = false;
  bool isDownload = false;
  double totalSaldoUtang = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoKeu = 0;
  final year = DateTime.now().year;
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  String month = 'Tahun';
  String selectedMonthNumber = ''; // '01' - '12'
  late List<String> yearList;
  String? selectedMetode;
  String? currentYear;
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
  @override
  void initState() {
    super.initState();

    final now = DateTime.now().year;
    yearList = List.generate(
      5,
      (index) => (now - index).toString(),
    );

    // default value AMAN
    currentYear = yearList.first;
    fetchLaporanKeuangan(tahun: currentYear);
    //simulateLastYear();
    // checkTanggalPeringatan(context);
    // checkYearChangeAndTruncate();
  }

  Future<void> checkTanggalPeringatan(BuildContext context) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final keyUtang = "isDownload_${now.year}";
    isDownload = prefs.getBool(keyUtang) ?? false;

    if (now.month == 12 && now.day >= 27 && isDownload == false) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Peringatan Akhir Tahun"),
              content: Text(
                "Tanggal ${now.day}-${now.month}-${now.year}. "
                "Tahun akan segera berganti.\n\n"
                "Silakan download laporan keuangan tahun ${now.year} "
                "sebelum data dihapus pada awal tahun baru.",
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganUtangPage()),
                    );
                    await exportToExcel();
                    await prefs.setBool(keyUtang, true);
                    isDownload = true;
                  },
                  child: Text("Download"),
                ),
              ],
            );
          },
        );
      });
    }
  }

  void simulateLastYear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_saved_year', (DateTime.now().year - 1).toString());
  }

  Future<void> checkYearChangeAndTruncate() async {
    final prefs = await SharedPreferences.getInstance();
    String currentYear1 = year.toString();
    final lastSavedYear = prefs.getString('last_saved_year') ?? currentYear1;

    if (lastSavedYear != currentYear1) {
      // await exportToExcelOnlySendPath(
      //   lastSavedYear,
      //   totalSaldoUtang.toString(),
      //   totalSaldoPengeluaran.toString(),
      //   totalSaldoKeu.toString(),
      // );

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}deleteListLaporanKeu.php'),
        body: {
          'id_rt': KodeRt.kodeRt,
        },
      );

      final json = jsonDecode(response.body);

      if (json['result'] == 'success') {
        await prefs.setString('last_saved_year', currentYear1);
        print(
            "Data tahun $lastSavedYear berhasil di-export & dihapus. Tahun aktif: $currentYear1");
      } else {
        Flushbar(
          message: 'Gagal menghapus data lama: ${json['message']}',
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    }
  }

  Future<void> fetchLaporanKeuangan({String? bulan, String? tahun}) async {
    final idRt = KodeRt.kodeRt;

    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/listUtang.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'id_rt': idRt,
        if (bulan != null) 'bulan': bulan,
        if (tahun != null) 'tahun': tahun,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);

      if (result['result'] == 'success') {
        dataLaporanKeu = result['data'];

        double totalUtang = dataLaporanKeu.fold(0, (sum, item) {
          final rawSaldo = item['nominal'].toString().replaceAll('.', '');
          final saldo = double.tryParse(rawSaldo) ?? 0;
          return sum + saldo;
        });

        setState(() {
          totalSaldoUtang = totalUtang;
        });

        print("Utang: $totalUtang");
      } else {
        setState(() {
          dataLaporanKeu = [];
          totalSaldoUtang = 0;
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
        SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> exportToExcelOnlySendPath(
    String tahun,
    String totalUtang,
    String totalPengeluaran,
    String totalSemua,
  ) async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Keuangan Utang'];

    List<String> headers = [
      'Tanggal Utang',
      'COA Utang',
      'Kode Ref Utang',
      'No Kavling Utang',
      'Keterangan Utang',
      'Saldo Utang',
      'Tanggal Pengeluaran',
      'COA Pengeluaran',
      'Kode Ref Pengeluaran',
      'No Kavling Pengeluaran',
      'Keterangan Pengeluaran',
      'Saldo Pengeluaran',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataLaporanKeu) {
      List<String> row = [
        item['tanggal_Utang'] ?? '-',
        item['coa_Utang'] ?? '-',
        item['kode_ref_Utang'] ?? '-',
        item['no_kavling_Utang'] ?? '-',
        item['ket_Utang'] ?? '-',
        item['saldo_Utang'] ?? '-',
        item['tanggal_pengeluaran'] ?? '-',
        item['coa_pengeluaran'] ?? '-',
        item['kode_ref_pengeluaran'] ?? '-',
        item['no_kavling_pengeluaran'] ?? '-',
        item['ket_pengeluaran'] ?? '-',
        item['saldo_pengeluaran'] ?? '-',
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Laporan Keuangan Tahun $tahun.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Laporan Keuangan Utang.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
      try {
        var response = await http.post(
          Uri.parse("${ApiUrls.baseUrl}/savePathExcelKeu.php"),
          body: {
            'tahun': tahun,
            'path': filePath,
            'totalUtang': totalUtang.toString(),
            'totalPengeluaran': totalPengeluaran.toString(),
            'totalSemua': totalSemua.toString(),
          },
        );

        if (response.statusCode == 200) {
          print("Path dan data berhasil dikirim ke server");
        } else {
          print("Gagal mengirim. Status: ${response.statusCode}");
        }
      } catch (e) {
        print("Error saat kirim path: $e");
      }
    }
  }

  Future<void> createAndUploadPdf() async {
    final pdf = pw.Document();

    final filteredData = dataLaporanKeu.where((item) {
      final saldo = (item['nominal'] ?? '').toString().trim();
      final ket = (item['keterangan'] ?? '').toString().trim();
      return saldo.isNotEmpty &&
          saldo.toLowerCase() != 'null' &&
          ket.isNotEmpty &&
          ket.toLowerCase() != 'null';
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),

        // ==========================================================
        //  FOOTER
        // ==========================================================
        footer: (pw.Context context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Text(
              'Terima kasih telah menggunakan aplikasi RT Digital',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Created by RT Digital',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey,
              ),
            ),
          ],
        ),

        // ==========================================================
        //  BODY
        // ==========================================================
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Laporan Utang $month $year',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  KodeRt.namaRt,
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2),
                pw.Text(
                  'Total Saldo Utang: ${_formatCurrencyTotal(totalSaldoUtang)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            ),

            // TABEL
            pw.Table.fromTextArray(
              headers: [
                'Tanggal',
                'Nama Warga',
                'No Kavling',
                'Rincian Utang',
                'Nominal',
              ],
              data: filteredData.map((item) {
                return [
                  item['tanggal'] ?? '-',
                  item['nama'] ?? '-',
                  item['no_kavling'] ?? '-',
                  item['keterangan'] ?? '-',
                  "Rp ${item['nominal']}",
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(120),
                4: const pw.FixedColumnWidth(70),
              },
            ),

            pw.SizedBox(height: 20),
          ];
        },
      ),
    );

    final Uint8List encoded = await pdf.save();

    // ==========================================================
    //  SAVE FILE
    // ==========================================================
    if (kIsWeb) {
      final blob = html.Blob([encoded], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Laporan Utang ${month} ${year}.pdf")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/Laporan Utang ${month} ${year}.pdf";

      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ PDF berhasil disimpan di $filePath')),
        );
      }
    }
  }

  Future<void> exportToExcel() async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Keuangan Utang'];

    List<String> headers = [
      'Tanggal',
      'Nama Warga',
      'No Kavling',
      'Uraian Utang',
      'Nominal',
    ];
    sheetObject.appendRow(headers);

    for (var item in dataLaporanKeu) {
      if ((item['tanggal'] ?? '').toString().trim().isEmpty &&
          (item['coa'] ?? '').toString().trim().isEmpty &&
          (item['nama'] ?? '').toString().trim().isEmpty &&
          (item['no_kavling'] ?? '').toString().trim().isEmpty &&
          (item['keterangan'] ?? '').toString().trim().isEmpty &&
          (item['nominal'] ?? '').toString().trim().isEmpty) {
        continue;
      }

      List<String> row = [
        item['tanggal'] ?? '-',
        item['nama'] ?? '-',
        item['no_kavling'] ?? '-',
        item['keterangan'] ?? '-',
        item['nominal'] ?? '-',
      ];
      sheetObject.appendRow(row);
    }

    if (kIsWeb) {
      final bytes = excel.encode();
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
            "download", "Laporan Keuangan Utang ${month} ${year}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Utang ${month} ${year}.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diexport ke $filePath')),
      );
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

  Future<void> deleteDataUtang(int id) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}delete_utang.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id': id,
          'id_rt': KodeRt.kodeRt,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['result'] == 'success') {
        Flushbar(
          message: 'Data utang berhasil dihapus',
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

  Future<void> _showConfirmationDialog(
      String tanggal,
      String saldo,
      String noKavling,
      String namaWarga,
      String ket,
      String coa,
      int id) async {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Color(0xFFFDECE8),
              title: Text('Konfirmasi Pelunasan',
                  style: GoogleFonts.lato(color: Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal: $tanggal'
                      '\nRincian Utang: $ket'
                      '\nKode COA: $coa'
                      '\nNo Kavling: $noKavling'
                      '\nNama Warga: $namaWarga'
                      '\nNominal: Rp $saldo'
                      '\n===================================',
                      style: GoogleFonts.lato(color: Colors.black),
                    ),
                    SizedBox(height: 15),
                    Text('Pilih Metode Pembayaran (Wajib):',
                        style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedMetode,
                          hint: Text("Pilih Metode"),
                          items: <String>['Bayar Tunai', 'Transfer']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              selectedMetode = newValue;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child:
                      Text('Batal', style: GoogleFonts.lato(color: Colors.red)),
                  onPressed: () {
                    selectedMetode = null;
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Lunas',
                      style: GoogleFonts.lato(
                          color: Color(0xFF3D8D7A),
                          fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    // --- VALIDASI WAJIB PILIH ---
                    if (selectedMetode == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Pilih metode pembayaran terlebih dahulu!"),
                            backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    // Panggil fungsi dengan tambahan parameter metode
                    tambahDataLaporanPendapatan(tanggal, saldo.toString(),
                        noKavling, '101', selectedMetode!, ket);

                    deleteDataUtang(id);

                    selectedMetode = null;
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganUtangPage()),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> tambahDataLaporanPendapatan(String tanggal, String saldo,
      String noKavling, String coa, String metode, String ket) async {
    String kodeRef = generateKodeRef(
      namaRT: KodeRt.kodeRt.toUpperCase(),
      kodeIuran: '001',
      alamatKavling: noKavling,
      tanggalLunas: tanggal,
      kodeTransaksi: coa,
    );
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}updatePendapatan.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "tanggal": tanggal,
        "keterangan": ket,
        "saldo": saldo,
        "coa": coa,
        "no_kavling": noKavling,
        "kode_ref": kodeRef,
        'id_rt': KodeRt.kodeRt,
        'metode': metode
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
      await tambahLogAktivitas(
          aktivitas:
              "Melunasi utang dengan no kavling: $noKavling, keterangan: $ket, nominal: Rp $saldo, metode: $metode,");
    } else {
      Flushbar(
        message: 'Gagal menyimpan data: ${data['message']}',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
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
                          onPressed: () => {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MenuPilihanPage(
                                      idMenu: 3,
                                    ),
                                  ),
                                )
                              }),
                      Text(
                        'Laporan Utang',
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
                  //     MaterialPageRoute(builder: (context) => LaporanKeuanganPendapatanPage()),
                  //   );
                  // }),
                  // _buildFilterButton('Pengeluaran', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(builder: (context) => LaporanKeuanganPengeluaranPage()),
                  //   );
                  // }),

                  // _buildFilterButton('Kas', onPressed: () {
                  //   Navigator.pushReplacement(
                  //     context,
                  //     MaterialPageRoute(builder: (context) => LaporanKeuanganPage()),
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
                  _buildFilterButton('Utang', isActive: true, onPressed: () {}),
                  _buildFilterButton('Aset', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganAsetPage()),
                    );
                  }),
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

       
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildMonthButton(
                  'Semua',
                  isSelected: month.isEmpty,
                  onPressed: () {
                    setState(() {
                      month = '';
                      selectedMonthNumber = '';
                    });

                    fetchLaporanKeuangan(
                      tahun: currentYear,
                    );
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
                    isSelected: month == monthNames[index],
                    onPressed: () {
                      setState(() {
                        month = monthNames[index];
                        selectedMonthNumber = monthNumber;
                      });

                      // 🔑 filter bulan + tahun
                      fetchLaporanKeuangan(
                        bulan: monthNumber,
                        tahun: currentYear,
                      );
                    },
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dropdown Tahun
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pilih Tahun: "),
              DropdownButton<String>(
                value: yearList.contains(currentYear) ? currentYear : null,
                items: yearList.map((year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newYear) {
                  if (newYear == null) return;

                  setState(() {
                    currentYear = newYear;
                  });

                  fetchLaporanKeuangan(
                    bulan: selectedMonthNumber.isNotEmpty
                        ? selectedMonthNumber // ⬅️ bulan tetap
                        : null, // ⬅️ atau semua bulan
                    tahun: currentYear, // ⬅️ tahun baru
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              'Total Utang $month $year: ${currencyFormat.format(totalSaldoUtang)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D8D7A),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : paginatedData.isEmpty
                    ? const Center(child: Text('Tidak ada data utang'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWideScreen = constraints.maxWidth > 800;
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
                                      1: FixedColumnWidth(200),
                                      2: FixedColumnWidth(200),
                                      3: FixedColumnWidth(200),
                                      4: FixedColumnWidth(200),

                                      5: FixedColumnWidth(100), // Kolom tombol
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D8D7A),
                                        ),
                                        children: [
                                          _buildTableHeader('Tanggal'),
                                          _buildTableHeader('Nama Warga'),
                                          _buildTableHeader('No Kavling'),
                                          _buildTableHeader('Uraian Utang'),
                                          _buildTableHeader('Nominal'),
                                          _buildTableHeader('Aksi'),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // ISI TABEL
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(100),
                                        },
                                        children: dataLaporanKeu
                                            .where((item) =>
                                                item['tanggal'] != null ||
                                                item['coa'] != null ||
                                                item['nama'] != null ||
                                                item['no_kavling'] != null ||
                                                item['keterangan'] != null ||
                                                item['nominal'] != null)
                                            .map((item) {
                                          return TableRow(
                                            children: [
                                              _buildTableCell(item['tanggal']),
                                              _buildTableCell(item['nama']),
                                              _buildTableCell(
                                                  item['no_kavling']),
                                              _buildTableCell(
                                                  item['keterangan']),
                                              _buildTableCell(
                                                  "Rp ${item['nominal']}"),
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
                                                    var tanggal =
                                                        item['tanggal'];
                                                    var saldo = item['nominal'];
                                                    var noKavling =
                                                        item['no_kavling'];
                                                    var coa = item['coa'];
                                                    var nama = item['nama'];
                                                    var ket =
                                                        item['keterangan'];

                                                    try {
                                                      _showConfirmationDialog(
                                                          tanggal,
                                                          saldo,
                                                          noKavling,
                                                          nama,
                                                          ket,
                                                          coa,
                                                          id);
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
                                                    "Lunas",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
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

  Widget _buildItemRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF3D8D7A)),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value != null ? value.toString() : '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                                      idMenu: 3,
                                    ),
                                  ),
                                )
                              }),
                      Text(
                        'Laporan Keuangan Utang',
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
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Utang',
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
                              builder: (context) => LaporanKeuanganAsetPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3D8D7A),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Aset',
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
                      backgroundColor:
                          month.isEmpty ? Colors.white : Colors.transparent,
                      foregroundColor: month.isEmpty
                          ? const Color(0xFF3D8D7A)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        month = '';
                        selectedMonthNumber = '';
                      });

                      fetchLaporanKeuangan(
                        tahun: currentYear,
                      );
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
                    final isSelected = month == monthNames[index];

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
                          month = monthNames[index];
                          selectedMonthNumber = monthNumber;
                        });

                        fetchLaporanKeuangan(
                          bulan: monthNumber,
                          tahun: currentYear,
                        );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pilih Tahun: "),
              DropdownButton<String>(
                value: yearList.contains(currentYear) ? currentYear : null,
                items: yearList.map((year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newYear) {
                  if (newYear == null) return;

                  setState(() {
                    currentYear = newYear;
                  });

                  fetchLaporanKeuangan(
                    bulan: selectedMonthNumber.isNotEmpty
                        ? selectedMonthNumber // ⬅️ bulan tetap
                        : null, // ⬅️ atau semua bulan
                    tahun: currentYear, // ⬅️ tahun baru
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Total Utang $month $year: ${currencyFormat.format(totalSaldoUtang)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : paginatedData.isEmpty
                    ? const Center(child: Text('Tidak ada data utang'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWideScreen = constraints.maxWidth > 800;
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
                                      1: FixedColumnWidth(200),
                                      2: FixedColumnWidth(200),
                                      3: FixedColumnWidth(200),
                                      4: FixedColumnWidth(200),

                                      5: FixedColumnWidth(100), // Kolom tombol
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D8D7A),
                                        ),
                                        children: [
                                          _buildTableHeader('Tanggal'),
                                          _buildTableHeader('Nama Warga'),
                                          _buildTableHeader('No Kavling'),
                                          _buildTableHeader('Uraian Utang'),
                                          _buildTableHeader('Nominal'),
                                          _buildTableHeader('Aksi'),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // ISI TABEL
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                          color: Colors.grey.shade600,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(200),
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(100),
                                        },
                                        children: dataLaporanKeu
                                            .where((item) =>
                                                item['tanggal'] != null ||
                                                item['coa'] != null ||
                                                item['nama'] != null ||
                                                item['no_kavling'] != null ||
                                                item['keterangan'] != null ||
                                                item['nominal'] != null)
                                            .map((item) {
                                          return TableRow(
                                            children: [
                                              _buildTableCell(item['tanggal']),
                                              _buildTableCell(item['nama']),
                                              _buildTableCell(
                                                  item['no_kavling']),
                                              _buildTableCell(
                                                  item['keterangan']),
                                              _buildTableCell(
                                                  "Rp ${item['nominal']}"),
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
                                                    var tanggal =
                                                        item['tanggal'];
                                                    var saldo = item['nominal'];
                                                    var noKavling =
                                                        item['no_kavling'];
                                                    var coa = item['coa'];
                                                    var nama = item['nama'];
                                                    var ket =
                                                        item['keterangan'];

                                                    try {
                                                      _showConfirmationDialog(
                                                          tanggal,
                                                          saldo,
                                                          noKavling,
                                                          nama,
                                                          ket,
                                                          coa,
                                                          id);
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
                                                    "Lunas",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                  heroTag: 'exportPDF',
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
