import '../format.dart';
import 'transaksi.dart';

const kondisiBarang = {
  'baru': 'Baru',
  'seperti_baru': 'Seperti baru',
  'bekas_baik': 'Bekas, masih baik',
  'bekas': 'Bekas',
};

/// Kategori dropdown di aplikasi (backend menerima teks bebas, maks. 50).
const kategoriPreloved = ['Pakaian', 'Elektronik', 'Perabot', 'Buku', 'Mainan', 'Kerajinan Daur Ulang', 'Lainnya'];

const kecamatanTubaba = [
  'Batu Putih', 'Gunung Agung', 'Gunung Terang', 'Lambu Kibang', 'Pagar Dewa',
  'Tulang Bawang Tengah', 'Tulang Bawang Udik', 'Tumijajar', 'Way Kenanga',
];

class BarangPreloved {
  const BarangPreloved({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.kategori,
    required this.kondisi,
    required this.harga,
    required this.kecamatan,
    required this.foto,
    required this.status,
    required this.milikSaya,
    this.penjual,
    this.createdAt,
  });

  final int id;
  final String judul;
  final String deskripsi;
  final String kategori;
  final String kondisi;
  final double harga;
  final String kecamatan;
  final List<String> foto;

  /// tersedia | terjual | disembunyikan
  final String status;
  final bool milikSaya;
  final Kontak? penjual;
  final DateTime? createdAt;

  bool get tersedia => status == 'tersedia';

  factory BarangPreloved.dariJson(Map<String, dynamic> json) => BarangPreloved(
        id: json['id'] as int,
        judul: '${json['judul']}',
        deskripsi: '${json['deskripsi'] ?? ''}',
        kategori: '${json['kategori'] ?? ''}',
        kondisi: '${json['kondisi']}',
        harga: keDouble(json['harga']),
        kecamatan: '${json['kecamatan'] ?? ''}',
        foto: (json['foto'] as List? ?? const []).map((e) => '$e').toList(),
        status: '${json['status']}',
        milikSaya: json['milik_saya'] == true,
        penjual: Kontak.dariJson(json['penjual']),
        createdAt: keTanggal(json['created_at']),
      );
}

class PesanChat {
  const PesanChat({
    required this.id,
    required this.milikSaya,
    this.isi,
    this.tawaranHarga,
    this.dibacaAt,
    this.createdAt,
  });

  final int id;
  final bool milikSaya;
  final String? isi;
  final double? tawaranHarga;
  final DateTime? dibacaAt;
  final DateTime? createdAt;

  bool get tawaran => tawaranHarga != null;

  factory PesanChat.dariJson(Map<String, dynamic> json) => PesanChat(
        id: json['id'] as int,
        milikSaya: json['milik_saya'] == true,
        isi: json['isi'] as String?,
        tawaranHarga: keDoubleAtauNull(json['tawaran_harga']),
        dibacaAt: keTanggal(json['dibaca_at']),
        createdAt: keTanggal(json['created_at']),
      );
}

class RingkasBarang {
  const RingkasBarang({required this.id, required this.judul, required this.harga, required this.status, this.foto});

  final int id;
  final String judul;
  final double harga;
  final String status;
  final String? foto;

  factory RingkasBarang.dariJson(Map<String, dynamic> json) => RingkasBarang(
        id: json['id'] as int,
        judul: '${json['judul']}',
        harga: keDouble(json['harga']),
        status: '${json['status']}',
        foto: json['foto'] as String?,
      );
}

class Percakapan {
  const Percakapan({
    required this.id,
    required this.peranSaya,
    required this.barang,
    required this.lawanBicara,
    this.pesanTerakhir,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  final int id;

  /// pembeli | penjual
  final String peranSaya;
  final RingkasBarang barang;
  final Kontak lawanBicara;
  final PesanChat? pesanTerakhir;
  final int unreadCount;
  final DateTime? lastMessageAt;

  bool get sayaPenjual => peranSaya == 'penjual';

  factory Percakapan.dariJson(Map<String, dynamic> json) => Percakapan(
        id: json['id'] as int,
        peranSaya: '${json['peran_saya']}',
        barang: RingkasBarang.dariJson((json['barang'] as Map).cast()),
        lawanBicara: Kontak.dariJson(json['lawan_bicara'])!,
        pesanTerakhir: json['pesan_terakhir'] is Map ? PesanChat.dariJson((json['pesan_terakhir'] as Map).cast()) : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        lastMessageAt: keTanggal(json['last_message_at']),
      );
}
