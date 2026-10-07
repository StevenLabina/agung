import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CRM OCR KTP Response Parsing & Handling Test', () {
    test('Parse successful response from crm.apikkedu.com/api/ocr/ktp', () {
      const responseBody = '''
      {
        "success": true,
        "message": "KTP berhasil dipindai.",
        "data": {
          "nik": "3574020207050001",
          "nama": "BENEDICTUS LEONARDO EDWARD",
          "alamat": "JL MASTRIP, RT 004/001, KEL. WONOASIH, KEC. WONOASIH",
          "no_kavling": "",
          "jenis_kelamin": "Laki-laki",
          "tanggal_lahir": "2005-07-02",
          "kewarganegaraan": "IDN",
          "pekerjaan": "PELAJAR/MAHASISWA",
          "berlaku_hingga": "SEUMUR HIDUP",
          "metadata": {
            "confidence": 100,
            "execution_time_seconds": 15.75,
            "method_used": "PP-OCRv6 + sharpen"
          }
        }
      }
      ''';

      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      expect(json['success'], isTrue);
      expect(json['message'], equals('KTP berhasil dipindai.'));

      final data = json['data'] as Map<String, dynamic>;
      expect(data['nik'], equals('3574020207050001'));
      expect(data['nama'], equals('BENEDICTUS LEONARDO EDWARD'));
      expect(data['alamat'], equals('JL MASTRIP, RT 004/001, KEL. WONOASIH, KEC. WONOASIH'));
      expect(data['jenis_kelamin'], equals('Laki-laki'));
      expect(data['tanggal_lahir'], equals('2005-07-02'));
      expect(data['kewarganegaraan'], equals('IDN'));
      expect(data['pekerjaan'], equals('PELAJAR/MAHASISWA'));
      expect(data['berlaku_hingga'], equals('SEUMUR HIDUP'));

      final metadata = data['metadata'] as Map<String, dynamic>;
      expect(metadata['confidence'], equals(100));
      expect(metadata['execution_time_seconds'], equals(15.75));
      expect(metadata['method_used'], equals('PP-OCRv6 + sharpen'));
    });

    test('NIK digits-only sanitization', () {
      const rawNik = '3574-0202-0705-0001';
      final cleanNik = rawNik.replaceAll(RegExp(r'\D'), '');
      expect(cleanNik, equals('3574020207050001'));
      expect(cleanNik.length, equals(16));
    });

    test('Parse error response from CRM endpoint (HTTP 401 & 422)', () {
      const unauthorizedBody = '{"status":false,"message":"Unauthorized: Invalid or missing API Key."}';
      final unauthJson = jsonDecode(unauthorizedBody) as Map<String, dynamic>;
      expect(unauthJson['status'], isFalse);
      expect(unauthJson['message'], contains('Unauthorized'));

      const validationBody = '{"success":false,"message":"Foto KTP wajib diunggah (field: image atau foto_ktp)."}';
      final valJson = jsonDecode(validationBody) as Map<String, dynamic>;
      expect(valJson['success'], isFalse);
      expect(valJson['message'], contains('Foto KTP wajib diunggah'));
    });
  });
}
