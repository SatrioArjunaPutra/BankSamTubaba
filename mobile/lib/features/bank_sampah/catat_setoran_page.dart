import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/models/operasional.dart';
import '../../core/models/transaksi.dart';
import '../../core/repositories.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'bs_providers.dart';
import 'kalkulator_setoran.dart';
import 'permintaan_setoran.dart';

/// Catat setoran: cari warga → Jual/Donasi → baris jenis + berat → total
/// realtime dari harga bank → konfirmasi → simpan. Jika dibuka dari
/// penjemputan berstatus diambil, warga & penjemputan_id sudah terisi.
/// Bentor memakai halaman yang sama untuk menimbang di lokasi (olehBentor).
class CatatSetoranPage extends ConsumerStatefulWidget {
  const CatatSetoranPage({super.key, this.penjemputan, this.olehBentor = false});

  final Penjemputan? penjemputan;
  final bool olehBentor;

  @override
  ConsumerState<CatatSetoranPage> createState() => _CatatSetoranPageState();
}

class _CatatSetoranPageState extends ConsumerState<CatatSetoranPage> {
  WargaNasabah? _warga;
  bool _donasi = false;
  final _baris = <BarisSetoran>[BarisSetoran()];
  bool _menyimpan = false;
  bool _memulihkan = true;
  String? _galatPemulihan;
  PermintaanSetoran? _tertunda;
  int? _penjemputanId;

  @override
  void initState() {
    super.initState();
    _penjemputanId = widget.penjemputan?.id;
    _donasi = widget.penjemputan?.catatan?.startsWith('[DONASI]') ?? false;
    final w = widget.penjemputan?.warga;
    if (w != null) {
      _warga = WargaNasabah(id: w.id, name: w.name, phone: w.phone, saldo: 0);
    }
    Future.microtask(_pulihkan);
  }

  Future<void> _pulihkan() async {
    setState(() {
      _memulihkan = true;
      _galatPemulihan = null;
    });
    try {
      final user = ref.read(authProvider).value;
      if (user == null || user.bankSampah == null) {
        throw StateError('Sesi operator tidak tersedia.');
      }
      final data = await ref
          .read(penyimpananSetoranProvider)
          .baca(user.id, user.bankSampah!.id);
      if (mounted) setState(() => _tertunda = data);
    } catch (_) {
      if (mounted) {
        setState(
          () => _galatPemulihan = 'Belum dapat memeriksa setoran tertunda. Coba lagi sebelum membuat setoran baru.',
        );
      }
    } finally {
      if (mounted) setState(() => _memulihkan = false);
    }
  }

  Future<void> _kirim(PermintaanSetoran p) async {
    try {
      final (_, saldo) = widget.olehBentor
          ? await ref
                .read(bentorRepositoryProvider)
                .catatSetoranTugas(
                  tugasId: p.penjemputanId!,
                  tipe: p.tipe,
                  items: p.items,
                  requestId: p.requestId,
                )
          : await ref
                .read(bankSampahRepositoryProvider)
                .catatSetoran(
                  wargaId: p.wargaId,
                  tipe: p.tipe,
                  items: p.items,
                  penjemputanId: p.penjemputanId,
                  requestId: p.requestId,
                );
      await ref.read(penyimpananSetoranProvider).hapus(p.operatorId, p.bankId);
      if (!mounted) return;
      if (!widget.olehBentor) ref.invalidate(dashboardBsProvider);
      tampilPesan(
        context,
        p.tipe == 'donasi'
            ? 'Donasi tercatat. Terima kasih!'
            : 'Setoran tercatat. Saldo setelah setoran ${p.namaWarga}: ${rupiah(saldo)}.',
      );
      context.pop(true);
    } on ApiException catch (e) {
      // 422 (selain konflik ID) memastikan transaksi tidak dibuat. Jaringan,
      // 5xx, atau kehilangan sesi belum memastikan hasil: pertahankan draf.
      if (e.status == 422 && !e.errors.containsKey('request_id')) {
        await ref
            .read(penyimpananSetoranProvider)
            .hapus(p.operatorId, p.bankId);
        if (mounted) {
          setState(() {
            _tertunda = null;
            _penjemputanId = p.penjemputanId;
            _warga = WargaNasabah(id: p.wargaId, name: p.namaWarga, saldo: 0);
            _donasi = p.tipe == 'donasi';
            _baris
              ..clear()
              ..addAll(
                p.items.map(
                  (i) => BarisSetoran(jenisSampahId: i.$1, berat: '${i.$2}'),
                ),
              );
          });
        }
      }
      if (mounted) tampilPesan(context, e.pesan, gagal: true);
    } catch (_) {
      if (mounted) {
        tampilPesan(
          context,
          'Hasil penyimpanan belum dapat dipastikan. Rincian tetap tersimpan; gunakan Cek ulang setoran.',
          gagal: true,
        );
      }
    }
  }

  Future<void> _ulangi() async {
    if (_menyimpan || _tertunda == null) return;
    setState(() => _menyimpan = true);
    try {
      await _kirim(_tertunda!);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _simpan(Map<int, double?> harga, List<Harga> daftarHarga) async {
    if (_menyimpan || _tertunda != null) return;
    final total = TotalSetoran.hitung(_baris, harga, donasi: _donasi);
    final siap = _baris
        .where((b) => b.jenisSampahId != null && b.beratKg != null)
        .toList();

    if (_warga == null || siap.isEmpty) {
      tampilPesan(
        context,
        'Pilih warga dan isi minimal satu jenis sampah beserta beratnya.',
        gagal: true,
      );
      return;
    }
    if (total.tanpaHarga.isNotEmpty) {
      tampilPesan(
        context,
        widget.olehBentor
            ? 'Ada jenis yang belum punya harga. Minta operator mengatur harga atau catat sebagai donasi.'
            : 'Ada jenis yang belum punya harga. Atur harga dulu atau catat sebagai donasi.',
        gagal: true,
      );
      return;
    }

    final nama = {for (final h in daftarHarga) h.jenisSampahId: h.nama};
    final rincian = siap
        .map((b) => '• ${nama[b.jenisSampahId]}: ${kg(b.beratKg)}')
        .join('\n');
    setState(() => _menyimpan = true);
    try {
      final ok = await konfirmasi(
        context,
        _donasi ? 'Catat donasi?' : 'Catat setoran?',
        '${_warga!.name}\n\n$rincian\n\nTotal ${kg(total.totalKg)}${_donasi ? ' (donasi, saldo tidak bertambah)' : '\nNilai ${rupiah(total.totalNilai)}'}',
        ya: 'Simpan',
      );
      if (!ok || !mounted) return;

      final user = ref.read(authProvider).value!;
      final p = PermintaanSetoran(
        requestId: PermintaanSetoran.idBaru(),
        operatorId: user.id,
        bankId: user.bankSampah!.id,
        wargaId: _warga!.id,
        namaWarga: _warga!.name,
        tipe: _donasi ? 'donasi' : 'jual',
        items: [for (final b in siap) (b.jenisSampahId!, b.beratKg!)],
        penjemputanId: _penjemputanId,
      );
      // Wajib berhasil tersimpan SEBELUM mengirim request ke server.
      await ref.read(penyimpananSetoranProvider).simpan(p);
      if (!mounted) return;
      setState(() => _tertunda = p);
      await _kirim(p);
    } catch (_) {
      if (mounted) {
        tampilPesan(
          context,
          'Belum dapat menyimpan rincian setoran di perangkat. Coba lagi.',
          gagal: true,
        );
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankId = ref.watch(authProvider).value?.bankSampah?.id ?? 0;
    final penyediaHarga = widget.olehBentor
        ? hargaBankProvider(bankId)
        : hargaBsProvider;
    final harga = ref.watch(penyediaHarga);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.olehBentor
              ? 'Timbang sampah'
              : _penjemputanId != null
              ? 'Setoran hasil jemput'
              : 'Catat setoran',
        ),
      ),
      body: _memulihkan
          ? const Center(child: CircularProgressIndicator())
          : _galatPemulihan != null
          ? PesanGagal(pesan: _galatPemulihan!, onUlang: _pulihkan)
          : _tertunda != null
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.cloud_sync_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Setoran belum terkonfirmasi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${_tertunda!.namaWarga} · ${_tertunda!.tipe == 'donasi' ? 'Donasi' : 'Jual'} · ${kg(_tertunda!.items.fold<double>(0, (s, i) => s + i.$2))}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Jangan buat setoran baru untuk transaksi ini. Cek ulang memakai rincian yang sama agar saldo tidak bertambah dua kali. Rincian tetap tersimpan jika aplikasi ditutup.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _menyimpan ? null : _ulangi,
                  icon: _menyimpan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _menyimpan ? 'Memeriksa...' : 'Cek ulang setoran',
                  ),
                ),
              ],
            )
          : TampilanAsync(
              nilai: harga,
              onUlang: () => ref.invalidate(penyediaHarga),
              data: (daftarHarga) => FormSetoran(
                daftarHarga: daftarHarga,
                warga: _warga,
                wargaTerkunci: _penjemputanId != null,
                onPilihWarga: (w) => setState(() => _warga = w),
                donasi: _donasi,
                onUbahTipe: (d) => setState(() => _donasi = d),
                baris: _baris,
                onUbah: () => setState(() {}),
                menyimpan: _menyimpan,
                onSimpan: () => _simpan({
                  for (final h in daftarHarga) h.jenisSampahId: h.hargaPerKg,
                }, daftarHarga),
              ),
            ),
    );
  }
}

/// Isi form setoran (dipisah agar bisa diuji tanpa API).
class FormSetoran extends StatefulWidget {
  const FormSetoran({super.key, required this.daftarHarga, required this.warga, required this.onPilihWarga, required this.donasi, required this.onUbahTipe, required this.baris, required this.onUbah, required this.onSimpan, this.wargaTerkunci=false, this.menyimpan=false});
  final List<Harga> daftarHarga;
  final WargaNasabah? warga;
  final bool wargaTerkunci;
  final ValueChanged<WargaNasabah> onPilihWarga;
  final bool donasi;
  final ValueChanged<bool> onUbahTipe;
  final List<BarisSetoran> baris;
  final VoidCallback onUbah;
  final VoidCallback onSimpan;
  final bool menyimpan;
  @override
  State<FormSetoran> createState()=>_FormSetoranState();
}

class _FormSetoranState extends State<FormSetoran> {
  final _controllers=<int,TextEditingController>{};
  @override
  void initState(){
    super.initState();
    if(widget.baris.every((b)=>b.jenisSampahId==null)&&widget.daftarHarga.isNotEmpty){
      const urutan=['Plastik','Kardus','Logam','Kertas'];
      final harga=[...widget.daftarHarga]..sort((a,b){
        final ai=urutan.indexOf(a.nama), bi=urutan.indexOf(b.nama);
        return (ai<0?99:ai).compareTo(bi<0?99:bi);
      });
      widget.baris..clear()..addAll(harga.take(4).map((h)=>BarisSetoran(jenisSampahId:h.jenisSampahId,berat:'0')));
    }
  }
  @override
  void dispose(){for(final c in _controllers.values){c.dispose();}super.dispose();}
  TextEditingController _controller(BarisSetoran b)=>_controllers.putIfAbsent(b.kunci,()=>TextEditingController(text:b.berat));
  void _langkah(BarisSetoran b,double delta){
    final nilai=((b.beratKg??0)+delta).clamp(0,1000000).toDouble();
    b.berat=nilai.toStringAsFixed(2);
    _controller(b).text=b.berat;
    widget.onUbah();
    setState((){});
  }
  Future<void> _pilihWarga() async {
    final w=await tampilkanSheet<WargaNasabah>(context,gulir:false,(_)=>const _CariWargaSheet());
    if(w!=null){widget.onPilihWarga(w);}
  }
  Future<void> _tambah() async {
    final tersedia=widget.daftarHarga.where((h)=>!widget.baris.any((b)=>b.jenisSampahId==h.jenisSampahId)).toList();
    final id=await tampilkanSheet<int>(context,(_)=>Column(mainAxisSize:MainAxisSize.min,children:[
      const Padding(padding:EdgeInsets.all(16),child:Text('Tambah jenis sampah',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
      for(final h in tersedia) ListTile(title:Text(h.nama),subtitle:Text(h.hargaPerKg==null?'Harga belum diatur':'${rupiah(h.hargaPerKg)}/kg'),onTap:()=>Navigator.pop(context,h.jenisSampahId)),
    ]));
    if(id!=null&&mounted){widget.baris.add(BarisSetoran(jenisSampahId:id,berat:'0'));widget.onUbah();setState((){});}
  }
  @override
  Widget build(BuildContext context){
    final harga={for(final h in widget.daftarHarga) h.jenisSampahId:h.hargaPerKg};
    final total=TotalSetoran.hitung(widget.baris,harga,donasi:widget.donasi);
    Widget ringkas(String label,String isi,Color warna,Key key)=>Expanded(child:Container(
      padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
      decoration:BoxDecoration(color:warna,borderRadius:BorderRadius.circular(14)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:TemaAplikasi.redup)),const SizedBox(height:3),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(isi,key:key,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)))]),
    ));
    return Column(children:[
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,20),children:[
        Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:const BorderSide(color:TemaAplikasi.garis)),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
          const CircleAvatar(radius:22,backgroundColor:Color(0xFFE6EEFB),child:Text('W',style:TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF1D4ED8)))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.warga?.name??'Pilih warga',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700)),Text(widget.warga==null?'Cari nama, nomor HP, atau email':'No. nasabah ${widget.warga!.id} · saldo ${rupiah(widget.warga!.saldo)}',style:const TextStyle(fontSize:11,color:TemaAplikasi.redup))])),
          if(!widget.wargaTerkunci) TextButton(onPressed:widget.menyimpan?null:_pilihWarga,style:TextButton.styleFrom(backgroundColor:TemaAplikasi.latar,foregroundColor:TemaAplikasi.teks,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:const BorderSide(color:TemaAplikasi.garis))),child:Text(widget.warga==null?'Pilih':'Ganti')),
        ]))),
        const SizedBox(height:14),
        SegmenReferensi<bool>(nilai:widget.donasi,pilihan:const[(false,'Jual'),(true,'Donasi')],onUbah:widget.menyimpan?null:widget.onUbahTipe),
        const SizedBox(height:16),
        const Row(children:[Expanded(child:Text('Hasil timbangan',style:TextStyle(fontSize:14,fontWeight:FontWeight.w800))),Text('Langkah 0,5 kg',style:TextStyle(fontSize:11,color:TemaAplikasi.redup))]),
        const SizedBox(height:10),
        for(final b in widget.baris)
          Builder(builder:(context){
            final h=widget.daftarHarga.where((h)=>h.jenisSampahId==b.jenisSampahId).firstOrNull;
            final aktif=(b.beratKg??0)>0;
            return Padding(padding:const EdgeInsets.only(bottom:8),child:Container(
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:aktif?const Color(0xFFB7D6AB):TemaAplikasi.garis)),
              child:Row(children:[
                Container(width:44,height:44,padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:aktif?const Color(0xFFEDF4D6):TemaAplikasi.hijauLembut,borderRadius:BorderRadius.circular(14)),child:IlustrasiReferensi(ilustrasiJenis(h?.nama??''))),
                const SizedBox(width:10),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(h?.nama??'Jenis sampah',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text(h?.hargaPerKg==null?'Harga belum diatur':'${rupiah(h!.hargaPerKg)}/kg',style:const TextStyle(fontSize:11,color:TemaAplikasi.redup))])),
                const SizedBox(width:5),
                SizedBox(width:34,height:38,child:IconButton(tooltip:'Kurangi ${h?.nama}',padding:EdgeInsets.zero,style:IconButton.styleFrom(backgroundColor:TemaAplikasi.latar,side:const BorderSide(color:TemaAplikasi.garis),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11))),onPressed:widget.menyimpan?null:()=>_langkah(b,-.5),icon:const Icon(Icons.remove,size:18))),
                SizedBox(width:52,child:Column(children:[
                  TextFormField(key:ValueKey('berat-${b.kunci}'),controller:_controller(b),enabled:!widget.menyimpan,textAlign:TextAlign.center,keyboardType:const TextInputType.numberWithOptions(decimal:true),inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800),decoration:const InputDecoration(labelText:'Berat',floatingLabelBehavior:FloatingLabelBehavior.never,filled:false,border:InputBorder.none,enabledBorder:InputBorder.none,focusedBorder:InputBorder.none,contentPadding:EdgeInsets.symmetric(vertical:4)),onChanged:(v){b.berat=v;widget.onUbah();}),
                  const Text('kg',style:TextStyle(fontSize:10,color:TemaAplikasi.redup)),
                ])),
                SizedBox(width:34,height:38,child:IconButton(tooltip:'Tambah ${h?.nama}',padding:EdgeInsets.zero,style:IconButton.styleFrom(backgroundColor:TemaAplikasi.hijauPekat,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11))),onPressed:widget.menyimpan?null:()=>_langkah(b,.5),icon:const Icon(Icons.add,size:18))),
              ]),
            ));
          }),
        if(widget.baris.length<widget.daftarHarga.length)
          OutlinedButton.icon(onPressed:widget.menyimpan?null:_tambah,icon:const Icon(Icons.add,size:18),label:const Text('Tambah jenis sampah'),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(48),side:const BorderSide(color:Color(0xFFC9D2BE)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
      ])),
      Container(
        padding:const EdgeInsets.fromLTRB(20,14,20,12),
        decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(28)),boxShadow:[BoxShadow(color:Color(0x12101B15),blurRadius:25,offset:Offset(0,-8))]),
        child:SafeArea(top:false,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Row(children:[ringkas('Total berat',kg(total.totalKg),TemaAplikasi.hijauLembut,const Key('total-kg')),const SizedBox(width:8),ringkas(widget.donasi?'Kontribusi':'Masuk ke saldo',widget.donasi?'Donasi':rupiah(total.totalNilai),TemaAplikasi.latar,const Key('total-nilai'))]),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:widget.menyimpan?null:widget.onSimpan,style:FilledButton.styleFrom(backgroundColor:TemaAplikasi.hijauPekat,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),icon:const Icon(Icons.check_circle_outline,size:20),label:Text(widget.menyimpan?'Menyimpan...':widget.donasi?'Simpan donasi':'Simpan & tambah saldo')),
        ])),
      ),
    ]);
  }
}

class _CariWargaSheet extends ConsumerStatefulWidget {
  const _CariWargaSheet();

  @override
  ConsumerState<_CariWargaSheet> createState() => _CariWargaSheetState();
}

class _CariWargaSheetState extends ConsumerState<_CariWargaSheet> {
  List<WargaNasabah>? _hasil;
  bool _mencari = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _cari(null); // tanpa kata kunci: nasabah bank ini
  }

  Future<void> _cari(String? q) async {
    if (q != null && q.trim().length < 3) {
      setState(() => _galat = 'Ketik minimal 3 huruf.');
      return;
    }
    setState(() {
      _mencari = true;
      _galat = null;
    });
    try {
      final h = await ref
          .read(bankSampahRepositoryProvider)
          .cariNasabah(q?.trim());
      if (mounted) setState(() => _hasil = h.items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Cari warga (nama / HP / email)',
                  prefixIcon: const Icon(Icons.search),
                  errorText: _galat,
                ),
                onSubmitted: _cari,
              ),
            ),
            if (_mencari) const LinearProgressIndicator(),
            Expanded(
              child: (_hasil?.isEmpty ?? false)
                  ? const Kosong(
                      pesan: 'Warga tidak ditemukan.\nWarga baru perlu mendaftar sendiri lewat aplikasi.',
                    )
                  : ListView(
                      children: [
                        for (final w in _hasil ?? const <WargaNasabah>[])
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(w.name),
                            subtitle: Text(w.phone ?? w.email ?? ''),
                            trailing: Text(
                              w.sudahNasabah ? rupiah(w.saldo) : 'Baru',
                            ),
                            onTap: () => Navigator.pop(context, w),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
