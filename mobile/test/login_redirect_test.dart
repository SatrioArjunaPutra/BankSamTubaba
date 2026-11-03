import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/models/user.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/router.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

User _user(Role role) =>
    User(id: 1, name: 'Uji', email: 'uji@demo.id', role: role);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('arahkan()', () {
    test('status login belum diketahui → splash', () {
      expect(arahkan(const AsyncLoading(), '/warga'), '/splash');
      expect(arahkan(const AsyncLoading(), '/splash'), isNull);
    });

    test('belum login hanya boleh login & register', () {
      expect(arahkan(const AsyncData(null), '/warga'), '/login');
      expect(arahkan(const AsyncData(null), '/splash'), '/login');
      expect(arahkan(const AsyncData(null), '/register'), isNull);
    });

    test(
      'tiap role diarahkan ke berandanya dan tidak bisa membuka rute role lain',
      () {
        final beranda = {
          Role.warga: '/warga',
          Role.bankSampah: '/bs',
          Role.bentor: '/bentor',
          Role.dlh: '/dlh',
        };

        beranda.forEach((role, rute) {
          final auth = AsyncData(_user(role));
          expect(arahkan(auth, '/login'), rute, reason: '$role setelah login');
          expect(arahkan(auth, rute), isNull);
          for (final lain in beranda.values.where((r) => r != rute)) {
            expect(
              arahkan(auth, '$lain/apa-saja'),
              rute,
              reason: '$role membuka $lain',
            );
          }
        });
      },
    );

    test('halaman akun boleh untuk semua role aplikasi, tidak untuk dlh', () {
      expect(arahkan(AsyncData(_user(Role.bentor)), '/akun/password'), isNull);
      expect(arahkan(AsyncData(_user(Role.dlh)), '/akun'), '/dlh');
    });
  });

  group('alur login lewat UI (mock backend)', () {
    Future<void> masuk(
      WidgetTester tester,
      String email, {
      String peran = 'Warga',
    }) async {
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

      expect(find.text('Masuk'), findsWidgets);
      await tester.tap(find.text(peran));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
    }

    testWidgets('warga masuk ke beranda warga', (tester) async {
      await masuk(tester, 'warga@demo.id');
      expect(find.text('Saldo tabungan'), findsOneWidget);
      expect(find.text('Preloved'), findsWidgets);
    });

    testWidgets('operator masuk ke beranda bank sampah', (tester) async {
      await masuk(tester, 'operator@demo.id', peran: 'Bank sampah');
      expect(find.text('Bank Sampah Demo Panaragan'), findsOneWidget);
      expect(find.byTooltip('Catat setoran'), findsOneWidget);
    });

    testWidgets('bentor masuk ke daftar tugas', (tester) async {
      await masuk(tester, 'bentor@demo.id', peran: 'Bentor');
      expect(find.text('Tugas aktif'), findsOneWidget);
      expect(find.text('Tugas aktif'), findsOneWidget);
    });

    testWidgets('bentor memuat ulang tugas ketika berpindah riwayat', (
      tester,
    ) async {
      await masuk(tester, 'bentor@demo.id', peran: 'Bentor');
      await tester.tap(find.byTooltip('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat penjemputan'), findsOneWidget);
      expect(find.textContaining('Belum ada tugas jemput.'), findsOneWidget);
      await tester.tap(find.byTooltip('Tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Tugas aktif'), findsOneWidget);
      expect(find.textContaining('Belum ada tugas jemput.'), findsNothing);
    });

    testWidgets('password salah tetap di login dengan pesan', (tester) async {
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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'warga@demo.id',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'salah',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email atau password salah.'), findsOneWidget);
      expect(await storage.baca(), isNull);
    });
  });
}
