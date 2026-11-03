import { useState } from 'react';
import { Check, Pencil, Plus, Power, Recycle, X } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilJenisSampah, tambahJenisSampah, ubahJenisSampah } from '../services/api';
import { useToast } from '../components/Toast';
import { GagalMuat, Input, JudulHalaman, Kartu, Kosong, Lencana, SkeletonBaris, Tombol } from '../components/ui';

export default function JenisSampah() {
  const toast = useToast();
  const { data, loading, error, refetch } = useFetch(() => ambilJenisSampah());
  const [baru, setBaru] = useState({ nama: '', satuan: 'kg' });
  const [galatBaru, setGalatBaru] = useState('');
  const [menyimpan, setMenyimpan] = useState(false);
  const [edit, setEdit] = useState(null); // { id, nama }
  const [sibuk, setSibuk] = useState(null);

  const daftar = data?.data ?? [];

  const tambah = async (e) => {
    e.preventDefault();
    setMenyimpan(true);
    setGalatBaru('');
    try {
      await tambahJenisSampah(baru);
      toast.sukses(`Jenis sampah "${baru.nama}" ditambahkan.`);
      setBaru({ nama: '', satuan: 'kg' });
      refetch();
    } catch (err) {
      setGalatBaru(err.pesanField?.nama || err.pesanField?.satuan || err.message);
    } finally {
      setMenyimpan(false);
    }
  };

  const ubah = async (jenis, perubahan, pesan) => {
    setSibuk(jenis.id);
    try {
      await ubahJenisSampah(jenis.id, perubahan);
      toast.sukses(pesan);
      setEdit(null);
      refetch();
    } catch (err) {
      toast.gagal(err.pesanField?.nama || err.message);
    } finally {
      setSibuk(null);
    }
  };

  return (
    <>
      <JudulHalaman
        ikon={Recycle}
        judul="Master Jenis Sampah"
        keterangan="Jenis yang dinonaktifkan tidak bisa dipilih untuk setoran baru; riwayat setoran lama tetap tersimpan."
      />

      <Kartu className="mb-4">
        <form onSubmit={tambah} className="flex flex-wrap items-start gap-2">
          <div className="flex-1 min-w-48">
            <Input required placeholder="Nama jenis sampah baru, mis. Elektronik" value={baru.nama} onChange={(e) => setBaru((b) => ({ ...b, nama: e.target.value }))} />
            {galatBaru && <p className="mt-1 text-xs text-red-600 dark:text-red-400">{galatBaru}</p>}
          </div>
          <Input className="w-24" aria-label="Satuan" value={baru.satuan} onChange={(e) => setBaru((b) => ({ ...b, satuan: e.target.value }))} />
          <Tombol type="submit" loading={menyimpan}>
            <Plus className="w-4 h-4" /> Tambah
          </Tombol>
        </form>
      </Kartu>

      <Kartu>
        {error ? (
          <GagalMuat error={error} onUlang={refetch} />
        ) : loading && !data ? (
          <SkeletonBaris jumlah={6} />
        ) : daftar.length === 0 ? (
          <Kosong judul="Belum ada jenis sampah" />
        ) : (
          <ul className="divide-y divide-slate-100 dark:divide-white/5">
            {daftar.map((j) => (
              <li key={j.id} className="py-2.5 flex items-center gap-3">
                {edit?.id === j.id ? (
                  <form
                    className="flex-1 flex items-center gap-2"
                    onSubmit={(e) => {
                      e.preventDefault();
                      ubah(j, { nama: edit.nama }, 'Nama jenis sampah diperbarui.');
                    }}
                  >
                    <Input autoFocus value={edit.nama} onChange={(e) => setEdit({ ...edit, nama: e.target.value })} />
                    <Tombol type="submit" loading={sibuk === j.id} title="Simpan">
                      <Check className="w-3.5 h-3.5" />
                    </Tombol>
                    <Tombol type="button" varian="sekunder" onClick={() => setEdit(null)} title="Batal">
                      <X className="w-3.5 h-3.5" />
                    </Tombol>
                  </form>
                ) : (
                  <>
                    <div className="flex-1">
                      <span className="font-medium text-slate-900 dark:text-white">{j.nama}</span>
                      <span className="ml-2 text-xs font-mono text-slate-500">/{j.satuan}</span>
                    </div>
                    {j.is_aktif ? <Lencana warna="hijau">Aktif</Lencana> : <Lencana>Nonaktif</Lencana>}
                    <Tombol varian="sekunder" onClick={() => setEdit({ id: j.id, nama: j.nama })} title="Ubah nama">
                      <Pencil className="w-3.5 h-3.5" />
                    </Tombol>
                    <Tombol
                      varian={j.is_aktif ? 'bahaya' : 'sekunder'}
                      loading={sibuk === j.id}
                      onClick={() => ubah(j, { is_aktif: !j.is_aktif }, `${j.nama} ${j.is_aktif ? 'dinonaktifkan' : 'diaktifkan'}.`)}
                      title={j.is_aktif ? 'Nonaktifkan' : 'Aktifkan'}
                    >
                      <Power className="w-3.5 h-3.5" />
                    </Tombol>
                  </>
                )}
              </li>
            ))}
          </ul>
        )}
      </Kartu>
    </>
  );
}
