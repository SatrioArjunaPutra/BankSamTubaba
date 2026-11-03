import { lazy, Suspense, useCallback, useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';
import Navbar from './components/Navbar';
import { MENU, MENU_TAMBAHAN } from './menu';
import { ToastProvider } from './components/Toast';
import { ambilProfil, EVENT_SESI_BERAKHIR, logout, token } from './services/api';
import Beranda from './pages/Beranda';
import { SkeletonBaris } from './components/ui';

// Pengunjung beranda tidak perlu mengunduh panel DLH beserta petanya
const PEMUAT_PANEL = {
  Ringkasan: () => import('./pages/Ringkasan'),
  Kinerja: () => import('./pages/Kinerja'),
  Peta: () => import('./pages/Peta'),
  BankSampah: () => import('./pages/BankSampah'),
  JenisSampah: () => import('./pages/JenisSampah'),
  Moderasi: () => import('./pages/Moderasi'),
  Pantauan: () => import('./pages/Pantauan'),
  Bentor: () => import('./pages/Bentor'),
  Laporan: () => import('./pages/Laporan'),
  BeritaDlh: () => import('./pages/BeritaDlh'),
};
const Ringkasan = lazy(PEMUAT_PANEL.Ringkasan);
const Kinerja = lazy(PEMUAT_PANEL.Kinerja);
const Peta = lazy(PEMUAT_PANEL.Peta);
const BankSampah = lazy(PEMUAT_PANEL.BankSampah);
const JenisSampah = lazy(PEMUAT_PANEL.JenisSampah);
const Moderasi = lazy(PEMUAT_PANEL.Moderasi);
const Pantauan = lazy(PEMUAT_PANEL.Pantauan);
const Bentor = lazy(PEMUAT_PANEL.Bentor);
const Laporan = lazy(PEMUAT_PANEL.Laporan);
const BeritaDlh = lazy(PEMUAT_PANEL.BeritaDlh);

// Setelah rilis baru, file lama di server sudah hilang: muat ulang sekali untuk mengambil versi terbaru
window.addEventListener('vite:preloadError', () => {
  if (sessionStorage.getItem('TUBABA_MUAT_ULANG')) return;
  sessionStorage.setItem('TUBABA_MUAT_ULANG', '1');
  window.location.reload();
});

const HALAMAN = {
  ringkasan: Ringkasan,
  kinerja: Kinerja,
  peta: Peta,
  'bank-sampah': BankSampah,
  'jenis-sampah': JenisSampah,
  moderasi: Moderasi,
  preloved: Moderasi,
  laporan: Laporan,
  berita: BeritaDlh,
  bentor: Bentor,
  warga: () => <Pantauan jenis="warga" />,
  transaksi: () => <Pantauan jenis="transaksi" />,
  donasi: () => <Pantauan jenis="donasi" />,
};

const tabDariHash = () => {
  const id = window.location.hash.replace('#', '');
  return [...MENU, ...MENU_TAMBAHAN].some((m) => m.id === id) ? id : 'ringkasan';
};

const temaAwal = () => {
  try {
    return localStorage.getItem('TUBABA_THEME') || 'light';
  } catch {
    return 'light';
  }
};

export default function App() {
  const [tema, setTema] = useState(temaAwal);
  const [user, setUser] = useState(null);
  const [memeriksa, setMemeriksa] = useState(() => Boolean(token.ambil()));
  const [pesanLogin, setPesanLogin] = useState('');
  const [tab, setTab] = useState(tabDariHash);

  // Token tersimpan dari sesi sebelumnya: pastikan masih berlaku & milik DLH
  useEffect(() => {
    if (!token.ambil()) return;
    ambilProfil()
      .then(({ data }) => {
        if (data.role === 'dlh') setUser(data);
        else token.hapus();
      })
      .catch(() => token.hapus())
      .finally(() => setMemeriksa(false));
  }, []);

  // 401 dari API mana pun → kembali ke login
  useEffect(() => {
    const keluarPaksa = () => {
      setUser(null);
      setPesanLogin('Sesi Anda berakhir. Silakan login kembali.');
    };
    window.addEventListener(EVENT_SESI_BERAKHIR, keluarPaksa);
    return () => window.removeEventListener(EVENT_SESI_BERAKHIR, keluarPaksa);
  }, []);

  useEffect(() => {
    const ikutiHash = () => setTab(tabDariHash());
    window.addEventListener('hashchange', ikutiHash);
    return () => window.removeEventListener('hashchange', ikutiHash);
  }, []);

  // Beranda bisa digulir jauh: masuk atau keluar selalu mulai dari atas halaman
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [user]);

  const pilihTab = useCallback((id) => {
    window.location.hash = id;
    setTab(id);
  }, []);

  // Begitu masuk, semua halaman panel disiapkan agar perpindahan menu tidak menunggu unduhan
  useEffect(() => {
    if (!user) return undefined;
    const tunda = setTimeout(() => {
      Object.values(PEMUAT_PANEL).forEach((muat) => muat().catch(() => {}));
    }, 300);
    return () => clearTimeout(tunda);
  }, [user]);

  const [ciut, setCiut] = useState(() => {
    try {
      return localStorage.getItem('TUBABA_SIDEBAR') === 'ciut';
    } catch {
      return false;
    }
  });
  const gantiCiut = () => {
    const berikut = !ciut;
    setCiut(berikut);
    try {
      localStorage.setItem('TUBABA_SIDEBAR', berikut ? 'ciut' : 'buka');
    } catch {
      // Penyimpanan diblokir browser: pilihan tetap berlaku untuk sesi ini
    }
  };

  const gantiTema = () => {
    const berikut = tema === 'dark' ? 'light' : 'dark';
    setTema(berikut);
    try {
      localStorage.setItem('TUBABA_THEME', berikut);
    } catch {
      // Penyimpanan diblokir browser: tema tetap berlaku untuk sesi ini
    }
  };

  const keluar = async () => {
    await logout().catch(() => {});
    token.hapus();
    setUser(null);
    setPesanLogin('');
  };

  const Halaman = HALAMAN[tab];

  return (
    <ToastProvider>
      <div
        className={`${tema} app-root ${user ? 'has-session' : ''} ${ciut ? 'sidebar-ciut' : ''}`}
      >
        {memeriksa ? (
          <div className="min-h-screen flex items-center justify-center">
            <Loader2 className="w-6 h-6 animate-spin text-cyan-500" aria-label="Memuat" />
          </div>
        ) : !user ? (
          <Beranda
            tema={tema}
            onGantiTema={gantiTema}
            pesanAwal={pesanLogin}
            onMasuk={(u) => {
              setUser(u);
              setPesanLogin('');
            }}
          />
        ) : (
          <>
            <Navbar aktif={tab} onPilih={pilihTab} user={user} tema={tema} onGantiTema={gantiTema} onKeluar={keluar} ciut={ciut} onGantiCiut={gantiCiut} />
            <main className="app-main animate-fadeIn" id="konten-utama">
              {['kinerja','jenis-sampah','moderasi','preloved','berita'].includes(tab) && <div className="page-context"><a href="#ringkasan">Ringkasan</a><span>/</span>{[...MENU,...MENU_TAMBAHAN].find(m=>m.id===tab)?.label}</div>}
              <Suspense fallback={<SkeletonBaris jumlah={6} />}>
                <div className="halaman-masuk" key={tab}><Halaman /></div>
              </Suspense>
            </main>
            <footer className="app-footer">
              Bank Sampah Pintar <span>·</span> Bersama membangun Tubaba yang lebih bersih.
            </footer>
          </>
        )}
      </div>
    </ToastProvider>
  );
}
