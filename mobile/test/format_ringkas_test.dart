import 'package:bank_sampah_tubaba/core/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('nama bank tanpa awalan, huruf apa pun', () {
    expect(namaBankRingkas('Bank Sampah Demo Panaragan'), 'Demo Panaragan');
    expect(namaBankRingkas('BANK SAMPAH MARGO DADI'), 'MARGO DADI');
    expect(namaBankRingkas('Berkah Jaya'), 'Berkah Jaya');
    expect(namaBankRingkas('Bank Sampah'), 'Bank Sampah');
  });

  test('tahun hanya ditulis bila berbeda dari tahun ini', () {
    final kini = DateTime(2026, 11, 3);
    expect(tanggalRingkas(DateTime(2026, 10, 29, 16, 50), sekarang: kini), '29 Okt, 16.50');
    expect(tanggalRingkas(DateTime(2025, 10, 29, 16, 50), sekarang: kini), '29 Okt 2025');
    expect(tanggalRingkas(null), '-');
  });
}
