import { useState } from 'react';
import { 
  AlertTriangle, 
  Ban, 
  CheckCircle2, 
  ExternalLink, 
  Eye, 
  Image as ImageIcon, 
  Phone, 
  Search, 
  ShieldAlert, 
  ShoppingBag, 
  Trash2, 
  User 
} from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { 
  ambilDaftarPrelovedDlh, 
  ambilLaporanPreloved, 
  hapusPrelovedDlh, 
  ubahStatusPreloved 
} from '../services/api';
import { useToast } from '../components/Toast';
import { 
  GagalMuat, 
  Input, 
  JudulHalaman, 
  Kartu, 
  Kosong, 
  Lencana, 
  Modal, 
  Paginasi, 
  Pilihan, 
  Skeleton, 
  Tombol 
} from '../components/ui';
import { formatRupiah, formatTanggal } from '../utils/format';

const KECAMATAN_TUBABA = [
  'Tulang Bawang Tengah',
  'Tumijajar',
  'Tulang Bawang Udik',
  'Gunung Terang',
  'Gunung Agung',
  'Way Kenanga',
  'Lambu Kibang',
  'Pagar Dewa',
  'Batu Putih',
];

const KATEGORI_PILIHAN = [
  'Pakaian',
  'Elektronik',
  'Buku & Alat Tulis',
  'Perabotan Rumah',
  'Peralatan Dapur',
  'Mainan & Hobi',
  'Olahraga',
  'Lainnya',
];

const LABEL_STATUS_LAPORAN = { 
  baru: 'Laporan baru', 
  ditindak: 'Sudah ditindak', 
  diabaikan: 'Diabaikan' 
};

const LAPORAN_AWAL = 3;

function KartuLaporan({ baris, sibuk, onUbahStatus, onHapus }) {
  const [semua, setSemua] = useState(false);
  const { barang: b, jumlah_laporan: jumlah, laporan } = baris;
  const tersembunyi = b.status === 'disembunyikan';
  const tampil = semua ? laporan : laporan.slice(0, LAPORAN_AWAL);

  return (
    <Kartu className="flex flex-col sm:flex-row gap-4 p-5">
      {b.foto?.[0] ? (
        <img src={b.foto[0]} alt={b.judul} className="w-24 h-24 rounded-2xl object-cover shrink-0 bg-slate-200 dark:bg-white/10" loading="lazy" />
      ) : (
        <div className="w-24 h-24 rounded-2xl shrink-0 bg-slate-200 dark:bg-white/10 flex items-center justify-center">
          <ImageIcon className="w-8 h-8 opacity-40" />
        </div>
      )}

      <div className="flex-1 min-w-0 space-y-1.5">
        <div className="flex items-start justify-between gap-2">
          <div className="font-semibold text-slate-900 dark:text-white truncate">{b.judul}</div>
          <Lencana warna={tersembunyi ? 'merah' : b.status === 'terjual' ? 'abu' : 'hijau'}>
            {tersembunyi ? 'Diban DLH' : b.status}
          </Lencana>
        </div>

        <div className="text-xs text-slate-500 dark:text-zinc-400">
          {formatRupiah(b.harga)} · {b.kategori} · {b.kecamatan} · Penjual: {b.penjual?.name || '-'}
        </div>

        <div className="text-sm font-semibold text-red-700 dark:text-red-300 pt-1">
          Dilaporkan {jumlah} warga
        </div>

        <ul className="space-y-2">
          {tampil.map((l) => (
            <li key={l.id} className="text-sm rounded-xl px-3 py-2 bg-amber-500/10 text-amber-900 dark:text-amber-200 border border-amber-500/20">
              <div className="break-words">“{l.alasan}”</div>
              <div className="mt-1 text-xs text-slate-500 dark:text-zinc-400">
                {l.pelapor?.name} · {formatTanggal(l.created_at)}
              </div>
            </li>
          ))}
        </ul>

        {laporan.length > LAPORAN_AWAL && (
          <button type="button" className="text-xs font-semibold text-emerald-700 dark:text-emerald-300 hover:underline" aria-expanded={semua} onClick={() => setSemua((v) => !v)}>
            {semua ? 'Tampilkan lebih sedikit' : `Lihat semua ${laporan.length} laporan`}
          </button>
        )}

        <div className="pt-2 flex flex-wrap items-center gap-2">
          {tersembunyi ? (
            <Tombol varian="sekunder" loading={sibuk} onClick={() => onUbahStatus(b, 'tersedia')}>
              <CheckCircle2 className="w-3.5 h-3.5" /> Buka Ban
            </Tombol>
          ) : (
            <Tombol varian="bahaya" loading={sibuk} onClick={() => onUbahStatus(b, 'disembunyikan')}>
              <Ban className="w-3.5 h-3.5" /> Ban Barang
            </Tombol>
          )}
          <Tombol varian="bahaya" className="bg-red-800 hover:bg-red-700" onClick={() => onHapus(b)}>
            <Trash2 className="w-3.5 h-3.5" /> Hapus
          </Tombol>
        </div>
      </div>
    </Kartu>
  );
}

export default function Moderasi() {
  const toast = useToast();
  // Tab Induk: 'katalog' (Monitoring semua barang warga) atau 'laporan' (Aduan scam)
  const [subTab, setSubTab] = useState(
    window.location.hash === '#moderasi' ? 'laporan' : 'katalog'
  );

  // --- State Monitoring Katalog Preloved ---
  const [filterBarang, setFilterBarang] = useState({
    q: '',
    status: 'semua',
    kategori: '',
    kecamatan: '',
    page: 1,
  });
  const [inputCari, setInputCari] = useState('');
  const [detailBarang, setDetailBarang] = useState(null);
  const [konfirmasiHapus, setKonfirmasiHapus] = useState(null);

  // --- State Laporan / Moderasi ---
  const [filterLaporan, setFilterLaporan] = useState({ status: 'baru', page: 1 });
  const [sibuk, setSibuk] = useState(null);

  // Fetch Katalog Barang Preloved
  const {
    data: dataBarang,
    loading: loadingBarang,
    error: errorBarang,
    refetch: refetchBarang,
  } = useFetch(
    () => ambilDaftarPrelovedDlh(filterBarang),
    `barang|${filterBarang.q}|${filterBarang.status}|${filterBarang.kategori}|${filterBarang.kecamatan}|${filterBarang.page}`
  );

  // Fetch Laporan Preloved
  const {
    data: dataLaporan,
    loading: loadingLaporan,
    error: errorLaporan,
    refetch: refetchLaporan,
  } = useFetch(
    () => ambilLaporanPreloved(filterLaporan),
    `laporan|${filterLaporan.status}|${filterLaporan.page}`
  );

  const daftarBarang = dataBarang?.data ?? [];
  const daftarLaporan = dataLaporan?.data ?? [];

  // Aksi Ban / Sembunyikan / Pulihkan
  const handleUbahStatus = async (barang, statusBaru) => {
    setSibuk(barang.id);
    try {
      await ubahStatusPreloved(barang.id, statusBaru);
      toast.sukses(
        statusBaru === 'disembunyikan'
          ? `Barang "${barang.judul}" berhasil di-ban (disembunyikan dari warga).`
          : `Barang "${barang.judul}" berhasil dipulihkan (tersedia kembali).`
      );
      refetchBarang();
      refetchLaporan();
      if (detailBarang?.id === barang.id) {
        setDetailBarang((b) => (b ? { ...b, status: statusBaru } : null));
      }
    } catch (err) {
      toast.gagal(err.message || 'Gagal mengubah status barang.');
    } finally {
      setSibuk(null);
    }
  };

  // Aksi Hapus Permanen Barang
  const handleHapus = async (barang) => {
    setSibuk(barang.id);
    try {
      await hapusPrelovedDlh(barang.id);
      toast.sukses(`Barang "${barang.judul}" berhasil dihapus secara permanen.`);
      setKonfirmasiHapus(null);
      if (detailBarang?.id === barang.id) setDetailBarang(null);
      refetchBarang();
      refetchLaporan();
    } catch (err) {
      toast.gagal(err.message || 'Gagal menghapus barang.');
    } finally {
      setSibuk(null);
    }
  };

  const handleCariSubmit = (e) => {
    e.preventDefault();
    setFilterBarang((f) => ({ ...f, q: inputCari.trim(), page: 1 }));
  };

  return (
    <>
      <JudulHalaman
        ikon={ShoppingBag}
        judul="Program Preloved DLH"
        keterangan="Satu induk kendali preloved warga: pantau seluruh barang bekas layak pakai dan tindak laporan dugaan penipuan / pelanggaran."
      />

      {/* Navigasi Tab Induk */}
      <div className="flex items-center gap-2 mb-6 border-b border-slate-200 dark:border-white/10 pb-3">
        <button
          onClick={() => {
            setSubTab('katalog');
            window.location.hash = 'preloved';
          }}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition ${
            subTab === 'katalog'
              ? 'bg-emerald-600 text-white shadow-sm'
              : 'text-slate-600 dark:text-zinc-300 hover:bg-slate-100 dark:hover:bg-white/5'
          }`}
        >
          <ShoppingBag className="w-4 h-4" />
          Katalog Monitoring Warga
          {dataBarang?.meta?.total !== undefined && (
            <span className="ml-1 px-2 py-0.5 text-xs bg-white/20 rounded-full">
              {dataBarang.meta.total}
            </span>
          )}
        </button>

        <button
          onClick={() => {
            setSubTab('laporan');
            window.location.hash = 'moderasi';
          }}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition ${
            subTab === 'laporan'
              ? 'bg-red-600 text-white shadow-sm'
              : 'text-slate-600 dark:text-zinc-300 hover:bg-slate-100 dark:hover:bg-white/5'
          }`}
        >
          <ShieldAlert className="w-4 h-4" />
          Laporan & Aduan Scam
          {dataLaporan?.meta?.total !== undefined && (
            <span className="ml-1 px-2 py-0.5 text-xs bg-white/20 rounded-full">
              {dataLaporan.meta.total}
            </span>
          )}
        </button>
      </div>

      {/* ============================================================ */}
      {/* TAB 1: MONITORING SELURUH KATALOG PRELOVED WARGA             */}
      {/* ============================================================ */}
      {subTab === 'katalog' && (
        <div className="space-y-6">
          {/* Baris Filter & Pencarian */}
          <Kartu className="p-4 sm:p-5">
            <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3">
              <form onSubmit={handleCariSubmit} className="flex-1 flex gap-2">
                <div className="relative flex-1 moderasi-cari">
                  <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <Input
                    className="pl-10"
                    placeholder="Cari judul barang, deskripsi, atau nama penjual..."
                    value={inputCari}
                    onChange={(e) => setInputCari(e.target.value)}
                  />
                </div>
                <Tombol type="submit" varian="utama">
                  Cari
                </Tombol>
              </form>

              <div className="flex flex-wrap items-center gap-2">
                {/* Filter Status */}
                <Pilihan
                  className="w-auto text-sm"
                  value={filterBarang.status}
                  onChange={(e) =>
                    setFilterBarang((f) => ({ ...f, status: e.target.value, page: 1 }))
                  }
                  aria-label="Filter status barang"
                >
                  <option value="semua">Semua Status</option>
                  <option value="tersedia">Tersedia</option>
                  <option value="terjual">Terjual</option>
                  <option value="disembunyikan">Disembunyikan (Diban)</option>
                </Pilihan>

                {/* Filter Kategori */}
                <Pilihan
                  className="w-auto text-sm"
                  value={filterBarang.kategori}
                  onChange={(e) =>
                    setFilterBarang((f) => ({ ...f, kategori: e.target.value, page: 1 }))
                  }
                  aria-label="Filter kategori"
                >
                  <option value="">Semua Kategori</option>
                  {KATEGORI_PILIHAN.map((k) => (
                    <option key={k} value={k}>
                      {k}
                    </option>
                  ))}
                </Pilihan>

                {/* Filter Kecamatan */}
                <Pilihan
                  className="w-auto text-sm"
                  value={filterBarang.kecamatan}
                  onChange={(e) =>
                    setFilterBarang((f) => ({ ...f, kecamatan: e.target.value, page: 1 }))
                  }
                  aria-label="Filter kecamatan"
                >
                  <option value="">Semua Kecamatan</option>
                  {KECAMATAN_TUBABA.map((kec) => (
                    <option key={kec} value={kec}>
                      {kec}
                    </option>
                  ))}
                </Pilihan>
              </div>
            </div>
          </Kartu>

          {/* Grid Barang Preloved */}
          {errorBarang ? (
            <Kartu>
              <GagalMuat error={errorBarang} onUlang={refetchBarang} />
            </Kartu>
          ) : loadingBarang && !dataBarang ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
              {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
                <Skeleton key={i} className="h-72 rounded-3xl" />
              ))}
            </div>
          ) : daftarBarang.length === 0 ? (
            <Kartu>
              <Kosong
                judul="Belum ada barang preloved"
                keterangan="Tidak ada barang warga yang cocok dengan kriteria pencarian / filter saat ini."
              />
            </Kartu>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
              {daftarBarang.map((b) => {
                const isBanned = b.status === 'disembunyikan';
                const isTerjual = b.status === 'terjual';

                return (
                  <Kartu
                    key={b.id}
                    className="flex flex-col p-4 overflow-hidden border border-slate-200/80 dark:border-white/10 hover:shadow-md transition"
                  >
                    {/* Gambar Barang */}
                    <div className="relative aspect-square w-full rounded-2xl overflow-hidden bg-slate-100 dark:bg-white/5 mb-3 group preloved-foto">
                      {b.foto?.[0] ? (
                        <img
                          src={b.foto[0]}
                          alt={b.judul}
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                          loading="lazy"
                        />
                      ) : (
                        <div className="w-full h-full flex flex-col items-center justify-center text-slate-400">
                          <ImageIcon className="w-10 h-10 mb-1 opacity-50" />
                          <span className="text-xs">Tanpa Foto</span>
                        </div>
                      )}

                      {/* Badge Status */}
                      <div className="absolute top-2.5 left-2.5">
                        <Lencana
                          warna={
                            isBanned ? 'merah' : isTerjual ? 'abu' : 'hijau'
                          }
                        >
                          {isBanned
                            ? 'Diban DLH'
                            : isTerjual
                            ? 'Terjual'
                            : 'Tersedia'}
                        </Lencana>
                      </div>

                      {/* Indikator Laporan Aduan */}
                      {b.jumlah_laporan > 0 && (
                        <div className="absolute top-2.5 right-2.5 bg-red-600 text-white text-xs font-bold px-2 py-0.5 rounded-full flex items-center gap-1 shadow-sm">
                          <AlertTriangle className="w-3 h-3" />
                          {b.jumlah_laporan} Laporan
                        </div>
                      )}
                    </div>

                    {/* Informasi Barang */}
                    <div className="flex-1 flex flex-col justify-between space-y-2">
                      <div>
                        <div className="flex items-center justify-between text-xs text-slate-500 dark:text-zinc-400 mb-1">
                          <span className="font-medium text-emerald-700 dark:text-emerald-400">
                            {b.kategori}
                          </span>
                          <span className="capitalize">{b.kondisi?.replace('_', ' ')}</span>
                        </div>

                        <h3 className="font-bold text-slate-900 dark:text-white text-base line-clamp-1">
                          {b.judul}
                        </h3>

                        <p className="text-sm font-extrabold text-emerald-600 dark:text-emerald-400 mt-1">
                          {formatRupiah(b.harga)}
                        </p>

                        <div className="mt-2 text-xs text-slate-500 dark:text-zinc-400 space-y-0.5">
                          <div className="flex items-center gap-1.5 truncate">
                            <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                            <span className="truncate">Warga: {b.penjual?.name || '-'}</span>
                          </div>
                          <div className="truncate text-xs text-slate-400">
                            Kec. {b.kecamatan} · {formatTanggal(b.created_at)}
                          </div>
                        </div>
                      </div>

                      {/* Tombol Aksi Kontrol DLH */}
                      <div className="pt-3 border-t border-slate-100 dark:border-white/10 flex items-center gap-1.5">
                        <Tombol
                          varian="sekunder"
                          className="flex-1 text-xs py-1.5 px-2"
                          onClick={() => setDetailBarang(b)}
                        >
                          <Eye className="w-3.5 h-3.5" /> Detail
                        </Tombol>

                        {/* Tombol Ban / Unban */}
                        {isBanned ? (
                          <Tombol
                            varian="utama"
                            className="text-xs py-1.5 px-2"
                            loading={sibuk === b.id}
                            title="Pulihkan dan tampilkan kembali ke warga"
                            onClick={() => handleUbahStatus(b, 'tersedia')}
                          >
                            <CheckCircle2 className="w-3.5 h-3.5" /> Buka Ban
                          </Tombol>
                        ) : (
                          <Tombol
                            varian="bahaya"
                            className="text-xs py-1.5 px-2"
                            loading={sibuk === b.id}
                            title="Sembunyikan / Ban barang ini dari warga"
                            onClick={() => handleUbahStatus(b, 'disembunyikan')}
                          >
                            <Ban className="w-3.5 h-3.5" /> Ban
                          </Tombol>
                        )}

                        {/* Tombol Hapus */}
                        <Tombol
                          varian="bahaya"
                          className="text-xs py-1.5 px-2 bg-red-800 hover:bg-red-700"
                          title="Hapus permanen barang ini"
                          onClick={() => setKonfirmasiHapus(b)}
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </Tombol>
                      </div>
                    </div>
                  </Kartu>
                );
              })}
            </div>
          )}

          {/* Paginasi Katalog */}
          <Paginasi
            meta={dataBarang?.meta}
            onHalaman={(page) => setFilterBarang((f) => ({ ...f, page }))}
          />
        </div>
      )}

      {/* ============================================================ */}
      {/* TAB 2: LAPORAN & ADUAN WARGA (MODERASI SCAM)                 */}
      {/* ============================================================ */}
      {subTab === 'laporan' && (
        <div className="space-y-6">
          <Kartu className="p-4 sm:p-5 flex items-center justify-between">
            <span className="text-sm text-slate-600 dark:text-zinc-300 font-medium">
              Filter status pengaduan:
            </span>
            <Pilihan
              className="w-auto text-sm"
              value={filterLaporan.status}
              onChange={(e) =>
                setFilterLaporan({ status: e.target.value, page: 1 })
              }
              aria-label="Status laporan"
            >
              {Object.entries(LABEL_STATUS_LAPORAN).map(([v, label]) => (
                <option key={v} value={v}>
                  {label}
                </option>
              ))}
            </Pilihan>
          </Kartu>

          {errorLaporan ? (
            <Kartu>
              <GagalMuat error={errorLaporan} onUlang={refetchLaporan} />
            </Kartu>
          ) : loadingLaporan && !dataLaporan ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {[1, 2, 3, 4].map((i) => (
                <Skeleton key={i} className="h-44 rounded-3xl" />
              ))}
            </div>
          ) : daftarLaporan.length === 0 ? (
            <Kartu>
              <Kosong
                judul="Tidak ada laporan pengaduan"
                keterangan={
                  filterLaporan.status === 'baru'
                    ? 'Bagus! Semua laporan dugaan penipuan / spam warga sudah ditinjau.'
                    : undefined
                }
              />
            </Kartu>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {daftarLaporan.map((baris) => (
                <KartuLaporan
                  key={baris.barang.id}
                  baris={baris}
                  sibuk={sibuk === baris.barang.id}
                  onUbahStatus={handleUbahStatus}
                  onHapus={setKonfirmasiHapus}
                />
              ))}
            </div>
          )}

          <Paginasi
            meta={dataLaporan?.meta}
            onHalaman={(page) => setFilterLaporan((f) => ({ ...f, page }))}
          />
        </div>
      )}

      {/* ============================================================ */}
      {/* MODAL DETAIL PRELOVED LENGKAP                                 */}
      {/* ============================================================ */}
      {detailBarang && (
        <Modal
          judul="Detail Barang Preloved Warga"
          lebar="max-w-2xl"
          onTutup={() => setDetailBarang(null)}
        >
          <div className="space-y-4">
            {/* Galeri Foto */}
            {detailBarang.foto && detailBarang.foto.length > 0 ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {detailBarang.foto.map((url, idx) => (
                  <a
                    key={idx}
                    href={url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="relative aspect-square rounded-2xl overflow-hidden bg-slate-100 group border border-slate-200"
                  >
                    <img
                      src={url}
                      alt={`${detailBarang.judul} foto ${idx + 1}`}
                      className="w-full h-full object-cover group-hover:scale-105 transition"
                    />
                    <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition flex items-center justify-center text-white">
                      <ExternalLink className="w-5 h-5" />
                    </div>
                  </a>
                ))}
              </div>
            ) : (
              <div className="py-8 bg-slate-100 dark:bg-white/5 rounded-2xl text-center text-sm text-slate-400">
                Tidak ada foto terlampir.
              </div>
            )}

            {/* Info Utama */}
            <div className="border-t border-slate-200 dark:border-white/10 pt-4 space-y-2">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-xl font-bold text-slate-900 dark:text-white">
                    {detailBarang.judul}
                  </h3>
                  <p className="text-lg font-extrabold text-emerald-600 dark:text-emerald-400">
                    {formatRupiah(detailBarang.harga)}
                  </p>
                </div>
                <Lencana
                  warna={
                    detailBarang.status === 'disembunyikan'
                      ? 'merah'
                      : detailBarang.status === 'terjual'
                      ? 'abu'
                      : 'hijau'
                  }
                >
                  {detailBarang.status === 'disembunyikan'
                    ? 'Diban DLH'
                    : detailBarang.status}
                </Lencana>
              </div>

              <div className="flex flex-wrap gap-2 text-xs text-slate-500 pt-1">
                <span className="px-2.5 py-1 bg-slate-100 dark:bg-white/10 rounded-lg">
                  Kategori: <b>{detailBarang.kategori}</b>
                </span>
                <span className="px-2.5 py-1 bg-slate-100 dark:bg-white/10 rounded-lg">
                  Kondisi: <b>{detailBarang.kondisi?.replace('_', ' ')}</b>
                </span>
                <span className="px-2.5 py-1 bg-slate-100 dark:bg-white/10 rounded-lg">
                  Kecamatan: <b>{detailBarang.kecamatan}</b>
                </span>
              </div>

              {/* Deskripsi */}
              <div className="pt-2">
                <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Deskripsi Barang
                </div>
                <p className="text-sm text-slate-700 dark:text-zinc-200 whitespace-pre-line leading-relaxed bg-slate-50 dark:bg-white/5 p-3 rounded-xl border border-slate-200/60 dark:border-white/10">
                  {detailBarang.deskripsi || 'Tidak ada deskripsi tambahan.'}
                </p>
              </div>

              {/* Data Penjual Warga */}
              <div className="pt-2">
                <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Informasi Penjual (Warga)
                </div>
                <div className="flex items-center justify-between p-3 rounded-xl bg-slate-100/70 dark:bg-white/5">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-emerald-600/10 text-emerald-700 dark:text-emerald-300 flex items-center justify-center font-bold">
                      {detailBarang.penjual?.name?.charAt(0) || 'W'}
                    </div>
                    <div>
                      <div className="font-semibold text-sm text-slate-900 dark:text-white">
                        {detailBarang.penjual?.name || 'Warga'}
                      </div>
                      <div className="text-xs text-slate-500 flex items-center gap-1">
                        <Phone className="w-3 h-3" />
                        {detailBarang.penjual?.phone || 'Nomor HP tidak dicantumkan'}
                      </div>
                    </div>
                  </div>
                  <div className="text-right text-xs text-slate-400">
                    Diunggah {formatTanggal(detailBarang.created_at)}
                  </div>
                </div>
              </div>
            </div>

            {/* Aksi DLH di Modal */}
            <div className="border-t border-slate-200 dark:border-white/10 pt-4 flex items-center justify-end gap-2">
              <Tombol varian="sekunder" onClick={() => setDetailBarang(null)}>
                Tutup
              </Tombol>

              {detailBarang.status === 'disembunyikan' ? (
                <Tombol
                  varian="utama"
                  loading={sibuk === detailBarang.id}
                  onClick={() => handleUbahStatus(detailBarang, 'tersedia')}
                >
                  <CheckCircle2 className="w-4 h-4" /> Buka Ban (Tampilkan)
                </Tombol>
              ) : (
                <Tombol
                  varian="bahaya"
                  loading={sibuk === detailBarang.id}
                  onClick={() => handleUbahStatus(detailBarang, 'disembunyikan')}
                >
                  <Ban className="w-4 h-4" /> Ban (Sembunyikan)
                </Tombol>
              )}

              <Tombol
                varian="bahaya"
                className="bg-red-800 hover:bg-red-700"
                onClick={() => setKonfirmasiHapus(detailBarang)}
              >
                <Trash2 className="w-4 h-4" /> Hapus Barang
              </Tombol>
            </div>
          </div>
        </Modal>
      )}

      {/* ============================================================ */}
      {/* MODAL KONFIRMASI HAPUS PERMANEN                              */}
      {/* ============================================================ */}
      {konfirmasiHapus && (
        <Modal
          judul="Konfirmasi Hapus Barang"
          lebar="max-w-md"
          onTutup={() => setKonfirmasiHapus(null)}
        >
          <div className="space-y-4">
            <div className="flex items-start gap-3 p-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-700 dark:text-red-300">
              <AlertTriangle className="w-6 h-6 shrink-0 mt-0.5" />
              <div className="text-sm">
                Apakah Anda yakin ingin menghapus barang <b>"{konfirmasiHapus.judul}"</b> milik{' '}
                <b>{konfirmasiHapus.penjual?.name}</b> secara permanen?
                <p className="mt-1 text-xs opacity-80">
                  Tindakan ini tidak dapat dibatalkan. Seluruh foto dan riwayat percakapan barang ini akan dihapus.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <Tombol varian="sekunder" onClick={() => setKonfirmasiHapus(null)}>
                Batal
              </Tombol>
              <Tombol
                varian="bahaya"
                loading={sibuk === konfirmasiHapus.id}
                onClick={() => handleHapus(konfirmasiHapus)}
              >
                Ya, Hapus Permanen
              </Tombol>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
