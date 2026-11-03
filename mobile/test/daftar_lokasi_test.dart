import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/repositories.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/features/auth/auth_controller.dart';
import 'package:bank_sampah_tubaba/features/auth/auth_pages.dart';
import 'package:bank_sampah_tubaba/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer wadah() {
    final storage = MemoryTokenStorage();
    final c = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(baseUrl: 'http://mock/api/v1', tokenStorage: storage, adapter: MockBackend()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('pendaftaran menyimpan alamat dan titik rumah', () async {
    final c = wadah();
    await c.read(authProvider.future);

    await c.read(authProvider.notifier).register(
      name: 'Warga Baru',
      email: 'baru@demo.id',
      phone: '081234567890',
      password: 'Rahasia123',
      alamat: 'Jl. Kenanga 2',
      lat: -4.5,
      lng: 105.08,
    );

    final user = c.read(authProvider).value!;
    expect(user.alamat, 'Jl. Kenanga 2');
    expect(user.lat, -4.5);
    expect(user.lng, 105.08);
  });

  test('bank terdekat bisa dicari sebelum login dan memuat jarak', () async {
    final c = wadah();

    final hasil = await c.read(umumRepositoryProvider).bankTerdekatPublik(-4.5, 105.08);

    expect(hasil, isNotEmpty);
    expect(hasil.length, lessThanOrEqualTo(3));
    expect(hasil.first.jarakKm, isNotNull);
  });

  testWidgets('formulir daftar menolak bila alamat dan titik rumah kosong', (tester) async {
    tester.view.physicalSize = const Size(780, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final c = wadah();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: TemaAplikasi.terang(), home: const RegisterPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nama lengkap'), 'Warga Baru');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'baru@demo.id');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor HP'), '081234567890');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password (min. 8 karakter)'), 'Rahasia123');
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Alamat wajib diisi.'), findsOneWidget);
    expect(find.text('Tandai titik rumah Anda di peta.'), findsOneWidget);
    expect(find.text('Tandai titik rumah di peta'), findsOneWidget);
    expect(c.read(authProvider).value, isNull);
  });
}
