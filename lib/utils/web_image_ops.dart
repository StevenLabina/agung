// Pengolahan foto memakai kemampuan bawaan browser (canvas).
//
// Di web, decode/crop/resize/encode JPEG dikerjakan browser (native, cepat,
// tidak membekukan UI). Di platform lain `NativeImageOps.available == false`
// dan semua fungsi mengembalikan null, jadi pemanggil memakai jalur cadangan
// (package:image).
export 'web_image_ops_stub.dart'
    if (dart.library.html) 'web_image_ops_web.dart';
