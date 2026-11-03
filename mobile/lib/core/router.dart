import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/akun/akun_pages.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_pages.dart';
import '../features/bank_sampah/bs_pages.dart';
import '../features/bank_sampah/bs_shell.dart';
import '../features/bank_sampah/catat_setoran_page.dart';
import '../features/bank_sampah/peta_bank_page.dart';
import '../features/berita/berita_pages.dart';
import '../features/bentor/bentor_pages.dart';
import '../features/preloved/barang_pages.dart';
import '../features/preloved/chat_pages.dart';
import '../features/warga/warga_pages.dart';
import '../features/warga/warga_shell.dart';
import '../features/warga/donasi_page.dart';
import 'daftar_berhalaman.dart';
import 'repositories.dart';
import 'models/preloved.dart';
import 'models/transaksi.dart';
import 'models/user.dart';

/// Halaman awal tiap role.
String berandaRole(Role role) => switch (role) {
  Role.warga => '/warga',
  Role.bankSampah => '/bs',
  Role.bentor => '/bentor',
  Role.dlh => '/dlh',
};

const _rutePublik = {'/login', '/register'};

/// Aturan redirect (fungsi murni agar mudah diuji):
/// - status login belum diketahui → /splash
/// - belum login → hanya /login & /register
/// - sudah login → hanya rute milik role-nya (+ /akun), selain itu ke berandanya
String? arahkan(AsyncValue<User?> auth, String lokasi) {
  if (auth.isLoading && !auth.hasValue) {
    return lokasi == '/splash' ? null : '/splash';
  }

  final user = auth.value;
  if (user == null) return _rutePublik.contains(lokasi) ? null : '/login';

  final beranda = berandaRole(user.role);
  final boleh =
      lokasi == beranda ||
      lokasi.startsWith('$beranda/') ||
      (lokasi.startsWith('/akun') && user.role != Role.dlh);
  return boleh ? null : beranda;
}

final routerProvider = Provider<GoRouter>((ref) {
  final segarkan = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => segarkan.value++);
  ref.onDispose(segarkan.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: segarkan,
    redirect: (context, state) =>
        arahkan(ref.read(authProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/dlh', builder: (_, _) => const BukanUntukDlhPage()),
      GoRoute(
        path: '/akun',
        builder: (_, _) => const AkunPage(),
        routes: [
          GoRoute(
            path: 'password',
            builder: (_, _) => const GantiPasswordPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/warga',
        builder: (_, _) => const WargaShell(),
        routes: [
          GoRoute(path: 'donasi', builder: (_, _) => const DonasiPage()),
          GoRoute(
            path: 'riwayat',
            builder: (_, _) => Consumer(
              builder: (context, ref, _) => Scaffold(
                appBar: AppBar(title: const Text('Riwayat transaksi')),
                body: DaftarBerhalaman<Setoran>(
                  muat: (hal) =>
                      ref.read(wargaRepositoryProvider).setoran(halaman: hal),
                  kosong: 'Belum ada transaksi.',
                  itemBuilder: (_, s, _) => KartuSetoran(setoran: s),
                ),
              ),
            ),
          ),
          GoRoute(path: 'cari', builder: (_, _) => const CariBankPage()),
          GoRoute(path: 'berita', builder: (_, _) => const DaftarBeritaPage()),
          GoRoute(
            path: 'berita/:id',
            builder: (_, s) =>
                DetailBeritaPage(id: int.parse(s.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'bank/:id',
            builder: (_, s) =>
                DetailBankPage(id: int.parse(s.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'jemput/baru',
            builder: (_, s) => MintaJemputPage(
              bankSampahId: int.tryParse(s.uri.queryParameters['bank'] ?? ''),
              catatanAwal: s.uri.queryParameters['catatan'],
              perkiraanKgAwal: s.uri.queryParameters['kg'],
            ),
          ),
          GoRoute(path: 'penarikan', builder: (_, _) => const PenarikanPage()),
          GoRoute(
            path: 'preloved/jual',
            builder: (_, _) => const FormBarangPage(),
          ),
          GoRoute(
            path: 'preloved/saya',
            builder: (_, _) => const BarangSayaPage(),
          ),
          GoRoute(
            path: 'preloved/:id',
            builder: (_, s) =>
                DetailBarangPage(id: int.parse(s.pathParameters['id']!)),
            routes: [
              GoRoute(
                path: 'ubah',
                builder: (_, s) =>
                    FormBarangPage(barang: s.extra as BarangPreloved),
              ),
            ],
          ),
          GoRoute(
            path: 'chat/:id',
            builder: (_, s) => RuangChatPage(percakapan: s.extra as Percakapan),
          ),
        ],
      ),
      GoRoute(
        path: '/bs',
        builder: (_, _) => const BsShell(),
        routes: [
          GoRoute(
            path: 'setoran/baru',
            builder: (_, s) =>
                CatatSetoranPage(penjemputan: s.extra as Penjemputan?),
          ),
          GoRoute(path: 'harga', builder: (_, _) => const AturHargaPage()),
          GoRoute(path: 'peta', builder: (_, _) => const PetaBankBsPage()),
          GoRoute(
            path: 'penarikan',
            builder: (_, _) => const PersetujuanPenarikanPage(),
          ),
          GoRoute(
            path: 'pengepul',
            builder: (_, _) => const PenjualanPengepulPage(),
          ),
          GoRoute(
            path: 'bentor/baru',
            builder: (_, _) => const TambahBentorPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/bentor',
        builder: (_, _) => const BentorBerandaPage(),
        routes: [
          GoRoute(
            path: 'tugas/:id',
            builder: (_, s) => DetailTugasPage(tugas: s.extra as Penjemputan),
          ),
          GoRoute(
            path: 'tugas/:id/timbang',
            builder: (_, s) => CatatSetoranPage(
              penjemputan: s.extra as Penjemputan,
              olehBentor: true,
            ),
          ),
        ],
      ),
    ],
  );
});
