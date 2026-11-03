import { useState } from 'react';
import { formatKg, formatRupiah, labelPeriode } from '../utils/format';

const LEBAR = 720;
const TINGGI = 240;
const PAD = { kiri: 48, kanan: 12, atas: 12, bawah: 28 };

/**
 * Grafik batang bertumpuk (kg jual + kg donasi) per periode, SVG murni.
 * data: [{ periode, total_kg, kg_donasi, nilai_setoran, jumlah_setoran }]
 */
export default function GrafikTren({ data }) {
  const [aktif, setAktif] = useState(null);

  const maks = Math.max(1, ...data.map((d) => d.total_kg));
  const lebarArea = LEBAR - PAD.kiri - PAD.kanan;
  const tinggiArea = TINGGI - PAD.atas - PAD.bawah;
  const lebarBatang = lebarArea / data.length;
  const y = (kg) => PAD.atas + tinggiArea - (kg / maks) * tinggiArea;
  const garis = [0, 0.5, 1].map((f) => maks * f);
  const tiapLabel = Math.ceil(data.length / 8);
  const titik = aktif !== null ? data[aktif] : null;

  return (
    <div>
      <svg viewBox={`0 0 ${LEBAR} ${TINGGI}`} className="w-full h-auto" role="img" aria-label="Grafik tren setoran">
        {garis.map((g) => (
          <g key={g}>
            <line x1={PAD.kiri} x2={LEBAR - PAD.kanan} y1={y(g)} y2={y(g)} className="stroke-slate-200 dark:stroke-white/10" />
            <text x={PAD.kiri - 6} y={y(g) + 3} textAnchor="end" className="fill-slate-500 dark:fill-zinc-400 text-[11px] font-mono">
              {Math.round(g)}
            </text>
          </g>
        ))}

        {data.map((d, i) => {
          const x = PAD.kiri + i * lebarBatang + lebarBatang * 0.15;
          const w = Math.max(1, lebarBatang * 0.7);
          const kgJual = d.total_kg - d.kg_donasi;
          return (
            <g key={d.periode} onMouseEnter={() => setAktif(i)} onMouseLeave={() => setAktif(null)}>
              <rect x={PAD.kiri + i * lebarBatang} y={PAD.atas} width={lebarBatang} height={tinggiArea} fill="transparent" />
              <rect x={x} y={y(kgJual)} width={w} height={tinggiArea + PAD.atas - y(kgJual)} rx="2" className="fill-cyan-500" />
              <rect x={x} y={y(d.total_kg)} width={w} height={y(kgJual) - y(d.total_kg)} rx="2" className="fill-emerald-400" />
              {i % tiapLabel === 0 && (
                <text x={x + w / 2} y={TINGGI - 8} textAnchor="middle" className="fill-slate-500 dark:fill-zinc-400 text-[11px] font-mono">
                  {labelPeriode(d.periode)}
                </text>
              )}
            </g>
          );
        })}
      </svg>

      <div className="flex flex-wrap items-center justify-between gap-3 mt-2 text-xs">
        <div className="flex items-center gap-4 text-slate-600 dark:text-zinc-300">
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-sm bg-cyan-500" /> Dijual (kg)
          </span>
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-sm bg-emerald-400" /> Donasi (kg)
          </span>
        </div>
        <div className="font-mono text-slate-700 dark:text-zinc-200 min-h-4">
          {titik
            ? `${labelPeriode(titik.periode)}: ${formatKg(titik.total_kg)} · ${formatRupiah(titik.nilai_setoran)} · ${titik.jumlah_setoran} setoran`
            : 'Arahkan kursor ke batang untuk detail'}
        </div>
      </div>
    </div>
  );
}
