import { useEffect, useState } from 'react';
import { ArrowRight, CalendarDays, Check, ChevronRight, Clock, Eye, Link2, Newspaper, PenLine, Search, Share2, ShoppingBag } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilBerita, ambilDetailBerita } from '../services/api';
import { FotoBerita, KartuBerita } from '../components/BeritaBeranda';
import { GagalMuat, Kosong, Skeleton, Tombol } from '../components/ui';
import { formatAngka, tanggalPanjang, urlBerita } from '../utils/format';
import { uraiIsiBerita } from '../utils/isiBerita';

const KATA_PER_MENIT = 200;

export function DaftarBerita() {
  const [ketik, setKetik] = useState('');
  const [q, setQ] = useState('');
  const [halaman, setHalaman] = useState(1);
  const [ulang, setUlang] = useState(0);
  const [baris, setBaris] = useState([]);
  const [meta, setMeta] = useState(null);
  const [gagal, setGagal] = useState(null);
  const [selesai, setSelesai] = useState(null);
  const permintaan = [q, halaman, ulang].join('|');
  const memuat = selesai !== permintaan;
  const galat = memuat ? null : gagal;

  useEffect(() => {
    const jeda = setTimeout(() => {
      setQ(ketik.trim());
      setHalaman(1);
    }, 350);
    return () => clearTimeout(jeda);
  }, [ketik]);

  useEffect(() => {
    let batal = false;
    ambilBerita({ q, page: halaman })
      .then((res) => {
        if (batal) return;
        setBaris((lama) => (halaman === 1 ? res.data : [...lama, ...res.data.filter((b) => !lama.some((l) => l.id === b.id))]));
        setMeta(res.meta);
        setGagal(null);
      })
      .catch((e) => !batal && setGagal(e))
      .finally(() => !batal && setSelesai(permintaan));
    return () => {
      batal = true;
    };
  }, [permintaan, q, halaman]);

  return (
    <>
      <section className="warta-hero">
        <img src="/beranda/hero.webp" alt="" fetchPriority="high" />
        <div className="beranda-wadah">
          <span className="warta-lencana"><Newspaper size={15} aria-hidden="true" /> Kabar &amp; Informasi</span>
          <h1>Warta &amp; Kegiatan <span>Bank Sampah</span></h1>
          <p>Ikuti perkembangan kegiatan, pengumuman, dan kabar bank sampah di Kabupaten Tulang Bawang Barat.</p>
        </div>
      </section>

      <section className="warta-daftar">
        <div className="beranda-wadah">
          <label className="warta-cari">
            <Search size={18} aria-hidden="true" />
            <input type="search" aria-label="Cari berita atau kegiatan" placeholder="Cari berita atau kegiatan…" value={ketik} onChange={(e) => setKetik(e.target.value)} />
          </label>

          {galat && !baris.length ? (
            <GagalMuat error={galat} onUlang={() => setUlang((n) => n + 1)} />
          ) : memuat && (halaman === 1 || !baris.length) ? (
            <div className="warta-grid" aria-label="Memuat berita">
              {[0, 1, 2].map((i) => <Skeleton key={i} className="berita-skeleton" />)}
            </div>
          ) : !baris.length ? (
            <Kosong
              judul={q ? 'Berita tidak ditemukan' : 'Belum ada berita'}
              keterangan={q ? 'Coba kata kunci lain.' : 'Berita dari Dinas Lingkungan Hidup akan tampil di sini.'}
            />
          ) : (
            <>
              <div className="warta-grid">
                {baris.map((b, i) => <KartuBerita berita={b} urutan={i % 3} key={b.id} />)}
              </div>
              {galat && <GagalMuat error={galat} onUlang={() => setUlang((n) => n + 1)} />}
              {!galat && meta && meta.current_page < meta.last_page && (
                <div className="etalase-lagi">
                  <Tombol varian="sekunder" loading={memuat} onClick={() => setHalaman((h) => h + 1)}>Muat lebih banyak</Tombol>
                </div>
              )}
            </>
          )}
        </div>
      </section>
    </>
  );
}

function BeritaLainnya({ id }) {
  const { data } = useFetch(() => ambilBerita());
  const lainnya = (data?.data ?? []).filter((b) => b.id !== id).slice(0, 3);

  return (
    <div className="artikel-kotak">
      <h2><Newspaper size={19} aria-hidden="true" /> Berita Lainnya</h2>
      {lainnya.length === 0 && <p className="artikel-kosong">{data ? 'Belum ada berita lain.' : 'Memuat…'}</p>}
      {lainnya.map((b) => (
        <a className="artikel-lain" href={urlBerita(b)} key={b.id}>
          <FotoBerita src={b.foto} />
          <span>
            <small>{tanggalPanjang(b.diterbitkan_at)}</small>
            <strong>{b.judul}</strong>
          </span>
        </a>
      ))}
      <a className="artikel-semua" href="#/berita">Lihat Semua Berita <ArrowRight size={14} aria-hidden="true" /></a>
    </div>
  );
}

const IKON_MEREK = {
  whatsapp: 'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z',
  facebook: 'M14 13.5h2.5l1-4H14v-2c0-1.03 0-2 2-2h1.5V2.14c-.326-.043-1.557-.14-2.857-.14C11.928 2 10 3.657 10 6.7v2.8H7v4h3V22h4z',
  twitter: 'M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z',
};

function IkonMerek({ nama }) {
  return <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d={IKON_MEREK[nama]} /></svg>;
}

// Clipboard API hanya tersedia di https dan localhost
async function salinTeks(teks) {
  if (navigator.clipboard) return navigator.clipboard.writeText(teks);
  const area = document.createElement('textarea');
  area.value = teks;
  area.style.position = 'fixed';
  area.style.opacity = '0';
  document.body.append(area);
  area.select();
  const berhasil = document.execCommand('copy');
  area.remove();
  if (!berhasil) throw new Error('Gagal menyalin');
  return undefined;
}

function BagikanBerita({ judul }) {
  const [status, setStatus] = useState(null); // null | 'ok' | 'gagal'
  const url = window.location.href;
  const alamat = encodeURIComponent(url);
  const teks = encodeURIComponent(judul);

  useEffect(() => {
    if (!status) return undefined;
    const jeda = setTimeout(() => setStatus(null), 2500);
    return () => clearTimeout(jeda);
  }, [status]);

  const salin = () => salinTeks(url).then(() => setStatus('ok')).catch(() => setStatus('gagal'));

  return (
    <div className="bagikan">
      <h2><Share2 size={15} aria-hidden="true" /> Bagikan Berita Ini:</h2>
      <div>
        <a className="whatsapp" href={`https://wa.me/?text=${encodeURIComponent(`${judul} ${url}`)}`} target="_blank" rel="noopener noreferrer"><IkonMerek nama="whatsapp" /> WhatsApp</a>
        <a className="facebook" href={`https://www.facebook.com/sharer/sharer.php?u=${alamat}`} target="_blank" rel="noopener noreferrer"><IkonMerek nama="facebook" /> Facebook</a>
        <a className="twitter" href={`https://twitter.com/intent/tweet?text=${teks}&url=${alamat}`} target="_blank" rel="noopener noreferrer"><IkonMerek nama="twitter" /> Twitter</a>
        <button type="button" onClick={salin} aria-live="polite">
          {status === 'ok' ? <Check size={15} aria-hidden="true" /> : <Link2 size={15} aria-hidden="true" />}
          {status === 'ok' ? 'Tautan tersalin' : status === 'gagal' ? 'Gagal menyalin' : 'Salin Tautan'}
        </button>
      </div>
    </div>
  );
}

function IsiArtikel({ isi }) {
  return (
    <div className="artikel-isi">
      {uraiIsiBerita(isi).map((blok, i) => {
        if (blok.jenis === 'subjudul') return <h2 key={i}>{blok.teks}</h2>;
        if (blok.jenis === 'kutipan') return <blockquote key={i}>{blok.teks}</blockquote>;
        return <p key={i}>{blok.teks}</p>;
      })}
    </div>
  );
}

export function ArtikelBerita({ id, onLihatPreloved }) {
  const { data, loading, error, refetch } = useFetch(() => ambilDetailBerita(id), id);
  const berita = data?.data?.id === id ? data.data : null;
  const menit = berita ? Math.max(1, Math.ceil(berita.isi.trim().split(/\s+/).length / KATA_PER_MENIT)) : 0;

  return (
    <>
      <div className="artikel-remah">
        <nav className="beranda-wadah" aria-label="Lokasi halaman">
          <a href="#">Beranda</a>
          <ChevronRight size={14} aria-hidden="true" />
          <a href="#/berita">Berita</a>
          {berita && <ChevronRight size={14} aria-hidden="true" />}
          {berita && <span>{berita.judul}</span>}
        </nav>
      </div>

      <div className="beranda-wadah artikel-tata">
        <article className="artikel-utama">
          {error ? (
            <GagalMuat error={error} onUlang={refetch} />
          ) : loading || !berita ? (
            <>
              <Skeleton className="artikel-skeleton-judul" />
              <Skeleton className="artikel-skeleton-foto" />
            </>
          ) : (
            <>
              <div className="artikel-info">
                <span className="artikel-penulis"><PenLine size={14} aria-hidden="true" /> DLH Tubaba</span>
                <span><CalendarDays size={15} aria-hidden="true" /> {tanggalPanjang(berita.diterbitkan_at)}</span>
                <span><Clock size={15} aria-hidden="true" /> {menit} mnt baca</span>
                <span><Eye size={15} aria-hidden="true" /> {formatAngka(berita.dibaca)} dibaca</span>
              </div>
              <h1>{berita.judul}</h1>
              {berita.foto && <img className="artikel-foto" src={berita.foto} alt="" decoding="async" />}
              <p className="artikel-pembuka">{berita.ringkasan}</p>
              <IsiArtikel isi={berita.isi} />
              <BagikanBerita judul={berita.judul} />
            </>
          )}
        </article>

        <aside className="artikel-samping">
          <BeritaLainnya id={id} />
          <div className="artikel-ajakan">
            <span><ShoppingBag size={22} aria-hidden="true" /></span>
            <h2>Preloved Warga</h2>
            <p>Lihat barang bekas layak pakai yang sedang dijual warga Tubaba.</p>
            <button type="button" onClick={onLihatPreloved}>Lihat Barang</button>
          </div>
        </aside>
      </div>
    </>
  );
}
