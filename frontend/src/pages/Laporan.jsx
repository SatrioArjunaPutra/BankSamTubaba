import { Fragment, useState } from 'react';
import { Download, FileText } from 'lucide-react';
import AngkaGulir from '../components/AngkaGulir';
import LogoAplikasi from '../components/LogoAplikasi';
import useFetch from '../hooks/useFetch';
import { ambilDashboard, ambilKinerja, ambilPantauan } from '../services/api';
import { GagalMuat, Skeleton } from '../components/ui';
import FilterPeriode from '../components/FilterPeriode';
import { queryPeriode } from '../utils/periode';
import { formatAngka, formatKg, formatRupiah } from '../utils/format';
import { unduhCsv } from '../utils/unduhCsv';

const TIPE=[['kinerja','Kinerja bank sampah','Berat, nasabah, dan nilai setoran'],['jenis','Volume per jenis sampah','Komposisi hasil timbang seluruh bank'],['donasi','Donasi sampah','Kontribusi tanpa penambahan saldo'],['bentor','Armada bentor','Status dan penugasan aktif saat ini']];
const BARIS_HP=10;
// PDF memakai angka biasa, karena pita digit animasi ikut terbaca sebagai teks berkas
const AngkaKpi=({teks})=><strong aria-label={teks}><span className="kpi-gulir"><AngkaGulir teks={teks} durasi={1400}/></span><span className="kpi-cetak" aria-hidden="true">{teks}</span></strong>;
export default function Laporan(){
  const [semuaBaris,setSemuaBaris]=useState(false);
  const [tipe,setTipe]=useState('kinerja'); const [format,setFormat]=useState('PDF'); const [bank,setBank]=useState(''); const [kecamatan,setKecamatan]=useState('');
  const [periode,setPeriode]=useState({periode:'bulan',dari:'',sampai:''});
  const [riwayat,setRiwayat]=useState([]);
  const query=queryPeriode(periode);
  const hasil=useFetch(async()=>{
    const [k,d]=await Promise.all([ambilKinerja(query),ambilDashboard(query)]);
    const drivers=[];
    if(tipe==='bentor'){
      let page=1,last=1;
      do{const a=await ambilPantauan('bentor',{page,per_page:100});drivers.push(...a.data);last=a.meta.last_page;page++;}while(page<=last);
    }
    return {k:k.data,d:d.data,drivers};
  },JSON.stringify([query,tipe]));
  const data=hasil.data; const banks=data?.k?.daftar??[];
  const filtered=banks.filter(b=>(!bank||String(b.bank_sampah.id)===bank)&&(!kecamatan||b.bank_sampah.kecamatan===kecamatan));
  const pilihan=TIPE.find(t=>t[0]===tipe);
  const scoped=tipe==='kinerja'||tipe==='donasi';
  const columns=tipe==='jenis'?['Jenis sampah','Berat (kg)']:tipe==='bentor'?['Bentor','Bank sampah','Plat nomor','Status','Tugas aktif']:tipe==='donasi'?['Bank sampah','Kecamatan','Donasi (kg)']:['Bank sampah','Kecamatan','Berat (kg)','Nasabah aktif','Nilai setoran'];
  const rows=tipe==='jenis'?(data?.d?.komposisi??[]).map(j=>[j.nama,formatAngka(j.total_kg)]):tipe==='bentor'?(data?.drivers??[]).map(b=>[b.driver,b.bank_sampah,b.plat_nomor,b.status,b.tugas_aktif]):filtered.map(b=>tipe==='donasi'?[b.bank_sampah.nama,b.bank_sampah.kecamatan,formatAngka(b.kg_donasi)]:[b.bank_sampah.nama,b.bank_sampah.kecamatan,formatAngka(b.total_kg),formatAngka(b.nasabah_aktif),formatRupiah(b.nilai_setoran)]);
  const totalKg=filtered.reduce((s,b)=>s+(tipe==='donasi'?b.kg_donasi:b.total_kg),0);
  const graph=tipe==='jenis'?(data?.d?.komposisi??[]).map(j=>({nama:j.nama,nilai:j.total_kg})):filtered.map(b=>({nama:b.bank_sampah.nama.replace(/^Bank Sampah (Demo )?/,''),nilai:tipe==='donasi'?b.kg_donasi:b.total_kg}));
  const judul='Laporan '+pilihan[1];
  const unduh=()=>{
    if(format==='CSV')unduhCsv(columns,rows,'laporan-'+tipe);
    else window.print();
    setRiwayat(r=>[{id:Date.now(),judul:pilihan[1],format},...r].slice(0,5));
  };
  return <div className="reference-list-page report-page"><header className="reference-heading"><div><p><a href="#ringkasan">Ringkasan</a> / Laporan</p><h1>Laporan</h1></div></header>
    <div className="report-workspace">
      <section className="reference-panel report-settings" aria-label="Atur laporan">
        <h2>1 · Jenis laporan</h2><div className="report-type-list">{TIPE.map(([v,t,d])=><button key={v} aria-pressed={tipe===v} onClick={()=>{setTipe(v);setBank('');setKecamatan('');}}><span><strong>{t}</strong><small>{d}</small></span><i className={tipe===v?'checked':''}/></button>)}</div>
        <h2>2 · Periode</h2><FilterPeriode nilai={periode} onUbah={setPeriode}/>
        <h2>3 · Cakupan</h2><select aria-label="Cakupan kecamatan" disabled={!scoped} value={kecamatan} onChange={e=>{setKecamatan(e.target.value);setBank('');}}><option value="">Semua kecamatan</option>{[...new Set(banks.map(b=>b.bank_sampah.kecamatan))].map(k=><option key={k}>{k}</option>)}</select><select aria-label="Cakupan bank sampah" disabled={!scoped} value={bank} onChange={e=>setBank(e.target.value)}><option value="">Semua bank sampah</option>{banks.filter(b=>!kecamatan||b.bank_sampah.kecamatan===kecamatan).map(b=><option value={b.bank_sampah.id} key={b.bank_sampah.id}>{b.bank_sampah.nama}</option>)}</select>
        <h2>4 · Format</h2><div className="reference-period" role="group" aria-label="Format berkas">{['PDF','CSV'].map(f=><button key={f} aria-pressed={format===f} onClick={()=>setFormat(f)}>{f}</button>)}</div>
        <button className="report-download" disabled={hasil.loading||Boolean(hasil.error)} onClick={unduh}><Download size={17}/>Buat &amp; unduh {format}</button><p className="section-caption">PDF memakai dialog cetak browser. Pilih “Simpan sebagai PDF”.</p>
      </section>
      <div className="report-preview-column">
        <section className="reference-panel report-preview" aria-label="Pratinjau laporan"><header><span className="report-letterhead"><LogoAplikasi className="report-logo"/><span><strong>Dinas Lingkungan Hidup</strong><small>Kabupaten Tulang Bawang Barat</small></span></span><span className="report-preview-label">PRATINJAU · {format}</span></header>
          <div className="report-document-title"><h2>{judul}</h2><p>Periode: {data?.k?.dari?.slice(0,10)??'…'} – {data?.k?.sampai?.slice(0,10)??'…'} · {kecamatan||'Semua kecamatan'}</p></div>
          {hasil.error?<GagalMuat error={hasil.error} onUlang={hasil.refetch}/>:hasil.loading?<Skeleton className="h-64"/>:<Fragment key={JSON.stringify([tipe,bank,kecamatan])}>
            <div className="report-kpis"><div><span>Bank sampah</span><AngkaKpi teks={formatAngka(filtered.length)}/></div><div><span>{tipe==='bentor'?'Armada':'Berat sampah'}</span><AngkaKpi teks={tipe==='bentor'?formatAngka(data?.drivers?.length??0):formatKg(tipe==='jenis'?(data?.d?.komposisi??[]).reduce((s,j)=>s+j.total_kg,0):totalKg)}/></div><div><span>{tipe==='donasi'?'Warga donatur':'Nasabah aktif'}</span><AngkaKpi teks={formatAngka(tipe==='donasi'?data?.d?.ringkasan?.donatur??0:data?.d?.ringkasan?.nasabah_aktif??0)}/></div></div>
            {tipe!=='bentor'&&<div className="report-chart">{graph.slice(0,10).map((g,i)=><div key={g.nama} style={{'--i':i}}><span>{formatKg(g.nilai)}</span><div><i style={{height:g.nilai/Math.max(1,...graph.map(x=>x.nilai))*100+'%'}}/></div><small>{g.nama}</small></div>)}</div>}
            <div className="reference-table-scroll"><table className={'reference-table tabel-kartu batasi-hp'+(semuaBaris?' semua':'')}><thead><tr>{columns.map(c=><th key={c}>{c}</th>)}</tr></thead><tbody>{rows.map((r,i)=><tr key={i} style={{'--i':Math.min(i,12)}}>{r.map((v,j)=><td key={j} data-label={j?columns[j]:undefined}>{v}</td>)}</tr>)}</tbody></table>{!rows.length&&<p className="table-empty">Belum ada data pada cakupan ini.</p>}</div>
            {rows.length>BARIS_HP&&!semuaBaris&&<button type="button" className="tombol-semua-hp" onClick={()=>setSemuaBaris(true)}>Tampilkan semua {rows.length} baris</button>}
            <footer>Dibuat oleh sistem Bank Sampah · Data aktual pada periode terpilih</footer>
          </Fragment>}
        </section>
        <section className="reference-panel report-history"><h2>Laporan terakhir pada sesi ini</h2>{riwayat.length?riwayat.map(r=><div key={r.id}><FileText size={22}/><span><strong>{r.judul}</strong><small>{r.format} · disiapkan pada sesi ini</small></span></div>):<p className="section-caption">Belum ada laporan yang diunduh pada sesi ini.</p>}</section>
      </div>
    </div>
  </div>;
}
