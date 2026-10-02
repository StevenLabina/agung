import 'dart:ui';

import 'package:another_flushbar/flushbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_aset.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_surplus_defisit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/screens/laporan_keuangan_utang.dart';
import 'package:iuran_rt_web/url.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class LaporanKeuanganNeracaPage extends StatefulWidget {
  @override
  _LaporanKeuanganNeracaPageState createState() =>
      _LaporanKeuanganNeracaPageState();
}

String formatRupiah(dynamic value) {
  if (value == null || value == '') return '';
  final number = int.tryParse(value.toString().replaceAll('.', ''));
  if (number == null) return value.toString();

  return number.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

final bulan = DateTime.now().month.toString().padLeft(2, '0');

class _LaporanKeuanganNeracaPageState extends State<LaporanKeuanganNeracaPage> {
  List<dynamic> dataLaporanKeu = [];
  String? get selectedMonthNumber {
    if (selectedMonth.isEmpty) return null;

    const monthMap = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'Mei': '05',
      'Jun': '06',
      'Jul': '07',
      'Agu': '08',
      'Sep': '09',
      'Okt': '10',
      'Nov': '11',
      'Des': '12',
    };

    return monthMap[selectedMonth];
  }

  bool isLoading = false;
  bool isDownload = false;
  double totalSaldoPendapatan = 0;
  double totalSaldoPengeluaran = 0;
  double totalSaldoPendapatanBln = 0;
  double totalSaldoPengeluaranBln = 0;
  double totalKasTunai = 0;
  double totalKasBank = 0;
  double totalPiutang = 0;
  double totalPiutangLainnya = 0;
  double totalAset = 0;
  double totalAktiva = 0;
  double totalKewajiban = 0;
  double totalSaldoKeu = 0;
  double totalSaldoAwal = 0;
  double totalUtangRT = 0;
  double totalUtangBank = 0;
  double totalIuranDimuka = 0;
  double totalAkmSurplusDef = 0;
  double totalBlnSurplusDef = 0;

  double totalSaldoPendapatanRaw = 0;
  double totalSaldoPengeluaranRaw = 0;
  double totalSaldoPendapatanBlnRaw = 0;
  double totalSaldoPengeluaranBlnRaw = 0;
  double totalKasTunaiRaw = 0;
  double totalKasBankRaw = 0;
  double totalPiutangRaw = 0;
  double totalPiutangLainnyaRaw = 0;
  double totalAsetRaw = 0;
  double totalAktivaRaw = 0;
  double totalKewajibanRaw = 0;
  double totalSaldoKeuRaw = 0;
  double totalSaldoAwalRaw = 0;
  double totalUtangRTRaw = 0;
  double totalUtangBankRaw = 0;
  double totalIuranDimukaRaw = 0;
  double totalAkmSurplusDefRaw = 0;
  double totalBlnSurplusDefRaw = 0;
  double hasilAkhir = 0;
  double hasilAkhirRaw = 0;
  String selectedMonth = 'Tahun';
  String monthNum = 'Tahun';

  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  List<dynamic> dataIuranTunai = [];
  List<dynamic> dataIuranBank = [];
  List<dynamic> dataIuranBelumLunas = [];
  List<dynamic> dataPiutangLainnya = [];
  List<dynamic> dataAset = [];
  List<dynamic> dataLaporanSurDef = [];
  List<dynamic> dataLaporanSurDefBln = [];
  List<dynamic> dataLaporanIuranDimuka = [];
  bool isDefisit = false;
  int? selectedMonthNumberr;
  late List<String> yearList;
  String? currentYear;
  @override
  void initState() {
    super.initState();
    updatePenyusutan();

    final now = DateTime.now().year;
    yearList = List.generate(
      5,
      (index) => (now - index).toString(),
    );

    currentYear = yearList.first;
    _loadAllData(lap_tahun: now.toString());
  }

  Future<void> _loadAllData({
    String? lap_bulan,
    String? lap_tahun,
  }) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      await Future.wait([
        loadDataKeuangan(
          bulan_kas: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchIuranPiutang(
          lap_bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchIuranPiutangLainnya(
          bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchLaporanKeuangan(
          bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchLaporanKeuanganBln(
          bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchLaporanKeuanganDimuka(
          bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchAset(
          bulan: lap_bulan,
          tahun: lap_tahun,
        ),
        fetchSaldoAwal(
          bulan: lap_bulan,
          tahun: lap_tahun,
        )
      ]);

      final int tahunSebelumnya = int.parse(lap_tahun!) - 1;

      await fetchHasilAkhirTahun(tahunSebelumnya.toString());
      // await setSaldoAwalByTahun(lap_tahun: lap_tahun!);
    } catch (e, s) {
      debugPrint("❌ LOAD ERROR: $e");
      debugPrintStack(stackTrace: s);
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<double> fetchHasilAkhirTahun(String tahun) async {
    try {
      final results = await Future.wait([
        fetchIuranByMetodeRaw(metode: 'Transfer', tahunKas: tahun),
        fetchIuranByMetodeRaw(metode: 'Bayar Tunai', tahunKas: tahun),
        fetchIuranPiutangRaw(tahun: tahun),
        fetchIuranPiutangLainnyaRaw(tahun: tahun),
        fetchAsetRaw(tahun: tahun),
        fetchLaporanKeuanganRaw(tahun: tahun),
        fetchLaporanKeuanganBlnRaw(tahun: tahun),
        fetchLaporanKeuanganDimukaRaw(tahun: tahun),
        fetchSaldoAwalRaw(tahun: tahun),
      ]);

      double kasBank = parseDouble(results[0]['total']);
      double kasTunai = parseDouble(results[1]['total']);
      double piutangWarga = parseDouble(results[2]['total']);
      double piutangLain = parseDouble(results[3]['total']);
      double aset = parseDouble(results[4]['total']);

      double surDefAkumulasi = parseDouble(results[5]['total']);
      double surDefBlnJalan = parseDouble(results[6]['total']);
      double iuranDimuka = parseDouble(results[7]['total']);
      double saldoAwal = parseDouble(results[8]['total']);

      // Log Detail AKTIVA
      print(
          "[AKTIVA] Bank: $kasBank, Tunai: $kasTunai, Piutang: $piutangWarga, Piutang Lain: $piutangLain, Aset: $aset");
      double totalAktiva =
          kasBank + kasTunai + piutangWarga + piutangLain + aset;

      // Log Detail KEWAJIBAN & EKUITAS
      // Sesuai rumus Anda: Kewajiban (Dimuka) + Ekuitas (Saldo Awal + Akumulasi + Bln Berjalan)
      print(
          "[KEWAJIBAN/EKUITAS] Akumulasi: $surDefAkumulasi, Bln Berjalan: $surDefBlnJalan, Dimuka: $iuranDimuka, Saldo Awal: $saldoAwal");

      // Perhatikan: Sesuaikan rumus ini dengan struktur Neraca Anda
      double totalKewajiban = surDefBlnJalan + iuranDimuka + saldoAwal;

      print(">>> TOTAL AKTIVA: $totalAktiva");
      print(">>> TOTAL KEWAJIBAN: $totalKewajiban");
      print(">>> HASIL AKHIR (Selisih): ${totalAktiva - totalKewajiban}");
      print("--- Selesai Kalkulasi Tahun: $tahun ---");

      return totalAktiva - totalKewajiban;
    } catch (e) {
      print("Error kalkulasi hasil akhir: $e");
      return 0.0;
    }
  }

  Future<void> updatePenyusutan() async {
    await http.post(
      Uri.parse("${ApiUrls.baseUrl}/update_penyusutan_aset.php"),
      body: jsonEncode({'id_rt': KodeRt.kodeRt}),
    );
  }

  Future<Map<String, dynamic>> fetchSaldoAwal(
      {String? bulan, String? tahun}) async {
    double saldoResult = 0.0;

    try {
      final response = await http.get(Uri.parse(
          '${ApiUrls.baseUrl}getSaldoAwal.php?id_rt=${KodeRt.kodeRt}&tahun=$tahun&bulan=$bulan'));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['result'] == 'success' &&
            responseData['data'] != null) {
          final saldo = responseData['data']['saldo_awal'];
          saldoResult = double.tryParse(saldo.toString()) ?? 0.0;
        } else if (responseData['result'] == 'empty') {
          saldoResult = 0;
        }

        if (mounted) {
          setState(() => totalSaldoAwal = saldoResult);
        }
      }
    } catch (e) {
      print("Error fetchSaldoAwal: $e");
    }

    return {'total': saldoResult};
  }

  Future<void> loadDataKeuangan({String? bulan_kas, String? tahun}) async {
    final tunai = await fetchIuranByMetode(
        metode: 'Bayar Tunai', bulanKas: bulan_kas, tahunKas: tahun);

    final bank = await fetchIuranByMetode(
        metode: 'Transfer', bulanKas: bulan_kas, tahunKas: tahun);

    if (!mounted) return;

    setState(() {
      totalKasTunai = tunai['total'];
      dataIuranTunai = tunai['data'];

      totalKasBank = bank['total'];
      dataIuranBank = bank['data'];
    });
  }

  Future<Map<String, dynamic>> fetchIuranByMetode(
      {required String metode, String? bulanKas, String? tahunKas}) async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/histori_all.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'id_rt': KodeRt.kodeRt,
        'metode': metode,
        'bulan':
            (bulanKas != null && bulanKas.isNotEmpty && bulanKas != 'Tahun')
                ? bulanKas
                : '',
        'tahun':
            (tahunKas != null && tahunKas.isNotEmpty && tahunKas != 'Tahun')
                ? tahunKas
                : '',
      },
    );

    if (response.statusCode != 200) {
      return {
        'total': 0.0,
        'data': [],
      };
    }

    final result = jsonDecode(response.body);
    final List list = result['data'] ?? [];

    final total = list.fold<double>(0, (sum, item) {
      final raw =
          item['r_nominal_iuran']?.toString().replaceAll('.', '') ?? '0';
      return sum + (double.tryParse(raw) ?? 0);
    });

    return {
      'total': total,
      'data': list,
    };
  }

  Future<Map<String, dynamic>> fetchAset({String? bulan, String? tahun}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl.endsWith('/') ? ApiUrls.baseUrl : '${ApiUrls.baseUrl}/'}list_aset.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
        },
      );

      if (response.statusCode != 200) {
        return {'total': 0.0, 'data': []};
      }

      final result = jsonDecode(response.body);
      final List dataAsett = result['data'] ?? [];

      final total = dataAsett.fold<double>(0.0, (sum, item) {
        final raw =
            item['harga_asset_sekarang']?.toString().replaceAll('.', '') ?? '0';
        return sum + (double.tryParse(raw) ?? 0.0);
      });

      if (mounted) {
        setState(() {
          dataAset = dataAsett;
          totalAset = total;
        });
      }

      return {
        'total': total,
        'data': dataAset,
      };
    } catch (e) {
      return {'total': 0.0, 'data': []};
    }
  }

  Future<Map<String, dynamic>> fetchIuranPiutang(
      {String? lap_bulan, String? tahun}) async {
    final Map<String, String> body = {
      'id_rt': KodeRt.kodeRt,
    };

    if (lap_bulan != null && lap_bulan.isNotEmpty) body['bulan'] = lap_bulan;
    if (tahun != null && tahun.isNotEmpty) body['tahun'] = tahun;

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/histori_belum_lunas.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) {
        return {'total': 0.0, 'data': []};
      }

      final result = jsonDecode(response.body);
      final List dataIuran = result['data'] ?? [];

      final total = dataIuran.fold<double>(0.0, (sum, item) {
        final raw =
            item['nominal_iuran']?.toString().replaceAll('.', '') ?? '0';
        return sum + (double.tryParse(raw) ?? 0.0);
      });

      if (mounted) {
        setState(() {
          dataIuranBelumLunas = dataIuran;
          totalPiutang = total;
        });
      }
      return {
        'total': total,
        'data': dataIuran,
      };
    } catch (e) {
      return {'total': 0.0, 'data': []};
    }
  }

  Future<Map<String, dynamic>> fetchIuranPiutangLainnya(
      {String? bulan, String? tahun}) async {
    double totalHasil = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listUtang.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];

        totalHasil = dataList.fold<double>(0.0, (sum, item) {
          final raw = item['nominal']?.toString().replaceAll('.', '') ?? '0';
          return sum + (double.tryParse(raw) ?? 0.0);
        });

        if (mounted) {
          setState(() {
            totalPiutangLainnya = totalHasil;
            dataPiutangLainnya = dataList;
          });
        }
      }
    } catch (e) {
      print("Error fetchIuranPiutangLainnya: $e");
    }

    // Mengembalikan Map agar bisa digunakan untuk kalkulasi
    return {
      'total': totalHasil,
      'data': dataList,
    };
  }

  Future<Map<String, dynamic>> fetchLaporanKeuangan(
      {String? bulan, String? tahun}) async {
    double selisih = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'VALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        double pendapatan = 0;
        double pengeluaran = 0;

        for (final item in dataList) {
          pendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
          pengeluaran += double.tryParse(
                  item['saldo_pengeluaran']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        selisih = pendapatan - pengeluaran;

        if (mounted) {
          setState(() {
            totalSaldoPendapatan = pendapatan;
            totalSaldoPengeluaran = pengeluaran;
            hasilAkhir = selisih;
            dataLaporanSurDef = dataList;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': selisih, 'data': dataList};
  }

  Future<Map<String, dynamic>> fetchLaporanKeuanganDimuka(
      {String? bulan, String? tahun}) async {
    double totalPendapatan = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'INVALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        for (final item in dataList) {
          totalPendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        if (mounted) {
          setState(() {
            totalIuranDimuka = totalPendapatan;
            dataLaporanIuranDimuka = dataList;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': totalPendapatan, 'data': dataList};
  }

  Future<Map<String, dynamic>> fetchLaporanKeuanganBln(
      {String? bulan, String? tahun}) async {
    double selisih = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'VALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        double pendapatan = 0;
        double pengeluaran = 0;

        for (final item in dataList) {
          pendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
          pengeluaran += double.tryParse(
                  item['saldo_pengeluaran']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        selisih = pendapatan - pengeluaran;

        if (mounted) {
          setState(() {
            totalSaldoPendapatanBln = pendapatan;
            totalSaldoPengeluaranBln = pengeluaran;
            totalBlnSurplusDef = selisih;
            dataLaporanSurDefBln = dataList;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': selisih, 'data': dataList};
  }

  Future<Map<String, dynamic>> fetchSaldoAwalRaw({String? tahun}) async {
    double saldoResult = 0.0;
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiUrls.baseUrl}getSaldoAwal.php?id_rt=${KodeRt.kodeRt}&tahun=$tahun'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['result'] == 'success' &&
            responseData['data'] != null) {
          final saldo = responseData['data']['saldo_awal'];
          saldoResult = double.tryParse(saldo.toString()) ?? 0.0;

          if (mounted) setState(() => totalSaldoAwalRaw = saldoResult);
        }
      }
    } catch (e) {
      print("Error fetchSaldoAwal: $e");
    }
    return {'total': saldoResult};
  }

  Future<void> loadDataKeuanganRaw({String? bulan_kas, String? tahun}) async {
    final tunai = await fetchIuranByMetodeRaw(
        metode: 'Bayar Tunai', bulanKas: bulan_kas, tahunKas: tahun);

    final bank = await fetchIuranByMetodeRaw(
        metode: 'Transfer', bulanKas: bulan_kas, tahunKas: tahun);

    if (!mounted) return;

    setState(() {
      totalKasTunaiRaw = tunai['total'];

      totalKasBank = bank['total'];
    });
  }

  Future<Map<String, dynamic>> fetchIuranByMetodeRaw(
      {required String metode, String? bulanKas, String? tahunKas}) async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}/histori_all.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'id_rt': KodeRt.kodeRt,
        'metode': metode,
        'bulan':
            (bulanKas != null && bulanKas.isNotEmpty && bulanKas != 'Tahun')
                ? bulanKas
                : '',
        'tahun':
            (tahunKas != null && tahunKas.isNotEmpty && tahunKas != 'Tahun')
                ? tahunKas
                : '',
      },
    );

    if (response.statusCode != 200) {
      return {
        'total': 0.0,
        'data': [],
      };
    }

    final result = jsonDecode(response.body);
    final List list = result['data'] ?? [];

    final total = list.fold<double>(0, (sum, item) {
      final raw =
          item['r_nominal_iuran']?.toString().replaceAll('.', '') ?? '0';
      return sum + (double.tryParse(raw) ?? 0);
    });

    return {
      'total': total,
      'data': list,
    };
  }

  Future<Map<String, dynamic>> fetchAsetRaw(
      {String? bulan, String? tahun}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl.endsWith('/') ? ApiUrls.baseUrl : '${ApiUrls.baseUrl}/'}list_aset.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
        },
      );

      if (response.statusCode != 200) {
        return {'total': 0.0, 'data': []};
      }

      final result = jsonDecode(response.body);
      final List dataAset = result['data'] ?? [];

      final total = dataAset.fold<double>(0.0, (sum, item) {
        final raw = item['harga_asset']?.toString().replaceAll('.', '') ?? '0';
        return sum + (double.tryParse(raw) ?? 0.0);
      });
      if (mounted) {
        setState(() {
          totalAsetRaw = total;
        });
      }

      return {
        'total': total,
        'data': dataAset,
      };
    } catch (e) {
      return {'total': 0.0, 'data': []};
    }
  }

  Future<Map<String, dynamic>> fetchIuranPiutangRaw(
      {String? lap_bulan, String? tahun}) async {
    final Map<String, String> body = {
      'id_rt': KodeRt.kodeRt,
    };

    if (lap_bulan != null && lap_bulan.isNotEmpty) body['bulan'] = lap_bulan;
    if (tahun != null && tahun.isNotEmpty) body['tahun'] = tahun;

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/histori_belum_lunas.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) {
        return {'total': 0.0, 'data': []};
      }

      final result = jsonDecode(response.body);
      final List dataIuran = result['data'] ?? [];

      final total = dataIuran.fold<double>(0.0, (sum, item) {
        final raw =
            item['nominal_iuran']?.toString().replaceAll('.', '') ?? '0';
        return sum + (double.tryParse(raw) ?? 0.0);
      });
      if (mounted) {
        setState(() {
          totalPiutangRaw = total;
        });
      }

      return {
        'total': total,
        'data': dataIuran,
      };
    } catch (e) {
      return {'total': 0.0, 'data': []};
    }
  }

  Future<Map<String, dynamic>> fetchIuranPiutangLainnyaRaw(
      {String? bulan, String? tahun}) async {
    double totalHasil = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listUtang.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];

        totalHasil = dataList.fold<double>(0.0, (sum, item) {
          final raw = item['nominal']?.toString().replaceAll('.', '') ?? '0';
          return sum + (double.tryParse(raw) ?? 0.0);
        });
      }
      if (mounted) {
        setState(() {
          totalPiutangLainnyaRaw = totalHasil;
        });
      }
    } catch (e) {
      print("Error fetchIuranPiutangLainnya: $e");
    }

    return {
      'total': totalHasil,
      'data': dataList,
    };
  }

  Future<Map<String, dynamic>> fetchLaporanKeuanganRaw(
      {String? bulan, String? tahun}) async {
    double selisih = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'VALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        double pendapatan = 0;
        double pengeluaran = 0;

        for (final item in dataList) {
          pendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
          pengeluaran += double.tryParse(
                  item['saldo_pengeluaran']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        selisih = pendapatan - pengeluaran;
        if (mounted) {
          setState(() {
            hasilAkhirRaw = selisih;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': selisih, 'data': dataList};
  }

  Future<Map<String, dynamic>> fetchLaporanKeuanganDimukaRaw(
      {String? bulan, String? tahun}) async {
    double totalPendapatan = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'INVALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        for (final item in dataList) {
          totalPendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        if (mounted) {
          setState(() {
            totalIuranDimukaRaw = totalPendapatan;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': totalPendapatan, 'data': dataList};
  }

  Future<Map<String, dynamic>> fetchLaporanKeuanganBlnRaw(
      {String? bulan, String? tahun}) async {
    double selisih = 0.0;
    List dataList = [];

    try {
      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/listLaporanKeuangan.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_rt': KodeRt.kodeRt,
          if (bulan != null) 'bulan': bulan,
          if (tahun != null) 'tahun': tahun,
          'status': 'VALID'
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dataList = result['data'] ?? [];
        double pendapatan = 0;
        double pengeluaran = 0;

        for (final item in dataList) {
          pendapatan += double.tryParse(
                  item['saldo_pendapatan']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
          pengeluaran += double.tryParse(
                  item['saldo_pengeluaran']?.toString().replaceAll('.', '') ??
                      '0') ??
              0;
        }
        selisih = pendapatan - pengeluaran;
        if (mounted) {
          setState(() {
            totalBlnSurplusDefRaw = selisih;
          });
        }
      }
    } catch (e) {
      print(e);
    }
    return {'total': selisih, 'data': dataList};
  }

  void _showConfirmationDialog(String type) {
    if (type == "kas_bank") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Kas Bank\nTotal: ${formatRupiah(totalKasBank)}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataIuranBank.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  border: TableBorder.all(
                                    color: Colors.grey.shade600,
                                    width: 1,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(130),
                                    1: FixedColumnWidth(140),
                                    2: FixedColumnWidth(140),
                                    3: FixedColumnWidth(140),
                                    4: FixedColumnWidth(120),
                                    5: FixedColumnWidth(140),
                                    6: FixedColumnWidth(140),
                                    7: FixedColumnWidth(100),
                                    8: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // ================= HEADER =================
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade100,
                                      ),
                                      children: [
                                        _buildTableHeader('No Kavling'),
                                        _buildTableHeader('Pemilik'),
                                        _buildTableHeader('Penghuni'),
                                        _buildTableHeader('Nama Iuran'),
                                        _buildTableHeader('Nominal'),
                                        _buildTableHeader('Jatuh Tempo'),
                                        _buildTableHeader('Tanggal Lunas'),
                                        _buildTableHeader('Status'),
                                        _buildTableHeader('Metode'),
                                      ],
                                    ),

                                    // ================= DATA =================
                                    ...dataIuranBank.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildTableCell(item['r_no_kavling']),
                                          _buildTableCell(
                                              item['r_nama_pemilik']),
                                          _buildTableCell(
                                              item['r_nama_penanggung_jawab']),
                                          _buildTableCell(item['r_nama_iuran']),
                                          _buildTableCell(
                                            NumberFormat.decimalPattern('id')
                                                .format(
                                              int.tryParse(
                                                    item['r_nominal_iuran']
                                                            ?.toString()
                                                            .replaceAll(
                                                                '.', '') ??
                                                        '0',
                                                  ) ??
                                                  0,
                                            ),
                                          ),
                                          _buildTableCell(
                                              item['r_batas_pembayaran']),
                                          _buildTableCell(
                                              item['r_tanggal_lunas']),
                                          _buildTableCell(item['r_status']),
                                          _buildTableCell(item['r_metode']),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
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
    } else if (type == "kas_tunai") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Kas Tunai\nTotal: ${formatRupiah(totalKasTunai)}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataIuranTunai.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  border: TableBorder.all(
                                    color: Colors.grey.shade600,
                                    width: 1,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(130),
                                    1: FixedColumnWidth(140),
                                    2: FixedColumnWidth(140),
                                    3: FixedColumnWidth(140),
                                    4: FixedColumnWidth(120),
                                    5: FixedColumnWidth(140),
                                    6: FixedColumnWidth(140),
                                    7: FixedColumnWidth(100),
                                    8: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // ================= HEADER =================
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade100,
                                      ),
                                      children: [
                                        _buildTableHeader('No Kavling'),
                                        _buildTableHeader('Pemilik'),
                                        _buildTableHeader('Penghuni'),
                                        _buildTableHeader('Nama Iuran'),
                                        _buildTableHeader('Nominal'),
                                        _buildTableHeader('Jatuh Tempo'),
                                        _buildTableHeader('Tanggal Lunas'),
                                        _buildTableHeader('Status'),
                                        _buildTableHeader('Metode'),
                                      ],
                                    ),

                                    // ================= DATA =================
                                    ...dataIuranTunai.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildTableCell(item['r_no_kavling']),
                                          _buildTableCell(
                                              item['r_nama_pemilik']),
                                          _buildTableCell(
                                              item['r_nama_penanggung_jawab']),
                                          _buildTableCell(item['r_nama_iuran']),
                                          _buildTableCell(
                                            NumberFormat.decimalPattern('id')
                                                .format(
                                              int.tryParse(
                                                    item['r_nominal_iuran']
                                                            ?.toString()
                                                            .replaceAll(
                                                                '.', '') ??
                                                        '0',
                                                  ) ??
                                                  0,
                                            ),
                                          ),
                                          _buildTableCell(
                                              item['r_batas_pembayaran']),
                                          _buildTableCell(
                                              item['r_tanggal_lunas']),
                                          _buildTableCell(item['r_status']),
                                          _buildTableCell(item['r_metode']),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
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
    } else if (type == "piutang") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Piutang Warga\nTotal: ${formatRupiah(totalPiutang)}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataIuranBelumLunas.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  border: TableBorder.all(
                                    color: Colors.grey.shade600,
                                    width: 1,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(130),
                                    1: FixedColumnWidth(150),
                                    2: FixedColumnWidth(150),
                                    3: FixedColumnWidth(150),
                                    4: FixedColumnWidth(130),
                                    5: FixedColumnWidth(160),
                                    6: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // 🔸 Header
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade100,
                                      ),
                                      children: [
                                        _buildTableHeader('No Kavling'),
                                        _buildTableHeader('Pemilik'),
                                        _buildTableHeader('Penghuni'),
                                        _buildTableHeader('Nama Iuran'),
                                        _buildTableHeader('Nominal'),
                                        _buildTableHeader('Jatuh Tempo'),
                                        _buildTableHeader('Status'),
                                      ],
                                    ),

                                    // 🔸 Data Rows
                                    ...dataIuranBelumLunas.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildTableCell(item['no_kavling']),
                                          _buildTableCell(
                                              item['nama_pemilik_rumah']),
                                          _buildTableCell(
                                              item['nama_penghuni']),
                                          _buildTableCell(item['nama_iuran']),
                                          _buildTableCell(
                                              item['nominal_iuran']),
                                          _buildTableCell(
                                              item['batas_pembayaran']),
                                          _buildTableCell(item['status']),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
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
    } else if (type == "piutang_lainnya") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Piutang Lainnya\nTotal: ${formatRupiah(totalPiutangLainnya)}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataPiutangLainnya.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
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
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade100,
                                          ),
                                          children: [
                                            _buildTableHeader('Tanggal'),
                                            _buildTableHeader('Nama Warga'),
                                            _buildTableHeader('No Kavling'),
                                            _buildTableHeader('Uraian Utang'),
                                            _buildTableHeader('Nominal'),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // ISI
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
                                          },
                                          children:
                                              dataPiutangLainnya.map((item) {
                                            return TableRow(
                                              children: [
                                                _buildTableCell(
                                                    item['tanggal']),
                                                _buildTableCell(item['nama']),
                                                _buildTableCell(
                                                    item['no_kavling']),
                                                _buildTableCell(
                                                    item['keterangan']),
                                                _buildTableCell(
                                                    "Rp ${item['nominal']}"),
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
    } else if (type == "aset") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text('Laporan Aset\nTotal: ${(formatRupiah(totalAset))}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataAset.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
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
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(200),
                                          6: FixedColumnWidth(200),
                                          7: FixedColumnWidth(200),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.shade100,
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
                                          1: FixedColumnWidth(200),
                                          2: FixedColumnWidth(200),
                                          3: FixedColumnWidth(200),
                                          4: FixedColumnWidth(200),
                                          5: FixedColumnWidth(200),
                                          6: FixedColumnWidth(200),
                                          7: FixedColumnWidth(200),
                                        },
                                        children: dataAset
                                            .where((item) =>
                                                item['nama_asset'] != null &&
                                                item['tanggal_diterima'] !=
                                                    null)
                                            .map((item) {
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
                                              _buildTableCell(
                                                  'Rp ${item['penyusutan_tahunan']}'),
                                              _buildTableCell(
                                                  '${item['tahun_penyusutan']} tahun'),
                                              _buildTableCell(
                                                  '${item['tahun_akm_penyusutan']} tahun'),
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
                        ),
            ),
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
    } else if (type == "akm_surplus_defisit") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Akumulasi Surplus Defisit\nTotal: ${(formatRupiah(totalBlnSurplusDef))}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dataLaporanSurDef.isEmpty
                        ? const Center(child: Text('Tidak ada data'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final currentYear = DateTime.now().year;

                              return buildRingkasanKeuanganSurDef(
                                  pendapatan: totalSaldoPendapatan,
                                  pengeluaran: totalSaldoPengeluaran,
                                  hasilAkhir: hasilAkhir,
                                  title: 'Ringkasan Keuangan',
                                  numberMonth: monthNum,
                                  month: selectedMonth,
                                  year: currentYear.toString());
                            },
                          )),
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
    } else if (type == "akm_surplus_defisit_bln") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text(
                'Laporan Surplus Defisit Bulan Berjalan\nTotal: ${(formatRupiah(totalBlnSurplusDef))}',
                style: GoogleFonts.lato(color: Colors.black)),
            content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dataLaporanSurDefBln.isEmpty
                        ? const Center(child: Text('Tidak ada data'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final currentYear = DateTime.now().year;

                              return buildRingkasanKeuanganSurDef(
                                  pendapatan: totalSaldoPendapatanBln,
                                  pengeluaran: totalSaldoPengeluaranBln,
                                  hasilAkhir: totalBlnSurplusDef,
                                  title: 'Ringkasan Keuangan',
                                  numberMonth: monthNum,
                                  month: selectedMonth,
                                  year: currentYear.toString());
                            },
                          )),
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
    } else if (type == "iuran_dimuka") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Color(0xFFFDECE8),
            title: Text('Laporan Iuran Dibayar Dimuka',
                style: GoogleFonts.lato(color: Colors.black)),
            content: SizedBox(
              child: Text('Total: ${(formatRupiah(totalIuranDimuka))}',
                  style: GoogleFonts.lato(color: Colors.black)),
            ),
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
  }

// Future<void> setSaldoAwalByTahun({required String lap_tahun}) async {
//   final Map<String, dynamic> resSaldo = await fetchSaldoAwal(tahun: lap_tahun);
//   final double saldoDb = (resSaldo['total'] ?? 0.0).toDouble();

//   double saldoYangAkanDigunakan = 0.0;

//   if (saldoDb != 0) {
//     saldoYangAkanDigunakan = saldoDb;
//   } else {
//     final int tahunSebelumnya = int.parse(lap_tahun) - 1;

//     saldoYangAkanDigunakan = await fetchHasilAkhirTahun(tahunSebelumnya.toString());
//   }

//   if (!mounted) return;
//   setState(() {
//     totalSaldoAwal = saldoYangAkanDigunakan;
//     totalKasBank = saldoYangAkanDigunakan;
//   });
// }

  Future<void> tambahDataLaporan(String tanggal, String keterangan,
      String saldo, String coa, String kodeRef, String noKavling) async {
    final response = await http.post(
      Uri.parse('${ApiUrls.baseUrl}tambahPendapatan.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "tanggal": tanggal,
        "keterangan": keterangan,
        "saldo": saldo,
        "coa": coa,
        "kode_ref": kodeRef,
        "no_kavling": noKavling,
        'id_rt': KodeRt.kodeRt
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] == 'success') {
        Flushbar(
          message: "Data berhasil disimpan",
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
   
    } else {
      Flushbar(
        message: 'Gagal menyimpan data: ${data['message']}',
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> exportToExcelOnlySendPath(
    String tahun,
    String totalPendapatan,
    String totalPengeluaran,
    String totalSemua,
  ) async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan Keuangan Surplus Defisit'];

    List<String> headers = [
      'Tanggal Pendapatan',
      'COA Pendapatan',
      'Kode Ref Pendapatan',
      'No Kavling Pendapatan',
      'Keterangan Pendapatan',
      'Saldo Pendapatan',
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
        item['tanggal_pendapatan'] ?? '-',
        item['coa_pendapatan'] ?? '-',
        item['kode_ref_pendapatan'] ?? '-',
        item['no_kavling_pendapatan'] ?? '-',
        item['ket_pendapatan'] ?? '-',
        item['saldo_pendapatan'] ?? '-',
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
      String filePath =
          "${directory.path}/Laporan Keuangan Surplus Defisit.xlsx";
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
            'totalPendapatan': totalPendapatan.toString(),
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

  Future<void> createAndUploadPdf(
      {required String selectedMonth,
      required String currentYear,
      required String namaRt,
      required double totalSaldoPendapatan,
      required double totalSaldoPengeluaran,
      required double hasilAkhir,
      required bool isDefisit,
      required double kasBank,
      required double kasTunai,
      required double piutangWarga,
      required double piutangLainnya,
      required double aset,
      required double utangRt,
      required double utangBank,
      required double iuranDimuka,
      required double akmSurplusDef,
      required double surplusDefBln,
      required double saldoAwal,
      required double totalAktiva,
      required double totalKewajiban}) async {
    final pdf = pw.Document();

    final ByteData imageData = await rootBundle.load('assets/images/Logo3.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Laporan Neraca \nPeriode $selectedMonth $currentYear',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            namaRt,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Divider(thickness: 2),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(3),
                        4: const pw.FlexColumnWidth(2),
                      },
                      border: const pw.TableBorder(
                        left: pw.BorderSide.none,
                        right: pw.BorderSide.none,
                        top: pw.BorderSide.none,
                        bottom: pw.BorderSide.none,
                        horizontalInside: pw.BorderSide.none,
                        verticalInside: pw.BorderSide.none,
                      ),
                      children: [
                        pw.TableRow(
                          children: [
                            _cellText('AKTIVA', bold: true),
                            pw.SizedBox(),
                            pw.SizedBox(), // ⬅ SPASI TENGAH
                            _cellText('KEWAJIBAN', bold: true),
                            pw.SizedBox(),
                          ],
                        ),
                        _spacerRow(),
                        pw.TableRow(
                          children: [
                            _cellText('AKTIVA LANCAR', bold: true),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            _cellText('KEWAJIBAN LANCAR', bold: true),
                            pw.SizedBox(),
                          ],
                        ),
                        _neracaRow(
                          'Kas Tunai',
                          formatRupiah(kasTunai),
                          'Utang RT',
                          formatRupiah(utangRt),
                        ),
                        _neracaRow(
                          'Kas Bank',
                          formatRupiah(kasBank),
                          'Utang Bank',
                          formatRupiah(utangBank),
                        ),
                        _neracaRow(
                          '',
                          '',
                          'Iuran Warga Dibayar Dimuka',
                          formatRupiah(iuranDimuka),
                        ),
                        _spacerRow(),
                        pw.TableRow(
                          children: [
                            _cellText('PIUTANG', bold: true),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                          ],
                        ),
                        _neracaRow(
                          'Piutang Iuran Warga',
                          formatRupiah(piutangWarga),
                          '',
                          '',
                        ),
                        _neracaRow(
                          'Piutang Lain-lainnya',
                          formatRupiah(piutangLainnya),
                          '',
                          '',
                        ),
                        _spacerRow(),
                        pw.TableRow(
                          children: [
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            _cellText('EKUITAS', bold: true),
                            pw.SizedBox(),
                          ],
                        ),
                        _neracaRow(
                          '',
                          '',
                          'Saldo Awal Saat Penggunaan Sistem',
                          formatRupiah(saldoAwal),
                        ),
                        _neracaRow(
                          '',
                          '',
                          'Akumulasi Surplus Defisit',
                          formatRupiah(akmSurplusDef),
                        ),
                        _neracaRow(
                          '',
                          '',
                          'Modal Aset Warga',
                          formatRupiah(aset),
                        ),
                        _neracaRow(
                          '',
                          '',
                          'Surplus Defisit Bulan Berjalan',
                          formatRupiah(surplusDefBln),
                        ),
                        _spacerRow(),
                        pw.TableRow(
                          children: [
                            _cellText('AKTIVA TIDAK LANCAR', bold: true),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                          ],
                        ),
                        _neracaRow(
                            'Aset Warga', '${formatRupiah(aset)}', '', ''),
                        _spacerRow(14),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(width: 1),
                            ),
                          ),
                          children: [
                            _cellText('TOTAL', bold: true),
                            pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: _cellText(
                                formatRupiah(totalAktiva),
                                bold: true,
                                align: pw.TextAlign.right,
                              ),
                            ),
                            pw.SizedBox(),
                            _cellText('TOTAL', bold: true),
                            pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: _cellText(
                                formatRupiah(totalKewajiban),
                                bold: true,
                                align: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Terima kasih telah menggunakan aplikasi RT Digital',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  "Created by RT Digital",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List encoded = await pdf.save();
    if (kIsWeb) {
      final blob = html.Blob([encoded], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "Laporan Keuangan Neraca ${selectedMonth} $currentYear.pdf",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Neraca ${selectedMonth} $currentYear.pdf";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);
    }
  }

  pw.TableRow _spacerRow([double height = 10]) {
    return pw.TableRow(
      children: List.generate(
        5, // ⬅ BUKAN 4 LAGI
        (_) => pw.SizedBox(height: height),
      ),
    );
  }

  pw.Widget _cellText(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 18),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        softWrap: true,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.TableRow _neracaRow(
    String leftTitle,
    String leftValue,
    String rightTitle,
    String rightValue,
  ) {
    return pw.TableRow(
      children: [
        _cellText(leftTitle),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _cellText(leftValue, align: pw.TextAlign.right),
        ),
        pw.SizedBox(), // ⬅ GUTTER
        _cellText(rightTitle),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _cellText(rightValue, align: pw.TextAlign.right),
        ),
      ],
    );
  }

  Future<void> exportToExcel(
      {required String namaRt,
      required String selectedMonth,
      required String currentYear,
      required double totalSaldoPendapatan,
      required double totalSaldoPengeluaran,
      required double hasilAkhir,
      required bool isDefisit,
      required double kasBank,
      required double kasTunai,
      required double piutangWarga,
      required double piutangLainnya,
      required double aset,
      required double utangRt,
      required double utangBank,
      required double iuranDimuka,
      required double akmSurplusDef,
      required double surplusDefBln,
      required double saldoAwal,
      required double totalAktiva,
      required double totalKewajiban}) async {
    var excel = exc.Excel.createExcel();
    final sheetName = 'Laporan Neraca $selectedMonth $currentYear';
    exc.Sheet sheet = excel[sheetName];

    int row = 0;

    sheet.merge(
      exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'Laporan Neraca Periode $selectedMonth $currentYear';
    row++;

    sheet.merge(
      exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = namaRt;
    row += 2;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'AKTIVA';
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = 'KEWAJIBAN';
    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'AKTIVA LANCAR';
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = 'KEWAJIBAN LANCAR';
    row++;

    _neracaExcelRow(sheet, row++, 'Kas Tunai', formatRupiah(kasTunai), '',
        'Utang RT', formatRupiah(utangRt));
    _neracaExcelRow(sheet, row++, 'Kas Bank', formatRupiah(kasBank.toString()),
        '', 'Utang Bank', formatRupiah(utangBank));
    _neracaExcelRow(sheet, row++, '', null, '', 'Iuran Warga Dibayar Dimuka',
        formatRupiah(iuranDimuka));

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'PIUTANG';
    row++;

    _neracaExcelRow(sheet, row++, 'Piutang Iuran Warga',
        formatRupiah(piutangWarga.toString()), '', '', null);
    _neracaExcelRow(sheet, row++, 'Piutang Lain-lainnya',
        formatRupiah(piutangLainnya.toString()), '', '', null);

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = 'EKUITAS';
    row++;

    _neracaExcelRow(
        sheet,
        row++,
        '',
        null,
        '',
        'Saldo Awal Saat Penggunaan Sistem',
        formatRupiah(saldoAwal.toString()));
    _neracaExcelRow(sheet, row++, '', null, '', 'Akumulasi Surplus Defisit',
        formatRupiah(akmSurplusDef.toString()));
    _neracaExcelRow(
        sheet,
        row++,
        '',
        null,
        '',
        'Surplus Defisit Bulan Berjalan',
        formatRupiah(surplusDefBln.toString()));

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'ASET';
    row++;

    _neracaExcelRow(sheet, row++, 'Aset Warga', formatRupiah(aset.toString()),
        '', '', null);

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = 'TOTAL';
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = formatRupiah(totalAktiva.toString());
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = 'TOTAL';
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = formatRupiah(totalKewajiban.toString());

    final encoded = excel.encode();
    if (encoded == null) return;

    if (kIsWeb) {
      final blob = html.Blob([encoded],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "Laporan Keuangan Neraca $selectedMonth $currentYear.xlsx",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath =
          "${directory.path}/Laporan Keuangan Neraca $selectedMonth $currentYear.xlsx";
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);
    }
  }

  void _neracaExcelRow(
    exc.Sheet sheet,
    int row,
    String leftTitle,
    String? leftValue,
    String _,
    String rightTitle,
    String? rightValue,
  ) {
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = leftTitle;
    if (leftValue != null) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = leftValue;
    }

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = rightTitle;
    if (rightValue != null) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = rightValue;
    }
  }

  // double _parseNumber(dynamic value) {
  //   if (value == null) return 0;
  //   String cleaned = value.toString().replaceAll(RegExp(r'[^0-9,-]'), '');
  //   if (cleaned.isEmpty) return 0;
  //   return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
  // }

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

  String generateKodeRef({
    required String namaRT,
    required String kodeIuran,
    required String alamatKavling,
    required String tanggalLunas,
    required String kodeTransaksi,
  }) {
    return '$namaRT$kodeIuran$alamatKavling$tanggalLunas$kodeTransaksi';
  }

  void _showSaldoAwalDialog(BuildContext context) async {
    final TextEditingController saldoAwalController = TextEditingController();
    final prefs = await SharedPreferences.getInstance();
    String? noKavling = prefs.getString('noKavling');

    String currentDate = DateFormat('dd-MM-yyyy-HH:mm').format(DateTime.now());
    final now = DateTime.now();
    final tanggalRef = DateFormat('yyMMdd').format(now);

    String kodeRef = generateKodeRef(
      namaRT: KodeRt.kodeRt.toUpperCase(),
      kodeIuran: '003',
      alamatKavling: noKavling.toString(),
      tanggalLunas: tanggalRef,
      kodeTransaksi: '0000',
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Saldo awal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: saldoAwalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Saldo Awal Tahun',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Batal'),
                ),
                TextButton(
                  onPressed: () async {
                    await tambahDataLaporan(
                      currentDate,
                      "Saldo Awal Tahun",
                      saldoAwalController.text,
                      "800",
                      kodeRef.toString(),
                      noKavling.toString(),
                    );

                    Navigator.of(context).pop();

                    await fetchLaporanKeuangan();

                    setState(() {});
                  },
                  child: Text('Cek'),
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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 3,),
                                        ),
                                        );
                        },
                      ),
                      Text(
                        'Laporan Neraca',
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
                  _buildFilterButton('Aset', onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LaporanKeuanganAsetPage()),
                    );
                  }),
                  _buildFilterButton('Neraca',
                      isActive: true, onPressed: () {}),
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
                // ================= TAHUN =================
                _buildMonthButton(
                  'Tahun',
                  isSelected: selectedMonth.isEmpty,
                  onPressed: () {
                    setState(() {
                      selectedMonth = "";
                    });

                    _loadAllData(lap_bulan: null, lap_tahun: currentYear);
                  },
                ),

                // ================= BULAN =================
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

                  return _buildMonthButton(
                    monthNames[index],
                    isSelected: selectedMonth == monthNames[index],
                    onPressed: () {
                      setState(() {
                        selectedMonth = monthNames[index];
                      });

                      _loadAllData(
                          lap_bulan: selectedMonthNumber, // ⬅️ BULAN
                          lap_tahun: currentYear // ⬅️ TAHUN
                          );
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pilih Tahun: "),
              DropdownButton<String>(
                value: currentYear,
                items: yearList.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? year) {
                  if (year == null) return;

                  setState(() {
                    currentYear = year;
                  });

                  _loadAllData(
                      lap_bulan: selectedMonthNumber, // ⬅️ ikut bulan terpilih
                      lap_tahun: currentYear // ⬅️ tahun baru
                      );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final int tahunSebelumnya = int.parse(currentYear!) - 1;
                        totalAktiva = totalKasBank +
                            totalKasTunai +
                            totalPiutang +
                            totalPiutangLainnya +
                            totalAset;
                        totalKewajiban = totalUtangRT +
                            totalBlnSurplusDef +
                            totalIuranDimuka +
                            totalSaldoAwal +
                            totalUtangBank +
                            (hasilAkhir - totalBlnSurplusDef) +
                            totalAset;
                        totalAktivaRaw = totalKasBankRaw +
                            totalKasTunaiRaw +
                            totalPiutangRaw +
                            totalPiutangLainnyaRaw +
                            totalAsetRaw;
                        totalKewajibanRaw = totalUtangRTRaw +
                            totalBlnSurplusDefRaw +
                            totalIuranDimukaRaw +
                            totalSaldoAwalRaw +
                            totalUtangBankRaw +
                            (hasilAkhirRaw - totalBlnSurplusDefRaw) +
                            totalAsetRaw;

                        return buildRingkasanKeuanganMobile(
                          pendapatan: totalSaldoPendapatan,
                          pengeluaran: totalSaldoPengeluaran,
                          hasilAkhir: hasilAkhir,
                          title:
                              'Laporan Neraca\nPeriode $selectedMonth $currentYear',
                          numberMonth: monthNum,
                          month: selectedMonth,
                          year: currentYear.toString(),
                          kasTunai: totalKasTunai,
                          kasBank: totalKasBank,
                          piutang: totalPiutang,
                          piutangLainnya: totalPiutangLainnya,
                          aset: totalAset,
                          totalAktiva: totalAktiva,
                          totalKewajiban: totalKewajiban,
                          saldoAwal: totalSaldoAwal,
                          utangRT: totalUtangRT,
                          utangBank: totalUtangBank,
                          blnSurplusDef: totalBlnSurplusDef,
                          iuranDimuka: totalIuranDimuka,
                          tahunLalu: tahunSebelumnya.toString(),
                          totalAktivaTahunLalu: totalAktivaRaw,
                          totalKewajibanTahunLalu: totalKewajibanRaw,
                          onTapItem: (type) {
                            _showConfirmationDialog(type);
                          },
                        );
                      },
                    )),
                       SizedBox(height: 8),
                      Align(
                            alignment: Alignment.center,
                            child:    Row(
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
             onPressed: () async {
              await createAndUploadPdf(
                currentYear: currentYear.toString(),
                selectedMonth: selectedMonth,
                namaRt: KodeRt.namaRt,
                totalSaldoPendapatan: totalSaldoPendapatan,
                totalSaldoPengeluaran: totalSaldoPengeluaran,
                hasilAkhir: hasilAkhir,
                isDefisit: isDefisit,
                kasBank: totalKasBank,
                kasTunai: totalKasTunai,
                piutangWarga: totalPiutang,
                piutangLainnya: totalPiutangLainnya,
                aset: totalAset,
                utangRt: totalUtangRT,
                utangBank: totalUtangBank,
                iuranDimuka: totalIuranDimuka,
                akmSurplusDef: totalAkmSurplusDef,
                surplusDefBln: totalBlnSurplusDef,
                saldoAwal: totalSaldoAwal,
                totalAktiva: totalAktiva,
                totalKewajiban: totalKewajiban,
              );
            },
          ),
          const SizedBox(width: 12), // jarak horizontal
          FloatingActionButton.extended(
            backgroundColor: const Color(0xFF3D8D7A),
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text(
              'Unduh Excel',
              style: TextStyle(color: Colors.white),
            ),
           onPressed: () async {
              await exportToExcel(
                currentYear: currentYear.toString(),
                selectedMonth: selectedMonth,
                namaRt: KodeRt.namaRt,
                totalSaldoPendapatan: totalSaldoPendapatan,
                totalSaldoPengeluaran: totalSaldoPengeluaran,
                hasilAkhir: hasilAkhir,
                isDefisit: isDefisit,
                kasBank: totalKasBank,
                kasTunai: totalKasTunai,
                piutangWarga: totalPiutang,
                piutangLainnya: totalPiutangLainnya,
                aset: totalAset,
                utangRt: totalUtangRT,
                utangBank: totalUtangBank,
                iuranDimuka: totalIuranDimuka,
                akmSurplusDef: totalAkmSurplusDef,
                surplusDefBln: totalBlnSurplusDef,
                saldoAwal: totalSaldoAwal,
                totalAktiva: totalAktiva,
                totalKewajiban: totalKewajiban,
              );
            },
          ),
        ],
      ),
                          ),
        ],
      ),
   
    );
  }

  /// 🔹 Tombol kategori
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

  // Widget _buildItemRow(String label, dynamic value) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 4.0),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Expanded(
  //           flex: 3,
  //           child: Text(
  //             '$label:',
  //             style: const TextStyle(
  //                 fontWeight: FontWeight.bold, color: Color(0xFF3D8D7A)),
  //           ),
  //         ),
  //         Expanded(
  //           flex: 5,
  //           child: Text(
  //             value != null ? value.toString() : '-',
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
                                              builder: (context) =>
                                                 MenuPilihanPage(idMenu: 3,),
                                        ),
                                        );
                        },
                      ),
                      Text(
                        'Laporan Neraca',
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
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Neraca',
                        style: TextStyle(
                          color: Color(0xFF3D8D7A),
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
                  // TOMBOL TAHUN
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
                        selectedMonthNumberr = null;
                      });

                      _loadAllData(
                          lap_bulan: null, // ⬅️ reset bulan
                          lap_tahun: currentYear // ⬅️ tetap pakai tahun
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

                    final monthNumber = index + 1;
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
                          selectedMonthNumberr = monthNumber;
                        });

                        _loadAllData(
                            lap_bulan: selectedMonthNumber, // ⬅️ BULAN
                            lap_tahun: currentYear // ⬅️ TAHUN
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pilih Tahun: "),
              DropdownButton<String>(
                value: currentYear,
                items: yearList.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? year) {
                  if (year == null) return;

                  setState(() {
                    currentYear = year;
                  });

                  _loadAllData(
                      lap_bulan: selectedMonthNumber, // ⬅️ ikut bulan terpilih
                      lap_tahun: currentYear // ⬅️ tahun baru
                      );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                // : dataLaporanKeu.isEmpty
                //     ? const Center(child: Text('Tidak ada data Transaksi'))
                : ScrollConfiguration(
                    behavior: MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final int tahunSebelumnya =
                              int.parse(currentYear!) - 1;
                          totalAktiva = totalKasBank +
                              totalKasTunai +
                              totalPiutang +
                              totalPiutangLainnya +
                              totalAset;
                          totalKewajiban = totalUtangRT +
                              totalBlnSurplusDef +
                              totalIuranDimuka +
                              totalSaldoAwal +
                              totalUtangBank +
                              (hasilAkhir - totalBlnSurplusDef) +
                              totalAset;
                          totalAktivaRaw = totalKasBankRaw +
                              totalKasTunaiRaw +
                              totalPiutangRaw +
                              totalPiutangLainnyaRaw +
                              totalAsetRaw;
                          totalKewajibanRaw = totalUtangRTRaw +
                              totalBlnSurplusDefRaw +
                              totalIuranDimukaRaw +
                              totalSaldoAwalRaw +
                              totalUtangBankRaw +
                              (hasilAkhirRaw - totalBlnSurplusDefRaw) +
                              totalAsetRaw;

                          return buildRingkasanKeuangan(
                            pendapatan: totalSaldoPendapatan,
                            pengeluaran: totalSaldoPengeluaran,
                            hasilAkhir: hasilAkhir,
                            title:
                                'Laporan Neraca\nPeriode $selectedMonth $currentYear',
                            numberMonth: monthNum,
                            month: selectedMonth,
                            year: currentYear.toString(),
                            kasTunai: totalKasTunai,
                            kasBank: totalKasBank,
                            piutang: totalPiutang,
                            piutangLainnya: totalPiutangLainnya,
                            aset: totalAset,
                            totalAktiva: totalAktiva,
                            totalKewajiban: totalKewajiban,
                            saldoAwal: totalSaldoAwal,
                            utangRT: totalUtangRT,
                            utangBank: totalUtangBank,
                            blnSurplusDef: totalBlnSurplusDef,
                            iuranDimuka: totalIuranDimuka,
                            tahunLalu: tahunSebelumnya.toString(),
                            totalAktivaTahunLalu: totalAktivaRaw,
                            totalKewajibanTahunLalu: totalKewajibanRaw,
                            onTapItem: (type) {
                              _showConfirmationDialog(type);
                            },
                          );
                        },
                      ),
                    ),
                  ),
          ),
          SizedBox(height: 16),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            backgroundColor: const Color(0xFF3D8D7A),
            heroTag: 'downloadPdf',
            onPressed: () async {
              await createAndUploadPdf(
                currentYear: currentYear.toString(),
                selectedMonth: selectedMonth,
                namaRt: KodeRt.namaRt,
                totalSaldoPendapatan: totalSaldoPendapatan,
                totalSaldoPengeluaran: totalSaldoPengeluaran,
                hasilAkhir: hasilAkhir,
                isDefisit: isDefisit,
                kasBank: totalKasBank,
                kasTunai: totalKasTunai,
                piutangWarga: totalPiutang,
                piutangLainnya: totalPiutangLainnya,
                aset: totalAset,
                utangRt: totalUtangRT,
                utangBank: totalUtangBank,
                iuranDimuka: totalIuranDimuka,
                akmSurplusDef: totalAkmSurplusDef,
                surplusDefBln: totalBlnSurplusDef,
                saldoAwal: totalSaldoAwal,
                totalAktiva: totalAktiva,
                totalKewajiban: totalKewajiban,
              );
            },
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
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            backgroundColor: const Color(0xFF3D8D7A),
            heroTag: 'downloadExcel',
            onPressed: () async {
              await exportToExcel(
                currentYear: currentYear.toString(),
                selectedMonth: selectedMonth,
                namaRt: KodeRt.namaRt,
                totalSaldoPendapatan: totalSaldoPendapatan,
                totalSaldoPengeluaran: totalSaldoPengeluaran,
                hasilAkhir: hasilAkhir,
                isDefisit: isDefisit,
                kasBank: totalKasBank,
                kasTunai: totalKasTunai,
                piutangWarga: totalPiutang,
                piutangLainnya: totalPiutangLainnya,
                aset: totalAset,
                utangRt: totalUtangRT,
                utangBank: totalUtangBank,
                iuranDimuka: totalIuranDimuka,
                akmSurplusDef: totalAkmSurplusDef,
                surplusDefBln: totalBlnSurplusDef,
                saldoAwal: totalSaldoAwal,
                totalAktiva: totalAktiva,
                totalKewajiban: totalKewajiban,
              );
            },
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

// Widget _buildTableHeader(String text) {
//   return Padding(
//     padding: const EdgeInsets.all(8.0),
//     child: Text(
//       text,
//       style: const TextStyle(fontWeight: FontWeight.bold),
//       textAlign: TextAlign.center,
//     ),
//   );
// }

// Widget _buildTableCell(String? text,
//     {bool alignRight = false, bool bold = false, Color? color}) {
//   return Container(
//     color: color,
//     padding: const EdgeInsets.all(8.0),
//     child: Text(
//       text ?? '',
//       textAlign: alignRight ? TextAlign.right : TextAlign.left,
//       style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
//     ),
//   );
// }

String _formatCurrency(dynamic value) {
  if (value == null) return "Rp 0";
  String strValue = value.toString().replaceAll('.', '');
  final number = double.tryParse(strValue) ?? 0;

  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  return formatter.format(number);
}

Widget buildRingkasanKeuangan({
  required double pendapatan,
  required double pengeluaran,
  required double hasilAkhir,
  required String title,
  required String numberMonth,
  required String month,
  required String year,
  required double kasTunai,
  required double kasBank,
  required double piutang,
  required double piutangLainnya,
  required double aset,
  required double totalAktiva,
  required double totalKewajiban,
  required double saldoAwal,
  required double utangRT,
  required double utangBank,
  required double blnSurplusDef,
  required double iuranDimuka,
  required String tahunLalu,
  required double totalAktivaTahunLalu,
  required double totalKewajibanTahunLalu,
  required void Function(String type) onTapItem,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double maxCardWidth =
          constraints.maxWidth > 1000 ? 900 : constraints.maxWidth * 0.95;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.green.shade100),
            ),
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
           
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    neracaHeader('AKTIVA', 'KEWAJIBAN'),
                    neracaSubHeader('AKTIVA LANCAR', 'KEWAJIBAN LANCAR'),
                    neracaRow(
                      'Kas Tunai',
                      formatRupiah(kasTunai),
                      'Utang RT',
                      formatRupiah(utangRT),
                      onLeftTitleTap: () => onTapItem('kas_tunai'),
                    ),
                    neracaRow(
                      'Kas Bank',
                      formatRupiah(kasBank),
                      'Utang Bank',
                      formatRupiah(utangBank),
                      onLeftTitleTap: () => onTapItem('kas_bank'),
                    ),
                    neracaRow(
                      '',
                      '',
                      'Iuran Warga Dibayar Dimuka',
                      formatRupiah(iuranDimuka),
                      onRightTitleTap: () => onTapItem('iuran_dimuka'),
                    ),
                    neracaSubHeader('PIUTANG', 'EKUITAS'),
                    neracaRow(
                      'Piutang Iuran Warga',
                      formatRupiah(piutang),
                      'Saldo Awal Saat Penggunaan Sistem',
                      formatRupiah(saldoAwal),
                      onLeftTitleTap: () => onTapItem('piutang'),
                    ),
                    neracaRow(
                      'Piutang Lain-lainnya',
                      formatRupiah(piutangLainnya),
                      'Modal Aset Warga',
                      formatRupiah(aset),
                      onLeftTitleTap: () => onTapItem('piutang_lainnya'),
                      onRightTitleTap: () => onTapItem('aset'),
                    ),
                    neracaRow(
                      '',
                      '',
                      'Akumulasi Surplus Defisit',
                      formatRupiah(hasilAkhir - blnSurplusDef),
                      onRightTitleTap: () =>
                          onTapItem('akm_surplus_defisit'),
                    ),
                    neracaRow(
                      '',
                      '',
                      'Surplus Defisit Bulan Berjalan',
                      formatRupiah(blnSurplusDef),
                      onRightTitleTap: () =>
                          onTapItem('akm_surplus_defisit_bln'),
                    ),
                    neracaSubHeader('AKTIVA TIDAK LANCAR', null),
                    neracaRow(
                      'Aset Warga',
                      formatRupiah(aset),
                      '',
                      '',
                      onLeftTitleTap: () => onTapItem('aset'),
                    ),
                    neracaDivider(),
                    // neracaTotal(
                    //   'TOTAL TAHUN $tahunLalu ',
                    //   formatRupiah(totalAktivaTahunLalu),
                    //   'TOTAL TAHUN $tahunLalu',
                    //   formatRupiah(totalKewajibanTahunLalu),
                    // ),
                    neracaTotal(
                      'TOTAL ASET',
                      formatRupiah(totalAktiva),
                      'TOTAL KEWAJIBAN',
                      formatRupiah(totalKewajiban),
                    ),
                  ],
                ),
              ),
            
          ),
        ),
      );
    },
  );
}

// Widget buildRingkasanKeuangan({
//   required double pendapatan,
//   required double pengeluaran,
//   required double hasilAkhir,
//   required String title,
//   required String numberMonth,
//   required String month,
//   required String year,
//   required double kasTunai,
//   required double kasBank,
//   required double piutang,
//   required double piutangLainnya,
//   required double aset,
//   required double totalAktiva,
//   required double totalKewajiban,
//   required double saldoAwal,
//   required double utangRT,
//   required double utangBank,
//   required double blnSurplusDef,
//   required double iuranDimuka,
//   required void Function(String type) onTapItem,
// }) {
//   return LayoutBuilder(
//     builder: (context, constraints) {
//       double maxCardWidth =
//           constraints.maxWidth > 1000 ? 900 : constraints.maxWidth * 0.95;

//       return Center(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: maxCardWidth),
//           child: Card(
//             elevation: 6,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//               side: BorderSide(color: Colors.green.shade100),
//             ),
//             margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Center(
//                     child: Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   neracaHeader('AKTIVA', 'KEWAJIBAN'),
//                   neracaSubHeader('AKTIVA LANCAR', 'KEWAJIBAN LANCAR'),
//                   neracaRow(
//                     'Kas Tunai', formatRupiah(kasTunai), 'Utang RT',
//                     formatRupiah(utangRT),
//                     onLeftTitleTap: () {
//                       onTapItem('kas_tunai');
//                     },
//                     //Buat UTANG
//                     // onRightTitleTap: () {
//                     //   Navigator.pushReplacement(
//                     //     context,
//                     //     MaterialPageRoute(
//                     //       builder: (context) => const DetailUtangRTPage(),
//                     //     ),
//                     //   );
//                     // },
//                   ),
//                   neracaRow(
//                     'Kas Bank', formatRupiah(kasBank), 'Utang Bank',
//                     formatRupiah(utangBank),
//                     onLeftTitleTap: () {
//                       onTapItem('kas_bank');
//                     },
//                     //Buat UTANG
//                     // onRightTitleTap: () {
//                     //   Navigator.pushReplacement(
//                     //     context,
//                     //     MaterialPageRoute(
//                     //       builder: (context) => const DetailUtangRTPage(),
//                     //     ),
//                     //   );
//                     // },
//                   ),
//                   neracaRow(
//                     '',
//                     '',
//                     'Iuran Warga Dibayar Dimuka',
//                     formatRupiah(iuranDimuka),
//                     onRightTitleTap: () {
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const HistoriTransaksiPage(),
//                         ),
//                       );
//                     },
//                   ),
//                   neracaSubHeader('PIUTANG', 'EKUITAS'),
//                   neracaRow(
//                     'Piutang Iuran Warga',
//                     formatRupiah(piutang),
//                     'Saldo Awal Saat Penggunaan Sistem',
//                     formatRupiah(saldoAwal),
//                     onLeftTitleTap: () {
//                       onTapItem('piutang');
//                     },
//                     //Buat UTANG
//                     // onRightTitleTap: () {
//                     //   Navigator.pushReplacement(
//                     //     context,
//                     //     MaterialPageRoute(
//                     //       builder: (context) => const DetailUtangRTPage(),
//                     //     ),
//                     //   );
//                     // },
//                   ),
//                   neracaRow(
//                     'Piutang Lain-lainnya',
//                     formatRupiah(piutangLainnya),
//                     'Akumulasi Surplus Defisit',
//                     formatRupiah(hasilAkhir),
//                     onLeftTitleTap: () {
//                       onTapItem('piutang_lainnya');
//                     },
//                      onRightTitleTap: () {
//                       onTapItem('akm_surplus_defisit');
//                     },
//                   ),
//                   neracaRow(
//                     '',
//                     '',
//                     'Surplus Defisit Bulan Berjalan',
//                     formatRupiah(blnSurplusDef),
//                     onRightTitleTap: () {
//                       onTapItem('akm_surplus_defisit_bln');
//                     },
//                   ),
//                   neracaSubHeader('ASSET', null),
//                   neracaRow(
//                     'Asset Warga',
//                     formatRupiah(aset),
//                     '',
//                     '',
//                     onLeftTitleTap: () {
//                       onTapItem('aset');
//                     },
//                   ),
//                   neracaDivider(),
//                   neracaTotal('TOTAL', formatRupiah(totalAktiva), 'TOTAL ',
//                       formatRupiah(totalKewajiban)),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }

Widget neracaHeader(String left, String right) {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Row(
      children: [
        Expanded(
          flex: 8,
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(flex: 4, child: Container()),
        const SizedBox(width: 16),
        Expanded(
          flex: 8,
          child: Text(
            right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(flex: 4, child: Container()),
      ],
    ),
  );
}

Widget neracaSubHeader(String left, String? right) {
  return Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Row(
      children: [
        Expanded(
          flex: 8,
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(flex: 4, child: SizedBox()),
        const SizedBox(width: 16),
        Expanded(
          flex: 8,
          child: right == null || right.isEmpty
              ? const SizedBox()
              : Text(
                  right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const Expanded(flex: 4, child: SizedBox()),
      ],
    ),
  );
}

Widget neracaRow(
  String leftTitle,
  dynamic leftValue,
  String rightTitle,
  dynamic rightValue, {
  VoidCallback? onLeftTitleTap,
  VoidCallback? onLeftValueTap,
  VoidCallback? onRightTitleTap,
  VoidCallback? onRightValueTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================= KIRI - JUDUL =================
        Expanded(
          flex: 10,
          child: leftTitle.isEmpty
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: InkWell(
                    onTap: onLeftTitleTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        leftTitle,
                        softWrap: true,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
        ),

        // ================= KIRI - NILAI =================
        Expanded(
          flex: 4,
          child: leftValue == null || leftValue == ''
              ? const SizedBox()
              : InkWell(
                  onTap: onLeftValueTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      leftValue.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
        ),

        const SizedBox(width: 24),

        // ================= KANAN - JUDUL =================
        Expanded(
          flex: 10,
          child: rightTitle.isEmpty
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: InkWell(
                    onTap: onRightTitleTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        rightTitle,
                        softWrap: true,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
        ),

        // ================= KANAN - NILAI =================
        Expanded(
          flex: 4,
          child: rightValue == null || rightValue == ''
              ? const SizedBox()
              : InkWell(
                  onTap: onRightValueTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      formatRupiah(rightValue),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

Widget neracaDivider() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(
      color: Colors.grey.shade400,
      thickness: 0.6,
    ),
  );
}

Widget neracaTotal(
  String leftTitle,
  dynamic leftValue,
  String rightTitle,
  dynamic rightValue,
) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          flex: 8,
          child: Text(
            leftTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            formatRupiah(leftValue),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 8,
          child: Text(
            rightTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            formatRupiah(rightValue),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTableHeader(String text) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
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

Widget buildRingkasanKeuanganSurDef(
    {required double pendapatan,
    required double pengeluaran,
    required double hasilAkhir,
    required String title,
    required String numberMonth,
    required String month,
    required String year}) {
  bool isDefisit = hasilAkhir < 0;

  return LayoutBuilder(
    builder: (context, constraints) {
      double maxCardWidth =
          constraints.maxWidth > 600 ? 500 : constraints.maxWidth * 0.9;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.green.shade100),
            ),
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildCustomRow(
                    'Pendapatan',
                    '',
                    _formatCurrency(pendapatan),
                    onTitleTap: () {},
                  ),
                  _buildCustomRow(
                    'Pengeluaran',
                    _formatCurrency(pengeluaran),
                    '',
                    onTitleTap: () {},
                  ),
                  const Divider(thickness: 1.5, color: Colors.grey),
                  _buildCustomRow(
                    isDefisit ? 'Defisit' : 'Surplus',
                    '',
                    _formatCurrency(hasilAkhir),
                    isDefisit: isDefisit,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildCustomRow(
  String title,
  dynamic leftValue,
  dynamic rightValue, {
  bool isDefisit = false,
  VoidCallback? onTitleTap,
}) {
  String formatValue(dynamic val) {
    if (val == '' || val == null) return '';
    if (val is double) return "Rp ${val.toStringAsFixed(0)}";
    return val.toString();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: (title == 'Surplus' || title == 'Defisit')
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isDefisit ? Colors.red : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatValue(leftValue),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDefisit ? Colors.red : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatValue(rightValue),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: (title == 'Surplus' || title == 'Defisit')
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isDefisit ? Colors.red : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildRingkasanKeuanganMobile({
  required double pendapatan,
  required double pengeluaran,
  required double hasilAkhir,
  required String title,
  required String numberMonth,
  required String month,
  required String year,
  required double kasTunai,
  required double kasBank,
  required double piutang,
  required double piutangLainnya,
  required double aset,
  required double totalAktiva,
  required double totalKewajiban,
  required double saldoAwal,
  required double utangRT,
  required double utangBank,
  required double blnSurplusDef,
  required double iuranDimuka,
  required String tahunLalu,
  required double totalAktivaTahunLalu,
  required double totalKewajibanTahunLalu,
  required void Function(String type) onTapItem,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Judul & Periode
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            // --- SEKSI RINGKASAN KAS (PENDAPATAN & PENGELUARAN) ---
            //_buildQuickSummaryCard(pendapatan, pengeluaran, hasilAkhir),
            const SizedBox(height: 20),

            // --- SEKSI AKTIVA ---
            _mobileHeader("AKTIVA"),
            _mobileSubHeader("AKTIVA LANCAR"),
            _mobileRow("Kas Tunai", kasTunai, () => onTapItem('kas_tunai')),
            _mobileRow("Kas Bank", kasBank, () => onTapItem('kas_bank')),

            _mobileSubHeader("PIUTANG"),
            _mobileRow(
                "Piutang Iuran Warga", piutang, () => onTapItem('piutang')),
            _mobileRow("Piutang Lainnya", piutangLainnya,
                () => onTapItem('piutang_lainnya')),

            _mobileSubHeader("AKTIVA TIDAK LANCAR"),
            _mobileRow("Aset Warga", aset, () => onTapItem('aset')),

            _mobileTotal("TOTAL ASET $year", totalAktiva),
            // _mobileTotal("TOTAL ASET $tahunLalu", totalAktivaTahunLalu),

            const Divider(height: 32, thickness: 1.5),

            // --- SEKSI KEWAJIBAN & EKUITAS ---
            _mobileHeader("KEWAJIBAN & EKUITAS"),
            _mobileSubHeader("KEWAJIBAN LANCAR"),
            _mobileRow("Utang RT", utangRT, () => onTapItem('utang_rt')),
            _mobileRow("Utang Bank", utangBank, () => onTapItem('utang_bank')),
            _mobileRow("Iuran Dibayar Dimuka", iuranDimuka,
                () => onTapItem('iuran_dimuka')),

            _mobileSubHeader("EKUITAS"),
            _mobileRow(
                "Saldo Awal Sistem", saldoAwal, () => onTapItem('saldo_awal')),
            _mobileRow("Modal Aset Warga", aset, () => onTapItem('aset')),
            _mobileRow(
                "Akumulasi Surplus/Defisit",
                (hasilAkhir - blnSurplusDef),
                () => onTapItem('akm_surplus_defisit')),
            _mobileRow("Surplus/Defisit Berjalan", blnSurplusDef,
                () => onTapItem('akm_surplus_defisit_bln')),

            _mobileTotal("TOTAL KEWAJIBAN $year", totalKewajiban),
            // _mobileTotal("TOTAL KEWAJIBAN $tahunLalu", totalKewajibanTahunLalu),
           
          ],
        ),
      ),
    ),
  );
}






// Helper UI lainnya (Header, SubHeader, Row) tetap sama seperti sebelumnya...
Widget _mobileHeader(String title) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10, bottom: 5),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    child: Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
  );
}

Widget _mobileSubHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 5),
    child: Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
  );
}

Widget _mobileRow(String label, double value, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Text(formatRupiah(value),
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

Widget _mobileTotal(String label, double value) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(formatRupiah(value),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
      ],
    ),
  );
}
