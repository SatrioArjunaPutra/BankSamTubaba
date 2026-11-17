import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/user.dart';
import '../../core/format.dart';
import '../../core/peta.dart';
import '../../core/repositories.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

const _labelRole = {
  Role.warga: 'Warga',
  Role.bankSampah: 'Operator Bank Sampah',
  Role.bentor: 'Driver Bentor',
  Role.dlh: 'DLH',
};

/// Isi tab "Akun" (dipakai semua role): profil, ganti password, keluar.
class AkunIsi extends ConsumerStatefulWidget {
  const AkunIsi({super.key});

  @override
  ConsumerState<AkunIsi> createState() => _AkunIsiState();
}

class _AkunIsiState extends ConsumerState<AkunIsi> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _hp;
  late final TextEditingController _alamat;
  LatLng? _titik;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).value!;
    _nama = TextEditingController(text: u.name);
    _hp = TextEditingController(text: u.phone ?? '');
    _alamat = TextEditingController(text: u.alamat ?? '');
    if (u.lat != null && u.lng != null) _titik = LatLng(u.lat!, u.lng!);
  }

  @override
  void dispose() {
    _nama.dispose();
    _hp.dispose();
    _alamat.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _menyimpan = true);
    await jalankan(context, () async {
      final user = await ref.read(umumRepositoryProvider).ubahProfil({
        'name': _nama.text.trim(),
        'phone': _hp.text.trim(),
        'alamat': _alamat.text.trim().isEmpty ? null : _alamat.text.trim(),
        if (_titik != null) ...{'lat': _titik!.latitude, 'lng': _titik!.longitude},
      });
      ref.read(authProvider.notifier).perbarui(user);
    }, sukses: 'Profil berhasil diperbarui.');
    if (mounted) setState(() => _menyimpan = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: paddingAman(context),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
          ),
          title: Text(
            user.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_labelRole[user.role]}${user.bankSampah != null ? ' · ${user.bankSampah!.nama}' : ''}\n${user.email}',
          ),
          isThreeLine: true,
        ),
        const Divider(),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _nama,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor HP'),
                validator: (v) =>
                    RegExp(r'^(\+62|62|0)8[0-9]{7,12}$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Nomor HP diawali 08.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamat,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
              ),
              if (user.role == Role.warga) ...[
                const SizedBox(height: 12),
                PemilihTitikRumah(
                  titik: _titik,
                  onBerubah: (t) => setState(() => _titik = t),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _menyimpan ? null : _simpan,
                child: const Text(
                  'Simpan Profil',
                  style: TextStyle(
                    letterSpacing: 0.1,
                    fontFeatures: [FontFeature('liga', 0)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/akun/password'),
          icon: const Icon(Icons.lock_reset),
          label: const Text('Ganti password'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/akun/perangkat'),
          icon: const Icon(Icons.devices_outlined),
          label: const Text('Perangkat aktif'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (await konfirmasi(
              context,
              'Keluar?',
              'Anda perlu login lagi untuk memakai aplikasi.',
              ya: 'Keluar',
            )) {
              await ref.read(authProvider.notifier).logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}

/// Halaman akun mandiri (untuk role yang tidak punya tab Akun, mis. bentor).
class AkunPage extends StatelessWidget {
  const AkunPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Akun')),
    body: const AkunIsi(),
  );
}

class GantiPasswordPage extends ConsumerStatefulWidget {
  const GantiPasswordPage({super.key});

  @override
  ConsumerState<GantiPasswordPage> createState() => _GantiPasswordPageState();
}

class _GantiPasswordPageState extends ConsumerState<GantiPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _loading = false;
  Map<String, String> _galat = {};

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _galat = {};
    });
    try {
      final pesan = await ref
          .read(umumRepositoryProvider)
          .ubahPassword(_lama.text, _baru.text);
      if (!mounted) return;
      tampilPesan(context, pesan);
      final user = ref.read(authProvider).value;
      if (user != null && user.harusGantiPassword) {
        // Dari password sementara: lanjut ke beranda, tidak ada halaman untuk kembali
        ref.read(authProvider.notifier).perbarui(user.salin(harusGantiPassword: false));
        context.go(berandaRole(user.role));
      } else {
        context.pop();
      }
    } on ApiException catch (e) {
      setState(
        () => _galat = e.errors.isEmpty ? {'password': e.pesan} : e.errors,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wajib = ref.watch(authProvider).value?.harusGantiPassword ?? false;
    return PopScope(
      canPop: !wajib,
      child: Scaffold(
        appBar: AppBar(
          title: Text(wajib ? 'Buat password baru' : 'Ganti password'),
          automaticallyImplyLeading: !wajib,
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: paddingAman(context),
            children: [
              if (wajib) ...[
                const _Catatan(
                  ikon: Icons.key_outlined,
                  teks:
                      'Kamu masuk dengan password sementara dari petugas bank sampah. '
                      'Buat password baru agar hanya kamu yang tahu.',
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _lama,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: wajib ? 'Password sementara' : 'Password lama',
                  errorText: _galat['password_lama'],
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baru,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password baru (min. 8)',
                  errorText: _galat['password'],
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Minimal 8 karakter.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ulang,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ulangi password baru',
                ),
                validator: (v) => v != _baru.text ? 'Password tidak sama.' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _simpan,
                child: const Text('Simpan'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Setelah diganti, perangkat lain yang memakai akun ini akan dikeluarkan.',
                style: TextStyle(fontSize: 12),
              ),
              if (wajib) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Keluar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak keterangan kuning muda dengan ikon di kiri.
class _Catatan extends StatelessWidget {
  const _Catatan({required this.ikon, required this.teks, this.anak = const []});

  final IconData ikon;
  final String teks;
  final List<Widget> anak;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, color: TemaAplikasi.kuningTua),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(teks, style: const TextStyle(fontSize: 13, height: 1.4, color: TemaAplikasi.kuningTua)),
              ...anak,
            ],
          ),
        ),
      ],
    ),
  );
}

final _perangkatProvider = FutureProvider.autoDispose<List<Perangkat>>(
  (ref) => ref.read(umumRepositoryProvider).perangkat(),
);

/// Daftar perangkat yang sedang login; perangkat lain bisa dikeluarkan.
class PerangkatPage extends ConsumerWidget {
  const PerangkatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(_perangkatProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perangkat aktif')),
      body: TampilanAsync(
        nilai: daftar,
        onUlang: () => ref.invalidate(_perangkatProvider),
        data: (perangkat) => ListView(
          padding: paddingAman(context),
          children: [
            const Text(
              'Perangkat yang sedang masuk dengan akunmu. Keluarkan perangkat yang tidak kamu kenali, '
              'lalu ganti password.',
              style: TextStyle(fontSize: 13, height: 1.4, color: TemaAplikasi.redup),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final (i, p) in perangkat.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: TemaAplikasi.hijauLembut,
                        foregroundColor: TemaAplikasi.hijau,
                        child: Icon(
                          p.nama.toLowerCase().contains('browser')
                              ? Icons.language
                              : Icons.phone_android,
                        ),
                      ),
                      title: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        p.saatIni
                            ? 'Perangkat ini'
                            : 'Terakhir aktif ${tanggalJam(p.terakhirDipakai ?? p.dibuat)}',
                        style: TextStyle(
                          color: p.saatIni ? TemaAplikasi.hijau : TemaAplikasi.redup,
                          fontWeight: p.saatIni ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      trailing: p.saatIni
                          ? null
                          : IconButton(
                              tooltip: 'Keluarkan ${p.nama}',
                              icon: const Icon(Icons.logout),
                              onPressed: () async {
                                if (!await konfirmasi(
                                  context,
                                  'Keluarkan perangkat?',
                                  '${p.nama} harus login lagi untuk memakai akun ini.',
                                  ya: 'Keluarkan',
                                )) {
                                  return;
                                }
                                if (!context.mounted) return;
                                final ok = await jalankan(
                                  context,
                                  () => ref.read(umumRepositoryProvider).keluarkanPerangkat(p.id),
                                  sukses: 'Perangkat dikeluarkan.',
                                );
                                if (ok) ref.invalidate(_perangkatProvider);
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: perangkat.length < 2
                  ? null
                  : () async {
                      if (!await konfirmasi(
                        context,
                        'Keluar dari perangkat lain?',
                        'Semua perangkat selain HP ini harus login lagi.',
                        ya: 'Keluarkan semua',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      var jumlah = 0;
                      final ok = await jalankan(context, () async {
                        jumlah = await ref.read(umumRepositoryProvider).keluarPerangkatLain();
                      });
                      if (!ok || !context.mounted) return;
                      tampilPesan(context, '$jumlah perangkat lain dikeluarkan.');
                      ref.invalidate(_perangkatProvider);
                    },
              icon: const Icon(Icons.devices_other),
              label: const Text('Keluar dari semua perangkat lain'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hapus akun warga: syarat dijelaskan di depan, lalu konfirmasi dengan password.
class HapusAkunPage extends ConsumerStatefulWidget {
  const HapusAkunPage({super.key});

  @override
  ConsumerState<HapusAkunPage> createState() => _HapusAkunPageState();
}

class _HapusAkunPageState extends ConsumerState<HapusAkunPage> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _galatPassword;
  String? _galatAkun;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _hapus() async {
    if (_password.text.isEmpty) {
      setState(() => _galatPassword = 'Masukkan password untuk konfirmasi.');
      return;
    }
    if (!await konfirmasi(
      context,
      'Hapus akun permanen?',
      'Data pribadimu dihapus dan akun tidak bisa dipulihkan.',
      ya: 'Hapus akun',
    )) {
      return;
    }
    setState(() {
      _loading = true;
      _galatPassword = null;
      _galatAkun = null;
    });
    try {
      await ref.read(umumRepositoryProvider).hapusAkun(_password.text);
      if (!mounted) return;
      tampilPesan(context, 'Akun Anda sudah dihapus.');
      await ref.read(authProvider.notifier).logout();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _galatPassword = e.errors['password'];
        _galatAkun = e.errors['akun'] ?? (e.errors.isEmpty ? e.pesan : null);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hapus akun')),
    body: ListView(
      padding: paddingAman(context),
      children: [
        const _Catatan(
          ikon: Icons.warning_amber_rounded,
          teks: 'Yang terjadi bila akun dihapus:',
          anak: [
            SizedBox(height: 6),
            _Butir('Nama, email, nomor HP, alamat, dan titik rumah dihapus.'),
            _Butir('Barang preloved yang masih dijual disembunyikan.'),
            _Butir('Riwayat setoran tetap tercatat di bank sampah tanpa namamu.'),
            _Butir('Akun tidak bisa dipulihkan.'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Syarat', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const _Butir('Saldo di semua bank sampah sudah Rp 0. Tarik dulu sisa saldomu.'),
        const _Butir('Tidak ada penarikan saldo yang menunggu persetujuan.'),
        const _Butir('Tidak ada penjemputan yang sedang berjalan.'),
        if (_galatAkun != null) ...[
          const SizedBox(height: 12),
          Text(_galatAkun!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Password', errorText: _galatPassword),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: _loading ? null : _hapus,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Hapus akun saya'),
        ),
      ],
    ),
  );
}

class _Butir extends StatelessWidget {
  const _Butir(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(height: 1.4)),
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 13, height: 1.4))),
      ],
    ),
  );
}

/// Ringkasan data yang dikumpulkan aplikasi dan siapa yang bisa melihatnya.
class KebijakanPrivasiPage extends StatelessWidget {
  const KebijakanPrivasiPage({super.key});

  static const _bagian = [
    (
      'Data yang kami simpan',
      [
        'Nama, email, nomor HP, alamat, dan titik rumah yang kamu isi.',
        'Riwayat setoran, donasi, penjemputan, dan penarikan saldo.',
        'Foto dan keterangan barang preloved, serta isi chat dengan pembeli atau penjual.',
      ],
    ),
    (
      'Siapa yang bisa melihat',
      [
        'Pengelola bank sampah tempat kamu menabung: nama, kontak, alamat, dan saldo di bank itu.',
        'Bentor yang ditugaskan: alamat dan titik penjemputanmu.',
        'Lawan chat preloved: namamu dan pesan di percakapan itu.',
        'DLH Kabupaten Tulang Bawang Barat, untuk mengawasi kinerja bank sampah.',
      ],
    ),
    (
      'Lokasi dan kamera',
      [
        'Lokasi dipakai saat kamu menandai titik rumah, mencari bank sampah terdekat, atau minta jemput.',
        'Kamera dipakai hanya saat kamu memotret barang atau sampah.',
      ],
    ),
    (
      'Hakmu',
      [
        'Mengubah profil kapan saja di menu Akun.',
        'Mengeluarkan perangkat lain di menu Perangkat aktif.',
        'Menghapus akun di menu Hapus akun.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kebijakan privasi')),
    body: ListView(
      padding: paddingAman(context),
      children: [
        for (final (judul, isi) in _bagian) ...[
          Text(judul, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final t in isi) _Butir(t),
          const SizedBox(height: 14),
        ],
        const Text(
          'Data tidak dijual atau dibagikan ke pihak lain di luar Bank Sampah Tubaba.',
          style: TextStyle(fontSize: 12.5, color: TemaAplikasi.redup),
        ),
      ],
    ),
  );
}
