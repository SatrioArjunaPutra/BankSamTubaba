import { useEffect, useState } from 'react';
import { ArrowUpRight, Bell, MapPin, Search, Store, TriangleAlert, Truck } from 'lucide-react';
import AngkaGulir from '../components/AngkaGulir';
import useFetch from '../hooks/useFetch';
import { ambilDashboard } from '../services/api';
import { GagalMuat, Kartu, Lencana } from '../components/ui';
import { formatAngka, formatKg } from '../utils/format';

const BULAN = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
const WARNA = [1,2,3,4,5,6].map((n)=>`var(--komposisi-${n})`);
const tanggal = d => [d.getFullYear(), String(d.getMonth()+1).padStart(2,'0'), String(d.getDate()).padStart(2,'0')].join('-');

// Batas atas grafik yang mudah dibaca: 2,5 kg menjadi 3 kg, 140 kg menjadi 200 kg
function batasGrafik(nilai) {
  if (nilai <= 0) return 1;
  const pangkat = 10 ** Math.floor(Math.log10(nilai));
  return [1, 2, 3, 5, 10].find((k) => k * pangkat >= nilai) * pangkat;
}

export default function Ringkasan() {
  const [hari, setHari] = useState(30);
  const [cari, setCari] = useState('');
  const [notifikasi, setNotifikasi] = useState(false);
  const [sampai] = useState(() => new Date());
  const dari = new Date(sampai);
  dari.setDate(dari.getDate() - hari + 1);
  const query = { dari: tanggal(dari), sampai: tanggal(sampai) };
  const { data, error, loading, refetch } = useFetch(() => ambilDashboard(query), JSON.stringify(query));
  useEffect(()=>{ const timer=setInterval(()=>{if(!document.hidden)refetch();},15000); return ()=>clearInterval(timer); },[refetch]);
  const dashboard = data?.data;
  const r = dashboard?.ringkasan ?? {};
  const tren = dashboard?.tren ?? BULAN.map((_, i) => ({periode: String(i+1), total_kg: 0}));
  const komposisi = dashboard?.komposisi ?? [];
  const kelompok = [
    {nama:'Plastik', total_kg:0}, {nama:'Kertas & kardus',total_kg:0},
    {nama:'Logam', total_kg:0}, {nama:'Kaca',total_kg:0}, {nama:'Lainnya',total_kg:0},
  ];
  komposisi.forEach(k => {
    const n = k.nama.toLowerCase();
    const i = n.includes('plastik') ? 0 : /kertas|kardus/.test(n) ? 1 : /logam|kaleng|alum/.test(n) ? 2 : n.includes('kaca') ? 3 : 4;
    kelompok[i].total_kg += k.total_kg;
  });
  const jumlahKg = kelompok.reduce((s,k)=>s+k.total_kg,0);
  const peringkat = (dashboard?.peringkat ?? []).filter(b => (b.bank_sampah.nama+' '+b.bank_sampah.kecamatan).toLowerCase().includes(cari.toLowerCase()));
  const pickups = dashboard?.penjemputan ?? [];
  const perubahan = r.kg_periode_lalu ? (r.total_kg-r.kg_periode_lalu)/r.kg_periode_lalu*100 : null;
  const labelPeriode = hari === 365 ? '12 bulan' : hari + ' hari';
  const catatanTotal = perubahan === null ? 'Belum ada pembanding periode lalu' : (perubahan >= 0 ? '+' : '') + Math.round(perubahan) + '% dibanding periode lalu';
  const angkaPita = [
    [formatAngka(r.bank_sampah_aktif ?? 0), 'Bank sampah aktif', 'dari ' + formatAngka(r.bank_sampah_total ?? 0) + ' terdaftar'],
    [formatAngka(r.jumlah_warga ?? 0), 'Warga terdaftar', formatAngka(r.warga_baru ?? 0) + ' baru periode ini'],
    [formatAngka(r.jemput_hari_ini ?? 0), 'Jemput hari ini', formatAngka(r.jemput_selesai_hari_ini ?? 0) + ' selesai · ' + formatAngka(r.jemput_aktif ?? 0) + ' berjalan'],
  ];
  const perluDitinjau = [
    ['#bank-sampah', Store, 'kuning', r.bank_tanpa_setoran, 'bank sampah tanpa setoran'],
    ['#bentor', Truck, 'hijau', r.jemput_aktif, 'penjemputan belum selesai'],
    ['#moderasi', TriangleAlert, 'merah', r.barang_dilaporkan, 'barang preloved dilaporkan warga'],
  ];
  const skalaGrafik = batasGrafik(Math.max(0, ...tren.map((t) => t.total_kg)));
  return <div className="reference-dashboard">
    <header className="reference-heading">
      <div><p>Dinas Lingkungan Hidup · Kabupaten Tulang Bawang Barat</p><h1>Ringkasan kinerja</h1></div>
      <div className="reference-toolbar">
        <label className="reference-search"><Search size={16}/><input aria-label="Cari bank sampah" type="search" placeholder="Cari bank sampah, kecamatan…" value={cari} onChange={e=>setCari(e.target.value)}/></label>
        <div className="reference-period" role="group" aria-label="Periode">{[[7,'7 hari'],[30,'30 hari'],[365,'12 bulan']].map(([n,label])=><button key={n} aria-pressed={hari===n} onClick={()=>setHari(n)}>{label}</button>)}</div>
        <div className="notification-wrap"><button className="reference-bell" aria-label="Notifikasi" aria-expanded={notifikasi} onClick={()=>setNotifikasi(!notifikasi)}><Bell size={18}/>{pickups.length>0&&<i/>}</button>{notifikasi&&<div className="notification-panel"><strong>Penjemputan berlangsung</strong><p>{pickups.length ? pickups.length+' penjemputan sedang ditangani.' : 'Belum ada penjemputan berlangsung.'}</p><a href="#bentor">Lihat bentor →</a></div>}</div>
      </div>
    </header>
    {error ? <Kartu><GagalMuat error={error} onUlang={refetch}/></Kartu> : <>
      <section className="pita-utama" aria-label="Indikator utama">
        <div className="pita-total">
          <span>Total sampah terkumpul · {labelPeriode}</span>
          <strong aria-label={formatAngka(r.total_kg ?? 0) + ' kg'}>{dashboard ? <AngkaGulir teks={formatAngka(r.total_kg ?? 0)} durasi={1500} /> : '–'}<small>kg</small></strong>
          <small>{catatanTotal}</small>
        </div>
        {angkaPita.map(([nilai, label, catatan]) => <div className="pita-angka" key={label}><strong aria-label={nilai}>{dashboard ? <AngkaGulir teks={nilai} durasi={1500} /> : '–'}</strong><span>{label}</span><small>{catatan}</small></div>)}
      </section>
      <section className="tinjau-baris" aria-label="Perlu ditinjau">
        {perluDitinjau.map(([href, Ikon, warna, nilai, label]) => <a className="tinjau-kartu" href={href} key={label}><span className={'tinjau-ikon ' + warna}><Ikon size={19}/></span><strong>{formatAngka(nilai ?? 0)}</strong><span>{label}</span><ArrowUpRight size={17}/></a>)}
      </section>
    </>}
    <div className="reference-panel-grid">
      <section className="reference-panel monthly-panel"><div className="panel-heading"><div><h2>Volume sampah per bulan</h2><p>Kilogram, seluruh bank sampah · {sampai.getFullYear()}</p></div><div className="chart-legend"><span><i style={{background:'var(--bar-kini)'}}/>Bulan berjalan</span><span><i style={{background:'var(--bar-lain)'}}/>Bulan lain</span></div></div>
        <div className="grafik-bulan">{[0, 0.5, 1].map((p) => <div className="grafik-garis" key={p} style={{bottom: 28 + p * 195 + 'px'}}><span>{formatAngka(skalaGrafik * p)} kg</span></div>)}<div className="reference-months" aria-label="Grafik volume sampah Januari sampai Desember">{tren.map((b,i)=><div className="month-column" key={b.periode}><span className={i===sampai.getMonth()?'month-value current':'month-value'}>{b.total_kg ? formatKg(b.total_kg) : ''}</span><div className="month-track"><div className={'month-bar '+(i===sampai.getMonth()?'current ':'')+(b.total_kg?'':'kosong')} style={{height: b.total_kg/skalaGrafik*100+'%','--i':i}}/></div><span className={i===sampai.getMonth()?'bulan-kini':undefined}>{BULAN[i]}</span></div>)}</div></div>
        {!loading&&tren.every(b=>b.total_kg===0)&&<p className="chart-empty">Belum ada setoran pada tahun ini.</p>}
      </section>
      <section className="reference-panel"><div className="panel-heading"><div><h2>Komposisi jenis sampah</h2><p>Persentase berat pada periode terpilih</p></div></div>
        <div className="composition-track" aria-hidden="true">{kelompok.map((k,i)=><span key={k.nama} style={{background:WARNA[i],flex:jumlahKg?k.total_kg:1,opacity:jumlahKg?1:.22}}/>)}</div>
        <div className="composition-list">{kelompok.map((k,i)=><div key={k.nama} className={k.total_kg?undefined:'nol'}><span><i style={{background:WARNA[i]}}/>{k.nama}</span><em>{formatKg(k.total_kg)}</em><strong>{jumlahKg?Math.round(k.total_kg/jumlahKg*100):0}%</strong></div>)}</div>
        <a href="#bank-sampah" className="reference-link">Lihat rincian per bank sampah →</a>
      </section>
    </div>
    <div className="reference-panel-grid">
      <section className="reference-panel"><div className="panel-heading"><h2>Peringkat bank sampah</h2><a href="#bank-sampah" className="reference-link">Lihat semua</a></div>
        <div className="reference-table-scroll"><table className="reference-table tabel-kartu"><thead><tr><th>Bank sampah</th><th>Kecamatan</th><th className="number">Sampah (kg)</th><th className="number">Nasabah</th><th>Status</th></tr></thead><tbody>{peringkat.slice(0,5).map((b,i)=><tr key={b.bank_sampah.id}><td><span className="rank-bank"><b className={i===0?'rank-badge first':'rank-badge'}>{i+1}</b><span><strong>{b.bank_sampah.nama}</strong><small>{b.bank_sampah.kode}</small></span></span></td><td data-label="Kecamatan" className="penuh">{b.bank_sampah.kecamatan}</td><td data-label="Sampah (kg)" className="number">{formatAngka(b.total_kg)}</td><td data-label="Nasabah" className="number">{formatAngka(b.nasabah_aktif)}</td><td data-label="Status"><Lencana warna="hijau">Aktif</Lencana></td></tr>)}</tbody></table>{!loading&&!peringkat.length&&<p className="table-empty">Tidak ada bank sampah yang cocok.</p>}</div>
      </section>
      <section className="reference-panel pickup-panel"><div className="panel-heading"><h2>Penjemputan berlangsung</h2><span className="live-badge"><i/>{formatAngka(r.jemput_aktif ?? 0)} aktif</span></div>
        {pickups.map((p,i)=><div className="reference-pickup" key={p.id}><span className="pickup-avatar">B{i+1}</span><span><strong>{p.driver??'Belum ditugaskan'}</strong><small>{p.bank_sampah} → {p.alamat}</small></span><Lencana warna={p.status==='diambil'?'kuning':'biru'}>{p.status==='diambil'?'Diambil':p.status==='menuju'?'Menuju lokasi':'Dijadwalkan'}</Lencana></div>)}
        {!pickups.length&&<div className="pickup-empty"><MapPin size={28}/><p>Belum ada penjemputan berlangsung.</p></div>}
        <a href="#peta" className="pickup-map-link"><MapPin size={16}/>Buka peta penjemputan<ArrowUpRight size={14}/></a>
      </section>
    </div>
  </div>;
}
