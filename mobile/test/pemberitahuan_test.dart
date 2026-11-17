import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/komponen_ui.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Backend palsu menyiapkan satu pemberitahuan belum dibaca untuk tiap peran.
Future<void> _masuk(WidgetTester tester, String email, {String? peran}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final storage = MemoryTokenStorage();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'http://mock/api/v1',
            tokenStorage: storage,
            adapter: MockBackend(),
          ),
        ),
      ],
      child: const AplikasiBankSampah(),
    ),
  );
  await tester.pumpAndSettle();
  if (peran != null) {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmenReferensi<bool>),
        matching: find.text('Bank Sampah'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(peran));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password',
  );
  final masuk = find.widgetWithText(FilledButton, 'Masuk');
  await tester.ensureVisible(masuk);
  await tester.tap(masuk);
  await tester.pumpAndSettle();
}

Future<void> _ketuk(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  // Backend palsu menjawab setelah 250 ms; beri waktu untuk permintaan berurutan
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'warga membuka pemberitahuan jemput dan diarahkan ke daftar penjemputan',
    (tester) async {
      await _masuk(tester, 'warga@demo.id');

      expect(find.byTooltip('Pemberitahuan, 1 belum dibaca'), findsOneWidget);
      await _ketuk(tester, find.byTooltip('Pemberitahuan, 1 belum dibaca'));

      expect(find.text('Pemberitahuan'), findsOneWidget);
      expect(find.text('Penjemputan dijadwalkan'), findsOneWidget);
      expect(find.text('Setoran tercatat'), findsOneWidget);

      await _ketuk(tester, find.text('Penjemputan dijadwalkan'));
      expect(find.text('Penjemputan'), findsWidgets);
      expect(
        find.byTooltip('Pemberitahuan'),
        findsNothing,
        reason: 'beranda tidak lagi tampil',
      );
    },
  );

  testWidgets('angka lonceng hilang setelah pemberitahuan dibaca', (
    tester,
  ) async {
    await _masuk(tester, 'warga@demo.id');

    await _ketuk(tester, find.byTooltip('Pemberitahuan, 1 belum dibaca'));
    await _ketuk(tester, find.byTooltip('Tandai semua dibaca'));
    await _ketuk(tester, find.byType(BackButton));

    expect(find.byTooltip('Pemberitahuan'), findsOneWidget);
    expect(find.byTooltip('Pemberitahuan, 1 belum dibaca'), findsNothing);
  });

  testWidgets('pengelola melihat permintaan jemput baru dari lonceng', (
    tester,
  ) async {
    await _masuk(tester, 'operator@demo.id', peran: 'Pengelola');

    await _ketuk(tester, find.byTooltip('Pemberitahuan, 1 belum dibaca'));
    expect(find.text('Permintaan jemput baru'), findsOneWidget);
    await _ketuk(tester, find.text('Permintaan jemput baru'));

    expect(find.byTooltip('Pemberitahuan'), findsOneWidget);
  });

  testWidgets('bentor menerima kabar tugas baru', (tester) async {
    await _masuk(tester, 'bentor@demo.id', peran: 'Bentor');

    await _ketuk(tester, find.byTooltip('Pemberitahuan, 1 belum dibaca'));
    expect(find.text('Tugas jemput baru'), findsOneWidget);
    await _ketuk(tester, find.text('Tugas jemput baru'));

    expect(find.text('Tugas aktif'), findsOneWidget);
    expect(find.byTooltip('Pemberitahuan'), findsOneWidget);
  });
}
