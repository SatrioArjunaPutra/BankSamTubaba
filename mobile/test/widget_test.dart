import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('aplikasi tanpa sesi menampilkan formulir masuk', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ],
        child: const AplikasiBankSampah(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk sebagai'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
