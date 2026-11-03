import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { ArrowUpRight, X } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilLaporanPreloved } from '../services/api';
import { formatTanggal } from '../utils/format';

const STATUS_JEMPUT = { diajukan: 'Menunggu ditugaskan', dijadwalkan: 'Terjadwal', menuju: 'Bentor menuju lokasi', diambil: 'Sampah sudah diambil' };
const MAKS_BARIS = 5;

function DaftarJemput({ penjemputan, total }) {
  const sisa = total - penjemputan.length;
  const [sekarang] = useState(() => new Date());
  return (
    <>
      <ul>
        {penjemputan.map((p) => {
          const terlambat = p.status === 'dijadwalkan' && p.jadwal_at && new Date(p.jadwal_at) < sekarang;
          return (
            <li key={p.id}>
              <strong>{STATUS_JEMPUT[p.status] ?? p.status}</strong>
              <span>{p.bank_sampah}</span>
              <small>Bentor: {p.driver ?? 'belum ada'}</small>
              {p.jadwal_at && <small className={terlambat ? 'titik-terlambat' : undefined}>Jadwal {formatTanggal(p.jadwal_at)}{terlambat ? ', sudah lewat' : ''}</small>}
            </li>
          );
        })}
      </ul>
      {sisa > 0 && <p>+{sisa} penjemputan lain, termasuk yang menunggu ditugaskan</p>}
    </>
  );
}

function DaftarLaporan() {
  const hasil = useFetch(() => ambilLaporanPreloved({ status: 'baru' }));
  if (hasil.error) return <p>Rincian gagal dimuat. Buka laporan untuk melihatnya.</p>;
  if (!hasil.data) return <p>Memuat rincian…</p>;
  const daftar = hasil.data.data ?? [];
  const sisa = (hasil.data.meta?.total ?? daftar.length) - Math.min(daftar.length, MAKS_BARIS);
  return (
    <>
      <ul>
        {daftar.slice(0, MAKS_BARIS).map((d) => (
          <li key={d.barang.id}>
            <strong>{d.barang.judul}</strong>
            <small>{d.jumlah_laporan} laporan warga</small>
          </li>
        ))}
      </ul>
      {sisa > 0 && <p>+{sisa} barang lain</p>}
    </>
  );
}

// Titik merah pada menu: bisa dipencet untuk melihat apa yang perlu diperhatikan.
export default function TitikMenu({ id, pesan, ringkasan, onBuka }) {
  const [terbuka, setTerbuka] = useState(false);
  const [posisi, setPosisi] = useState(null);
  const tombolRef = useRef(null);
  const kotakRef = useRef(null);

  useLayoutEffect(() => {
    if (!terbuka) return;
    const t = tombolRef.current.getBoundingClientRect();
    const k = kotakRef.current.getBoundingClientRect();
    // Muncul di luar sidebar. Di HP sidebar hampir selebar layar, jadi kotak menimpanya.
    const kanan = tombolRef.current.closest('.app-sidebar')?.getBoundingClientRect().right ?? t.right;
    setPosisi({
      left: Math.max(12, Math.min(kanan + 12, window.innerWidth - k.width - 12)),
      top: Math.max(12, Math.min(t.top - 12, window.innerHeight - k.height - 12)),
    });
  }, [terbuka]);

  // Elemen yang masih tersembunyi tidak bisa menerima fokus
  useEffect(() => {
    if (posisi) kotakRef.current?.focus();
  }, [posisi]);

  useEffect(() => {
    if (!terbuka) return undefined;
    const tutup = () => setTerbuka(false);
    const luar = (e) => {
      if (!kotakRef.current?.contains(e.target) && !tombolRef.current?.contains(e.target)) tutup();
    };
    document.addEventListener('pointerdown', luar);
    window.addEventListener('resize', tutup);
    return () => {
      document.removeEventListener('pointerdown', luar);
      window.removeEventListener('resize', tutup);
    };
  }, [terbuka]);

  const tutupKeTombol = () => {
    setTerbuka(false);
    tombolRef.current?.focus();
  };
  const buka = () => {
    setTerbuka(false);
    onBuka();
  };

  return (
    <>
      <button
        ref={tombolRef}
        type="button"
        className="tombol-titik"
        aria-label={`Lihat rincian: ${pesan}`}
        aria-expanded={terbuka}
        title={pesan}
        onClick={() => { setPosisi(null); setTerbuka((t) => !t); }}
      >
        <i className="menu-titik" aria-hidden="true" />
      </button>
      {terbuka && createPortal(
        <div
          ref={kotakRef}
          className="kotak-titik"
          role="dialog"
          aria-label={pesan}
          tabIndex={-1}
          style={posisi ?? { visibility: 'hidden', left: 0, top: 0 }}
          onKeyDown={(e) => {
            if (e.key !== 'Escape') return;
            e.stopPropagation();
            tutupKeTombol();
          }}
        >
          <header>
            <h3>{pesan}</h3>
            <button type="button" aria-label="Tutup rincian" onClick={tutupKeTombol}><X size={16} /></button>
          </header>
          {id === 'bentor'
            ? <DaftarJemput penjemputan={ringkasan?.penjemputan ?? []} total={ringkasan?.ringkasan?.jemput_aktif ?? 0} />
            : <DaftarLaporan />}
          <button type="button" className="kotak-titik-aksi" onClick={buka}>
            {id === 'bentor' ? 'Lihat bentor' : 'Tinjau laporan'} <ArrowUpRight size={15} />
          </button>
        </div>,
        // Di dalam .app-root agar warna tema terbaca
        document.querySelector('.app-root') ?? document.body,
      )}
    </>
  );
}
