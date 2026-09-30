class ApiUrls {
  static const String baseUrl = "https://trr08-api.rukuntetangga.net/";
  //static const String baseUrl = "http://localhost/wirausaha/";
  //static const String baseUrl = "https://de47-180-253-149-19.ngrok-free.app";
  //jalankan ngrok: ngrok http 3000
  //token: eMj5BcZjSs6qtDEhooufqS:APA91bHNASadUuqgrbuEvjs0lgqg7MLDq9xGXaBleIxD_FEefk5Ub3CfZMaHLbn0J6FmUza0VzMiaRjDFdtmeT7J05bEeII_-HWxaDEMEu4hZ-Il0J-EOvI
}
class KodeRt {
  //static  String kodeRt = "spi";
  static String kodeRt = "demo";
  static String versionApp = "1.0";
  static String get alamatRt {
    if (kodeRt == "trr") {
      return "Taman Rivera Regency";
    } else if (kodeRt == "spi") {
      return "RT 3 - RW 9 Dukuh Sutorejo";
    } 
     else if (kodeRt == "sj") {
      return "Saronojiwo";
    } else if (kodeRt == "kom") {
      return "CV TRR";
    }
    
    else {
      return "Jl Surabaya Testing";
    }
  }

  static String get alamatDetailRt {
    if (kodeRt == "trr") {
      return "Layanan Digital Terpadu Untuk Warga RT 08 RW 01\nKelurahan Medokan Ayu Rungkut";
    } else if (kodeRt == "spi") {
      return "Mulyorejo Surabaya";
    }  else if (kodeRt == "sj") {
      return "Layanan Digital Terpadu Untuk Warga RT 05 RW 03\nKelurahan Panjangjiwo";
    }else if (kodeRt == "kom") {
      return "Testing Web CV TRR";
    }else {
      return "Jl Surabaya Testing";
    }
  }

  static String get namaRt {
    if (kodeRt == "trr") {
      return "Taman Rivera Regency";
    } else if (kodeRt == "spi") {
      return "Sutorejo Prima Indah";
    }  else if (kodeRt == "sj") {
      return "Saronojiwo";
    }else if (kodeRt == "kom") {
      return "CV TRR";
    }else {
      return "Jl Surabaya Testing";
    }
  }
  static String get gambarRt{
      if (kodeRt == "trr") {
      return "assets/images/trr.png";
    } else if (kodeRt == "spi") {
      return "assets/images/SutorejoPrimaIndah.jpeg";
    } 
    else if (kodeRt == "sj") {
     return "assets/images/Saronojiwo.jpg";
    }
    else if (kodeRt == "kom") {
     return "assets/images/kom.jpg";
    }else {
      return "assets/images/trr.png";
    }
  }
 
  static String get ketentuanIPL {
       if (kodeRt == "trr") {
      return  '1. Kavling tidak dihuni: Rp120.000\n'
              '2. Blok N/O/P: Rp145.000\n'
              '3. Blok C s/d M (1 lantai): Rp170.000\n'
              '4. Blok B/H/G dan M (2 lantai): Rp195.000\n'
              '5. Blok A (Usaha UMKM/Kantor): Rp220.000\n'
              '6. Blok A (Usaha Perseroan): Rp250.000\n';
    } else if (kodeRt == "spi") {
      return  '1. Blok A: Rp130.000\n'
              '2. Blok Z: Rp150.000\n';
    } 
    else if (kodeRt == "sj") {
      return  '1. Blok A: Rp130.000\n'
              '2. Blok Z: Rp150.000\n';
    }else if (kodeRt == "kom") {
      return  '1. Blok A: Rp130.000\n'
              '2. Blok Z: Rp150.000\n';
    }else {
      return  
              '1. Blok A (Testing): Rp120.000\n'
              '2. Blok Z (Testing): Rp175.000\n';
    }
  }
   static String get accountRT {
    if (kodeRt == "trr") {
      return "6753880009";
    } else if (kodeRt == "spi") {
      return "3890667642";
    } else if (kodeRt == "sj") {
      return "1400018057696";
    } else {
      return "0882266476";
    }
  }
  static String get codeBankRT {
    if (kodeRt == "trr") {
      return "BCA";
    } else if (kodeRt == "spi") {
      return "BCA";
    } else if (kodeRt == "sj") {
      return "CENAIDJA";
    } else {
      return "BCA";
    }
  }
  static String get jenisRekening {
  if (codeBankRT == "BCA") {
    return "Bank Central Asia (BCA)";
  } else if (codeBankRT == "BMRI") {
    return "Bank Mandiri";
  } else if (codeBankRT == "BRI") {
    return "Bank Rakyat Indonesia (BRI)";
  } 
  else if (codeBankRT == "BNI") {
    return "Bank Negara Indonesia (BNI)";
  }
  else if (codeBankRT == "DNMN") {
    return "Bank Danamon Indonesia";
  }
  else if (codeBankRT == "PRMT") {
    return "Bank Permata Indonesia";
  }
  else if (codeBankRT == "MYBK") {
    return "Bank Maybank Indonesia";
  }
  else {
    return "Non Bank";
  }
}
}