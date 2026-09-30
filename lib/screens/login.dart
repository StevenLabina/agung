import 'dart:async';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iuran_rt_web/screens/log_akses_perumahan.dart';

import 'package:iuran_rt_web/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iuran_rt_web/main.dart';
import 'package:flutter/services.dart';

class MyLogin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RT Digital-Pengurus RT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Login(),
    );
  }
}

class Login extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String username = '';
  String password = '';
  String errorLogin = '';
  int currentYear = DateTime.now().year;
  bool _loading = false;
  Map<String, bool> isDisabled = {};
  List<dynamic> _keluhanData = [];
 Timer? _logoutTimer;
  bool isLoading = true;
  String errorMessage = '';
  Map<String, TextEditingController> jawabanControllers = {};
  final TextEditingController _noKavlingController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool obscureText = true;
  @override
  void initState() {
    super.initState();
    fetchKeluhanData();
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
 Future<void> doLogin() async {
  setState(() {
    _loading = true;
  });

  try {
    print(
      'Attempting login with username: $username and password: $password',
    );

    final response = await http.post(
      Uri.parse("${ApiUrls.baseUrl}/login.php"),
      body: {
        'no_kavling': username,
        'password': password,
        'id_rt': KodeRt.kodeRt,
      },
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      Map<String, dynamic> json = jsonDecode(response.body);

      if (json['result'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final data = json['data'];

        // ==========================================
        // DATA USER
        // ==========================================

        String noKavling =
            data['no_kavling']?.toString() ?? '';

        String alamatKavling =
            data['alamat_kavling']?.toString() ?? '';

        String username =
            data['nama_pemilik_rumah']?.toString() ?? '';

        String noTelpon =
            data['no_telpon_pemilik_rumah']?.toString() ??
            data['no_telpon_penanggung_jawab']?.toString() ??
            '';

        int idUser =
            int.tryParse(data['id']?.toString() ?? '0') ?? 0;

        bool isAdmin =
            int.tryParse(
                  data['pengurus_rt']?.toString() ?? '0',
                ) ==
                1;

        // ==========================================
        // AMBIL JWT
        // ==========================================

        String token =
            json['token']?.toString() ?? '';

        if (token.isEmpty) {
          print('❌ Token JWT tidak ditemukan');

          setState(() {
            errorLogin = "Token login tidak ditemukan.";
          });

          return;
        }

        // ==========================================
        // SIMPAN DATA USER
        // ==========================================

        await prefs.setString(
          "noKavling",
          noKavling,
        );

        await prefs.setString(
          "alamatKavling",
          alamatKavling,
        );

        await prefs.setString(
          "username",
          username,
        );

        await prefs.setString(
          "noTelpon",
          noTelpon,
        );

        await prefs.setInt(
          "idUser",
          idUser,
        );

        await prefs.setBool(
          "isAdmin",
          isAdmin,
        );

        // ==========================================
        // SIMPAN JWT TOKEN
        // ==========================================

        await prefs.setString(
          "jwt_token",
          token,
        );

        print("=================================");
        print("✅ LOGIN BERHASIL");
        print("Username  : $username");
        print("No Kavling: $noKavling");
        print("ID User   : $idUser");
        print("Admin     : $isAdmin");
        print("JWT       : Tersimpan");
        print("Expired   : 10 menit");
        print("=================================");

        _loadDisabledState();

        // ==========================================
        // ADMIN
        // ==========================================

        if (isAdmin) {
          // Mulai timer 10 menit
          startAutoLogout();

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(
                keluhanData: _keluhanData,
              ),
            ),
          );

          await tambahLogAktivitas(
            aktivitas:
                "Login sistem RT Digital sebagai admin",
          );
        } else {
          setState(() {
            errorLogin =
                "Anda tidak memiliki akses untuk masuk layanan ini.";
          });
        }
      } else {
        setState(() {
          errorLogin =
              "Alamat kavling atau kata sandi anda tidak sesuai";
        });
      }
    } else {
      throw Exception(
        'Failed to read API: ${response.statusCode}',
      );
    }
  } catch (e) {
    print('Error: $e');

    if (!mounted) return;

    setState(() {
      errorLogin = "Failed to connect to server";
    });
  } finally {
    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }
}
 Future<void> logout() async {
  _logoutTimer?.cancel();
  _logoutTimer = null;

  final prefs = await SharedPreferences.getInstance();

  await prefs.clear();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => MyLogin(),
    ),
    (route) => false,
  );
}
void startAutoLogout() {
  _logoutTimer?.cancel();

  _logoutTimer = Timer(
    const Duration(minutes: 240),
    () async {
     

      await logout();
    },
  );

  
}
  Future<void> fetchKeluhanData() async {
    final idRt = KodeRt.kodeRt;
    try {
      final response = await http.post(
        Uri.parse("${ApiUrls.baseUrl}listKeluhan_admin.php"),
        body: {
          'id_rt': idRt,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] == 'success') {
          setState(() {
            _keluhanData = json['data'];
            isLoading = false;

            print("Data keluhan yang diterima: $_keluhanData");

            for (var keluhan in _keluhanData) {
              String idStr = keluhan['id'].toString();
              print("DEBUG: Menambahkan ID Keluhan: $idStr");
              jawabanControllers[idStr] = TextEditingController();
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  void _loadDisabledState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    int savedYear = prefs.getInt('savedYear') ?? currentYear;

    if (savedYear < currentYear) {
      setState(() {
        isDisabled.clear();
      });
      await prefs.setInt('savedYear', currentYear);
    } else {
      setState(() {
        isDisabled = Map<String, bool>.from(
            (prefs.getStringList('disabledMonths') ?? []).asMap().map(
                  (key, value) => MapEntry(value, true),
                ));
      });
    }
  }

  Future<Map<String, dynamic>> transferMandiri() async {
    final url = Uri.parse('${ApiUrls.baseUrl}/transfer_mandiri.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usrapi': 'steven',
          'password': 'St3v3n*_Apikk0',
          'refnum': 'HK202411020000002',
          'account': '1400018057696',
          'amount': 10000,
          'remark': 'testing',
          'transdate': '2024-12-02',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == true) {
          return {
            'status': true,
            'message': 'Transfer berhasil',
            'data': responseData,
          };
        } else {
          return {
            'status': false,
            //'message': responseData['msg'] ?? 'Terjadi kesalahan',
            'message': 'Terjadi kesalahan',
          };
        }
      } else {
        return {
          'status': false,
          'message':
              'Gagal terhubung ke server. Status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(KodeRt.gambarRt),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Semi-transparent white overlay
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  height: 580,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30.0, vertical: 30.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            child: Center(
                              child: Image.asset(
                                'assets/images/Logo2.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 597,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Selamat datang\n',
                                    style: TextStyle(
                                      color: Color(0xFF181C14),
                                      fontSize: 14,
                                      fontFamily: 'Figtree',
                                      fontWeight: FontWeight.w600,
                                      height: 0,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Pengurus RT',
                                    style: TextStyle(
                                      color: Color(0xFF181C14),
                                      fontSize: 20,
                                      fontFamily: 'Figtree',
                                      fontWeight: FontWeight.w700,
                                      height: 0,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            'Nama Pengguna (No Kavling)',
                            _noKavlingController,
                            false,
                            () {},
                          ),
                          SizedBox(height: 15),
                          _buildTextField(
                            'Kata Sandi',
                            _passwordController,
                            obscureText,
                            () {
                              setState(() {
                                obscureText = !obscureText;
                              });
                            },
                          ),
                           
                         
                    

                          SizedBox(height: 20),
                          _loading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue),
                                )
                              : ElevatedButton(
                                  onPressed: doLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3D8D7A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize:
                                        const Size(double.infinity, 60),
                                  ),
                                  child: const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontFamily: 'Figtree',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LogAksesPerumahanPage(),
                                      ),
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3D8D7A),
                              side: const BorderSide(
                                color: Color(0xFF3D8D7A),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(double.infinity, 60),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(
                              'Akses Perumahan',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Figtree',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          if (errorLogin.isNotEmpty)
                          Expanded(child:   AutoSizeText(
                                errorLogin,
                                style: TextStyle(
                                    color: Color.fromARGB(255, 255, 0, 0)),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                minFontSize: 10,
                                overflow: TextOverflow.ellipsis,
                              ),)
                         
                            
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                "© 2025 RT Digital - Admin • Version ${KodeRt.versionApp}",
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggleVisibility,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 478.45,
          child: Text(
            label,
            style: TextStyle(
              color: Color(0xFF8B8B8B),
              fontSize: 18,
              fontFamily: 'Figtree',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: 11.86),
        TextField(
          controller: controller,
          onChanged: (value) {
            setState(() {
              if (controller == _noKavlingController) {
                username = value;
              } else if (controller == _passwordController) {
                password = value;
              }
            });
          },
          obscureText: obscureText,
          inputFormatters: [
            LengthLimitingTextInputFormatter(16),
            FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9\s]+$'))
          ],
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 16.0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.47),
              borderSide: const BorderSide(
                width: 0.85,
                color: Color(0xFFBBBBBB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.47),
              borderSide: const BorderSide(
                width: 0.85,
                color: Color(0xFFBBBBBB),
              ),
            ),
            suffixIcon: controller == _passwordController
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Color(0xFF3D8D7A),
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
