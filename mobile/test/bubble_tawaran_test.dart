import 'package:bank_sampah_tubaba/core/models/preloved.dart';
import 'package:bank_sampah_tubaba/features/preloved/chat_pages.dart';
import 'package:bank_sampah_tubaba/features/preloved/pengelola_pesan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _pasang(WidgetTester tester, PesanTampil tampil, {VoidCallback? kirimUlang}) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BubblePesan(tampil: tampil, onKirimUlang: kirimUlang))),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tawaran harga tampil sebagai bubble khusus dalam Rupiah', (tester) async {
    await _pasang(tester, PesanTampil(kunci: 's1', pesan: PesanChat(id: 1, milikSaya: false, tawaranHarga: 140000, createdAt: DateTime(2026, 10, 29, 9, 30))));

    expect(find.text('Tawaran harga'), findsOneWidget);
    expect(find.byKey(const Key('nilai-tawaran')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('nilai-tawaran'))).data, 'Rp 140.000');
    expect(find.byIcon(Icons.local_offer), findsOneWidget);

    // Bubble tawaran punya bingkai amber, berbeda dari pesan biasa
    final kotak = tester.widget<Container>(find.descendant(of: find.byType(BubblePesan), matching: find.byType(Container)).first);
    expect((kotak.decoration as BoxDecoration).border, isNotNull);
  });

  testWidgets('tawaran sendiri berlabel "Tawaran Anda" dan rata kanan', (tester) async {
    await _pasang(tester, const PesanTampil(kunci: 's2', pesan: PesanChat(id: 2, milikSaya: true, tawaranHarga: 99500)));

    expect(find.text('Tawaran Anda'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('nilai-tawaran'))).data, 'Rp 99.500');
    expect(tester.widget<Align>(find.byType(Align).first).alignment, Alignment.centerRight);
  });

  testWidgets('pesan teks biasa tanpa tampilan tawaran', (tester) async {
    await _pasang(tester, const PesanTampil(kunci: 's3', pesan: PesanChat(id: 3, milikSaya: false, isi: 'Masih ada?')));

    expect(find.text('Masih ada?'), findsOneWidget);
    expect(find.byKey(const Key('nilai-tawaran')), findsNothing);
    expect(tester.widget<Align>(find.byType(Align).first).alignment, Alignment.centerLeft);
  });

  testWidgets('kiriman gagal menampilkan tombol kirim ulang', (tester) async {
    var diulang = false;
    await _pasang(
      tester,
      const PesanTampil(kunci: 'l0', pesan: PesanChat(id: -1, milikSaya: true, tawaranHarga: 120000), status: StatusKirim.gagal),
      kirimUlang: () => diulang = true,
    );

    expect(find.text('Gagal terkirim'), findsOneWidget);
    await tester.tap(find.text('Kirim ulang'));
    expect(diulang, isTrue);
  });
}
