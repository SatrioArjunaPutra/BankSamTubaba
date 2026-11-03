import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/bank_sampah.dart';
import '../../core/models/operasional.dart';
import '../../core/models/transaksi.dart';
import '../../core/models/user.dart';
import '../../core/repositories.dart';

final dashboardBsProvider = FutureProvider.autoDispose<DashboardBank>(
  (ref) => ref.watch(bankSampahRepositoryProvider).dashboard(),
);
final permintaanBaruBsProvider = FutureProvider.autoDispose<List<Penjemputan>>(
  (ref) async =>
      (await ref.watch(bankSampahRepositoryProvider).penjemputan('diajukan'))
          .items
          .take(3)
          .toList(),
);

final hargaBsProvider = FutureProvider.autoDispose<List<Harga>>(
  (ref) => ref.watch(bankSampahRepositoryProvider).harga(),
);

/// Harga bank tempat bentor bertugas; bentor tidak memakai endpoint /bs/harga.
final hargaBankProvider = FutureProvider.autoDispose.family<List<Harga>, int>(
  (ref, bankId) async =>
      (await ref.watch(umumRepositoryProvider).detailBankSampah(bankId)).harga,
);

final armadaBsProvider = FutureProvider.autoDispose<(List<Armada>, List<User>)>(
  (ref) => ref.watch(bankSampahRepositoryProvider).armada(),
);
