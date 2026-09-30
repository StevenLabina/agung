import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iuran_rt_web/drawer.dart';

class PetunjukPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        backgroundColor: Color(0xFFFDECE8),
        elevation: 0,
      ),
      drawer: MyDrawer(currentPage: 'PetunjukPage',),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Container(
            width: 567,
            height: 102,
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/images/SealQuestion.svg'),
                const SizedBox(width: 20),
                Text(
                  'Petunjuk',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xFF181C14),
                    fontSize: 40,
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w600,
                    height: 0,
                  ),
                ),
              ],
            ),
          ),
          _buildStepCard(
            'Buat Pengumuman Atau Informasi Untuk Warga',
            'Digunakan untuk membuat iuran baru. Anda dapat mengatur kategori iuran, nominal, dan periode pembayaran yang dibutuhkan.',
             Icon(
                    Icons.info,
                    color: Color(0xFF3D8D7A),
                    size: 40,
                  ),
          ),
          _buildStepCard(
            'Buat Tagihan Iuran Untuk Warga',
            'Digunakan untuk mendaftarkan data warga baru. Pastikan mengisi informasi warga dengan lengkap dan akurat.',
             SvgPicture.asset('assets/images/HandCoins.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
          _buildStepCard(
            'Buat Rincian Isi Data Warga',
            'Digunakan untuk melihat dan memantau rekap pembayaran iuran warga secara online, termasuk riwayat dan status pembayaran.',
             SvgPicture.asset('assets/images/UserPlus.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
          _buildStepCard(
            'Data Warga',
            'Digunakan untuk melihat dan mengelola seluruh data warga yang telah terdaftar dalam sistem.',
           SvgPicture.asset('assets/images/UsersFour.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
          _buildStepCard(
            'Laporan Iuran Tunai Warga',
            'Digunakan untuk melihat riwayat bayar iuran berdasarkan tanggal bayar dan penghuni\n',
            SvgPicture.asset( 'assets/images/Receipt.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
          _buildStepCard(
            'Laporan Transaksi Iuran Warga',
            'Digunakan untuk melihat seluruh riwayat bayar iuran berdasarkan tanggal bayar dan penghuni\n',
            SvgPicture.asset('assets/images/Lifebuoy.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
           _buildStepCard(
            'Laporan Revisi Perubahan Data Warga',
            'Digunakan untuk melihat laporan revisi perubahan data warga yang telah dilakukan oleh warga\n',
            SvgPicture.asset('assets/images/Lifebuoy.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
            _buildStepCard(
            'Rekap Iuran Warga Yang Belum Lunas',
            'Digunakan untuk melihat rekap iuran warga yang belum lunas\n',
            SvgPicture.asset('assets/images/Lifebuoy.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
           _buildStepCard(
            'Rekap Iuran Warga Yang Sudah Lunas',
            'Digunakan untuk melihat rekap iuran warga yang sudah lunas\n', 
            SvgPicture.asset('assets/images/Lifebuoy.svg',
            color: Color(0xFF3D8D7A),
            width: 40,
            height: 40,),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String title, String description, Widget icon) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            icon,
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
