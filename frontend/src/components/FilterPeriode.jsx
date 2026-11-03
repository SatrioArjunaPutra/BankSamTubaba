import { Input, Pilihan } from './ui';

const PILIHAN = [
  ['hari', 'Hari ini'],
  ['minggu', 'Minggu ini'],
  ['bulan', 'Bulan ini'],
  ['tahun', 'Tahun ini'],
  ['kustom', 'Rentang tanggal'],
];

/**
 * nilai: { periode, dari, sampai }. denganSemua menambah opsi "Sepanjang waktu".
 */
export default function FilterPeriode({ nilai, onUbah, denganSemua = false }) {
  const opsi = denganSemua ? [['', 'Sepanjang waktu'], ...PILIHAN] : PILIHAN;

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Pilihan className="w-auto" value={nilai.periode} onChange={(e) => onUbah({ ...nilai, periode: e.target.value })} aria-label="Periode">
        {opsi.map(([v, label]) => (
          <option key={v} value={v}>
            {label}
          </option>
        ))}
      </Pilihan>
      {nilai.periode === 'kustom' && (
        <>
          <Input type="date" className="w-auto" value={nilai.dari} onChange={(e) => onUbah({ ...nilai, dari: e.target.value })} aria-label="Dari tanggal" />
          <Input type="date" className="w-auto" value={nilai.sampai} onChange={(e) => onUbah({ ...nilai, sampai: e.target.value })} aria-label="Sampai tanggal" />
        </>
      )}
    </div>
  );
}
