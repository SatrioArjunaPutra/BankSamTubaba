import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/berita.dart';
import '../../core/providers.dart';

class BeritaRepository {
  BeritaRepository(this._api);
  final ApiClient _api;

  Future<Halaman<Berita>> daftar({String? q, int halaman = 1}) => _api.daftar(
    '/berita',
    Berita.dariJson,
    query: {'q': q},
    halaman: halaman,
  );

  Future<Berita> detail(int id) async =>
      Berita.dariJson(((await _api.get('/berita/$id'))['data'] as Map).cast());
}

final beritaRepositoryProvider = Provider(
  (ref) => BeritaRepository(ref.watch(apiClientProvider)),
);

const jumlahBeritaBeranda = 3;

final beritaTerbaruProvider = FutureProvider.autoDispose<List<Berita>>(
  (ref) async => (await ref.watch(beritaRepositoryProvider).daftar()).items
      .take(jumlahBeritaBeranda)
      .toList(),
);

final detailBeritaProvider = FutureProvider.autoDispose.family<Berita, int>(
  (ref, id) => ref.watch(beritaRepositoryProvider).detail(id),
);
