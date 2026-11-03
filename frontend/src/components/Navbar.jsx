import { ArrowUpRight, ChevronLeft, LogOut, Menu, Moon, Settings, Sun, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import useFetch from '../hooks/useFetch';
import { MENU, MENU_TAMBAHAN } from '../menu';
import { ambilDashboard } from '../services/api';
import LogoAplikasi from './LogoAplikasi';
import TitikMenu from './TitikMenu';

const GRUP = [...new Set(MENU.map((m) => m.grup))];

export default function Navbar({ aktif, onPilih, user, tema, onGantiTema, onKeluar, ciut, onGantiCiut }) {
  const [terbuka, setTerbuka] = useState(false);
  const panelRef = useRef(null);
  const pemicuRef = useRef(null);
  const pilih = (id) => { onPilih(id); setTerbuka(false); };

  // Titik merah pada menu yang perlu dilihat DLH
  const [putaran, setPutaran] = useState(0);
  const dashboard = useFetch(() => ambilDashboard(), putaran).data?.data;
  const ringkasan = dashboard?.ringkasan;
  // Titik merah: ada yang perlu dilihat DLH di menu itu
  const pesanTitik = {
    bentor: ringkasan?.jemput_aktif > 0 ? ringkasan.jemput_aktif + ' penjemputan belum selesai' : null,
    preloved: ringkasan?.barang_dilaporkan > 0 ? ringkasan.barang_dilaporkan + ' barang dilaporkan warga' : null,
  };
  useEffect(() => {
    const jeda = setInterval(() => { if (!document.hidden) setPutaran((n) => n + 1); }, 60000);
    return () => clearInterval(jeda);
  }, []);

  useEffect(() => {
    if (!terbuka) return;
    const panel = panelRef.current;
    panel.querySelector('button')?.focus();
    const tombol = (e) => {
      if (e.key === 'Escape') {
        setTerbuka(false);
        pemicuRef.current?.focus();
      }
      if (e.key !== 'Tab') return;
      const fokus = [...panel.querySelectorAll('button:not(:disabled), a[href]')];
      const pertama = fokus[0];
      const terakhir = fokus.at(-1);
      if (e.shiftKey && document.activeElement === pertama) { e.preventDefault(); terakhir?.focus(); }
      else if (!e.shiftKey && document.activeElement === terakhir) { e.preventDefault(); pertama?.focus(); }
    };
    window.addEventListener('keydown', tombol);
    return () => window.removeEventListener('keydown', tombol);
  }, [terbuka]);

  return (
    <>
      <header className="mobile-header">
        <button className="brand" onClick={() => pilih('ringkasan')}>
          <span className="brand-icon brand-logo"><LogoAplikasi /></span>
          <span><strong>Bank Sampah</strong><small>DLH Tubaba</small></span>
        </button>
        <button ref={pemicuRef} className="icon-button" aria-label={terbuka ? 'Tutup menu' : 'Buka menu'} aria-expanded={terbuka} aria-controls="sidebar-dlh" onClick={() => setTerbuka(!terbuka)}>
          {terbuka ? <X size={20} /> : <Menu size={20} />}
        </button>
      </header>
      <button className="sidebar-toggle" aria-label={ciut ? 'Buka sidebar' : 'Tutup sidebar'} aria-expanded={!ciut} title={ciut ? 'Buka sidebar' : 'Tutup sidebar'} onClick={onGantiCiut}>
        <ChevronLeft size={16} />
      </button>
      {terbuka && <button className="sidebar-backdrop" aria-label="Tutup menu" onClick={() => setTerbuka(false)} />}
      <aside ref={panelRef} id="sidebar-dlh" className={`app-sidebar ${terbuka ? 'is-open' : ''}`}>
        <button onClick={() => pilih('ringkasan')} className="brand sidebar-brand">
          <span className="brand-icon brand-logo"><LogoAplikasi /></span>
          <span><strong>Bank Sampah</strong><small>Panel DLH Tubaba</small></span>
        </button>
        <nav aria-label="Menu utama" className="sidebar-nav">
          {GRUP.map((grup) => (
            <div className="sidebar-grup" key={grup}>
              <span className="sidebar-label">{grup}</span>
              {MENU.filter((m) => m.grup === grup).map(({ id, label, ikon: Ikon }) => (
                <div className="menu-baris" key={id}>
                  <button data-label={label} aria-label={label} onClick={() => pilih(id)} aria-current={aktif === id ? 'page' : undefined}>
                    <Ikon size={20} strokeWidth={1.8} /><span>{label}</span>
                  </button>
                  {pesanTitik[id] && <TitikMenu id={id} pesan={pesanTitik[id]} ringkasan={dashboard} onBuka={() => pilih(id === 'preloved' ? 'moderasi' : id)} />}
                </div>
              ))}
            </div>
          ))}
        </nav>
        <details className="sidebar-settings" open={MENU_TAMBAHAN.some((m) => m.id === aktif)}><summary aria-label="Pengaturan"><Settings size={18}/>Pengaturan</summary>{MENU_TAMBAHAN.map(({id, label, ikon: Ikon}) => <button key={id} data-label={label} aria-label={label} onClick={() => pilih(id)} aria-current={aktif === id ? 'page' : undefined}><Ikon size={16}/><span>{label}</span></button>)}</details>
        <div className="sidebar-bottom">
          <div className="sidebar-report">
            <strong>Laporan kinerja</strong>
            <p>Rekap seluruh bank sampah untuk periode yang dipilih.</p>
            <button data-label="Buat laporan" aria-label="Buat laporan" onClick={() => pilih('laporan')}><span>Buat laporan</span> <ArrowUpRight size={16} /></button>
          </div>
          <div className="sidebar-user">
            <span className="user-avatar">DL</span>
            <span className="user-info"><strong title={user.email}>{user.name}</strong><small>Admin DLH</small></span>
            <button className="icon-button" onClick={onGantiTema} title={tema === 'dark' ? 'Mode terang' : 'Mode gelap'} aria-label={tema === 'dark' ? 'Mode terang' : 'Mode gelap'}>
              {tema === 'dark' ? <Sun size={17} /> : <Moon size={17} />}
            </button>
          </div>
          <button className="logout-button" aria-label="Keluar dari panel" onClick={onKeluar}><LogOut size={17} /> Keluar dari panel</button>
        </div>
      </aside>
    </>
  );
}
