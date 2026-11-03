import { useEffect, useState } from 'react';
import { ImageOff, Megaphone, Newspaper, Pencil, Plus, Search, Trash2 } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilBeritaDlh, hapusBerita, simpanBerita } from '../services/api';
import { useToast } from '../components/Toast';
import TeksBerjalanDlh from '../components/TeksBerjalanDlh';
import { Field, GagalMuat, Input, JudulHalaman, Kartu, Kosong, Lencana, Modal, Paginasi, Pilihan, SkeletonBaris, Tombol } from '../components/ui';
import { formatTanggal, KATEGORI_BERITA } from '../utils/format';

const KOSONG = { judul: '', ringkasan: '', isi: '', kategori: 'berita', status: 'draf' };

function FormBerita({ berita, onTutup, onTersimpan }) {
  const toast = useToast();
  const [isian, setIsian] = useState(berita ? { judul: berita.judul, ringkasan: berita.ringkasan, isi: berita.isi, kategori: berita.kategori, status: berita.status } : KOSONG);
  const [foto, setFoto] = useState(null);
  const [pratinjau, setPratinjau] = useState(null);
  const [hapusFoto, setHapusFoto] = useState(false);
  const [menyimpan, setMenyimpan] = useState(false);
  const [galat, setGalat] = useState({});
  const ubah = (kunci) => (e) => setIsian((f) => ({ ...f, [kunci]: e.target.value }));

  useEffect(() => () => {
    if (pratinjau) URL.revokeObjectURL(pratinjau);
  }, [pratinjau]);

  const pilihFoto = (e) => {
    const file = e.target.files?.[0] ?? null;
    setFoto(file);
    setHapusFoto(false);
    setPratinjau(file ? URL.createObjectURL(file) : null);
  };

  const kirim = async (e) => {
    e.preventDefault();
    setMenyimpan(true);
    setGalat({});
    const form = new FormData();
    Object.entries(isian).forEach(([k, v]) => form.append(k, v));
    if (foto) form.append('foto', foto);
    if (hapusFoto) form.append('hapus_foto', '1');
    try {
      await simpanBerita(berita?.id, form);
      toast.sukses(isian.status === 'terbit' ? 'Berita diterbitkan.' : 'Draf berita disimpan.');
      onTersimpan();
    } catch (err) {
      setGalat(err.pesanField ?? {});
      toast.gagal(err.message);
    } finally {
      setMenyimpan(false);
    }
  };

  const fotoTampil = pratinjau ?? (hapusFoto ? null : berita?.foto);

  return (
    <Modal judul={berita ? 'Ubah berita' : 'Tulis berita'} onTutup={onTutup} lebar="max-w-2xl">
      <form onSubmit={kirim} className="berita-form">
        <Field label="Judul" error={galat.judul}>
          <Input required maxLength={150} value={isian.judul} onChange={ubah('judul')} />
        </Field>
        <div className="berita-form-pasangan">
          <Field label="Kategori" error={galat.kategori}>
            <Pilihan value={isian.kategori} onChange={ubah('kategori')}>
              {Object.entries(KATEGORI_BERITA).map(([v, label]) => <option key={v} value={v}>{label}</option>)}
            </Pilihan>
          </Field>
          <Field label="Status" error={galat.status}>
            <Pilihan value={isian.status} onChange={ubah('status')}>
              <option value="draf">Draf (belum tampil)</option>
              <option value="terbit">Terbit (tampil di beranda)</option>
            </Pilihan>
          </Field>
        </div>
        <Field label="Ringkasan" error={galat.ringkasan}>
          <textarea className="form-input" rows={2} required maxLength={300} value={isian.ringkasan} onChange={ubah('ringkasan')} />
        </Field>
        <Field label="Isi berita" error={galat.isi}>
          <textarea className="form-input" rows={8} required maxLength={20000} value={isian.isi} onChange={ubah('isi')} />
        </Field>
        <small className="berita-form-petunjuk">Pisahkan paragraf dengan baris kosong. Awali baris dengan <code>##</code> dan spasi untuk subjudul, atau <code>&gt;</code> dan spasi untuk kutipan.</small>
        <Field label="Foto (JPG, PNG, atau WebP, maksimal 2 MB)" error={galat.foto}>
          <Input type="file" accept="image/jpeg,image/png,image/webp" onChange={pilihFoto} />
        </Field>
        {fotoTampil && (
          <div className="berita-form-foto">
            <img src={fotoTampil} alt="Pratinjau foto berita" />
            {!foto && <Tombol type="button" varian="sekunder" onClick={() => setHapusFoto(true)}><ImageOff size={15} /> Hapus foto</Tombol>}
          </div>
        )}
        <div className="berita-form-aksi">
          <Tombol type="button" varian="sekunder" onClick={onTutup}>Batal</Tombol>
          <Tombol type="submit" loading={menyimpan}>{isian.status === 'terbit' ? 'Simpan dan terbitkan' : 'Simpan draf'}</Tombol>
        </div>
      </form>
    </Modal>
  );
}

export default function BeritaDlh() {
  const toast = useToast();
  const [tab, setTab] = useState('artikel');
  const [filter, setFilter] = useState({ status: '', q: '', page: 1 });
  const [cari, setCari] = useState('');
  const [form, setForm] = useState(null); // null | { berita?: object }
  const [sibuk, setSibuk] = useState(null);
  const { data, loading, error, refetch } = useFetch(() => ambilBeritaDlh(filter), JSON.stringify(filter));
  const daftar = data?.data ?? [];

  const hapus = async (b) => {
    if (!window.confirm(`Hapus berita "${b.judul}"? Tindakan ini tidak bisa dibatalkan.`)) return;
    setSibuk(b.id);
    try {
      await hapusBerita(b.id);
      toast.sukses('Berita dihapus.');
      refetch();
    } catch (err) {
      toast.gagal(err.message);
    } finally {
      setSibuk(null);
    }
  };

  return (
    <>
      <JudulHalaman
        ikon={Newspaper}
        judul="Berita"
        keterangan={tab === 'artikel' ? 'Artikel berstatus Terbit langsung tampil di beranda. Draf hanya terlihat di panel ini.' : 'Pengumuman singkat yang bergerak di bagian paling atas web publik.'}
        aksi={tab === 'artikel' && <Tombol onClick={() => setForm({})}><Plus className="w-4 h-4" /> Tulis berita</Tombol>}
      />

      <div className="panel-tab">
        <button type="button" aria-pressed={tab === 'artikel'} onClick={() => setTab('artikel')}><Newspaper className="w-4 h-4" /> Artikel</button>
        <button type="button" aria-pressed={tab === 'teks'} onClick={() => setTab('teks')}><Megaphone className="w-4 h-4" /> Teks Berjalan</button>
      </div>

      {tab === 'teks' ? <TeksBerjalanDlh /> : (
      <Kartu>
        <form className="berita-filter" onSubmit={(e) => { e.preventDefault(); setFilter((f) => ({ ...f, q: cari.trim(), page: 1 })); }}>
          <Input placeholder="Cari judul berita" aria-label="Cari judul berita" value={cari} onChange={(e) => setCari(e.target.value)} />
          <Pilihan aria-label="Status berita" value={filter.status} onChange={(e) => setFilter((f) => ({ ...f, status: e.target.value, page: 1 }))}>
            <option value="">Semua status</option>
            <option value="terbit">Terbit</option>
            <option value="draf">Draf</option>
          </Pilihan>
          <Tombol type="submit" varian="sekunder"><Search className="w-4 h-4" /> Cari</Tombol>
        </form>

        {error ? (
          <GagalMuat error={error} onUlang={refetch} />
        ) : loading && !data ? (
          <SkeletonBaris jumlah={5} />
        ) : daftar.length === 0 ? (
          <Kosong judul="Belum ada berita" keterangan="Tulis berita pertama lewat tombol Tulis berita." />
        ) : (
          <ul className="berita-baris">
            {daftar.map((b) => (
              <li key={b.id}>
                <span className="berita-baris-foto">{b.foto ? <img src={b.foto} alt="" loading="lazy" decoding="async" /> : <Newspaper size={22} aria-hidden="true" />}</span>
                <div className="berita-baris-teks">
                  <strong>{b.judul}</strong>
                  <small>{KATEGORI_BERITA[b.kategori] ?? b.kategori} · {b.status === 'terbit' ? `Terbit ${formatTanggal(b.diterbitkan_at)} · ${b.dibaca} dibaca` : `Diubah ${formatTanggal(b.updated_at)}`}</small>
                </div>
                <Lencana warna={b.status === 'terbit' ? 'hijau' : 'abu'}>{b.status === 'terbit' ? 'Terbit' : 'Draf'}</Lencana>
                <div className="berita-baris-aksi">
                  <Tombol varian="sekunder" aria-label={`Ubah ${b.judul}`} title="Ubah" onClick={() => setForm({ berita: b })}><Pencil className="w-3.5 h-3.5" /></Tombol>
                  <Tombol varian="bahaya" aria-label={`Hapus ${b.judul}`} title="Hapus" loading={sibuk === b.id} onClick={() => hapus(b)}><Trash2 className="w-3.5 h-3.5" /></Tombol>
                </div>
              </li>
            ))}
          </ul>
        )}
        <Paginasi meta={data?.meta} onHalaman={(page) => setFilter((f) => ({ ...f, page }))} />
      </Kartu>
      )}

      {form && (
        <FormBerita
          key={form.berita?.id ?? 'baru'}
          berita={form.berita}
          onTutup={() => setForm(null)}
          onTersimpan={() => {
            setForm(null);
            refetch();
          }}
        />
      )}
    </>
  );
}
