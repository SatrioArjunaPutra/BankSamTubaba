import { useState } from 'react';
import { Download, Search, ShieldCheck } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import { ambilDaftarBankSampah, ambilDashboard, ambilPantauan } from '../services/api';
import { GagalMuat, Kartu, Kosong, Lencana, Skeleton } from '../components/ui';
import StatistikPantauan from '../components/StatistikPantauan';
import FilterPeriode from '../components/FilterPeriode';
import { queryPeriode } from '../utils/periode';
import { unduhCsv } from '../utils/unduhCsv';
import { formatAngka, formatKg, formatRupiah } from '../utils/format';
const DEFINISI = {
  warga: {judul:'Warga',kolom:['Warga','Terdaftar di','Total setor','Saldo','Terakhir setor','Status']},
  transaksi: {judul:'Transaksi',kolom:['ID','Waktu','Warga','Bank sampah','Jenis','Berat','Nilai','Status']},
  donasi: {judul:'Donasi sampah',kolom:['Donatur','Bank sampah','Jenis','Berat','Cara serah','Status']},
};
const tanggal=v=>v?new Date(v).toLocaleDateString('id-ID',{day:'numeric',month:'short',year:'numeric'}):'—';
const STATUS={tercatat:'Tercatat',diajukan:'Menunggu',disetujui:'Disetujui',ditolak:'Ditolak'};
export default function Pantauan({jenis}) {
  const d=DEFINISI[jenis];
  const [q,setQ]=useState(''); const [bank,setBank]=useState(''); const [page,setPage]=useState(1); const [tipe,setTipe]=useState('');
  const [periode,setPeriode]=useState({periode:'bulan',dari:'',sampai:''});
  const rentang=queryPeriode(periode);
  const query={...rentang,q,bank_sampah_id:bank,page,tipe};
  const hasil=useFetch(()=>ambilPantauan(jenis,query),JSON.stringify([jenis,query]));
  const banks=useFetch(()=>ambilDaftarBankSampah());
  const dashboard=useFetch(()=>ambilDashboard(rentang),JSON.stringify(rentang));
  const rows=hasil.data?.data??[]; const meta=hasil.data?.meta;
  const values=r=>jenis==='warga'?[r.name,(r.bank_sampah??[]).map(b=>b.nama).join(', ')||'Belum menjadi nasabah',formatKg(r.total_kg),formatRupiah(r.saldo),tanggal(r.terakhir_setor),r.is_aktif?'Aktif':'Nonaktif']:jenis==='donasi'?[r.warga?.name,r.bank_sampah?.nama,r.items.map(i=>i.nama).join(', '),formatKg(r.total_kg),r.penjemputan_id?'Dijemput bentor':'Diantar','Tercatat']:[(r.tipe==='penarikan'?'TR-':'ST-')+String(r.id).padStart(4,'0'),tanggal(r.created_at),r.warga?.name,r.bank_sampah?.nama,r.tipe==='penarikan'?'Penarikan':r.tipe==='donasi'?'Donasi':'Setoran jual',r.tipe==='penarikan'?'—':formatKg(r.total_kg),formatRupiah(r.total_nilai),STATUS[r.status]??'Tercatat'];
  const filter=(setter,v)=>{setter(v);setPage(1);};
  const sebaran=jenis==='donasi'?(dashboard.data?.data?.peringkat??[]).map(b=>({nama:b.bank_sampah.nama,nilai:b.kg_donasi})).sort((a,b)=>b.nilai-a.nilai):Object.values((dashboard.data?.data?.peringkat??[]).reduce((o,b)=>{const n=b.bank_sampah.kecamatan;(o[n]??={nama:n,nilai:0}).nilai+=b.total_kg;return o;},{}));
  return <div className="reference-list-page">
    <header className="reference-heading"><div><p><a href="#ringkasan">Ringkasan</a> / {d.judul}</p><h1>{d.judul}</h1></div><div className="reference-toolbar">{jenis!=='warga'&&<FilterPeriode nilai={periode} onUbah={v=>{setPeriode(v);setPage(1);}}/>}<button className="reference-export" disabled={!rows.length} onClick={()=>unduhCsv(d.kolom,rows.map(values),jenis+'-halaman-'+page)}><Download size={16}/>Ekspor halaman</button></div></header>
    <StatistikPantauan jenis={jenis} data={dashboard.data?.data?.ringkasan}/>
    {dashboard.error&&<GagalMuat error={dashboard.error} onUlang={dashboard.refetch}/>}
    <div className="reference-filters"><label className="reference-search"><Search size={17}/><input type="search" aria-label={'Cari '+d.judul} placeholder={jenis==='warga'?'Cari nama atau nomor HP…':'Cari nama warga…'} value={q} onChange={e=>filter(setQ,e.target.value)}/></label><select aria-label="Saring bank sampah" value={bank} onChange={e=>filter(setBank,e.target.value)}><option value="">Semua bank sampah</option>{(banks.data?.data??[]).map(b=><option key={b.id} value={b.id}>{b.nama}</option>)}</select>{jenis==='transaksi'&&<div className="reference-period" role="group" aria-label="Jenis transaksi">{[['','Semua'],['jual','Setoran'],['penarikan','Penarikan'],['donasi','Donasi']].map(([v,l])=><button key={v} aria-pressed={tipe===v} onClick={()=>filter(setTipe,v)}>{l}</button>)}</div>}</div>
    <div className={jenis==='transaksi'?'':'monitor-workspace'}>
      <Kartu className="reference-list-card">{jenis==='donasi'&&<div className="panel-heading mb-5"><div><h2>Donasi sampah terbaru</h2><p>Semua bank sampah · diurutkan dari yang terbaru</p></div></div>}{hasil.error?<GagalMuat error={hasil.error} onUlang={hasil.refetch}/>:hasil.loading?<Skeleton className="h-64"/>:!rows.length?<Kosong judul={'Belum ada '+d.judul.toLowerCase()} keterangan="Data akan muncul setelah aktivitas dicatat di aplikasi."/>:<div className="reference-table-scroll"><table className={'reference-table tabel-kartu'+(jenis==='transaksi'?' transaksi-hp':'')}><thead><tr>{d.kolom.map(k=><th key={k}>{k}</th>)}</tr></thead><tbody>{rows.map(r=><tr key={(r.tipe??jenis)+'-'+r.id}>{values(r).map((v,i)=><td key={i} data-label={i?d.kolom[i]:undefined} className={d.kolom[i]==='Bank sampah'||d.kolom[i]==='Terdaftar di'?'penuh':undefined}>{i===0?<span className="rank-bank">{jenis!=='transaksi'&&<b className="rank-badge">{jenis==='warga'?'W':'D'}</b>}<span><strong>{v}</strong>{jenis==='warga'&&<small>{r.phone??'Nomor HP belum diisi'}</small>}{jenis==='donasi'&&<small>{tanggal(r.created_at)}</small>}</span></span>:i===d.kolom.length-1?<Lencana warna={v==='Nonaktif'||v==='Ditolak'?'abu':v==='Menunggu'?'kuning':'hijau'}>{v}</Lencana>:v}</td>)}</tr>)}</tbody></table></div>}
        <div className="reference-pagination"><span>Menampilkan {rows.length} dari {formatAngka(meta?.total??0)} data · halaman {page}</span><div><button disabled={page===1} onClick={()=>setPage(page-1)}>Sebelumnya</button><button disabled={page>=(meta?.last_page??1)} onClick={()=>setPage(page+1)}>Berikutnya</button></div></div>
      </Kartu>
      {jenis!=='transaksi'&&<aside className="monitor-aside"><Kartu><div className="panel-heading"><h2>{jenis==='donasi'?'Penerima donasi terbanyak':'Kontribusi per kecamatan'}</h2><p>Berat sampah pada periode terpilih</p></div><div className="spread-list">{sebaran.slice(0,6).map(s=><div key={s.nama}><div><span>{s.nama.replace(/^Bank Sampah (Demo )?/,'')}</span><strong>{formatKg(s.nilai)}</strong></div><div className="spread-track"><i style={{width:s.nilai/Math.max(1,...sebaran.map(x=>x.nilai))*100+'%'}}/></div></div>)}</div></Kartu>{jenis==='warga'?<div className="privacy-notice"><ShieldCheck size={23}/><div><strong>Data pribadi disamarkan</strong><p>Nomor HP ditampilkan sebagian. Alamat lengkap warga tidak ditampilkan di panel DLH.</p></div></div>:<div className="privacy-notice"><ShieldCheck size={23}/><div><strong>Donasi tanpa penambahan saldo</strong><p>Berat donasi merupakan hasil timbang yang sudah dicatat operator bank sampah.</p></div></div>}</aside>}
    </div>
  </div>;
}
