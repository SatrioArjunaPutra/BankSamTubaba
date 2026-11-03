import { useEffect, useState } from 'react';
import { ArrowRight, CheckCircle2, ChevronsDown, HandHeart, ImagePlus, MapPin, MessagesSquare, Moon, Recycle, ShoppingBag, Smartphone, Sun, Truck, Wallet } from 'lucide-react';
import { ambilStatistikPublik } from '../services/api';
import { formatAngka } from '../utils/format';
import { Tombol } from '../components/ui';
import useDiamDiLuarLayar from '../hooks/useDiamDiLuarLayar';
import LogoAplikasi from '../components/LogoAplikasi';
import AngkaGulir from '../components/AngkaGulir';
import BeritaBeranda from '../components/BeritaBeranda';
import EtalasePreloved from '../components/EtalasePreloved';
import JalanBentor from '../components/JalanBentor';
import Muncul from '../components/Muncul';
import TeksBerjalan from '../components/TeksBerjalan';
import Login from './Login';
import { ArtikelBerita, DaftarBerita } from './BeritaHalaman';

const MENU_BERANDA = [
  ['beranda', 'Beranda'],
  ['layanan', 'Layanan'],
  ['etalase-preloved', 'Preloved'],
  ['berita', 'Berita'],
  ['cara-mulai', 'Panduan'],
];

const LAYANAN = [
  {
    kode: 'tabungan', nama: 'Tabungan Sampah', Ikon: Wallet,
    teks: 'Sampah ditimbang dan nilainya masuk ke saldo warga di bank sampah tersebut.',
    poin: ['Harga mengikuti daftar harga tiap bank sampah', 'Saldo dapat dipantau dari aplikasi', 'Penarikan diajukan lewat aplikasi warga'],
  },
  {
    kode: 'jemput', nama: 'Penjemputan Sampah', Ikon: Truck,
    teks: 'Warga mengajukan penjemputan, lalu bank sampah menjadwalkan bentor untuk datang ke alamat warga.',
    poin: ['Diajukan langsung dari aplikasi', 'Status penjemputan dapat dipantau', 'Bentor menimbang sampah di lokasi'],
  },
  {
    kode: 'donasi', nama: 'Donasi Sampah', Ikon: HandHeart,
    teks: 'Warga dapat mendonasikan sampah untuk bank sampah. Sampah donasi tidak diubah menjadi uang atau saldo.',
    poin: ['Sampah dapat diantar sendiri atau dijemput', 'Berat tercatat per jenis sampah', 'Tidak menambah saldo warga'],
  },
  {
    kode: 'preloved', nama: 'Preloved Warga', Ikon: ShoppingBag,
    teks: 'Warga dapat menjual dan membeli barang bekas layak pakai sesama warga Tubaba.',
    poin: ['Pasang hingga 5 foto per barang', 'Tanya dan tawar lewat chat di aplikasi', 'Pembayaran dilakukan secara COD'],
    tautan: 'etalase-preloved', labelTautan: 'Lihat Barang',
  },
];

// Jumlah kecil justru membuat layanan terlihat sepi
const MINIMAL_BARANG_TAMPIL = 10;

const PASANG_APLIKASI = { label: 'Pasang', Ikon: Smartphone, info: 'Ponsel Android', judul: 'Pasang Aplikasi Warga', teks: 'Pasang aplikasi Bank Sampah Tubaba, lalu daftar dengan email dan nomor HP.' };

const ALUR = [
  {
    kode: 'setor',
    nama: 'Setor Sampah',
    Ikon: Recycle,
    langkah: [
      PASANG_APLIKASI,
      { label: 'Pilih', Ikon: MapPin, info: 'Harga per jenis', judul: 'Pilih Bank Sampah', teks: 'Temukan bank sampah terdekat dan lihat daftar harga setiap jenis sampah.' },
      { label: 'Setor', Ikon: Truck, info: 'Antar atau jemput', judul: 'Setor atau Minta Jemput', teks: 'Antar sampah sendiri atau ajukan penjemputan, lalu pantau saldo dari aplikasi.' },
    ],
  },
  {
    kode: 'preloved',
    nama: 'Jual Preloved',
    Ikon: ShoppingBag,
    langkah: [
      PASANG_APLIKASI,
      { label: 'Unggah', Ikon: ImagePlus, info: 'Maksimal 5 foto', judul: 'Unggah Barang', teks: 'Isi judul, harga, dan kondisi barang bekas layak pakai, lalu tambahkan fotonya.' },
      { label: 'Transaksi', Ikon: MessagesSquare, info: 'Bayar di tempat', judul: 'Chat dan COD', teks: 'Pembeli menghubungi penjual lewat chat di aplikasi, lalu membayar secara COD.', tautan: 'etalase-preloved', labelTautan: 'Lihat Barang' },
    ],
  },
];

// Tujuan gulir yang menunggu beranda tampil kembali dari halaman berita
let tujuanTertunda = null;
// Posisi beranda saat ditinggalkan, supaya tombol kembali tidak mengulang dari atas
let posisiBeranda = null;

// Rute publik memakai hash agar berjalan di hosting apa pun: #/berita dan #/berita/12-judul
const ruteDariHash = () => {
  const cocok = window.location.hash.match(/^#\/berita(?:\/(\d+)[^/]*)?$/);
  if (!cocok) return { halaman: 'beranda', id: null };
  return cocok[1] ? { halaman: 'artikel', id: Number(cocok[1]) } : { halaman: 'berita', id: null };
};

// Tombol menu tidak mengubah hash, karena hash dipakai untuk rute tab panel
function gulirKe(id) {
  const tujuan = document.getElementById(id);
  if (!tujuan) {
    tujuanTertunda = id;
    window.location.hash = '';
    return;
  }
  // Gulir bawaan browser tetap lancar walau halaman sedang sibuk, berbeda dengan gulir lewat JavaScript
  const halus = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  tujuan.scrollIntoView({ behavior: halus ? 'smooth' : 'auto' });
  // Etalase memuat isinya saat dilewati, jadi posisi tujuan bisa bergeser di tengah jalan
  window.addEventListener('scrollend', () => tujuan.scrollIntoView(), { once: true });
}

function TautanGulir({ ke, className, children, ...props }) {
  return (
    <a
      href={`#${ke}`}
      className={className}
      {...props}
      onClick={(e) => {
        e.preventDefault();
        gulirKe(ke);
      }}
    >
      {children}
    </a>
  );
}

const KUNCI_STATISTIK = 'TUBABA_STATISTIK';

const statistikTerakhir = () => {
  try {
    return JSON.parse(localStorage.getItem(KUNCI_STATISTIK));
  } catch {
    return null;
  }
};

function AngkaRingkas() {
  // Angka kunjungan sebelumnya langsung tampil, lalu diganti angka terbaru begitu tiba
  const [angka, setAngka] = useState(statistikTerakhir);
  const [gagal, setGagal] = useState(false);

  useEffect(() => {
    let batal = false;
    ambilStatistikPublik()
      .then((res) => {
        try {
          localStorage.setItem(KUNCI_STATISTIK, JSON.stringify(res.data));
        } catch {
          // Penyimpanan diblokir browser: angka tetap tampil pada kunjungan ini
        }
        if (!batal) setAngka(res.data);
      })
      .catch(() => !batal && setGagal(true));
    return () => {
      batal = true;
    };
  }, []);

  if (!angka && gagal) return null;
  if (!angka) {
    return (
      <dl className="beranda-angka" aria-label="Memuat statistik">
        {['Bank sampah', 'Kecamatan'].map((label) => (
          <div key={label}>
            <dt>{label}</dt>
            <dd className="beranda-angka-tunggu">–</dd>
          </div>
        ))}
      </dl>
    );
  }

  const daftar = [
    [angka.bank_sampah, 'Bank sampah', 1],
    [angka.kecamatan, 'Kecamatan', 1],
    [angka.barang_preloved, 'Barang dijual', MINIMAL_BARANG_TAMPIL],
  ].filter(([nilai, , minimal]) => nilai >= minimal);

  return (
    <dl className="beranda-angka">
      {daftar.map(([nilai, label]) => (
        <div key={label}>
          <dt>{label}</dt>
          <dd aria-label={formatAngka(nilai)}><AngkaGulir teks={formatAngka(nilai)} /></dd>
        </div>
      ))}
    </dl>
  );
}

function InformasiLayanan() {
  const [aktif, setAktif] = useState(0);
  const { kode, nama, teks, poin, tautan, labelTautan } = LAYANAN[aktif];

  const geserDenganPanah = (e) => {
    const tujuan = { ArrowRight: aktif + 1, ArrowLeft: aktif - 1, Home: 0, End: LAYANAN.length - 1 }[e.key];
    if (tujuan === undefined) return;
    e.preventDefault();
    const berikut = (tujuan + LAYANAN.length) % LAYANAN.length;
    setAktif(berikut);
    e.currentTarget.children[berikut].focus();
  };

  return (
    <>
      <Muncul className="beranda-tab" role="tablist" aria-label="Pilih layanan" onKeyDown={geserDenganPanah}>
        {LAYANAN.map(({ kode: k, nama: n, Ikon }, i) => (
          <button
            type="button"
            role="tab"
            key={k}
            id={`tab-layanan-${k}`}
            aria-selected={i === aktif}
            aria-controls="panel-layanan"
            tabIndex={i === aktif ? 0 : -1}
            onClick={() => setAktif(i)}
          >
            <span><Ikon size={21} strokeWidth={1.9} aria-hidden="true" /></span>
            {n}
          </button>
        ))}
      </Muncul>
      <Muncul urutan={1}>
        <div className="beranda-panel" key={kode} id="panel-layanan" role="tabpanel" aria-labelledby={`tab-layanan-${kode}`}>
          <img src={`/beranda/layanan-${kode}.webp`} alt="" decoding="async" />
          <div>
            <h3>{nama}</h3>
            <p>{teks}</p>
            <ul>
              {poin.map((isi) => <li key={isi}><CheckCircle2 size={17} aria-hidden="true" /> {isi}</li>)}
            </ul>
            {tautan && (
              <TautanGulir ke={tautan} className="beranda-panel-tautan">{labelTautan} <ArrowRight size={16} aria-hidden="true" /></TautanGulir>
            )}
          </div>
        </div>
      </Muncul>
    </>
  );
}

function AlurMulai() {
  const diamLuarLayar = useDiamDiLuarLayar();
  const [aktif, setAktif] = useState(0);
  const alur = ALUR[aktif];

  const geserDenganPanah = (e) => {
    const tujuan = { ArrowRight: aktif + 1, ArrowLeft: aktif - 1, Home: 0, End: ALUR.length - 1 }[e.key];
    if (tujuan === undefined) return;
    e.preventDefault();
    const berikut = (tujuan + ALUR.length) % ALUR.length;
    setAktif(berikut);
    e.currentTarget.children[berikut].focus();
  };

  return (
    <div className="beranda-wadah" ref={diamLuarLayar}>
      <Muncul as="header" className="alur-kepala">
        <span>Mudah &amp; Transparan</span>
        <h2>Mulai dalam 3 Langkah</h2>
        <p>Ikuti tahapan berikut untuk mulai memakai layanan Bank Sampah Tubaba.</p>
        <div className="alur-tab" role="tablist" aria-label="Pilih alur" onKeyDown={geserDenganPanah}>
          {ALUR.map(({ kode, nama, Ikon }, i) => (
            <button
              type="button"
              role="tab"
              key={kode}
              id={`tab-alur-${kode}`}
              aria-selected={i === aktif}
              aria-controls="panel-alur"
              tabIndex={i === aktif ? 0 : -1}
              onClick={() => setAktif(i)}
            >
              <Ikon size={16} aria-hidden="true" />
              {nama}
            </button>
          ))}
        </div>
      </Muncul>
      {/* Berganti tab memasang ulang panel, sehingga cahaya mulai lagi dari bola pertama */}
      <Muncul urutan={1}>
        <div className="alur-panel" key={alur.kode} id="panel-alur" role="tabpanel" aria-labelledby={`tab-alur-${alur.kode}`}>
          <div className="alur-garis" aria-hidden="true"><i /></div>
          <ol>
            {alur.langkah.map(({ label, Ikon, info, judul, teks, tautan, labelTautan }, i) => (
              <li key={judul} className={i === alur.langkah.length - 1 ? 'terakhir' : undefined} style={{ '--urutan': i }}>
                <span className="alur-label">{label}</span>
                <span className="alur-bola"><Ikon size={22} strokeWidth={2} aria-hidden="true" /></span>
                <div className="alur-isi">
                  <small><Ikon size={13} aria-hidden="true" /> {info}</small>
                  <h3>{judul}</h3>
                  <p>{teks}</p>
                  {tautan && <TautanGulir ke={tautan} className="alur-tautan">{labelTautan} <ArrowRight size={14} aria-hidden="true" /></TautanGulir>}
                </div>
              </li>
            ))}
          </ol>
        </div>
      </Muncul>
    </div>
  );
}

// Terpisah dari Beranda: menu aktif berubah saat digulir, dan hanya header yang perlu digambar ulang
function HeaderBeranda({ diBeranda, tema, onGantiTema, onMasukDlh }) {
  const [aktif, setAktif] = useState('beranda');
  const [digulir, setDigulir] = useState(false);

  useEffect(() => {
    let bingkai = 0;
    const hitung = () => {
      bingkai = 0;
      // Bagian terakhir pendek, jadi dianggap aktif begitu halaman sampai di dasar
      const diDasar = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2;
      const terlewati = MENU_BERANDA.filter(([id]) => {
        const bagian = document.getElementById(id);
        return bagian && bagian.getBoundingClientRect().top <= window.innerHeight * 0.45;
      });
      setAktif((diDasar ? MENU_BERANDA : terlewati).at(-1)?.[0] ?? 'beranda');
      setDigulir(window.scrollY > 8);
    };
    // Cukup sekali per frame, karena membaca posisi semua bagian
    const perbarui = () => {
      if (!bingkai) bingkai = requestAnimationFrame(hitung);
    };
    window.addEventListener('scroll', perbarui, { passive: true });
    return () => {
      window.removeEventListener('scroll', perbarui);
      cancelAnimationFrame(bingkai);
    };
  }, []);

  return (
    <header className={`beranda-header ${digulir || !diBeranda ? 'digulir' : ''}`}>
      <TautanGulir ke="beranda" className="beranda-merek">
        <span className="beranda-logo"><LogoAplikasi /></span>
        <span><strong>Bank Sampah Tubaba</strong><small>Dinas Lingkungan Hidup</small></span>
      </TautanGulir>
      <nav aria-label="Menu beranda">
        {MENU_BERANDA.map(([id, label]) => (
          id === 'berita' ? (
            <a key={id} href="#/berita" aria-current={!diBeranda || aktif === id ? 'true' : undefined}><span>{label}</span></a>
          ) : (
            <TautanGulir key={id} ke={id} aria-current={diBeranda && aktif === id ? 'true' : undefined}><span>{label}</span></TautanGulir>
          )
        ))}
      </nav>
      <div className="beranda-header-aksi">
        <button
          type="button"
          className="icon-button beranda-tema"
          onClick={onGantiTema}
          title={tema === 'dark' ? 'Mode terang' : 'Mode gelap'}
          aria-label={tema === 'dark' ? 'Ganti ke mode terang' : 'Ganti ke mode gelap'}
        >
          {tema === 'dark' ? <Sun size={18} aria-hidden="true" /> : <Moon size={18} aria-hidden="true" />}
        </button>
        <Tombol varian="sekunder" className="beranda-masuk" onClick={onMasukDlh}>Masuk DLH</Tombol>
      </div>
    </header>
  );
}

export default function Beranda({ onMasuk, pesanAwal, tema, onGantiTema }) {
  const [bukaLogin, setBukaLogin] = useState(Boolean(pesanAwal));
  const [pesanLogin, setPesanLogin] = useState(pesanAwal);
  const [rute, setRute] = useState(ruteDariHash);
  const diBeranda = rute.halaman === 'beranda';
  const kunciRute = `${rute.halaman}|${rute.id}`;

  useEffect(() => {
    const ikuti = () => {
      if (document.getElementById('beranda')) posisiBeranda = window.scrollY;
      setRute(ruteDariHash());
    };
    window.addEventListener('hashchange', ikuti);
    return () => window.removeEventListener('hashchange', ikuti);
  }, []);

  useEffect(() => {
    if (kunciRute.startsWith('beranda')) {
      if (tujuanTertunda) {
        const id = tujuanTertunda;
        tujuanTertunda = null;
        requestAnimationFrame(() => gulirKe(id));
      } else if (posisiBeranda !== null) {
        const posisi = posisiBeranda;
        posisiBeranda = null;
        requestAnimationFrame(() => window.scrollTo({ top: posisi, behavior: 'instant' }));
      }
    } else {
      window.scrollTo({ top: 0, behavior: 'instant' });
    }
  }, [kunciRute]);

  return (
    <div className="beranda">
      <TeksBerjalan />
      <HeaderBeranda diBeranda={diBeranda} tema={tema} onGantiTema={onGantiTema} onMasukDlh={() => setBukaLogin(true)} />

      {rute.halaman === 'berita' && <DaftarBerita />}
      {rute.halaman === 'artikel' && <ArtikelBerita key={rute.id} id={rute.id} onLihatPreloved={() => gulirKe('etalase-preloved')} />}

      {diBeranda && (
      <>
      <section className="beranda-hero" id="beranda">
        <div className="beranda-hero-latar">
          <img src="/beranda/hero.webp" alt="" fetchPriority="high" />
          <div className="beranda-hero-isi">
            <span className="beranda-lokasi">Kabupaten Tulang Bawang Barat</span>
            <h1>Bank Sampah <span>Tubaba</span></h1>
            <p className="beranda-subjudul">Layanan Bank Sampah Terpadu</p>
            <p>Setor sampah, minta dijemput bentor, dan jual barang bekas layak pakai melalui aplikasi warga.</p>
            <div className="beranda-aksi">
              <TautanGulir ke="cara-mulai" className="ui-button ui-button-primary beranda-tombol">Mulai Menabung</TautanGulir>
              <TautanGulir ke="etalase-preloved" className="ui-button ui-button-secondary beranda-tombol">Lihat Barang</TautanGulir>
            </div>
            <AngkaRingkas />
            <TautanGulir ke="layanan" className="beranda-gulir">Gulir ke bawah <ChevronsDown size={18} aria-hidden="true" /></TautanGulir>
          </div>
        </div>
      </section>

      <section className="beranda-bagian" id="layanan">
        <div className="beranda-wadah">
          <Muncul as="header" className="alur-kepala">
            <span>Layanan Warga</span>
            <h2>Informasi Layanan</h2>
            <p>Pilih layanan untuk melihat penjelasannya.</p>
          </Muncul>
          <InformasiLayanan />
        </div>
      </section>

      <EtalasePreloved />

      <BeritaBeranda />

      <section className="beranda-bagian" id="cara-mulai">
        <AlurMulai />
      </section>

      <JalanBentor />
      </>
      )}

      <footer className="beranda-kaki">
        <div className="beranda-wadah">
          <div className="beranda-kaki-identitas">
            <span className="beranda-logo"><LogoAplikasi /></span>
            <p><strong>Dinas Lingkungan Hidup</strong><br />Kabupaten Tulang Bawang Barat</p>
          </div>
        </div>
      </footer>

      {bukaLogin && (
        <Login
          pesanAwal={pesanLogin}
          onMasuk={onMasuk}
          onTutup={() => {
            setBukaLogin(false);
            setPesanLogin('');
          }}
        />
      )}
    </div>
  );
}
