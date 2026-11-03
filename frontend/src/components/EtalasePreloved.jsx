import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ArrowRight, CalendarDays, ChevronLeft, ChevronRight, MapPin, MessageCircle, Search } from 'lucide-react';
import { ambilEtalasePreloved } from '../services/api';
import useLayarHp from '../hooks/useLayarHp';
import { formatAngka, formatRupiah } from '../utils/format';
import { gayaKartu, posisiCincin, ukuranKarusel, ulangiBarang } from '../utils/karusel';
import Muncul from './Muncul';
import useDiamDiLuarLayar from '../hooks/useDiamDiLuarLayar';
import { GagalMuat, Kosong, Modal, Pilihan, Skeleton } from './ui';

const KONDISI = { baru: 'Baru', seperti_baru: 'Seperti baru', bekas_baik: 'Bekas baik', bekas: 'Bekas' };
const labelKondisi = (kondisi) => KONDISI[kondisi] ?? kondisi;
const tanggalTayang = (iso) => new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });

function DetailBarang({ barang, onTutup }) {
  const [foto, setFoto] = useState(0);
  const src = barang.foto[foto];
  return (
    <Modal judul={barang.judul} polos onTutup={onTutup} lebar="max-w-4xl">
      <div className="etalase-detail">
        <div className="etalase-galeri">
          <div className="etalase-panggung">
            {src ? (
              <>
                <img className="etalase-panggung-latar" src={src} alt="" decoding="async" />
                <img className="etalase-panggung-foto" src={src} alt={barang.judul} decoding="async" />
              </>
            ) : 'Foto belum tersedia'}
          </div>
          {barang.foto.length > 1 && (
            <div className="etalase-thumbs">
              {barang.foto.map((url, i) => (
                <button type="button" key={url} aria-label={'Foto ' + (i + 1)} aria-pressed={i === foto} onClick={() => setFoto(i)}>
                  <img src={url} alt="" loading="lazy" decoding="async" />
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="etalase-rincian">
          <div className="etalase-lencana">
            <span className="utama">{labelKondisi(barang.kondisi)}</span>
            <span>{barang.kategori}</span>
          </div>
          <p className="etalase-detail-judul" aria-hidden="true">{barang.judul}</p>
          <strong className="etalase-harga">{formatRupiah(barang.harga)}</strong>
          <ul className="etalase-fakta">
            <li><MapPin size={16} aria-hidden="true" /> {barang.kecamatan}</li>
            <li><CalendarDays size={16} aria-hidden="true" /> Ditayangkan {tanggalTayang(barang.created_at)}</li>
          </ul>
          <div>
            <h3>Deskripsi</h3>
            <p className="etalase-deskripsi">{barang.deskripsi}</p>
          </div>
          <div className="etalase-cara-beli">
            <MessageCircle size={20} aria-hidden="true" />
            <div>
              <strong>Tertarik dengan barang ini?</strong>
              Chat penjual lewat aplikasi warga Bank Sampah Tubaba. Pembayaran dilakukan secara COD.
            </div>
          </div>
        </div>
      </div>
    </Modal>
  );
}

const JEDA_LANJUT_MS = 7000;

// Halaman pertama tanpa filter disimpan, agar kunjungan berikutnya langsung tampil walau server lambat.
// Isinya data publik etalase, tanpa data penjual.
const KUNCI_ETALASE = 'TUBABA_ETALASE';

function etalaseTerakhir() {
  try {
    return JSON.parse(localStorage.getItem(KUNCI_ETALASE));
  } catch {
    return null;
  }
}

// Kartu bergeser sendiri, berhenti saat dipencet, dan lanjut lagi setelah beberapa detik. Bisa juga digeser
// dengan mouse, jari, trackpad, keyboard, atau tombol. Kartu mengikuti tarikan lalu jatuh ke posisi
// terdekat. Daftar berputar, jadi kartu samping tetap ada walau barangnya sedikit.
function KaruselBarang({ barang, indeks, total, dijeda, onGeser, onBuka }) {
  const hp = useLayarHp();
  const panggung = useRef(null);
  const seret = useRef(null);
  const jedaRoda = useRef(0);
  const [lebarWadah, setLebarWadah] = useState(0);
  const [tarikan, setTarikan] = useState(0);
  const [menyeret, setMenyeret] = useState(false);
  const [berjalan, setBerjalan] = useState(() => !window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  const [ditahan, setDitahan] = useState(false);
  const [sentuhan, setSentuhan] = useState(0);
  const [terlihat, setTerlihat] = useState(false);
  const n = barang.length;
  const ukuran = ukuranKarusel(lebarWadah, hp, n);
  const cincin = ulangiBarang(barang, ukuran.pasangan ? 6 : 5);
  const aktif = ((indeks % n) + n) % n;

  useLayoutEffect(() => {
    const el = panggung.current;
    const ukur = () => setLebarWadah(el.clientWidth);
    ukur();
    const pengamat = new ResizeObserver(ukur);
    pengamat.observe(el);
    return () => pengamat.disconnect();
  }, []);

  useEffect(() => {
    const pengamat = new IntersectionObserver(([masuk]) => setTerlihat(masuk.isIntersecting), { threshold: 0.3 });
    pengamat.observe(panggung.current);
    return () => pengamat.disconnect();
  }, []);

  // Waktu berasal dari animasi titik aktif, jadi jeda dan isi titik selalu sejalan
  const jeda = !terlihat || ditahan || menyeret;

  const henti = () => {
    setBerjalan(false);
    setSentuhan((n) => n + 1);
  };
  const pencet = (arah) => {
    henti();
    onGeser(arah);
  };

  // Tanpa tombol jeda: lanjut sendiri setelah tidak disentuh, kecuali detail barang sedang terbuka
  useEffect(() => {
    if (berjalan || dijeda || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;
    const tunda = setTimeout(() => setBerjalan(true), JEDA_LANJUT_MS);
    return () => clearTimeout(tunda);
  }, [berjalan, dijeda, sentuhan]);

  const mulai = (e) => {
    henti();
    if (n < 2 || (e.pointerType === 'mouse' && e.button !== 0)) return;
    seret.current = { x: e.clientX, id: e.pointerId, jalan: false, dx: 0 };
  };
  const gerak = (e) => {
    const s = seret.current;
    if (!s) return;
    s.dx = e.clientX - s.x;
    if (!s.jalan && Math.abs(s.dx) > 6) {
      s.jalan = true;
      panggung.current.setPointerCapture(s.id);
      setMenyeret(true);
    }
    if (s.jalan) setTarikan(s.dx / ukuran.langkah);
  };
  const lepas = (e) => {
    const s = seret.current;
    seret.current = null;
    if (!s?.jalan) return;
    // Klik yang menyusul seretan tidak boleh membuka detail
    panggung.current.dataset.baruSeret = '1';
    setTimeout(() => { if (panggung.current) delete panggung.current.dataset.baruSeret; }, 0);
    setMenyeret(false);
    setTarikan(0);
    if (e.type === 'pointercancel') return;
    const posisi = s.dx / ukuran.langkah;
    const lompat = Math.abs(s.dx) > 40 && Math.abs(posisi) < 0.5 ? -Math.sign(s.dx) : -Math.round(posisi);
    if (lompat) onGeser(lompat);
  };
  const roda = (e) => {
    if (n < 2 || Math.abs(e.deltaX) <= Math.abs(e.deltaY) || Math.abs(e.deltaX) < 20) return;
    if (e.timeStamp - jedaRoda.current < 450) return;
    jedaRoda.current = e.timeStamp;
    pencet(Math.sign(e.deltaX));
  };
  const panah = (e) => {
    if (n < 2) return;
    if (e.key === 'ArrowLeft') pencet(-1);
    if (e.key === 'ArrowRight') pencet(1);
  };

  return (
    <>
      <div
        ref={panggung}
        className={'etalase-karusel' + (menyeret ? ' menyeret' : '')}
        style={{ height: ukuran.tinggi }}
        role="group"
        aria-roledescription="carousel"
        aria-label="Barang preloved warga"
        onPointerDown={mulai}
        onPointerMove={gerak}
        onPointerUp={lepas}
        onPointerCancel={lepas}
        onWheel={roda}
        onKeyDown={panah}
        onPointerEnter={(e) => { if (e.pointerType === 'mouse') setDitahan(true); }}
        onPointerLeave={(e) => { if (e.pointerType === 'mouse') setDitahan(false); }}
        onFocus={() => setDitahan(true)}
        onBlur={() => setDitahan(false)}
      >
        {lebarWadah > 0 && cincin.map((b, k) => {
          const dasar = n < 2 ? 0 : posisiCincin(k, indeks, cincin.length, ukuran.pasangan);
          const p = dasar + tarikan;
          const g = gayaKartu(p, ukuran);
          const utuh = dasar === 0 || (ukuran.pasangan && dasar === 1);
          const samping = !utuh && g.tampak > 0;
          return (
            <button
              type="button"
              className={'karusel-kartu' + (utuh ? ' besar' : '')}
              key={k}
              tabIndex={utuh || samping ? 0 : -1}
              aria-hidden={utuh || samping ? undefined : true}
              aria-label={utuh ? b.judul + ', ' + formatRupiah(b.harga) + ', lihat detail' : 'Tampilkan ' + b.judul}
              style={{
                width: ukuran.lebar,
                height: ukuran.tinggi,
                marginLeft: -ukuran.lebar / 2,
                zIndex: utuh ? 3 : 1,
                opacity: g.tampak,
                pointerEvents: g.tampak > 0.05 ? undefined : 'none',
                transform: 'translateX(' + g.x + 'px) scale(' + g.skala + ')',
                clipPath: 'inset(0 ' + g.potong + '% round ' + 22 / g.skala + 'px)',
                '--redup': g.redup,
                '--info': g.info,
              }}
              onClick={() => {
                if (panggung.current.dataset.baruSeret) return;
                henti();
                if (utuh) onBuka(b);
                else onGeser(dasar < 0 ? dasar : dasar - (ukuran.pasangan ? 1 : 0));
              }}
            >
              {b.foto[0]
                ? <img src={b.foto[0]} alt="" loading="lazy" decoding="async" draggable={false} />
                : <span className="karusel-kosong">Foto belum tersedia</span>}
              <span className="karusel-label">{b.kategori}</span>
              <span className="karusel-info">
                <strong>{b.judul}</strong>
                <span className="karusel-harga">{formatRupiah(b.harga)}</span>
                <span className="karusel-meta"><MapPin size={14} aria-hidden="true" /><span>{b.kecamatan} · {labelKondisi(b.kondisi)}</span></span>
                <span className="karusel-buka"><ArrowRight size={20} aria-hidden="true" /></span>
              </span>
            </button>
          );
        })}
      </div>
      {n > 1 && (
        <div className="karusel-kendali">
          <button type="button" aria-label="Barang sebelumnya" onClick={() => pencet(-1)}><ChevronLeft size={20} /></button>
          <span className="karusel-titik" role="status" aria-live={berjalan ? 'off' : 'polite'} aria-label={'Barang ' + (aktif + 1) + ' dari ' + formatAngka(total)}>
            {n > 8 && <span>{formatAngka(aktif + 1)} / {formatAngka(total)}</span>}
            {(n <= 8 ? barang : [barang[aktif]]).map((b) => (
              <i key={b.id} className={b.id === barang[aktif].id ? 'aktif' : undefined}>
                {berjalan && b.id === barang[aktif].id && (
                  <b key={indeks} className={jeda ? 'jeda' : undefined} onAnimationEnd={() => onGeser(1)} />
                )}
              </i>
            ))}
          </span>
          <button type="button" aria-label="Barang berikutnya" onClick={() => pencet(1)}><ChevronRight size={20} /></button>
        </div>
      )}
    </>
  );
}

export default function EtalasePreloved() {
  const bagian = useRef(null);
  const [terlihat, setTerlihat] = useState(false);
  const [ketik, setKetik] = useState('');
  const [q, setQ] = useState('');
  const [kategori, setKategori] = useState('');
  const [kecamatan, setKecamatan] = useState('');
  const [halaman, setHalaman] = useState(1);
  const [ulang, setUlang] = useState(0);
  const diamLuarLayar = useDiamDiLuarLayar();
  const [simpanan] = useState(etalaseTerakhir);
  const [barang, setBarang] = useState(simpanan?.data ?? []);
  const [meta, setMeta] = useState(simpanan?.meta ?? null);
  const [pilihan, setPilihan] = useState(simpanan?.filter ?? { kategori: [], kecamatan: [] });
  const [selesai, setSelesai] = useState(null);
  const [gagal, setGagal] = useState(null);
  const [detail, setDetail] = useState(null);
  const [indeks, setIndeks] = useState(0);
  const permintaan = [q, kategori, kecamatan, halaman, ulang].join('|');
  const memuat = selesai !== permintaan;
  const galat = memuat ? null : gagal;

  // Data diambil saat etalase mendekati layar, agar beranda tetap ringan dan kartunya sudah siap saat terlihat
  useEffect(() => {
    const pengamat = new IntersectionObserver(([masuk]) => {
      if (masuk.isIntersecting) {
        setTerlihat(true);
        pengamat.disconnect();
      }
    }, { rootMargin: '0px 0px 1400px 0px' });
    pengamat.observe(bagian.current);
    return () => pengamat.disconnect();
  }, []);

  useEffect(() => {
    const jeda = setTimeout(() => {
      setQ(ketik.trim());
      setHalaman(1);
    }, 350);
    return () => clearTimeout(jeda);
  }, [ketik]);

  useEffect(() => {
    if (!terlihat) return undefined;
    let batal = false;
    ambilEtalasePreloved({ q, kategori, kecamatan, page: halaman })
      .then((res) => {
        if (batal) return;
        if (halaman === 1) setIndeks(0);
        setBarang((lama) => (halaman === 1 ? res.data : [...lama, ...res.data.filter((b) => !lama.some((l) => l.id === b.id))]));
        setMeta(res.meta);
        setPilihan(res.filter);
        setGagal(null);
        if (halaman === 1 && !q && !kategori && !kecamatan) {
          try {
            localStorage.setItem(KUNCI_ETALASE, JSON.stringify({ data: res.data, meta: res.meta, filter: res.filter }));
          } catch {
            // Penyimpanan diblokir browser: etalase tetap tampil dari server
          }
        }
      })
      .catch((e) => !batal && setGagal(e))
      .finally(() => !batal && setSelesai(permintaan));
    return () => {
      batal = true;
    };
  }, [terlihat, permintaan, q, kategori, kecamatan, halaman]);

  const adaFilter = Boolean(ketik || kategori || kecamatan);
  const tanpaFilter = !q && !kategori && !kecamatan;
  const pertamaMemuat = memuat && !(tanpaFilter && barang.length) && (halaman === 1 || !barang.length);
  const hapusFilter = () => {
    setKetik('');
    setQ('');
    setKategori('');
    setKecamatan('');
    setHalaman(1);
  };

  return (
    <section className="etalase" id="etalase-preloved" ref={bagian} aria-label="Etalase preloved warga">
      <div className="beranda-wadah" ref={diamLuarLayar}>
        <Muncul as="header" className="alur-kepala">
          <span>Dari Warga, Untuk Warga</span>
          <h2>Preloved Warga</h2>
          <p>Barang bekas layak pakai yang sedang dijual warga. Pembelian dilakukan melalui aplikasi warga.</p>
        </Muncul>
        <Muncul className="etalase-filter">
          <label className="reference-search">
            <Search size={16} />
            <input type="search" aria-label="Cari barang preloved" placeholder="Cari barang…" value={ketik} onChange={(e) => setKetik(e.target.value)} />
          </label>
          <Pilihan aria-label="Kategori barang" value={kategori} onChange={(e) => { setKategori(e.target.value); setHalaman(1); }}>
            <option value="">Semua kategori</option>
            {pilihan.kategori.map((k) => <option key={k}>{k}</option>)}
          </Pilihan>
          <Pilihan aria-label="Kecamatan barang" value={kecamatan} onChange={(e) => { setKecamatan(e.target.value); setHalaman(1); }}>
            <option value="">Semua kecamatan</option>
            {pilihan.kecamatan.map((k) => <option key={k}>{k}</option>)}
          </Pilihan>
          {adaFilter && (
            <button type="button" className="etalase-hapus-filter" onClick={hapusFilter}>Hapus filter</button>
          )}
          {!pertamaMemuat && !galat && meta && <span className="etalase-jumlah" role="status">{formatAngka(meta.total)} barang</span>}
        </Muncul>

        {galat && !barang.length ? (
          <GagalMuat error={galat} onUlang={() => setUlang((n) => n + 1)} />
        ) : pertamaMemuat ? (
          <div className="etalase-muat" aria-label="Memuat barang">
            {[0, 1].map((i) => <Skeleton key={i} />)}
          </div>
        ) : !barang.length ? (
          <Kosong
            judul={adaFilter ? 'Tidak ada barang yang cocok' : 'Belum ada barang dijual'}
            keterangan={adaFilter ? 'Coba ubah kata kunci atau filter.' : 'Barang dari warga akan tampil di sini.'}
          />
        ) : (
          <>
            <KaruselBarang
              barang={barang}
              indeks={indeks}
              total={meta?.total ?? barang.length}
              dijeda={Boolean(detail)}
              onBuka={setDetail}
              onGeser={(arah) => {
                const berikut = indeks + arah;
                // Barang berikutnya dimuat sebelum daftar sampai di ujung
                if (arah > 0 && !memuat && meta && meta.current_page < meta.last_page && berikut + 3 >= barang.length) setHalaman((h) => h + 1);
                setIndeks(berikut);
              }}
            />
            {galat && <GagalMuat error={galat} onUlang={() => setUlang((n) => n + 1)} />}
          </>
        )}
      </div>
      {detail && <DetailBarang key={detail.id} barang={detail} onTutup={() => setDetail(null)} />}
    </section>
  );
}
