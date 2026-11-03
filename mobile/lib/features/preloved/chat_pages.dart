import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/preloved.dart';
import '../../core/widgets.dart';
import 'barang_pages.dart' show infoCod;
import 'pengelola_pesan.dart';
import 'preloved_repository.dart';
import 'preloved_tab.dart' show FotoJaringan;

const _intervalDaftar = Duration(seconds: 15);
const _intervalRuang = Duration(seconds: 3);

/// Tab Chat: daftar percakapan. Polling 15 detik hanya saat tab aktif dan
/// aplikasi di foreground.
class DaftarChatTab extends ConsumerStatefulWidget {
  const DaftarChatTab({super.key, required this.aktif});

  final bool aktif;

  @override
  ConsumerState<DaftarChatTab> createState() => _DaftarChatTabState();
}

class _DaftarChatTabState extends ConsumerState<DaftarChatTab> with WidgetsBindingObserver {
  Halaman<Percakapan>? _data;
  String? _galat;
  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _aturTimer();
  }

  @override
  void didUpdateWidget(DaftarChatTab lama) {
    super.didUpdateWidget(lama);
    if (lama.aktif != widget.aktif) _aturTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _aturTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _aturTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.aktif && _foreground) {
      _muat();
      _timer = Timer.periodic(_intervalDaftar, (_) => _muat());
    }
  }

  Future<void> _muat() async {
    try {
      final h = await ref.read(prelovedRepositoryProvider).daftarChat();
      if (mounted) {
        setState(() {
          _data = h;
          _galat = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _galat = pesanDari(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      if (_galat != null) return PesanGagal(pesan: _galat!, onUlang: _muat);
      // Tab belum pernah dibuka: jangan biarkan spinner berputar di latar
      return widget.aktif ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: data.items.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [Kosong(pesan: 'Belum ada percakapan.\nBuka barang di tab Preloved lalu ketuk "Chat Penjual".', ikon: Icons.chat_bubble_outline)])
          : ListView.separated(
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = data.items[i];
                final terakhir = c.pesanTerakhir;
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 52, height: 52, child: FotoJaringan(url: c.barang.foto))),
                  title: Text(c.lawanBicara.name, style: TextStyle(fontWeight: c.unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(
                    '${c.barang.judul}\n${terakhir == null ? '' : '${terakhir.milikSaya ? 'Anda: ' : ''}${terakhir.tawaran ? 'Tawar ${rupiah(terakhir.tawaranHarga)}' : terakhir.isi}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_waktuSingkat(c.lastMessageAt), style: const TextStyle(fontSize: 11)),
                    if (c.unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Badge(label: Text('${c.unreadCount}')),
                    ],
                  ]),
                  onTap: () async {
                    await context.push('/warga/chat/${c.id}', extra: c);
                    _muat();
                  },
                );
              },
            ),
    );
  }
}

String _waktuSingkat(DateTime? t) {
  if (t == null) return '';
  final lokal = t.toLocal();
  final kini = DateTime.now();
  final hariIni = lokal.year == kini.year && lokal.month == kini.month && lokal.day == kini.day;
  return DateFormat(hariIni ? 'HH.mm' : 'd MMM', 'id_ID').format(lokal);
}

/// Ruang chat. Polling GET /chat/{id}/pesan?after_id= tiap 3 detik HANYA saat
/// layar terbuka dan aplikasi di foreground; berhenti saat dispose/background.
class RuangChatPage extends ConsumerStatefulWidget {
  const RuangChatPage({super.key, required this.percakapan});

  final Percakapan percakapan;

  @override
  ConsumerState<RuangChatPage> createState() => _RuangChatPageState();
}

class _RuangChatPageState extends ConsumerState<RuangChatPage> with WidgetsBindingObserver {
  late final PengelolaPesan _pesan;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _memuat = true;
  String? _galat;
  late String _statusBarang = widget.percakapan.barang.status;

  PrelovedRepository get _repo => ref.read(prelovedRepositoryProvider);
  int get _id => widget.percakapan.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pesan = PengelolaPesan(
      ambil: (afterId) => _repo.pesan(_id, afterId: afterId),
      kirimKeServer: ({isi, tawaranHarga}) => _repo.kirim(_id, isi: isi, tawaranHarga: tawaranHarga),
    )..addListener(_gulirKeBawah);
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      await _pesan.muatAwal();
      _tandaiDibaca();
      _hidupkanPolling();
    } catch (e) {
      _galat = pesanDari(e);
    }
    if (mounted) setState(() => _memuat = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hidupkanPolling();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _hidupkanPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_intervalRuang, (_) async {
      try {
        if (await _pesan.ambilBaru() > 0) _tandaiDibaca();
      } catch (_) {
        // Gagal sesaat (sinyal hilang) diabaikan; dicoba lagi di putaran berikut
      }
    });
  }

  void _tandaiDibaca() => _repo.tandaiDibaca(_id).catchError((_) {});

  void _gulirKeBawah() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pesan.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _kirimTeks() {
    final isi = _input.text.trim();
    if (isi.isEmpty) return;
    _input.clear();
    _pesan.kirim(isi: isi);
  }

  Future<void> _tawar() async {
    final teks = TextEditingController();
    final nilai = await showDialog<double>(
      context: context,
      builder: (c) => DialogAplikasi(
        judul: 'Tawar harga',
        isi: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Harga: ${rupiah(widget.percakapan.barang.harga)}'),
          const SizedBox(height: 8),
          TextField(
            controller: teks,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Tawaran Anda', prefixText: 'Rp '),
          ),
        ]),
        aksi: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, double.tryParse(teks.text)), child: const Text('Kirim tawaran')),
        ],
      ),
    );
    if (nilai != null && nilai > 0) _pesan.kirim(tawaranHarga: nilai);
  }

  Future<void> _tandaiTerjual() async {
    if (!await konfirmasi(context, 'Tandai terjual?', 'Barang tidak akan tampil lagi di daftar preloved.', ya: 'Terjual')) return;
    if (!mounted) return;
    final ok = await jalankan(context, () => _repo.tandaiTerjual(widget.percakapan.barang.id), sukses: 'Barang ditandai terjual.');
    if (ok && mounted) setState(() => _statusBarang = 'terjual');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.percakapan;
    final daftar = _pesan.pesan;

    return Scaffold(
      appBar: AppBar(title: Text(c.lawanBicara.name), actions: [
        if (c.sayaPenjual && _statusBarang == 'tersedia')
          TextButton(onPressed: _tandaiTerjual, style: TextButton.styleFrom(foregroundColor: Colors.white), child: const Text('Tandai terjual')),
      ]),
      body: Column(children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 44, height: 44, child: FotoJaringan(url: c.barang.foto))),
            title: Text(c.barang.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${rupiah(c.barang.harga)}${_statusBarang != 'tersedia' ? ' · ${_statusBarang.toUpperCase()}' : ''}'),
            onTap: () => context.push('/warga/preloved/${c.barang.id}'),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.amber.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Text(infoCod, style: TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: _memuat
              ? const Center(child: CircularProgressIndicator())
              : _galat != null
                  ? PesanGagal(pesan: _galat!, onUlang: () {
                      setState(() {
                        _memuat = true;
                        _galat = null;
                      });
                      _mulai();
                    })
                  : daftar.isEmpty
                      ? const Kosong(pesan: 'Mulai percakapan. Tanyakan kondisi barang atau ajukan tawaran.')
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: daftar.length,
                          itemBuilder: (_, i) => BubblePesan(
                            key: ValueKey(daftar[i].kunci),
                            tampil: daftar[i],
                            onKirimUlang: () => _pesan.kirimUlang(daftar[i].kunci),
                            onHapus: () => _pesan.hapusGagal(daftar[i].kunci),
                          ),
                        ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              ActionChip(
                avatar: Icon(Icons.local_offer_outlined, color: Colors.amber.shade900),
                label: const Text('Tawar Harga'),
                onPressed: _tawar,
              ),
              const SizedBox(height: 4),
              _barisInput(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _barisInput() => Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Tulis pesan', counterText: ''),
            onSubmitted: (_) => _kirimTeks(),
          ),
        ),
        const SizedBox(width: 4),
        IconButton.filled(tooltip: 'Kirim', onPressed: _kirimTeks, icon: const Icon(Icons.send)),
      ]);
}

/// Gelembung pesan: teks biasa, atau tawaran harga (tampilan khusus Rp).
/// Kiriman yang gagal menampilkan tombol kirim ulang.
class BubblePesan extends StatelessWidget {
  const BubblePesan({super.key, required this.tampil, this.onKirimUlang, this.onHapus});

  final PesanTampil tampil;
  final VoidCallback? onKirimUlang;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final p = tampil.pesan;
    final skema = Theme.of(context).colorScheme;
    final saya = p.milikSaya;
    final warnaLatar = p.tawaran ? Colors.amber.shade100 : (saya ? skema.primaryContainer : skema.surfaceContainerHighest);

    final isi = p.tawaran
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_offer, size: 16, color: Colors.amber.shade900),
              const SizedBox(width: 4),
              Text(saya ? 'Tawaran Anda' : 'Tawaran harga', style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
            ]),
            Text(rupiah(p.tawaranHarga), key: const Key('nilai-tawaran'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (p.isi != null) Text(p.isi!),
          ])
        : Text(p.isi ?? '');

    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: warnaLatar,
            borderRadius: BorderRadius.circular(14),
            border: p.tawaran ? Border.all(color: Colors.amber.shade700) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerLeft, widthFactor: 1, child: isi),
            const SizedBox(height: 2),
            switch (tampil.status) {
              StatusKirim.terkirim => Text(
                  '${p.createdAt == null ? '' : DateFormat('HH.mm').format(p.createdAt!.toLocal())}${saya && p.dibacaAt != null ? ' · dibaca' : ''}',
                  style: const TextStyle(fontSize: 10),
                ),
              StatusKirim.mengirim => const Text('mengirim...', style: TextStyle(fontSize: 10)),
              StatusKirim.gagal => Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Gagal terkirim', style: TextStyle(fontSize: 11, color: skema.error)),
                  TextButton(onPressed: onKirimUlang, child: const Text('Kirim ulang')),
                  IconButton(tooltip: 'Hapus', visualDensity: VisualDensity.compact, onPressed: onHapus, icon: const Icon(Icons.close, size: 16)),
                ]),
            },
          ]),
        ),
      ),
    );
  }
}
