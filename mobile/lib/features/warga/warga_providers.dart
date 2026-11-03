import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/bank_sampah.dart';
import '../../core/models/transaksi.dart';
import '../../core/repositories.dart';
import '../auth/auth_controller.dart';

final saldoProvider = FutureProvider.autoDispose<RingkasanSaldo>((ref) => ref.watch(wargaRepositoryProvider).saldo());

final setoranTerbaruProvider = FutureProvider.autoDispose<List<Setoran>>(
  (ref) async => (await ref.watch(wargaRepositoryProvider).setoran()).items.take(5).toList(),
);

final detailBankProvider = FutureProvider.autoDispose.family<BankSampah, int>(
  (ref, id) => ref.watch(umumRepositoryProvider).detailBankSampah(id),
);

/// Bank sampah aktif (maks. 100) untuk pilihan di form jemput & penarikan.
final pilihanBankProvider = FutureProvider.autoDispose<List<BankSampah>>((ref) async {
  final repo = ref.watch(umumRepositoryProvider);
  final semua = <BankSampah>[];
  for (var hal = 1; hal <= 5; hal++) {
    final h = await repo.daftarBankSampah(halaman: hal);
    semua.addAll(h.items);
    if (!h.adaBerikutnya) break;
  }
  return semua;
});

/// Bank sampah terdekat dari titik rumah warga; null bila tidak ada dalam 50 km.
final bankTerdekatRumahProvider = FutureProvider.autoDispose<BankSampah?>((ref) async {
  final user = ref.watch(authProvider).value;
  final lat = user?.lat;
  final lng = user?.lng;
  if (lat == null || lng == null) return null;
  final daftar = await ref.watch(umumRepositoryProvider).bankTerdekat(lat, lng, radiusKm: 50);
  return daftar.firstOrNull;
});
