import { useState } from 'react';
import { Download, Phone, Search, Truck } from 'lucide-react';
import { CircleMarker, MapContainer, Popup } from 'react-leaflet';
import useFetch from '../hooks/useFetch';
import { ambilDashboard, ambilPantauan } from '../services/api';
import { GagalMuat, Kartu, Lencana } from '../components/ui';
import DasarPetaTubaba from '../components/DasarPetaTubaba';
import StatistikPantauan from '../components/StatistikPantauan';
import { unduhCsv } from '../utils/unduhCsv';
import { formatKg } from '../utils/format';
const LABEL={siaga:'Tersedia',terjadwal:'Terjadwal',bertugas:'Bertugas',nonaktif:'Istirahat'};
const WARNA={siaga:'#15803d',terjadwal:'#d97706',bertugas:'#2563eb',nonaktif:'#89948c'};
const LENCANA={siaga:'hijau',terjadwal:'kuning',bertugas:'biru',nonaktif:'abu'};
export default function Bentor(){
  const [status,setStatus]=useState(''); const [q,setQ]=useState(''); const [page,setPage]=useState(1); const [terpilih,setTerpilih]=useState(null);
  const [hari]=useState(()=>new Date().toLocaleDateString('id-ID',{day:'numeric',month:'long',year:'numeric'}));
  const hasil=useFetch(()=>ambilPantauan('bentor',{status,q,page}),JSON.stringify([status,q,page]));
  const dashboard=useFetch(()=>ambilDashboard());
  const daftar=hasil.data?.data??[]; const detail=daftar.find(b=>b.id===terpilih)??daftar[0];
  const titik=daftar.filter(b=>Number.isFinite(b.lat)&&Number.isFinite(b.lng));
  return <div className="reference-list-page"><header className="reference-heading"><div><p><a href="#ringkasan">Ringkasan</a> / Bentor</p><h1>Bentor</h1></div><div className="reference-toolbar"><span className="section-caption">Hari ini · {hari}</span><button className="reference-export" disabled={!daftar.length} onClick={()=>unduhCsv(['Bentor','Bank sampah','Plat nomor','Status','Kapasitas kg','Tugas aktif'],daftar.map(b=>[b.driver,b.bank_sampah,b.plat_nomor,LABEL[b.status_tampil],b.kapasitas_kg,b.tugas_aktif]),'bentor-halaman-'+page)}><Download size={16}/>Ekspor halaman</button></div></header>
    <StatistikPantauan jenis="bentor" data={dashboard.data?.data?.ringkasan}/>
    {hasil.error?<Kartu><GagalMuat error={hasil.error} onUlang={hasil.refetch}/></Kartu>:<div className="bentor-workspace">
      <section className="reference-panel bentor-map-panel"><div className="panel-heading"><div><h2>Peta sebaran</h2><p>Titik bank operasional, bukan pelacakan GPS bentor</p></div><div className="chart-legend">{Object.entries(LABEL).map(([k,l])=><span key={k}><i style={{background:WARNA[k]}}/>{l}</span>)}</div></div>
        <div className="bentor-map">{hasil.loading?<div className="pickup-empty">Memuat lokasi…</div>:<MapContainer key={titik.map(t=>t.id).join(',')} center={titik.length?[titik[0].lat,titik[0].lng]:[-4.44,105.13]} zoom={11} bounds={titik.length>1?titik.map(t=>[t.lat,t.lng]):undefined} scrollWheelZoom style={{height:'100%',width:'100%'}}><DasarPetaTubaba/>{titik.map(b=><CircleMarker key={b.id} center={[b.lat,b.lng]} radius={detail?.id===b.id?13:9} pathOptions={{color:'white',weight:3,fillColor:WARNA[b.status_tampil],fillOpacity:1}} eventHandlers={{click:()=>setTerpilih(b.id)}}><Popup><strong>{b.driver}</strong><br/>{b.bank_sampah}<br/>{LABEL[b.status_tampil]}</Popup></CircleMarker>)}</MapContainer>}</div>
        {detail?<div className="bentor-contact"><span className="pickup-avatar">BT</span><div><strong>{detail.driver}</strong><small>{detail.bank_sampah} · {LABEL[detail.status_tampil]}</small></div><span><small>Tugas aktif</small><strong>{detail.tugas_aktif}</strong></span><span><small>Kapasitas</small><strong>{formatKg(detail.kapasitas_kg)}</strong></span>{detail.phone&&<a className="reference-export" href={'tel:'+detail.phone}><Phone size={15}/>Hubungi</a>}</div>:<p className="table-empty">Belum ada bentor yang cocok dengan filter.</p>}
      </section>
      <section className="reference-panel"><div className="panel-heading"><h2>Daftar bentor</h2><Truck size={20}/></div><div className="reference-period bentor-status" role="group" aria-label="Saring status bentor">{[['','Semua'],['bertugas','Bertugas'],['terjadwal','Terjadwal'],['siaga','Tersedia'],['nonaktif','Istirahat']].map(([k,l])=><button key={k} aria-pressed={status===k} onClick={()=>{setStatus(k);setPage(1);}}>{l}</button>)}</div><label className="reference-search"><Search size={15}/><input aria-label="Cari bentor" placeholder="Cari bentor…" value={q} onChange={e=>{setQ(e.target.value);setPage(1);}}/></label>
        <div className="bentor-driver-list">{daftar.map(b=><button className={detail?.id===b.id?'driver-row selected':'driver-row'} key={b.id} onClick={()=>setTerpilih(b.id)} aria-pressed={detail?.id===b.id}><span className="pickup-avatar">BT</span><span><strong>{b.driver}</strong><small>{b.bank_sampah}</small><small>{b.plat_nomor}</small></span><span><Lencana warna={LENCANA[b.status_tampil]}>{LABEL[b.status_tampil]}</Lencana><small>{b.tugas_aktif} tugas aktif</small></span></button>)}</div><div className="reference-pagination"><span>{hasil.data?.meta?.total??0} bentor</span><div><button disabled={page===1} onClick={()=>setPage(page-1)}>‹</button><button disabled={page>=(hasil.data?.meta?.last_page??1)} onClick={()=>setPage(page+1)}>›</button></div></div>
      </section>
    </div>}
  </div>;
}
