import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/user.dart';
import '../../core/peta.dart';
import '../../core/repositories.dart';
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
      context.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: paddingAman(context),
          children: [
            TextFormField(
              controller: _lama,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password lama',
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
          ],
        ),
      ),
    );
  }
}
