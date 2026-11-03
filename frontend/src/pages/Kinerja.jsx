import { useEffect, useMemo, useRef, useState } from 'react';
import { ArrowDown, ArrowUp, BarChart3 } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import useLayarHp from '../hooks/useLayarHp';
import { ambilKinerja, ambilTren } from '../services/api';
import FilterPeriode from '../components/FilterPeriode';
import { queryPeriode } from '../utils/periode';
import GrafikTren from '../components/GrafikTren';
import { GagalMuat, JudulHalaman, Kartu, Kosong, Pilihan, SkeletonBaris } from '../components/ui';
import { formatAngka, formatKg, formatRupiah } from '../utils/format';

const BARIS_HP = 10;

const KOLOM = [
  ['total_kg', 'Total', formatKg],
  ['kg_donasi', 'Donasi', formatKg],
  ['nasabah_aktif', 'Nasabah aktif', formatAngka],
  ['nilai_setoran', 'Nilai setoran', formatRupiah],
  ['jemput_selesai', 'Jemput selesai', formatAngka],
  ['rata2_waktu_jemput_jam', 'Rata² jemput', (v) => (v === null ? '-' : `${v.toLocaleString('id-ID')} jam`)],
];

export default function Kinerja() {
  const [periode, setPeriode] = useState({ periode: 'bulan', dari: '', sampai: '' });
  const [urut, setUrut] = useState({ kolom: 'total_kg', turun: true });
  const [terpilih, setTerpilih] = useState(null);
  const [semuaBaris, setSemuaBaris] = useState(false);
  const hp = useLayarHp();
  const panel = useRef(null);
  const query = queryPeriode(periode);
  const kunciQuery = JSON.stringify(query);

  const { data, loading, error, refetch } = useFetch(() => ambilKinerja(query), kunciQuery);

  const baris = useMemo(() => {
    const daftar = [...(data?.data?.daftar ?? [])];
    // Nilai null (mis. belum ada jemput selesai) selalu di bawah
    daftar.sort((a, b) => {
      const va = a[urut.kolom];
      const vb = b[urut.kolom];
      if (va === null) return 1;
      if (vb === null) return -1;
      return urut.turun ? vb - va : va - vb;
    });
    return daftar;
  }, [data, urut]);

  // Di HP grafik ada di atas daftar, jadi harus dibawa ke layar saat baris dipilih
  useEffect(() => {
    if (hp && terpilih) panel.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [hp, terpilih]);

  const ubahUrut = (kolom) => setUrut((u) => ({ kolom, turun: u.kolom === kolom ? !u.turun : true }));

  return (
    <>
      <JudulHalaman
        ikon={BarChart3}
        judul="Kinerja Bank Sampah"
        keterangan={hp ? 'Ketuk bank sampah untuk melihat grafik tren.' : 'Klik judul kolom untuk mengurutkan, klik baris untuk melihat grafik tren.'}
        aksi={<FilterPeriode nilai={periode} onUbah={setPeriode} />}
      />

      <div ref={panel} className="kinerja-panel">
        {terpilih && <PanelTren bank={terpilih} query={query} kunciQuery={kunciQuery} onTutup={() => setTerpilih(null)} />}
      </div>

      <label className="urut-hp">
        Urutkan menurut
        <Pilihan value={urut.kolom} onChange={(e) => setUrut({ kolom: e.target.value, turun: true })}>
          {KOLOM.map(([kunci, label]) => <option key={kunci} value={kunci}>{label}</option>)}
        </Pilihan>
      </label>

      <Kartu className="overflow-x-auto">
        {error ? (
          <GagalMuat error={error} onUlang={refetch} />
        ) : loading && !data ? (
          <SkeletonBaris jumlah={8} />
        ) : baris.length === 0 ? (
          <Kosong judul="Belum ada bank sampah aktif" />
        ) : (
          <table className={`w-full text-sm min-w-[760px] tabel-kartu tiga-kolom batasi-hp ${semuaBaris ? 'semua' : ''}`}>
            <thead>
              <tr className="text-left text-xs font-mono uppercase tracking-wider text-slate-500 dark:text-zinc-400 border-b border-slate-200 dark:border-white/10">
                <th className="py-2 pr-2 w-10">#</th>
                <th className="py-2 pr-2">Bank sampah</th>
                {KOLOM.map(([kunci, label]) => (
                  <th key={kunci} className="py-2 px-2 text-right" aria-sort={urut.kolom === kunci ? (urut.turun ? 'descending' : 'ascending') : 'none'}>
                    <button onClick={() => ubahUrut(kunci)} className="inline-flex items-center gap-1 uppercase hover:text-cyan-600 dark:hover:text-cyan-300">
                      {label}
                      {urut.kolom === kunci && (urut.turun ? <ArrowDown className="w-3 h-3" /> : <ArrowUp className="w-3 h-3" />)}
                    </button>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {baris.map((b, i) => (
                <tr
                  key={b.bank_sampah.id}
                  onClick={() => setTerpilih(b.bank_sampah)}
                  className={`cursor-pointer border-b border-slate-100 dark:border-white/5 hover:bg-cyan-500/5 ${
                    terpilih?.id === b.bank_sampah.id ? 'bg-cyan-500/10' : ''
                  }`}
                >
                  <td className="py-2.5 pr-2 font-mono text-xs text-slate-400 sembunyi-hp">{i + 1}</td>
                  <td className="py-2.5 pr-2">
                    <button type="button" onClick={(e) => { e.stopPropagation(); setTerpilih(b.bank_sampah); }} className="font-semibold text-left text-slate-900 dark:text-white hover:text-cyan-700" aria-label={`Lihat tren ${b.bank_sampah.nama}`}>{b.bank_sampah.nama}</button>
                    <div className="text-xs font-mono text-slate-500 dark:text-zinc-400">
                      {b.bank_sampah.kode} · {b.bank_sampah.kecamatan}
                    </div>
                  </td>
                  {KOLOM.map(([kunci, label, format]) => (
                    <td key={kunci} data-label={label} className="py-2.5 px-2 text-right tabular-nums text-slate-700 dark:text-zinc-200">
                      {format(b[kunci])}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {baris.length > BARIS_HP && !semuaBaris && (
          <button type="button" className="tombol-semua-hp" onClick={() => setSemuaBaris(true)}>
            Tampilkan semua {baris.length} bank sampah
          </button>
        )}
      </Kartu>
    </>
  );
}

function PanelTren({ bank, query, kunciQuery, onTutup }) {
  const [intervalTren, setIntervalTren] = useState('');
  const { data, loading, error, refetch } = useFetch(
    () => ambilTren(bank.id, { ...query, interval: intervalTren || undefined }),
    `${bank.id}|${kunciQuery}|${intervalTren}`,
  );
  const deret = data?.data?.data ?? [];

  return (
    <Kartu className="mb-6">
      <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
        <div>
          <div className="font-mono text-xs uppercase tracking-wider text-slate-500 dark:text-zinc-400">Tren setoran</div>
          <div className="font-semibold text-slate-900 dark:text-white">{bank.nama}</div>
        </div>
        <div className="flex items-center gap-2">
          <Pilihan className="w-auto" value={intervalTren} onChange={(e) => setIntervalTren(e.target.value)} aria-label="Interval">
            <option value="">Interval otomatis</option>
            <option value="harian">Harian</option>
            <option value="bulanan">Bulanan</option>
          </Pilihan>
          <button onClick={onTutup} className="text-xs font-mono uppercase text-slate-500 hover:text-red-500">
            Tutup
          </button>
        </div>
      </div>
      {error ? (
        <GagalMuat error={error} onUlang={refetch} />
      ) : loading && !data ? (
        <SkeletonBaris jumlah={4} />
      ) : deret.every((d) => d.total_kg === 0) ? (
        <Kosong judul="Belum ada setoran di periode ini" />
      ) : (
        <GrafikTren data={deret} />
      )}
    </Kartu>
  );
}
