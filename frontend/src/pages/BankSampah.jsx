import { useState } from 'react';
import { Download, MapPin, Pencil, Phone, Plus, Power, Search, Store, UserPlus, Users } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import useLayarHp from '../hooks/useLayarHp';
import { ambilAkunBankSampah, ambilDaftarBankSampah, ambilPantauan, ambilTren, buatOperator, tambahBankSampah, ubahBankSampah, ubahStatusAkun } from '../services/api';
import { useToast } from '../components/Toast';
import { Field, GagalMuat, Input, Kartu, Kosong, Lencana, Modal, Paginasi, SkeletonBaris, Tombol } from '../components/ui';
import { formatAngka, formatKg } from '../utils/format';
import { unduhCsv } from '../utils/unduhCsv';

const KOSONG = { kode: '', nama: '', tiyuh: '', kecamatan: '', alamat: '', lat: '', lng: '', no_hp_publik: '' };

export default function BankSampah() {
  const toast = useToast();
  const [filter, setFilter] = useState({ q: '', is_aktif: '', kecamatan: '', page: 1 });
  const [cari, setCari] = useState('');
  const [form, setForm] = useState(null); // null | {bank?: object}
  const [formOperator, setFormOperator] = useState(null);
  const [kelolaAkun, setKelolaAkun] = useState(null);
  const [mengubah, setMengubah] = useState(null);
  const [terpilih, setTerpilih] = useState(null);
  const hp = useLayarHp();

  const { data, loading, error, refetch } = useFetch(() => ambilDaftarBankSampah(filter), JSON.stringify(filter));
  const daftar = data?.data ?? [];
  const detail = daftar.find((b) => b.id === terpilih) ?? (hp ? undefined : daftar[0]);

  const ubahAktif = async (bank) => {
    setMengubah(bank.id);
    try {
      await ubahBankSampah(bank.id, { is_aktif: !bank.is_aktif });
      toast.sukses(`${bank.nama} ${bank.is_aktif ? 'dinonaktifkan' : 'diaktifkan'}.`);
      refetch();
    } catch (err) {
      toast.gagal(err.message);
    } finally {
      setMengubah(null);
    }
  };

  const tutupDetailHp = () => {
    if (hp) setTerpilih(null);
  };

  const isiDetail = detail && (
    <>
          <div className="bank-detail-icon"><Store size={28} strokeWidth={1.6} /></div>
          <p className="section-caption mt-4">{detail.kode}</p>
          <h2 className="bank-detail-title">{detail.nama}</h2>
          <div className="mt-3"><Lencana warna={detail.is_aktif ? 'hijau' : 'abu'}>{detail.is_aktif ? 'Aktif' : 'Nonaktif'}</Lencana></div>
          <div className="bank-detail-info">
            <div><MapPin size={17} /><span><strong>Lokasi bank sampah</strong><small>{detail.alamat || detail.tiyuh}<br />{detail.tiyuh}, {detail.kecamatan}</small></span></div>
            <div><Phone size={17} /><span><strong>Kontak publik</strong><small>{detail.no_hp_publik || 'Belum dicantumkan'}</small></span></div>
            <div><Users size={17} /><span><strong>Operator terdaftar</strong><small>{detail.jumlah_operator ?? 0} operator</small></span></div>
          </div>
          <div className="bank-summary-stats"><span>Sampah bln ini<strong>{formatKg(detail.sampah_bulan_ini_kg)}</strong></span><span>Nasabah<strong>{formatAngka(detail.jumlah_nasabah)}</strong></span><span>Bentor<strong>{formatAngka(detail.jumlah_bentor)}</strong></span></div>
          <DetailOperasionalBank key={detail.id} bank={detail}/>
          {detail.koordinat_estimasi && <p className="section-caption mb-5">Titik lokasi masih estimasi kecamatan.</p>}
          <div className="flex flex-col gap-2">
            <Tombol onClick={() => { tutupDetailHp(); setForm({ bank: detail }); }}><Pencil size={15} /> Ubah data bank</Tombol>
            <Tombol varian="sekunder" onClick={() => { tutupDetailHp(); setKelolaAkun(detail); }}><Users size={15} /> Kelola operator & bentor</Tombol>
            {hp && (
              <>
                <Tombol varian="sekunder" onClick={() => { tutupDetailHp(); setFormOperator(detail); }}><UserPlus size={15} /> Buat akun operator</Tombol>
                <Tombol varian={detail.is_aktif ? 'bahaya' : 'sekunder'} loading={mengubah === detail.id} onClick={() => ubahAktif(detail)}><Power size={15} /> {detail.is_aktif ? 'Nonaktifkan bank sampah' : 'Aktifkan bank sampah'}</Tombol>
              </>
            )}
          </div>
    </>
  );

  return (
    <>
      <header className="reference-heading">
        <div><p><a href="#ringkasan">Ringkasan</a> / Bank sampah</p><h1>Bank sampah</h1></div>
        <div className="reference-toolbar">
          <button className="reference-export" disabled={!daftar.length} onClick={() => unduhCsv(['Bank sampah','Kecamatan','Sampah bulan ini (kg)','Nasabah','Bentor','Status'], daftar.map(b => [b.nama,b.kecamatan,b.sampah_bulan_ini_kg,b.jumlah_nasabah,b.jumlah_bentor,b.is_aktif?'Aktif':'Nonaktif']), 'bank-sampah-halaman-'+filter.page)}><Download size={16}/>Ekspor halaman</button>
          <Tombol onClick={() => setForm({})}>
            <Plus className="w-4 h-4" /> Tambah bank sampah
          </Tombol>
        </div>
      </header>

      <div className="bank-workspace">
      <Kartu className="bank-list-card">
        <form
          className="flex flex-wrap gap-2 mb-4"
          onSubmit={(e) => {
            e.preventDefault();
            setFilter((f) => ({ ...f, q: cari, page: 1 }));
          }}
        >
          <Input className="flex-1 min-w-48" placeholder="Cari nama, tiyuh, atau kode" value={cari} onChange={(e) => setCari(e.target.value)} />
          <div className="status-filter" role="group" aria-label="Status bank sampah">
            {[['', 'Semua'], ['1', 'Aktif'], ['0', 'Nonaktif']].map(([v, label]) => (
              <button key={v} type="button" aria-pressed={filter.is_aktif === v} onClick={() => setFilter((f) => ({ ...f, is_aktif: v, page: 1 }))}>{label}</button>
            ))}
          </div>
          <Tombol type="submit" varian="sekunder">
            <Search className="w-4 h-4" /> Cari
          </Tombol>
          <select className="form-input" style={{width:'auto'}} aria-label="Kecamatan bank sampah" value={filter.kecamatan} onChange={e=>setFilter(f=>({...f,kecamatan:e.target.value,page:1}))}>
            <option value="">Semua kecamatan</option>
            {['Batu Putih','Gunung Agung','Gunung Terang','Lambu Kibang','Pagar Dewa','Tulang Bawang Tengah','Tulang Bawang Udik','Tumijajar','Way Kenanga'].map(k=><option key={k}>{k}</option>)}
          </select>
        </form>

        {error ? (
          <GagalMuat error={error} onUlang={refetch} />
        ) : loading && !data ? (
          <SkeletonBaris jumlah={8} />
        ) : daftar.length === 0 ? (
          <Kosong judul="Bank sampah tidak ditemukan" keterangan="Ubah kata kunci pencarian atau tambah bank sampah baru." />
        ) : (
          <div className="overflow-x-auto">
            <table className="reference-table w-full text-sm min-w-[760px] tabel-kartu bank-hp">
              <thead>
                <tr className="text-left text-xs font-mono uppercase tracking-wider text-slate-500 dark:text-zinc-400 border-b border-slate-200 dark:border-white/10">
                  <th className="py-2 pr-2">Bank sampah</th>
                  <th className="py-2 pr-2">Kecamatan</th>
                  <th className="py-2 pr-2">Sampah bln ini</th>
                  <th className="py-2 pr-2">Nasabah</th>
                  <th className="py-2 pr-2">Bentor</th>
                  <th className="py-2 pr-2">Status</th>
                  <th className="py-2 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {daftar.map((b) => (
                  <tr key={b.id} onClick={hp ? () => setTerpilih(b.id) : undefined} className={`border-b border-slate-100 dark:border-white/5 ${detail?.id === b.id ? 'bank-selected' : ''}`}>
                    <td className="py-2.5 pr-2 font-medium text-slate-900 dark:text-white">
                      <button className="text-left hover:text-cyan-600" aria-pressed={detail?.id === b.id} onClick={() => setTerpilih(b.id)}>{b.nama}</button>
                      <small className="block text-slate-500 dark:text-zinc-400 mt-1">{b.kode} · {b.jumlah_operator ?? 0} operator</small>
                      {b.koordinat_estimasi && <span className="ml-2"><Lencana warna="kuning">Koordinat estimasi</Lencana></span>}
                    </td>
                    <td data-label="Kecamatan" className="py-2.5 pr-2 text-xs text-slate-600 dark:text-zinc-300 penuh">
                      {b.kecamatan}
                    </td>
                    <td data-label="Sampah bln ini" className="py-2.5 pr-2">{formatKg(b.sampah_bulan_ini_kg)}</td>
                    <td data-label="Nasabah" className="py-2.5 pr-2">{formatAngka(b.jumlah_nasabah)}</td>
                    <td data-label="Bentor" className="py-2.5 pr-2">{formatAngka(b.jumlah_bentor)}</td>
                    <td data-label="Status" className="py-2.5 pr-2">{b.is_aktif ? <Lencana warna="hijau">Aktif</Lencana> : <Lencana>Nonaktif</Lencana>}</td>
                    <td className="py-2.5 text-right whitespace-nowrap space-x-1 tabel-aksi">
                      <Tombol varian="sekunder" onClick={() => setForm({ bank: b })} title="Ubah">
                        <Pencil className="w-3.5 h-3.5" />
                      </Tombol>
                      <Tombol varian="sekunder" onClick={() => setFormOperator(b)} title="Buat akun operator">
                        <UserPlus className="w-3.5 h-3.5" />
                      </Tombol>
                      <Tombol varian="sekunder" onClick={() => setKelolaAkun(b)} title="Akun operator & bentor">
                        <Users className="w-3.5 h-3.5" />
                      </Tombol>
                      <Tombol varian={b.is_aktif ? 'bahaya' : 'sekunder'} loading={mengubah === b.id} onClick={() => ubahAktif(b)} title={b.is_aktif ? 'Nonaktifkan' : 'Aktifkan'}>
                        <Power className="w-3.5 h-3.5" />
                      </Tombol>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Paginasi meta={data?.meta} onHalaman={(page) => setFilter((f) => ({ ...f, page }))} />
      </Kartu>
      {detail && !error && !hp && <Kartu className="bank-detail-card">{isiDetail}</Kartu>}
      {detail && hp && (
        <Modal judul={detail.nama} onTutup={() => setTerpilih(null)}>
          <div className="bank-detail-popup">{isiDetail}</div>
        </Modal>
      )}
      </div>

      {form && (
        <FormBankSampah
          bank={form.bank}
          onTutup={() => setForm(null)}
          onTersimpan={() => {
            setForm(null);
            refetch();
          }}
        />
      )}
      {formOperator && <FormOperator bank={formOperator} onTutup={() => setFormOperator(null)} onTersimpan={() => { setFormOperator(null); refetch(); }} />}
      {kelolaAkun && <DaftarAkun bank={kelolaAkun} onTutup={() => { setKelolaAkun(null); refetch(); }} />}
    </>
  );
}

function DetailOperasionalBank({bank}) {
  const [rentang]=useState(()=>{
    const akhir=new Date();
    const awal=new Date(akhir.getFullYear(),akhir.getMonth()-5,1);
    const tanggal=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
    return {dari:tanggal(awal),sampai:tanggal(akhir),interval:'bulanan'};
  });
  const tren=useFetch(()=>ambilTren(bank.id,rentang),JSON.stringify([bank.id,rentang]));
  const armada=useFetch(()=>ambilPantauan('bentor',{bank_sampah_id:bank.id,per_page:100}),bank.id);
  const data=tren.data?.data?.data??[];
  const maks=Math.max(1,...data.map(d=>d.total_kg));
  return <div className="bank-operational-detail">
    <h3>Setoran 6 bulan</h3>
    {tren.error?<GagalMuat error={tren.error} onUlang={tren.refetch}/>:<div className="bank-mini-chart" role="img" aria-label="Berat setoran enam bulan terakhir">{data.map(d=><div key={d.periode} title={`${d.periode}: ${formatKg(d.total_kg)}`}><div><i style={{height:Math.max(d.total_kg?3:0,d.total_kg/maks*100)+'%'}}/></div><small>{new Date(d.periode+'-01T12:00:00').toLocaleDateString('id-ID',{month:'short'})}</small></div>)}</div>}
    {tren.loading&&<p>Memuat tren…</p>}
    <h3>Bentor terdaftar</h3>
    {armada.error?<GagalMuat error={armada.error} onUlang={armada.refetch}/>:armada.loading?<p>Memuat armada…</p>:!armada.data?.data?.length?<p>Belum ada armada terdaftar.</p>:<div className="bank-driver-list">{armada.data.data.slice(0,4).map(a=><div key={a.id}><span className="rank-badge">BT</span><span><strong>{a.driver}</strong><small>{a.plat_nomor}</small></span><Lencana warna={a.status==='siaga'?'hijau':a.status==='bertugas'?'kuning':'abu'}>{a.status==='siaga'?'Tersedia':a.status==='bertugas'?'Bertugas':'Istirahat'}</Lencana></div>)}{armada.data.meta.total>4&&<a href="#bentor">Lihat seluruh {armada.data.meta.total} bentor →</a>}</div>}
  </div>;
}

const LABEL_ROLE = { bank_sampah: 'Operator', bentor: 'Bentor' };

// Akun operator & bentor satu bank sampah; nonaktif = langsung keluar dari semua perangkat
function DaftarAkun({ bank, onTutup }) {
  const toast = useToast();
  const [sibuk, setSibuk] = useState(null);
  const { data, loading, error, refetch } = useFetch(() => ambilAkunBankSampah(bank.id), bank.id);
  const akun = data?.data ?? [];

  const ubah = async (a) => {
    if (a.is_aktif && !window.confirm(`Nonaktifkan akun ${a.name}? Akun ini akan langsung keluar dari semua perangkat.`)) return;
    setSibuk(a.id);
    try {
      await ubahStatusAkun(a.id, !a.is_aktif);
      toast.sukses(`Akun ${a.name} ${a.is_aktif ? 'dinonaktifkan' : 'diaktifkan'}.`);
      refetch();
    } catch (err) {
      toast.gagal(err.message);
    } finally {
      setSibuk(null);
    }
  };

  return (
    <Modal judul={`Akun · ${bank.nama}`} onTutup={onTutup}>
      {error ? (
        <GagalMuat error={error} onUlang={refetch} />
      ) : loading && !data ? (
        <SkeletonBaris jumlah={3} />
      ) : akun.length === 0 ? (
        <Kosong judul="Belum ada akun" keterangan="Buat akun operator lewat tombol tambah operator." />
      ) : (
        <ul className="divide-y divide-slate-100 dark:divide-white/5">
          {akun.map((a) => (
            <li key={a.id} className="py-2.5 flex items-center gap-3">
              <div className="flex-1 min-w-0">
                <div className="font-medium text-slate-900 dark:text-white truncate">{a.name}</div>
                <div className="text-xs text-slate-500 dark:text-zinc-400 truncate">
                  {LABEL_ROLE[a.role] ?? a.role} · {a.email}
                </div>
              </div>
              {a.is_aktif ? <Lencana warna="hijau">Aktif</Lencana> : <Lencana>Nonaktif</Lencana>}
              <Tombol varian={a.is_aktif ? 'bahaya' : 'sekunder'} loading={sibuk === a.id} onClick={() => ubah(a)}>
                {a.is_aktif ? 'Nonaktifkan' : 'Aktifkan'}
              </Tombol>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  );
}

function FormBankSampah({ bank, onTutup, onTersimpan }) {
  const toast = useToast();
  const [nilai, setNilai] = useState(() =>
    bank ? Object.fromEntries(Object.keys(KOSONG).map((k) => [k, bank[k] ?? ''])) : KOSONG,
  );
  const [galat, setGalat] = useState({});
  const [loading, setLoading] = useState(false);

  const set = (k) => (e) => setNilai((n) => ({ ...n, [k]: e.target.value }));

  const simpan = async (e) => {
    e.preventDefault();
    setLoading(true);
    setGalat({});

    // Kosong dikirim null; kode kosong saat tambah = dibuat otomatis
    const data = Object.fromEntries(Object.entries(nilai).map(([k, v]) => [k, v === '' ? null : v]));
    if (!data.kode) delete data.kode;
    if (data.lat !== null) data.lat = Number(data.lat);
    if (data.lng !== null) data.lng = Number(data.lng);

    // Koordinat yang dikirim dianggap pasti oleh server; jangan kirim jika tidak diubah
    if (bank && data.lat === bank.lat && data.lng === bank.lng) {
      delete data.lat;
      delete data.lng;
    }

    try {
      if (bank) await ubahBankSampah(bank.id, data);
      else await tambahBankSampah(data);
      toast.sukses(bank ? 'Bank sampah berhasil diperbarui.' : 'Bank sampah berhasil ditambahkan.');
      onTersimpan();
    } catch (err) {
      setGalat(err.pesanField ?? {});
      toast.gagal(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal judul={bank ? `Ubah ${bank.nama}` : 'Tambah bank sampah'} onTutup={onTutup}>
      <form onSubmit={simpan} className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <Field label="Kode (kosongkan = otomatis)" error={galat.kode}>
          <Input value={nilai.kode} onChange={set('kode')} placeholder="BS-TUBABA-xx" />
        </Field>
        <Field label="Nama" error={galat.nama}>
          <Input required value={nilai.nama} onChange={set('nama')} />
        </Field>
        <Field label="Tiyuh" error={galat.tiyuh}>
          <Input required value={nilai.tiyuh} onChange={set('tiyuh')} />
        </Field>
        <Field label="Kecamatan" error={galat.kecamatan}>
          <Input required value={nilai.kecamatan} onChange={set('kecamatan')} />
        </Field>
        <div className="sm:col-span-2">
          <Field label="Alamat" error={galat.alamat}>
            <Input value={nilai.alamat} onChange={set('alamat')} />
          </Field>
        </div>
        <Field label="Latitude" error={galat.lat}>
          <Input type="number" step="any" value={nilai.lat} onChange={set('lat')} placeholder="-4.58" />
        </Field>
        <Field label="Longitude" error={galat.lng}>
          <Input type="number" step="any" value={nilai.lng} onChange={set('lng')} placeholder="105.13" />
        </Field>
        <div className="sm:col-span-2">
          <Field label="No HP publik (opsional)" error={galat.no_hp_publik}>
            <Input value={nilai.no_hp_publik} onChange={set('no_hp_publik')} placeholder="08xxxxxxxxxx" />
          </Field>
        </div>
        <div className="sm:col-span-2 flex justify-end gap-2 pt-2">
          <Tombol type="button" varian="sekunder" onClick={onTutup}>
            Batal
          </Tombol>
          <Tombol type="submit" loading={loading}>
            Simpan
          </Tombol>
        </div>
      </form>
    </Modal>
  );
}

function FormOperator({ bank, onTutup, onTersimpan }) {
  const toast = useToast();
  const [nilai, setNilai] = useState({ name: '', email: '', phone: '', password: '', password_confirmation: '' });
  const [galat, setGalat] = useState({});
  const [loading, setLoading] = useState(false);
  const set = (k) => (e) => setNilai((n) => ({ ...n, [k]: e.target.value }));

  const simpan = async (e) => {
    e.preventDefault();
    setLoading(true);
    setGalat({});
    try {
      await buatOperator(bank.id, nilai);
      toast.sukses(`Akun operator ${nilai.email} dibuat untuk ${bank.nama}.`);
      onTersimpan();
    } catch (err) {
      setGalat(err.pesanField ?? {});
      toast.gagal(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal judul={`Akun operator · ${bank.nama}`} onTutup={onTutup}>
      <form onSubmit={simpan} className="space-y-3">
        <Field label="Nama" error={galat.name}>
          <Input required value={nilai.name} onChange={set('name')} />
        </Field>
        <Field label="Email" error={galat.email}>
          <Input type="email" required value={nilai.email} onChange={set('email')} />
        </Field>
        <Field label="Nomor HP" error={galat.phone}>
          <Input required value={nilai.phone} onChange={set('phone')} placeholder="08xxxxxxxxxx" />
        </Field>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Field label="Password (min. 8)" error={galat.password}>
            <Input type="password" autoComplete="new-password" required value={nilai.password} onChange={set('password')} />
          </Field>
          <Field label="Ulangi password">
            <Input type="password" autoComplete="new-password" required value={nilai.password_confirmation} onChange={set('password_confirmation')} />
          </Field>
        </div>
        <p className="text-xs text-slate-500 dark:text-zinc-400">Sampaikan email dan password ini langsung ke operator. Operator login lewat aplikasi mobile.</p>
        <div className="flex justify-end gap-2 pt-2">
          <Tombol type="button" varian="sekunder" onClick={onTutup}>
            Batal
          </Tombol>
          <Tombol type="submit" loading={loading}>
            Buat akun
          </Tombol>
        </div>
      </form>
    </Modal>
  );
}
