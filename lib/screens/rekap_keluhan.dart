import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iuran_rt_web/menu_pilihan.dart';
import 'package:iuran_rt_web/url.dart';

class RekapKeluhanPage extends StatefulWidget {
  @override
  _RekapKeluhanPageState createState() => _RekapKeluhanPageState();
}

class _RekapKeluhanPageState extends State<RekapKeluhanPage> {
  List<dynamic> _keluhanData = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
  final TextEditingController _1tanggalController = TextEditingController();
  final TextEditingController _2tanggalController = TextEditingController();
  DateTime? _selectedDate1;
  DateTime? _selectedDate2;
  bool showFilter = false;
  String? noKavling;
  @override
  void initState() {
    super.initState();
    fetchKeluhanData();
  }

  Future<void> fetchKeluhanData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      print("Tanggal 1 (sebelum dikirim): ${_1tanggalController.text}");
      print("Tanggal 2 (sebelum dikirim): ${_2tanggalController.text}");

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}histori_keluhan.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'selectedDate1': _1tanggalController.text,
          'selectedDate2': _2tanggalController.text,
          'id_rt': KodeRt.kodeRt
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['result'] == 'success') {
          setState(() {
            _keluhanData = result['data'];
          });
          print("Data ditemukan: ${result['data']}");
        } else {
          setState(() {
            _keluhanData = [];
            errorMessage = 'Data tidak ditemukan';
          });
        }
      } else {
        setState(() {
          errorMessage =
              'Gagal mengambil data dari server (Kode: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate1(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate1 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate1 = pickedDate;
        _selectedDate2 = _selectedDate1!.add(Duration(days: 7));

        _1tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate1!);
        _2tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate2!);
      });
    }
  }

  Future<void> _selectDate2(BuildContext context) async {
    // Pilih Tanggal
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate2 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate2 = pickedDate;
        _selectedDate1 = _selectedDate2!.subtract(Duration(days: 7));

        _2tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate2!);
        _1tanggalController.text =
            DateFormat('yyyy-MM-dd-00:00').format(_selectedDate1!);
      });
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
                                                 MenuPilihanPage(idMenu: 2,),
                                        ),
                                        )
                          }
                      ),
                      Text(
                        'Rekap Keluhan/Saran Warga',
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

          SizedBox(height: 10),

          Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: Icon(
                    showFilter ? Icons.filter_alt_off : Icons.filter_alt,
                    color: const Color(0xFF3D8D7A),
                    size: 18,
                  ),
                  label: Text(
                    showFilter ? "Sembunyikan Filter" : "Tampilkan Filter",
                    style: const TextStyle(
                      color: Color(0xFF3D8D7A),
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      showFilter = !showFilter;
                    });
                  },
                ),
              ),
            ],
          ),
           SizedBox(height: 10),
          if (showFilter)
            Align(
              alignment: Alignment.center,
              child:  Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar
                  Container(
                    width: 300,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Filter berdasarkan tanggal",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        TextField(
                          controller: _1tanggalController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            labelText: "Dari Tanggal",
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate1(context),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _2tanggalController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            labelText: "Sampai Tanggal",
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate2(context),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3D8D7A),
                            minimumSize: Size(double.infinity, 48),
                          ),
                          onPressed: fetchKeluhanData,
                          child: Text(
                            'Tampilkan',
                            style: GoogleFonts.lato(
                                color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

               
                ],
              ),
            ) ,
            ),
           
          SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                      ? Center(child: Text(errorMessage))
                      : ListView.builder(
                          itemCount: _keluhanData.length,
                          itemBuilder: (context, index) {
                            var keluhan = _keluhanData[index];
                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 10),
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Tanggal Keluhan: ${keluhan['r_tanggal_keluhan'] ?? ''}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 10),
                                    keluhan['r_gambar_keluhan'] != null &&
                                            keluhan['r_gambar_keluhan']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(
                                            "${ApiUrls.baseUrl}${keluhan['r_gambar_keluhan']}",
                                            height: 150,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Text(
                                                  "Gagal memuat gambar");
                                            },
                                          )
                                        : Text("Tidak ada gambar"),
                                    SizedBox(height: 10),
                                    Text(
                                        "No Kavling: ${keluhan['r_identitas'] ?? 'Tanpa Nama'}"),
                                    SizedBox(height: 10),
                                    Text("Masukan/Keluhan Warga:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Text(
                                        keluhan['r_keluhan'] ?? '',
                                        style: TextStyle(color: Colors.black87),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text("Tanggapan Pengurus RT:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Text(
                                        keluhan['r_jawaban']?.isNotEmpty == true
                                            ? keluhan['r_jawaban']!
                                            : '-',
                                        style: TextStyle(color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
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
          // Header
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
                                                 MenuPilihanPage(idMenu: 2,),
                                        ),
                                        )
                          }
                      ),
                      Text(
                        'Rekap Keluhan/Saran Warga',
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

          SizedBox(height: 10),

         Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1400,
                  ),
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// FILTER CARD
                          SizedBox(
                            width: 320,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                 Text("Filter berdasarkan tanggal",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _1tanggalController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          labelText: "Dari Tanggal",
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate1(context),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _2tanggalController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          labelText: "Sampai Tanggal",
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate2(context),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3D8D7A),
                          minimumSize: Size(double.infinity, 48),
                        ),
                        onPressed: fetchKeluhanData,
                        child: Text(
                          'Tampilkan',
                          style: GoogleFonts.lato(
                              color: Colors.white, fontSize: 18),
                        ),
                      ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 32),

                          /// TABLE AREA
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  /// TITLE
                                  const Text(
                                    'Rekap Keluhan/Saran Warga',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  /// TABLE
                                     Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: isLoading
                        ? Center(child: CircularProgressIndicator())
                        : errorMessage.isNotEmpty
                            ? Center(child: Text(errorMessage))
                            : ListView.builder(
                                itemCount: _keluhanData.length,
                                itemBuilder: (context, index) {
                                  var keluhan = _keluhanData[index];
                                  return Card(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 3,
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 10),
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Tanggal Keluhan: ${keluhan['r_tanggal_keluhan'] ?? ''}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 10),
                                          keluhan['r_gambar_keluhan'] != null &&
                                                  keluhan['r_gambar_keluhan']
                                                      .toString()
                                                      .isNotEmpty
                                              ? Image.network(
                                                  "${ApiUrls.baseUrl}${keluhan['r_gambar_keluhan']}",
                                                  height: 150,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Text(
                                                        "Gagal memuat gambar");
                                                  },
                                                )
                                              : Text("Tidak ada gambar"),
                                          SizedBox(height: 10),
                                          Text(
                                              "No Kavling: ${keluhan['r_identitas'] ?? 'Tanpa Nama'}"),
                                          SizedBox(height: 10),
                                          Text("Masukan/Keluhan Warga:",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(height: 5),
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey),
                                            ),
                                            child: Text(
                                              keluhan['r_keluhan'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.black87),
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Text("Tanggapan Pengurus RT:",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(height: 5),
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey),
                                            ),
                                            child: Text(
                                              keluhan['r_jawaban']
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? keluhan['r_jawaban']!
                                                  : '-',
                                              style: TextStyle(
                                                  color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),

                                  const SizedBox(height: 24),

                                  /// PAGINATION
                                 
                                ],
                              ),
                            ),
                          ),
                        ],
                      )),
                ),
              ),
            ),
        
        ],
      ),
    );
  }
}
