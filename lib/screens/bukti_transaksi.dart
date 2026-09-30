import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';


class BuktiTransaksiPage extends StatefulWidget {
  @override
  _BuktiTransaksiPageState createState() => _BuktiTransaksiPageState();
}

class _BuktiTransaksiPageState extends State<BuktiTransaksiPage> {
  List<dynamic> _revisiData = [];
  bool isLoading = true;
  String errorMessage = '';
  String iMetode = 'Bayar Tunai';

  @override
  void initState() {
    super.initState();
    fetchRevisiData();
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
  Future<void> createAndUploadPdfInvoice(
      {required String nomorRekening,
      required String jenisRekening,
      required String tanggalLunas,
      required String noTelpon,
      required String namaIuran,
      required String noKavling,
      required String TotalIuran,
      required String Iuran,
      required String selectedPayment,
      required String namaPenanggungJawab,
      required String alamatKavling,
      required String tanggalJatuhTempo,
      required int idIuran,
      required int idWarga,
      required String admin}) async {
    final pdf = pw.Document();
    //final prefs = await SharedPreferences.getInstance();
    //int userId = prefs.getInt('idUser') ?? 0;
    final ByteData imageData = await rootBundle.load('assets/images/Logo3.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();
    final image = pw.MemoryImage(imageBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: pw.WrapAlignment.center,
                  children: List.generate(
                    50,
                    (index) => pw.Opacity(
                      opacity: 0.1,
                      child: pw.Image(image, width: 50, height: 50),
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text('INVOICE PEMBAYARAN',
                              style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('${KodeRt.namaRt}',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.normal)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 12),
                    pw.Text('Informasi Pelanggan',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                        'Nama Penghuni: ${namaPenanggungJawab.isNotEmpty ? namaPenanggungJawab : "Data Kosong"}'),
                    pw.Text(
                        'Alamat Kavling: ${alamatKavling.isNotEmpty ? alamatKavling : "Data Kosong"}'),
                    pw.Text(
                        'No Kavling: ${noKavling.isNotEmpty ? noKavling : "Data Kosong"}'),
                    pw.Text(
                        'Nomor Telepon: ${noTelpon.isNotEmpty ? noTelpon : "Data Kosong"}'),
                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 12),
                    pw.Text('Informasi Transaksi',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                        'Nomor Rekening: ${nomorRekening.isNotEmpty ? nomorRekening : "Data Kosong"}'),
                    pw.Text(
                        'Jenis Rekening: ${jenisRekening.isNotEmpty ? jenisRekening : "Data Kosong"}'),
                    pw.Text(
                        'Nama Iuran: ${namaIuran.isNotEmpty ? namaIuran : "Data Kosong"}'),
                    pw.Text('Nominal Iuran: Rp ${Iuran.toString()}'),
                    pw.Text('Biaya Layanan: Rp ${admin}'),
                    pw.Text(
                        'Tanggal Jatuh Tempo: ${tanggalJatuhTempo.isNotEmpty ? tanggalJatuhTempo : "Data Kosong"}'),
                    pw.Text(
                        'Tanggal Lunas: ${tanggalLunas.isNotEmpty ? tanggalLunas : "Data Kosong"}'),
                    pw.Text(
                        'Metode Pembayaran: ${selectedPayment.isNotEmpty ? selectedPayment : "Data Kosong"}'),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 12),
                    pw.Text('Detail Pembayaran',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 6),
                    pw.Table.fromTextArray(
                      context: context,
                      headers: ['Deskripsi', 'Jumlah'],
                      data: [
                        ['Biaya Layanan', 'Rp ${admin}'],
                        ['Jumlah Iuran', 'Rp ${Iuran.toString()}'],
                        ['Total Iuran', 'Rp ${TotalIuran.toString()}'],
                      ],
                      headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14),
                      cellStyle: pw.TextStyle(fontSize: 12),
                      border: pw.TableBorder.all(width: 1),
                      cellAlignment: pw.Alignment.centerLeft,
                      columnWidths: {
                        0: pw.FlexColumnWidth(2),
                        1: pw.FlexColumnWidth(1),
                      },
                    ),
                    // Footer
                    pw.SizedBox(height: 20),
                    pw.Divider(thickness: 1),
                    pw.Text('Terima kasih telah melakukan pembayaran.',
                        style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    savePdf(await pdf.save(), idIuran, idWarga);
  }

  Future<void> savePdf(Uint8List pdfBytes, int idIuran, int idWarga) async {
    try {
      Map<String, dynamic>? response;

      if (kIsWeb) {
        response = await uploadPdfToServerWeb(pdfBytes, idIuran, idWarga);
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        response = await uploadPdfToServer(file, idIuran, idWarga);

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (response != null && response['success'] == true) {
        print("✅ PDF berhasil diunggah.");
        print("📄 Path di server: ${response['path']}");
      } else {
        print("❌ Gagal upload PDF: ${response?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      print('⚠️ Error saat upload PDF: $e');
    }
  }

  Future<Map<String, dynamic>?> uploadPdfToServerWeb(
      Uint8List pdfBytes, int idIuran, int idWarga) async {
    try {
      final url = Uri.parse('${ApiUrls.baseUrl}/invoiceToServer.php');
      final request = http.MultipartRequest('POST', url);

      final fileName = "invoice_${DateTime.now().millisecondsSinceEpoch}.pdf";

      request.files.add(
        http.MultipartFile.fromBytes('file', pdfBytes, filename: fileName),
      );

      request.fields['id_iuran'] = idIuran.toString();
      request.fields['id_warga'] = idWarga.toString();
      request.fields['id_rt'] = KodeRt.kodeRt;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      }
    } catch (e) {
      print('⚠️ Upload PDF Web error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> uploadPdfToServer(
      File pdfFile, int idIuran, int idWarga) async {
    try {
      final url = Uri.parse('${ApiUrls.baseUrl}/invoiceToServer.php');
      final request = http.MultipartRequest('POST', url);

      request.files.add(
        await http.MultipartFile.fromPath('file', pdfFile.path),
      );

      request.fields['id_iuran'] = idIuran.toString();
      request.fields['id_warga'] = idWarga.toString();
      request.fields['id_rt'] = KodeRt.kodeRt;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      }
    } catch (e) {
      print('⚠️ Upload PDF error: $e');
    }
    return null;
  }

  Future<void> fetchRevisiData() async {
    final idRt = KodeRt.kodeRt;

    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/listAjukanLunas.php"),
        body: {
          'id_rt': idRt,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] == 'success') {
          setState(() {
            _revisiData = json['data'];
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

  Future<void> kirimNotifikasiWA(
      String id, String namaIuran, String nominalIuran) async {
    final urlNotifikasiWA = '${ApiUrls.baseUrl}/whatsapp_api_1.php';
    try {
      final responseNotifikasiWA = await http.post(
        Uri.parse(urlNotifikasiWA),
        body: {
          'msg':
              'Halo, transaksi iuran "${namaIuran}" dengan nominal sebesar Rp${nominalIuran} anda telah berhasil, terima kasih telah menggunakan layanan ini',
          'id': id,
        },
      );

      if (responseNotifikasiWA.statusCode == 200) {
        final jsonResponseNotifikasiWA = jsonDecode(responseNotifikasiWA.body);
        final status = jsonResponseNotifikasiWA['status'];
        final statusInt =
            status is int ? status : int.tryParse(status.toString()) ?? 0;

        if (statusInt == 1) {
          print('Notifikasi WhatsApp berhasil dikirim');
        } else {
          print(
              'Gagal mengirim notifikasi WhatsApp: ${jsonResponseNotifikasiWA['reason']}');
        }
      } else {
        print(
            'Gagal mengirim notifikasi WhatsApp: ${responseNotifikasiWA.statusCode}');
      }
    } catch (e) {
      print('Error: Gagal terhubung ke server WhatsApp $e');
    }
  }

  Future<void> updatePathInvoice(String id_transaksi) async {
    final url = Uri.parse('${ApiUrls.baseUrl}/updatePathInvoice.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'id_transaksi': id_transaksi.toString(), 'id_rt': KodeRt.kodeRt},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        print('Berhasil: ${data['message']}');
      } else {
        print('Gagal: ${data['message']}');
      }
    } else {
      print('Error koneksi ke server: ${response.statusCode}');
    }
  }

  Future<void> updateStatusLunas(int id) async {
    final now = DateTime.now();
    final tanggalLunasFormatted = DateFormat('dd-MM-yyyy-HH:mm').format(now);
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}/sudahLunas.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id': id,
          'tanggal_lunas': tanggalLunasFormatted,
          'id_rt': KodeRt.kodeRt
        }),
      );
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      if (response.body.isNotEmpty) {
        final json = jsonDecode(response.body);
        if (json['result'] == 'success') {
       
        
          fetchRevisiData();
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(json['message'])));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update status: Empty response")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to update status: $e")));
    }
  }

  // Future<void> tambahDataLaporan(String tanggal, String keterangan,
  //     String saldo, String coa, String kodeRef, String noKavling) async {
  //   final response = await http.post(
  //     Uri.parse('${ApiUrls.baseUrl}tambahPendapatan.php'),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({
  //       "tanggal": tanggal,
  //       "keterangan": keterangan,
  //       "saldo": saldo,
  //       "coa": coa,
  //       "kode_ref": kodeRef,
  //       "no_kavling": noKavling,
  //       "id_rt": KodeRt.kodeRt
  //     }),
  //   );

  //   final data = jsonDecode(response.body);
  //   if (data['result'] == 'success') {
  //     Fluttertoast.showToast(msg: 'Data berhasil disimpan');
  //   } else {
  //     Fluttertoast.showToast(msg: 'Gagal menyimpan data: ${data['message']}');
  //   }
  // }

  String generateKodeRef({
    required String namaRT,
    required String kodeIuran,
    required String alamatKavling,
    required String tanggalLunas,
    required String kodeTransaksi,
  }) {
    return '$namaRT$kodeIuran$alamatKavling$tanggalLunas$kodeTransaksi';
  }

  Future<void> sendToHistory(
      String noKavling,
      String alamatKavling,
      String namaPemilik,
      String namaPenanggung,
      String namaIuran,
      String batas,
      String nominalIuran,
      String metode,
      String idIuran,
      String coa,
      String kode_iuran) async {
    try {
      final now = DateTime.now();
      final tanggalLunasFormatted = DateFormat('dd-MM-yyyy-HH:mm').format(now);

      final tanggalRef = DateFormat('yyMMdd').format(now);

      // Buat kode referensi
      String kodeRef = generateKodeRef(
        namaRT: KodeRt.kodeRt.toUpperCase(),
        kodeIuran: kode_iuran,
        alamatKavling: noKavling,
        tanggalLunas: tanggalRef,
        kodeTransaksi: idIuran.toString().padLeft(4, '0'),
      );

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}tambah_histori.php'),
        body: {
          'r_no_kavling': noKavling,
          'r_alamat_kavling': alamatKavling,
          'r_nama_pemilik': namaPemilik,
          'r_nama_penanggung_jawab': namaPenanggung,
          'r_nama_iuran': namaIuran,
          'r_nominal_iuran': nominalIuran,
          'r_tanggal_lunas': tanggalLunasFormatted,
          'r_batas_pembayaran': batas,
          'r_metode': metode,
          'r_id_iuran': idIuran,
          'r_coa': coa,
          'r_kode_ref': kodeRef,
          'id_rt': KodeRt.kodeRt,
          'r_status_cash_out': 'NONE',
          'r_batch': 'NONE',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['result'] == 'success') {
          //  tambahDataLaporan(tanggalLunasFormatted, namaIuran, nominalIuran, coa,
          //     kodeRef, noKavling);
          updatePathInvoice(idIuran);
         await tambahLogAktivitas(
  aktivitas:
      'Melunasi iuran "$namaIuran" sebesar Rp$nominalIuran untuk no kavling $noKavling',
);
         
          print('Data berhasil ditambahkan ke histori');
        } else {
          print('Gagal menambahkan ke histori: ${result['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saat mengirim data ke histori: $e');
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
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            height: 65,
            margin: const EdgeInsets.only(top: 12, left: 12, right: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 232, 226, 226),
              border: Border.all(
                color: const Color.fromARGB(255, 58, 112, 50),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.black, size: 18),
                       onPressed: () => {
                               Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 4,),
                                        ),
                                        )
                          }
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Pengajuan Iuran Tunai',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

            const SizedBox(height: 20),
            
          
             Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Text(
                          errorMessage,
                          style: GoogleFonts.lato(
                              color: Colors.black, fontSize: 13),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: ListView.builder(
                          itemCount: _revisiData.length,
                          itemBuilder: (context, index) {
                            final revisi = _revisiData[index];
                            return _buildCardMobile(revisi);
                          },
                        ),
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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 4,),
                                        ),
                                        )
                          }
                      ),
                      Text(
                        'Pengajuan Iuran Tunai Dari Warga',
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
                              "Pengajuan Iuran Tunai\nDari Warga 🛈",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Daftar data pengajuan\niuran dengan metode pembayaran\ntunai dari warga",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 50),
                      Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Text(
                          errorMessage,
                          style: GoogleFonts.lato(
                              color: Colors.black, fontSize: 13),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: ListView.builder(
                          itemCount: _revisiData.length,
                          itemBuilder: (context, index) {
                            final revisi = _revisiData[index];
                            return _buildCardMobile(revisi);
                          },
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
    );
  }

  // Widget _buildCard(Map revisi) {
  //   String namaIuran = revisi['nama_iuran'] ?? 'N/A';

  //   String nominalIuranStr = revisi['nominal_iuran']?.toString() ?? '0';
  //   String kodeUnikStr = revisi['kode_unik']?.toString() ?? '0';

  //   int nominalIuran = int.tryParse(nominalIuranStr.replaceAll('.', '')) ?? 0;
  //   int admin =  (int.tryParse(kodeUnikStr.replaceAll('.', '')) ?? 0);
  //   int totalIuran = nominalIuran + admin;

  //   String iuranFormatted = NumberFormat("#,###", "id_ID").format(nominalIuran);
  //   String adminFormatted = NumberFormat("#,###", "id_ID").format(admin);
  //   String totalIuranFormatted =
  //       NumberFormat("#,###", "id_ID").format(totalIuran);
  //   final now = DateTime.now();
  //   final tanggalLunasFormatted = DateFormat('dd-MM-yyyy-HH:mm').format(now);
  //   int parseInt(dynamic value) {
  //     if (value == null) return 0;
  //     if (value is int) return value;
  //     if (value is String) return int.tryParse(value) ?? 0;
  //     return 0;
  //   }

  //   return Center(
  //     child: ConstrainedBox(
  //       constraints: BoxConstraints(maxWidth: 900),
  //       child: Container(
  //         padding: const EdgeInsets.all(16.0),
  //         child: Card(
  //           color: Color(0xFF3D8D7A),
  //           child: Padding(
  //             padding: const EdgeInsets.all(16.0),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: <Widget>[
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: <Widget>[
  //                     Container(
  //                       width: 300,
  //                       padding: const EdgeInsets.all(8.0),
  //                       child: Card(
  //                         color: Color(0xFF8E2611),
  //                         child: Padding(
  //                           padding: const EdgeInsets.all(16.0),
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: <Widget>[
  //                               Row(
  //                                 children: [
  //                                   Icon(Icons.money_outlined,
  //                                       color: Colors.white),
  //                                   SizedBox(width: 8),
  //                                   Text(
  //                                     '$namaIuran',
  //                                     style: GoogleFonts.lato(
  //                                         fontSize: 14, color: Colors.white),
  //                                   ),
  //                                 ],
  //                               ),
  //                               SizedBox(height: 8),
  //                               Text(
  //                                 '$iuranFormatted',
  //                                 style: TextStyle(
  //                                   fontSize: 18,
  //                                   color: Colors.white,
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     Flexible(
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           Row(
  //                             children: [
  //                               Icon(Icons.location_on, color: Colors.white),
  //                               SizedBox(width: 8),
  //                               Flexible(
  //                                 child: Text(
  //                                   'No Kavling: ${revisi['no_kavling']}',
  //                                   style: TextStyle(
  //                                       color: Colors.white, fontSize: 16),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                           Row(
  //                             children: [
  //                               Icon(Icons.location_on, color: Colors.white),
  //                               SizedBox(width: 8),
  //                               Flexible(
  //                                 child: Text(
  //                                   'Alamat Kavling: ${revisi['alamat_kavling']}',
  //                                   style: TextStyle(
  //                                       color: Colors.white, fontSize: 16),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                           Row(
  //                             children: [
  //                               Icon(Icons.person, color: Colors.white),
  //                               SizedBox(width: 8),
  //                               Flexible(
  //                                 child: Text(
  //                                   'Nama Penghuni: ${revisi['nama_penanggung_jawab']}',
  //                                   style: TextStyle(
  //                                       color: Colors.white, fontSize: 16),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                           Row(
  //                             children: [
  //                               Icon(Icons.phone, color: Colors.white),
  //                               SizedBox(width: 8),
  //                               Flexible(
  //                                 child: Text(
  //                                   'No Telpon: ${revisi['no_telpon_penanggung_jawab']}',
  //                                   style: TextStyle(
  //                                       color: Colors.white, fontSize: 16),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 SizedBox(height: 16),
  //                 ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.white,
  //                     minimumSize: Size(double.infinity, 48),
  //                   ),
  //                   onPressed: () async {
  //                     try {
  //                       await updateStatusLunas(
  //                           parseInt(revisi['id_transaksi']));
  //                       await createAndUploadPdfInvoice(
  //                           nomorRekening: KodeRt.accountRT,
  //                           jenisRekening: KodeRt.jenisRekening,
  //                           tanggalLunas: tanggalLunasFormatted,
  //                           noTelpon:
  //                               revisi['no_telpon_penanggung_jawab'] ?? '',
  //                           namaIuran: revisi['nama_iuran'] ?? '',
  //                           noKavling: revisi['no_kavling'] ?? '',
  //                           TotalIuran: totalIuranFormatted,
  //                           Iuran: revisi['nominal_iuran'] ?? '',
  //                           selectedPayment: iMetode,
  //                           namaPenanggungJawab:
  //                               revisi['nama_penanggung_jawab'] ?? '',
  //                           alamatKavling: revisi['alamat_kavling'] ?? '',
  //                           tanggalJatuhTempo: revisi['batas_pembayaran'] ?? '',
  //                           idIuran: parseInt(revisi['id_iuran']),
  //                           idWarga: parseInt(revisi['id_warga']),
  //                           admin: adminFormatted);
                 
  //                       await sendToHistory(
  //                         revisi['no_kavling'] ?? '',
  //                         revisi['alamat_kavling'] ?? '',
  //                         revisi['nama_pemilik_rumah'] ?? '',
  //                         revisi['nama_penanggung_jawab'] ?? '',
  //                         revisi['nama_iuran'] ?? '',
  //                         revisi['batas_pembayaran'] ?? '',
  //                         revisi['nominal_iuran'] ?? '',
  //                         iMetode.toString(),
  //                         revisi['id_transaksi'],
  //                         revisi['coa']?.toString() ?? '',
  //                         revisi['kode_iuran']?.toString() ?? '',
  //                       );
  //                     } catch (e) {
  //                       print("Terjadi error: $e");
  //                     }
  //                   },
  //                   child: Text(
  //                     'Klik Bila Sudah Lunas',
  //                     style: GoogleFonts.lato(color: Colors.black),
  //                   ),
  //                 ),
  //                 SizedBox(height: 16),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildCardMobile(Map revisi) {
  String namaIuran = revisi['nama_iuran'] ?? 'N/A';

  String nominalIuranStr = revisi['nominal_iuran']?.toString() ?? '0';
  //String kodeUnikStr = revisi['kode_unik']?.toString() ?? '0';

  int nominalIuran = int.tryParse(nominalIuranStr.replaceAll('.', '')) ?? 0;
  int admin = 350;
  int totalIuran = nominalIuran + admin;

  String iuranFormatted = NumberFormat("#,###", "id_ID").format(nominalIuran);
  String adminFormatted = NumberFormat("#,###", "id_ID").format(admin);
  String totalIuranFormatted = NumberFormat("#,###", "id_ID").format(totalIuran);

  final now = DateTime.now();
  final tanggalLunasFormatted = DateFormat('dd-MM-yyyy-HH:mm').format(now);

  int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  return Center(
    child: Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: Color(0xFF3D8D7A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian judul dan nominal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Color(0xFF8E2611),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.money_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            namaIuran,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      iuranFormatted,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Data detail warga
              _buildInfoRow(Icons.home, 'No Kavling: ${revisi['no_kavling']}'),
              _buildInfoRow(Icons.location_on, 'Alamat Kavling: ${revisi['alamat_kavling']}'),
              _buildInfoRow(Icons.person, 'Nama Penghuni: ${revisi['nama_penanggung_jawab']}'),
              _buildInfoRow(Icons.phone, 'No Telpon: ${revisi['no_telpon_penanggung_jawab']}'),

              SizedBox(height: 16),

              // Tombol bayar lunas
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () async {
                  try {
                    await updateStatusLunas(parseInt(revisi['id_transaksi']));
                    await createAndUploadPdfInvoice(
                         nomorRekening: KodeRt.accountRT,
                            jenisRekening: KodeRt.jenisRekening,
                      tanggalLunas: tanggalLunasFormatted,
                      noTelpon: revisi['no_telpon_penanggung_jawab'] ?? '',
                      namaIuran: revisi['nama_iuran'] ?? '',
                      noKavling: revisi['no_kavling'] ?? '',
                      TotalIuran: totalIuranFormatted,
                      Iuran: revisi['nominal_iuran'] ?? '',
                      selectedPayment: iMetode,
                      namaPenanggungJawab: revisi['nama_penanggung_jawab'] ?? '',
                      alamatKavling: revisi['alamat_kavling'] ?? '',
                      tanggalJatuhTempo: revisi['batas_pembayaran'] ?? '',
                      idIuran: parseInt(revisi['id_iuran']),
                      idWarga: parseInt(revisi['id_warga']),
                      admin: adminFormatted,
                    );

                    await sendToHistory(
                      revisi['no_kavling'] ?? '',
                      revisi['alamat_kavling'] ?? '',
                      revisi['nama_pemilik_rumah'] ?? '',
                      revisi['nama_penanggung_jawab'] ?? '',
                      revisi['nama_iuran'] ?? '',
                      revisi['batas_pembayaran'] ?? '',
                      revisi['nominal_iuran'] ?? '',
                      iMetode.toString(),
                      revisi['id_transaksi'],
                      revisi['coa']?.toString() ?? '',
                      revisi['kode_iuran']?.toString() ?? '',
                    );
                         Flushbar(
          message: "Status telah diupdate menjadi LUNAS",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
                  } catch (e) {
                    print("Terjadi error: $e");
                  }
                },
                child: Text(
                  'Klik Bila Sudah Lunas',
                  style: GoogleFonts.lato(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildInfoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.lato(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

}

void main() {
  runApp(MaterialApp(
    home: BuktiTransaksiPage(),
  ));
}
