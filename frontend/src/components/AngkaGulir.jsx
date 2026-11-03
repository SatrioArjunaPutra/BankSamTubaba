import { useLayoutEffect, useRef } from 'react';

const JEDA_ANGKA = 250;
const kurangiAnimasi = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// Isi satu kolom dari awal sampai digit akhirnya. Kolom satuan berputar satu kali penuh
// agar terasa menghitung, kolom terdepan mulai kosong supaya angka tidak diawali nol.
function isiKolom(digit, urutan, jumlah) {
  if (jumlah === 1) return digit === 0 ? [0] : Array.from({ length: digit }, (_, i) => i + 1);
  if (urutan === jumlah - 1) return Array.from({ length: 10 + digit }, (_, i) => (i + 1) % 10);
  if (urutan === 0) return ['', ...Array.from({ length: digit }, (_, i) => i + 1)];
  return Array.from({ length: digit + 1 }, (_, i) => i);
}

// Digerakkan transform oleh kartu grafis, sehingga tetap halus walau browser sedang sibuk memuat
function KolomAngka({ isi, durasi }) {
  const pita = useRef(null);
  const akhir = `translateY(${(-(isi.length - 1) / isi.length) * 100}%)`;

  // Sebelum browser menggambar, agar nilai akhir tidak sempat terlihat sekilas
  useLayoutEffect(() => {
    if (kurangiAnimasi() || isi.length < 2) return undefined;
    const animasi = pita.current.animate(
      [{ transform: 'translateY(0)' }, { transform: akhir }],
      { duration: durasi, delay: JEDA_ANGKA, easing: 'cubic-bezier(.45,.05,.2,1)', fill: 'backwards' },
    );
    return () => animasi.cancel();
  }, [isi.length, akhir, durasi]);

  return (
    <span className="angka-kolom" aria-hidden="true">
      <span ref={pita} style={{ transform: akhir }}>
        {isi.map((angka, i) => <i key={i}>{angka}</i>)}
      </span>
    </span>
  );
}

/** Angka yang berputar dari nol sampai teks tujuan. Induknya yang memberi aria-label. */
export default function AngkaGulir({ teks, durasi = 2600 }) {
  const jumlah = teks.replace(/\D/g, '').length;
  let urutan = -1;

  return [...teks].map((huruf, i) => {
    if (!/\d/.test(huruf)) return <span aria-hidden="true" key={i}>{huruf}</span>;
    urutan += 1;
    return <KolomAngka key={i} isi={isiKolom(Number(huruf), urutan, jumlah)} durasi={durasi} />;
  });
}
