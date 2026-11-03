import { useLayoutEffect, useRef, useState } from 'react';
import useDiamDiLuarLayar from '../hooks/useDiamDiLuarLayar';
import useFetch from '../hooks/useFetch';
import { ambilTeksBerjalan } from '../services/api';

const LAJU_PX_PER_DETIK = 60;
const DURASI_AWAL = 40;

const hariIni = () => new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

function Deret({ daftar, ulang, salinan = false }) {
  return (
    <ul className="teks-jalan-deret" aria-hidden={salinan || undefined}>
      {Array.from({ length: ulang }, (_, i) => daftar.map((t) => (
        <li key={`${i}-${t.id}`} aria-hidden={(!salinan && i > 0) || undefined}>{t.teks}</li>
      )))}
    </ul>
  );
}

export default function TeksBerjalan() {
  const diamLuarLayar = useDiamDiLuarLayar();
  const { data, loading, error } = useFetch(ambilTeksBerjalan);
  const daftar = data?.data ?? [];
  const pita = useRef(null);
  const [ulang, setUlang] = useState(1);
  const [durasi, setDurasi] = useState(DURASI_AWAL);
  const jumlah = daftar.length;

  // Teks diulang sampai memenuhi layar agar tidak ada celah, dengan laju yang tetap sama
  useLayoutEffect(() => {
    const el = pita.current;
    if (!el) return undefined;
    const deret = el.firstElementChild;
    const ukur = () => {
      const satuPutaran = [...deret.children].slice(0, jumlah).reduce((total, li) => total + li.offsetWidth, 0);
      if (!satuPutaran) return;
      const kali = Math.max(1, Math.ceil(el.parentElement.clientWidth / satuPutaran));
      setUlang(kali);
      setDurasi(Math.round((satuPutaran * kali) / LAJU_PX_PER_DETIK));
    };
    ukur();
    const pengamat = new ResizeObserver(ukur);
    pengamat.observe(el.parentElement);
    pengamat.observe(deret.firstElementChild);
    return () => pengamat.disconnect();
  }, [jumlah]);

  // Tempatnya sudah disiapkan selama memuat agar halaman tidak melompat saat teks tiba
  if (error || (!loading && jumlah === 0)) return null;

  return (
    <aside className="teks-jalan" ref={diamLuarLayar} aria-label="Pengumuman">
      <div className="teks-jalan-tanda">
        <span className="teks-jalan-live"><i aria-hidden="true" />LIVE</span>
        <span className="teks-jalan-tanggal">{hariIni()}</span>
      </div>
      <div className="teks-jalan-jendela">
        {jumlah > 0 && (
          <div ref={pita} className="teks-jalan-pita" style={{ animationDuration: `${durasi}s` }}>
            <Deret daftar={daftar} ulang={ulang} />
            <Deret daftar={daftar} ulang={ulang} salinan />
          </div>
        )}
      </div>
    </aside>
  );
}
