import { ArrowRight, CalendarDays, Newspaper } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilBerita } from '../services/api';
import { KATEGORI_BERITA, tanggalPanjang, urlBerita } from '../utils/format';
import Muncul from './Muncul';
import { GagalMuat, Kosong, Skeleton } from './ui';

export function FotoBerita({ src }) {
  return (
    <span className="berita-foto">
      {src ? <img src={src} alt="" loading="lazy" decoding="async" /> : <Newspaper size={34} strokeWidth={1.5} aria-hidden="true" />}
    </span>
  );
}

export function KartuBerita({ berita, urutan = 0 }) {
  return (
    <Muncul as="a" className="berita-kartu" href={urlBerita(berita)} urutan={urutan}>
      <span className="berita-sampul">
        <FotoBerita src={berita.foto} />
        <span className="berita-label">{KATEGORI_BERITA[berita.kategori] ?? berita.kategori}</span>
      </span>
      <span className="berita-teks">
        <strong>{berita.judul}</strong>
        <span className="berita-ringkasan">{berita.ringkasan}</span>
        <span className="berita-kaki-kartu">
          <span>Oleh <b>DLH Tubaba</b> · {tanggalPanjang(berita.diterbitkan_at)}</span>
          <em>Baca <ArrowRight size={14} aria-hidden="true" /></em>
        </span>
      </span>
    </Muncul>
  );
}

// Bagian ringkas di beranda; daftar lengkap dan isi artikel ada di halaman berita
export default function BeritaBeranda() {
  const { data, loading, error, refetch } = useFetch(() => ambilBerita());
  const daftar = data?.data ?? [];
  const besar = daftar.slice(0, 2);
  const kecil = daftar.slice(2, 4);

  return (
    <section className="beranda-bagian" id="berita">
      <div className="beranda-wadah">
        <Muncul as="header" className="alur-kepala">
          <span>Kabar &amp; Informasi</span>
          <h2>Berita Terbaru</h2>
          <p>Ikuti kegiatan, pengumuman, dan kabar seputar bank sampah di Tulang Bawang Barat.</p>
        </Muncul>

        {error ? (
          <GagalMuat error={error} onUlang={refetch} />
        ) : loading && !data ? (
          <div className="berita-grid" aria-label="Memuat berita">
            {[0, 1].map((i) => <Skeleton key={i} className="berita-skeleton" />)}
          </div>
        ) : !daftar.length ? (
          <Kosong judul="Belum ada berita" keterangan="Berita dari Dinas Lingkungan Hidup akan tampil di sini." />
        ) : (
          <>
            <div className={`berita-grid ${kecil.length ? 'ada-samping' : ''}`}>
              {besar.map((b, i) => <KartuBerita berita={b} urutan={i} key={b.id} />)}
              {kecil.length > 0 && (
                <div className="berita-samping">
                  {kecil.map((b, i) => (
                    <Muncul as="a" className="berita-kartu-kecil" href={urlBerita(b)} urutan={i + 2} key={b.id}>
                      <FotoBerita src={b.foto} />
                      <span>
                        <strong>{b.judul}</strong>
                        <small><CalendarDays size={13} aria-hidden="true" /> {tanggalPanjang(b.diterbitkan_at)}<b>Baca <ArrowRight size={13} aria-hidden="true" /></b></small>
                      </span>
                    </Muncul>
                  ))}
                </div>
              )}
            </div>
            <div className="berita-semua-aksi">
              <a href="#/berita" className="ui-button ui-button-primary beranda-tombol">
                <Newspaper size={17} aria-hidden="true" /> Lihat Semua Berita <ArrowRight size={17} aria-hidden="true" />
              </a>
            </div>
          </>
        )}
      </div>
    </section>
  );
}
