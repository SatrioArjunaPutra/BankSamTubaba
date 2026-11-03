import { useState } from 'react';
import { Eye, EyeOff, Pencil, Plus, Trash2 } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilTeksBerjalanDlh, hapusTeksBerjalan, simpanTeksBerjalan } from '../services/api';
import { useToast } from './Toast';
import { Field, GagalMuat, Input, Kartu, Kosong, Lencana, Modal, Paginasi, SkeletonBaris, Tombol } from './ui';

const BATAS_TEKS = 200;

function FormTeks({ data, onTutup, onTersimpan }) {
  const toast = useToast();
  const [teks, setTeks] = useState(data?.teks ?? '');
  const [urutan, setUrutan] = useState(data?.urutan ?? '');
  const [aktif, setAktif] = useState(data?.is_aktif ?? true);
  const [menyimpan, setMenyimpan] = useState(false);
  const [galat, setGalat] = useState({});

  const kirim = async (e) => {
    e.preventDefault();
    setMenyimpan(true);
    setGalat({});
    try {
      await simpanTeksBerjalan(data?.id, { teks, is_aktif: aktif, ...(urutan === '' ? {} : { urutan: Number(urutan) }) });
      toast.sukses(aktif ? 'Teks berjalan ditayangkan.' : 'Teks berjalan disimpan tanpa ditayangkan.');
      onTersimpan();
    } catch (err) {
      setGalat(err.pesanField ?? {});
      toast.gagal(err.message);
    } finally {
      setMenyimpan(false);
    }
  };

  return (
    <Modal judul={data ? 'Ubah teks berjalan' : 'Tambah teks berjalan'} onTutup={onTutup} lebar="max-w-xl">
      <form onSubmit={kirim} className="berita-form">
        <Field label="Teks" error={galat.teks}>
          <textarea className="form-input" rows={3} required maxLength={BATAS_TEKS} value={teks} onChange={(e) => setTeks(e.target.value)} />
        </Field>
        <small className="berita-form-petunjuk">{teks.length}/{BATAS_TEKS} karakter</small>
        <Field label="Urutan tampil (angka kecil lebih dulu)" error={galat.urutan}>
          <Input type="number" required={Boolean(data)} min={0} max={9999} placeholder={data ? undefined : 'Kosongkan agar tampil paling akhir'} value={urutan} onChange={(e) => setUrutan(e.target.value)} />
        </Field>
        <label className="teks-jalan-centang">
          <input type="checkbox" checked={aktif} onChange={(e) => setAktif(e.target.checked)} />
          Tayangkan di web publik
        </label>
        <div className="berita-form-aksi">
          <Tombol type="button" varian="sekunder" onClick={onTutup}>Batal</Tombol>
          <Tombol type="submit" loading={menyimpan}>Simpan</Tombol>
        </div>
      </form>
    </Modal>
  );
}

export default function TeksBerjalanDlh() {
  const toast = useToast();
  const [page, setPage] = useState(1);
  const [form, setForm] = useState(null); // null | { data?: object }
  const [sibuk, setSibuk] = useState(null);
  const { data, loading, error, refetch } = useFetch(() => ambilTeksBerjalanDlh({ page }), page);
  const daftar = data?.data ?? [];

  const jalankan = async (t, aksi, pesan) => {
    setSibuk(t.id);
    try {
      await aksi();
      toast.sukses(pesan);
      refetch();
    } catch (err) {
      toast.gagal(err.message);
    } finally {
      setSibuk(null);
    }
  };

  const ubahTayang = (t) => jalankan(
    t,
    () => simpanTeksBerjalan(t.id, { is_aktif: !t.is_aktif }),
    t.is_aktif ? 'Teks dimatikan.' : 'Teks ditayangkan.',
  );

  const hapus = (t) => {
    if (!window.confirm(`Hapus teks "${t.teks}"? Tindakan ini tidak bisa dibatalkan.`)) return;
    jalankan(t, () => hapusTeksBerjalan(t.id), 'Teks dihapus.');
  };

  return (
    <Kartu>
      <div className="teks-jalan-kepala">
        <p>Teks aktif bergerak di bagian paling atas web publik, sesuai urutan. Bila tidak ada teks aktif, stripnya tidak tampil.</p>
        <Tombol onClick={() => setForm({})}><Plus className="w-4 h-4" /> Tambah teks</Tombol>
      </div>

      {error ? (
        <GagalMuat error={error} onUlang={refetch} />
      ) : loading && !data ? (
        <SkeletonBaris jumlah={3} />
      ) : daftar.length === 0 ? (
        <Kosong judul="Belum ada teks berjalan" keterangan="Tambahkan teks pertama lewat tombol Tambah teks." />
      ) : (
        <ul className="berita-baris teks-jalan-baris">
          {daftar.map((t) => (
            <li key={t.id}>
              <span className="teks-jalan-urutan" title="Urutan tampil">{t.urutan}</span>
              <div className="berita-baris-teks"><strong>{t.teks}</strong></div>
              <Lencana warna={t.is_aktif ? 'hijau' : 'abu'}>{t.is_aktif ? 'Tayang' : 'Mati'}</Lencana>
              <div className="berita-baris-aksi">
                <Tombol
                  varian="sekunder"
                  aria-label={t.is_aktif ? `Matikan ${t.teks}` : `Tayangkan ${t.teks}`}
                  title={t.is_aktif ? 'Matikan' : 'Tayangkan'}
                  loading={sibuk === t.id}
                  onClick={() => ubahTayang(t)}
                >
                  {t.is_aktif ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                </Tombol>
                <Tombol varian="sekunder" aria-label={`Ubah ${t.teks}`} title="Ubah" onClick={() => setForm({ data: t })}><Pencil className="w-3.5 h-3.5" /></Tombol>
                <Tombol varian="bahaya" aria-label={`Hapus ${t.teks}`} title="Hapus" disabled={sibuk === t.id} onClick={() => hapus(t)}><Trash2 className="w-3.5 h-3.5" /></Tombol>
              </div>
            </li>
          ))}
        </ul>
      )}
      <Paginasi meta={data?.meta} onHalaman={setPage} />

      {form && (
        <FormTeks
          key={form.data?.id ?? 'baru'}
          data={form.data}
          onTutup={() => setForm(null)}
          onTersimpan={() => {
            setForm(null);
            refetch();
          }}
        />
      )}
    </Kartu>
  );
}
