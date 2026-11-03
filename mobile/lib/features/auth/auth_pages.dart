import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/logo_aplikasi.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/peta.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'auth_controller.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoAplikasi(ukuran: 88),
            const SizedBox(height: 16),
            const Text(
              'Bank Sampah Tubaba',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _Kerangka extends StatelessWidget {
  const _Kerangka({required this.judul, required this.anak});
  final String judul;
  final List<Widget> anak;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Scaffold(
      backgroundColor: TemaAplikasi.hijauPekat,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(image: corakTapis)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, ukuran) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: ukuran.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const LogoAplikasi(ukuran: 36),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Bank Sampah',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Sampahmu,\ntabunganmu.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  height: 1,
                                  letterSpacing: -1.7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Pilah, setor, dan pantau saldo sampahmu dari rumah.',
                                style: TextStyle(
                                  color: Color(0xFFB7E4C7),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(34),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (judul != 'Masuk') ...[
                                  Text(
                                    judul,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Mulai langkah kecil untuk Tubaba lebih hijau.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TemaAplikasi.redup,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                ...anak,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _sembunyi = true;
  String _peran = 'warga';
  String? _galat;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _galat = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text, peran: _peran);
      // Router mengarahkan ke beranda sesuai role
    } on ApiException catch (e) {
      setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Kerangka(
      judul: 'Masuk',
      anak: [
        const Text(
          'Masuk sebagai',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SegmenReferensi<String>(
          nilai: _peran,
          pilihan: const [
            ('warga', 'Warga'),
            ('bank_sampah', 'Bank sampah'),
            ('bentor', 'Bentor'),
          ],
          onUbah: (v) => setState(() {
            _peran = v;
            _galat = null;
          }),
        ),
        const SizedBox(height: 20),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_galat != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _galat!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Masukkan email yang valid.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _sembunyi,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _sembunyi ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _sembunyi = !_sembunyi),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password wajib diisi.' : null,
                onFieldSubmitted: (_) => _masuk(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _masuk,
                style: FilledButton.styleFrom(
                  backgroundColor: TemaAplikasi.hijauPekat,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Masuk'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Warga baru? Daftar di sini'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _hp = TextEditingController();
  final _password = TextEditingController();
  final _alamat = TextEditingController();
  LatLng? _titik;
  List<BankSampah>? _terdekat;
  bool _mencariBank = false;
  bool _gagalCariBank = false;
  bool _loading = false;
  Map<String, String> _galat = {};

  @override
  void dispose() {
    for (final c in [_nama, _email, _hp, _password, _alamat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _gantiTitik(LatLng titik) {
    setState(() {
      _titik = titik;
      _galat = {..._galat}..remove('lat');
    });
    _cariBank();
  }

  Future<void> _cariBank() async {
    final titik = _titik;
    if (titik == null) return;
    setState(() {
      _mencariBank = true;
      _gagalCariBank = false;
      _terdekat = null;
    });
    try {
      final hasil = await ref.read(umumRepositoryProvider).bankTerdekatPublik(titik.latitude, titik.longitude);
      // Abaikan jawaban lama bila titiknya sudah dipindah lagi
      if (!mounted || titik != _titik) return;
      setState(() {
        _terdekat = hasil;
        _mencariBank = false;
      });
    } on ApiException {
      if (!mounted || titik != _titik) return;
      setState(() {
        _mencariBank = false;
        _gagalCariBank = true;
      });
    }
  }

  Future<void> _daftar() async {
    final formOk = _form.currentState!.validate();
    final titik = _titik;
    if (titik == null) {
      setState(() => _galat = {..._galat, 'lat': 'Tandai titik rumah Anda di peta.'});
    }
    if (!formOk || titik == null) return;
    setState(() {
      _loading = true;
      _galat = {};
    });
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            name: _nama.text.trim(),
            email: _email.text.trim(),
            phone: _hp.text.trim(),
            password: _password.text,
            alamat: _alamat.text.trim(),
            lat: titik.latitude,
            lng: titik.longitude,
          );
    } on ApiException catch (e) {
      setState(() => _galat = e.errors.isEmpty ? {'umum': e.pesan} : e.errors);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Kerangka(
      judul: 'Daftar sebagai Warga',
      anak: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_galat['umum'] != null)
                Text(
                  _galat['umum']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                controller: _nama,
                decoration: InputDecoration(
                  labelText: 'Nama lengkap',
                  errorText: _galat['name'],
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _galat['email'],
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Masukkan email yang valid.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hp,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: '08xxxxxxxxxx',
                  errorText: _galat['phone'],
                ),
                validator: (v) =>
                    RegExp(r'^(\+62|62|0)8[0-9]{7,12}$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Nomor HP diawali 08 (contoh 081234567890).',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (min. 8 karakter)',
                  errorText: _galat['password'],
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Password minimal 8 karakter.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamat,
                maxLines: 2,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Alamat rumah',
                  hintText: 'Jalan, RT/RW, tiyuh',
                  counterText: '',
                  errorText: _galat['alamat'],
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Alamat wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              PemilihTitikRumah(
                titik: _titik,
                galat: _galat['lat'] ?? _galat['lng'],
                onBerubah: _gantiTitik,
                penandaLain: [
                  if (_terdekat?.firstOrNull case final b? when b.lat != null && b.lng != null)
                    penandaPin(LatLng(b.lat!, b.lng!), warna: TemaAplikasi.hijau, ikon: Icons.recycling),
                ],
              ),
              if (_titik != null) ...[
                const SizedBox(height: 10),
                _BankTerdekatDaftar(
                  memuat: _mencariBank,
                  gagal: _gagalCariBank,
                  daftar: _terdekat,
                  onUlang: _cariBank,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _daftar,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Daftar'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sudah punya akun? Masuk'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Jarak dari titik rumah ke bank sampah terdekat di formulir daftar.
class _BankTerdekatDaftar extends StatelessWidget {
  const _BankTerdekatDaftar({
    required this.memuat,
    required this.gagal,
    required this.daftar,
    required this.onUlang,
  });

  final bool memuat;
  final bool gagal;
  final List<BankSampah>? daftar;
  final VoidCallback onUlang;

  @override
  Widget build(BuildContext context) {
    const redup = TextStyle(fontSize: 12.5, color: TemaAplikasi.redup);
    final hasil = daftar;
    final Widget isi;
    if (memuat) {
      isi = const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Menghitung jarak…', style: redup),
        ],
      );
    } else if (gagal) {
      isi = Row(
        children: [
          const Expanded(child: Text('Jarak belum bisa dihitung. Anda tetap bisa mendaftar.', style: redup)),
          TextButton(onPressed: onUlang, child: const Text('Coba lagi')),
        ],
      );
    } else if (hasil == null || hasil.isEmpty) {
      isi = const Text('Belum ada bank sampah dalam radius 50 km dari titik ini.', style: redup);
    } else {
      isi = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bank sampah terdekat',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TemaAplikasi.hijauPekat),
          ),
          const SizedBox(height: 6),
          for (final b in hasil)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    jarakKm(b.jarakKm ?? 0),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: TemaAplikasi.hijau),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TemaAplikasi.hijauLembut,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isi,
    );
  }
}

/// Akun DLH memakai web dashboard, bukan aplikasi ini.
class BukanUntukDlhPage extends ConsumerWidget {
  const BukanUntukDlhPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Kosong(
        pesan: 'Akun DLH menggunakan web dashboard DLH, bukan aplikasi ini.',
        ikon: Icons.desktop_windows_outlined,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          child: const Text('Keluar'),
        ),
      ),
    );
  }
}
