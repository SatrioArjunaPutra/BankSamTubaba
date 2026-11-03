import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _angka = NumberFormat.decimalPattern('id_ID');

String rupiah(num? n) => _rupiah.format(n ?? 0);

String kg(num? n) => '${_angka.format(n ?? 0)} kg';

String angka(num? n) => _angka.format(n ?? 0);

final _jarak = NumberFormat('#,##0.0', 'id_ID');

/// "1,7 km"
String jarakKm(num n) => '${_jarak.format(n)} km';

/// "28 Okt 2026, 14.30"
String tanggalJam(DateTime? t) => t == null ? '-' : DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(t.toLocal());

/// "28 Okt, 14.30"; tahun hanya ditulis bila berbeda dari tahun ini.
String tanggalRingkas(DateTime? t, {DateTime? sekarang}) {
  if (t == null) return '-';
  final lokal = t.toLocal();
  final tahunIni = (sekarang ?? DateTime.now()).toLocal().year == lokal.year;
  return DateFormat(tahunIni ? 'd MMM, HH.mm' : 'd MMM yyyy', 'id_ID').format(lokal);
}

/// Nama bank tanpa awalan "Bank Sampah", untuk baris yang sempit.
String namaBankRingkas(String nama) {
  final ringkas = nama.replaceFirst(RegExp(r'^bank\s+sampah\s+', caseSensitive: false), '').trim();
  return ringkas.isEmpty ? nama : ringkas;
}

/// "28 Okt 2026"
String tanggal(DateTime? t) => t == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(t.toLocal());

/// "Hari ini", "Kemarin", "5 hari lalu", "2 minggu lalu"; sebulan lebih memakai tanggal.
String waktuLalu(DateTime? t, {DateTime? sekarang}) {
  if (t == null) return '-';
  final kini = (sekarang ?? DateTime.now()).toLocal();
  final lokal = t.toLocal();
  final selisih = DateTime(kini.year, kini.month, kini.day)
      .difference(DateTime(lokal.year, lokal.month, lokal.day))
      .inDays;
  if (selisih <= 0) return 'Hari ini';
  if (selisih == 1) return 'Kemarin';
  if (selisih < 7) return '$selisih hari lalu';
  if (selisih < 30) return '${selisih ~/ 7} minggu lalu';
  return tanggal(t);
}

/// Angka dari JSON (number) → double, aman untuk null/int.
double keDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

double? keDoubleAtauNull(Object? v) => v == null ? null : keDouble(v);

DateTime? keTanggal(Object? v) => v is String ? DateTime.tryParse(v) : null;
