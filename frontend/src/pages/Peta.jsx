import { useEffect, useMemo, useState } from 'react';
import { CircleMarker, GeoJSON, MapContainer, Marker, Popup, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import { ArrowLeft, Download, Layers, LocateFixed, MapPin, Search, ShieldAlert, X, ChevronDown, SlidersHorizontal } from 'lucide-react';
import useFetch from '../hooks/useFetch';
import useLayarHp from '../hooks/useLayarHp';
import { ambilPeta } from '../services/api';
import { GagalMuat, Lencana } from '../components/ui';
import { formatKg, formatRupiah } from '../utils/format';
import { unduhCsv } from '../utils/unduhCsv';
import { ATRIBUSI_PETA, TINGKAT_AKTIVITAS, URL_PETA_DASAR, URL_PETA_LABEL, ambilLapisanWilayah, kelompokPeta, klasterTitik, maskLuarWilayah, normalisasiWilayah as norm, tingkatAktivitas, tingkatKlaster, titikDalamWilayah, titikValid, warnaKepadatan } from '../utils/peta';

const PUSAT = [-4.44, 105.13];
const WARNA_NONAKTIF = '#64748b';
const TANPA_TITIK = [];
const ZOOM_DEKAT = 13;
const warnaTitik = b => b.is_aktif ? tingkatAktivitas(b.total_kg).warna : WARNA_NONAKTIF;
const kelasTitik = (b, diLuar) => diLuar.has(b.id) ? 'luar' : b.koordinat_estimasi ? 'estimasi' : '';
const labelDesa = p => norm(p.kecamatan) + '|' + norm(p.nama);
const labelBank = b => norm(b.kecamatan) + '|' + norm(b.tiyuh);
const aman = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

const ambilBatas = () => ambilLapisanWilayah(['kabupaten','kecamatan','desa']);

function FokusPeta({ batas, titik, terpilih, versi }) {
  const map = useMap();
  useEffect(() => {
    if (terpilih && titikValid(terpilih)) {
      map.flyTo([terpilih.lat, terpilih.lng], 16, { duration: 0.5 });
      return;
    }
    const bounds = L.latLngBounds([]);
    if (batas?.features?.length) bounds.extend(L.geoJSON(batas).getBounds());
    titik.filter(titikValid).forEach(b => bounds.extend([b.lat, b.lng]));
    if (bounds.isValid()) map.fitBounds(bounds, {padding:[28,28],maxZoom:14});
  }, [map, batas, titik, terpilih, versi]);
  useEffect(() => {
    const observer = new ResizeObserver(() => map.invalidateSize({pan:false}));
    observer.observe(map.getContainer());
    return () => observer.disconnect();
  }, [map]);
  return null;
}

function TitikPeta({ daftar, terpilih, onPilih, diLuar, mode }) {
  const map = useMap();
  const [zoom, setZoom] = useState(() => map.getZoom());
  useMapEvents({zoomend:() => setZoom(map.getZoom())});
  useEffect(() => { map.getContainer().classList.toggle('spatial-dekat', zoom >= ZOOM_DEKAT); }, [map, zoom]);
  const clusters = useMemo(() => klasterTitik(daftar, b => map.project([b.lat,b.lng],zoom)), [daftar,map,zoom]);
  return <>
    {clusters.map(c => {
      const tunggal = c.bank.length === 1;
      const bank = c.bank[0];
      const warna = tunggal ? warnaTitik(bank) : tingkatKlaster(c.bank).warna;
      const kelas = tunggal ? 'spatial-pin '+kelasTitik(bank,diLuar)+(bank.is_aktif?'':' nonaktif') : 'spatial-cluster';
      const teks = !tunggal ? c.bank.length : mode === 'volume' ? Math.round(bank.total_kg) : mode === 'jemput' ? bank.jemput_aktif : '';
      const icon = L.divIcon({className:'spatial-marker',
        html:'<span class="'+kelas+'" style="--warna:'+warna+'">'+teks+'</span>',
        iconSize:[36,36],iconAnchor:[18,18],popupAnchor:[0,-18]});
      return <Marker key={c.id+':'+c.bank.map(b=>b.id).join(',')} position={[c.lat,c.lng]} icon={icon} title={tunggal ? bank.nama : c.bank.length+' bank sampah · klik untuk memperbesar'}
        eventHandlers={{click:() => {
          if(tunggal) onPilih(bank);
          else map.fitBounds(c.bank.map(b=>[b.lat,b.lng]), {padding:[60,60],maxZoom:17});
        }}}>
        <Popup><div className="spatial-popup">{tunggal ? <>
          <strong>{bank.nama}</strong><p>{bank.tiyuh} · {bank.kecamatan}</p><p>{bank.koordinat_estimasi?'Lokasi estimasi kecamatan':'Koordinat dari data registri'}</p><p>Keaktifan: {tingkatAktivitas(bank.total_kg).label} · {formatKg(bank.total_kg)} bulan ini</p>
          <button onClick={()=>onPilih(bank)}>Lihat detail</button>
        </> : <><strong>{c.bank.length} bank sampah di area ini</strong><p>Keaktifan rata-rata: {tingkatKlaster(c.bank).label}</p><p>Perbesar peta atau pilih bank, termasuk titik yang berimpit.</p>
          <div>{c.bank.map(b=><button key={b.id} onClick={()=>onPilih(b)}>{b.nama}<small>{b.tiyuh}</small></button>)}</div>
        </>}</div></Popup>
      </Marker>;
    })}
    {terpilih && titikValid(terpilih) && <CircleMarker center={[terpilih.lat,terpilih.lng]} radius={22} interactive={false} pathOptions={{color:'#0e3b26',weight:3,fillOpacity:0.05}}/>}
  </>;
}

export default function Peta() {
  const [sumber, setSumber] = useState('registri');
  const [kecamatan, setKecamatan] = useState('');
  const [desa, setDesa] = useState('');
  const [q, setQ] = useState('');
  const [kualitas, setKualitas] = useState('');
  const [status, setStatus] = useState('');
  const [kelompok, setKelompok] = useState('kecamatan');
  const [mode, setMode] = useState('lokasi');
  const [lapisan, setLapisan] = useState({kabupaten:true,kecamatan:true,desa:false});
  const [id, setId] = useState(null);
  const [versi, setVersi] = useState(0);
  const [filterTerbuka, setFilterTerbuka] = useState(false);
  const hp = useLayarHp();
  const hasil = useFetch(() => ambilPeta({sumber}), sumber);
  const batas = useFetch(ambilBatas);
  const banks = useMemo(() => hasil.data?.data?.bank_sampah ?? [], [hasil.data]);
  const geo = batas.data;
  const namaBelumCocok = useMemo(() => {
    if (!geo) return new Set();
    const nama = new Set(geo.desa.features.map(f => labelDesa(f.properties)));
    return new Set(banks.filter(b => !nama.has(labelBank(b))).map(b => b.id));
  }, [banks, geo]);
  const diLuar = useMemo(() => new Set(geo ? banks.filter(b=>titikValid(b)&&!geo.kabupaten.features.some(f=>titikDalamWilayah(b.lat,b.lng,f))).map(b=>b.id) : []), [banks,geo]);
  const kecamatans = useMemo(() => [...new Set([...(geo?.kecamatan.features??[]).map(f=>f.properties.nama),...banks.map(b=>b.kecamatan)])].filter(Boolean).sort((a,b)=>a.localeCompare(b,'id')), [banks,geo]);
  const desas = useMemo(() => {
    const values = new Map();
    for(const f of geo?.desa.features??[]) if(!kecamatan||norm(f.properties.kecamatan)===norm(kecamatan)) values.set(labelDesa(f.properties),f.properties);
    for(const b of banks) if(!kecamatan||norm(b.kecamatan)===norm(kecamatan)) {
      const key=labelBank(b);
      if(!values.has(key)) values.set(key,{nama:b.tiyuh,kecamatan:b.kecamatan});
    }
    return [...values].sort(([,a],[,b])=>(a.nama??'').localeCompare(b.nama??'','id'));
  }, [banks,geo,kecamatan]);
  const tampil = useMemo(() => banks.filter(b =>
    (!kecamatan||norm(b.kecamatan)===norm(kecamatan)) && (!desa||labelBank(b)===desa) &&
    (!q||[b.nama,b.kode,b.tiyuh,b.kecamatan].join(' ').toLowerCase().includes(q.trim().toLowerCase())) &&
    (!status||b.is_aktif===(status==='aktif')) &&
    (!kualitas||(kualitas==='estimasi'?b.koordinat_estimasi:kualitas==='terisi'?!b.koordinat_estimasi&&titikValid(b):kualitas==='luar'?diLuar.has(b.id):kualitas==='nama'?namaBelumCocok.has(b.id):!titikValid(b)))
  ), [banks,kecamatan,desa,q,status,kualitas,diLuar,namaBelumCocok]);
  const selected = tampil.find(b=>b.id===id)??null;
  const groups = useMemo(()=>kelompokPeta(tampil,kelompok),[tampil,kelompok]);
  const featureDesa = geo?.desa.features.find(f=>labelDesa(f.properties)===desa);
  const layerData = useMemo(() => !geo ? {} : {
    kabupaten:geo.kabupaten,
    kecamatan:{type:'FeatureCollection',features:geo.kecamatan.features.filter(f=>!kecamatan||norm(f.properties.nama)===norm(kecamatan))},
    desa:{type:'FeatureCollection',features:geo.desa.features.filter(f=>(!kecamatan||norm(f.properties.kecamatan)===norm(kecamatan))&&(!desa||labelDesa(f.properties)===desa))},
  }, [geo,kecamatan,desa]);
  const fokus = useMemo(()=>desa ? featureDesa ? {type:'FeatureCollection',features:[featureDesa]} : null : kecamatan ? layerData.kecamatan : geo?.kabupaten,[geo,desa,kecamatan,featureDesa,layerData]);
  const pilihKecamatan = nama => {setKecamatan(nama);setDesa('');setId(null);setVersi(v=>v+1);};
  const pilihDesa = p => {setKecamatan(p.kecamatan);setDesa(labelDesa(p));setLapisan(s=>({...s,desa:true}));setId(null);setVersi(v=>v+1);};
  const reset = () => {setKecamatan('');setDesa('');setQ('');setKualitas('');setStatus('');setId(null);setVersi(v=>v+1);};
  const jumlahPerKecamatan = useMemo(() => {
    const hitung = new Map();
    for(const b of banks) hitung.set(norm(b.kecamatan),(hitung.get(norm(b.kecamatan))??0)+1);
    return hitung;
  }, [banks]);
  const jumlahKecamatan = nama => jumlahPerKecamatan.get(norm(nama))??0;
  const maksKecamatan = Math.max(0,...jumlahPerKecamatan.values());
  const mask = useMemo(() => geo ? maskLuarWilayah(geo.kabupaten) : null, [geo]);
  const ekspor = () => unduhCsv(['Kode','Bank sampah','Desa/tiyuh','Kecamatan','Latitude','Longitude','Jenis koordinat','Status','Perlu verifikasi batas'],
    tampil.map(b=>[b.kode,b.nama,b.tiyuh,b.kecamatan,b.lat,b.lng,b.koordinat_estimasi?'Estimasi kecamatan':'Dari data registri',b.is_aktif?'Aktif':'Nonaktif',diLuar.has(b.id)?'Ya':'Tidak']), 'peta-bank-sampah-tubaba');

  // Tampilan awal berfokus ke Tubaba; titik di luar batas baru ikut saat difilter.
  const titikFokus = !kecamatan && !q.trim() && !kualitas && !status ? TANPA_TITIK : tampil;

  return <div className="spatial-page">
    <header className="reference-heading"><div><p><a href="#ringkasan">Ringkasan</a> / Peta wilayah</p><h1>Peta bank sampah</h1><p className="spatial-subtitle">Sebaran lokasi dan batas administrasi Kabupaten Tulang Bawang Barat</p></div>
      <button className="reference-export" disabled={!tampil.length} onClick={ekspor}><Download size={16}/>Ekspor titik terfilter</button></header>
    <div className="spatial-stats" aria-label="Ringkasan titik bank sampah">
      <span><strong>{banks.length}</strong> Bank sampah {sumber==='registri'?'registri':'demo'}</span>
      <span><strong>{banks.filter(b=>b.total_kg>0).length}</strong> Ada setoran bulan ini</span>
      <span><i className="dot terisi"/><strong>{banks.filter(b=>titikValid(b)&&!b.koordinat_estimasi).length}</strong> Koordinat terisi</span>
      <span><i className="dot estimasi"/><strong>{banks.filter(b=>titikValid(b)&&b.koordinat_estimasi).length}</strong> Estimasi kecamatan</span>
      <span><strong>{kecamatans.length}</strong> Kecamatan</span>
      {diLuar.size>0&&<button onClick={()=>{setKualitas('luar');setId(null);}}><ShieldAlert size={15}/>{diLuar.size} titik di luar batas</button>}
    </div>
    {hasil.error?<GagalMuat error={hasil.error} onUlang={hasil.refetch}/>:<div className="spatial-workspace">
      <button type="button" className="spatial-filter-toggle" aria-expanded={filterTerbuka} onClick={()=>setFilterTerbuka(v=>!v)}><SlidersHorizontal size={16}/>Filter &amp; daftar bank ({tampil.length})<ChevronDown size={16} className={filterTerbuka?'terbuka':''}/></button>
      <aside className={'spatial-sidebar'+(filterTerbuka?'':' tertutup')} aria-label="Filter dan daftar bank sampah">
        <div className="spatial-filter-title"><span><MapPin size={17}/>Filter peta</span><button onClick={reset}>Reset</button></div>
        <label className="reference-search"><Search size={16}/><input aria-label="Cari bank sampah di peta" placeholder="Nama bank, kode, atau desa…" value={q} onChange={e=>{setQ(e.target.value);setId(null);}}/></label>
        <label>Sumber titik<select value={sumber} onChange={e=>{setSumber(e.target.value);reset();}}><option value="registri">Data registri bank sampah</option><option value="demo">Data demo uji coba</option></select></label>
        <label>Kecamatan<select aria-label="Kecamatan peta" value={kecamatan} onChange={e=>pilihKecamatan(e.target.value)}><option value="">Semua kecamatan</option>{kecamatans.map(k=><option key={k}>{k}</option>)}</select></label>
        <label>Desa / tiyuh<select aria-label="Desa atau tiyuh peta" value={desa} onChange={e=>{setDesa(e.target.value);if(e.target.value)setLapisan(s=>({...s,desa:true}));setId(null);}}><option value="">Semua desa / tiyuh</option>{desas.map(([key,p])=><option key={key} value={key}>{p.nama}{!kecamatan?' · '+p.kecamatan:''}</option>)}</select></label>
        <div className="spatial-filter-pair"><label>Verifikasi titik<select value={kualitas} onChange={e=>{setKualitas(e.target.value);setId(null);}}><option value="">Semua titik</option><option value="terisi">Koordinat dari data</option><option value="estimasi">Estimasi kecamatan</option><option value="luar">Di luar batas</option><option value="nama">Nama desa belum cocok</option><option value="kosong">Belum ada titik</option></select></label>
          <label>Status<select value={status} onChange={e=>{setStatus(e.target.value);setId(null);}}><option value="">Semua status</option><option value="aktif">Aktif</option><option value="nonaktif">Nonaktif</option></select></label></div>
        <div className="spatial-list-title"><strong>{tampil.length} bank ditemukan</strong><label className="sr-only" htmlFor="kelompok-peta">Kelompokkan daftar</label><select id="kelompok-peta" value={kelompok} onChange={e=>setKelompok(e.target.value)}><option value="kecamatan">Per kecamatan</option><option value="tiyuh">Per desa / tiyuh</option></select></div>
        <div className="spatial-bank-list">{hasil.loading?<p className="spatial-empty">Memuat titik bank sampah…</p>:!groups.length?<p className="spatial-empty">Tidak ada bank yang cocok dengan filter.</p>:groups.map(g=><details key={g.nama} open={groups.length===1?true:undefined}>
          <summary><span>{g.nama}</span><b>{g.bank.length}</b></summary><div>{g.bank.map(b=><button key={b.id} onClick={()=>{if(!kecamatan)setKecamatan(b.kecamatan);setId(b.id);setFilterTerbuka(false);if(hp)document.querySelector('.spatial-map-canvas')?.scrollIntoView({block:'center'});}} aria-pressed={b.id===id} className={b.id===id?'selected':''}><i className={'dot '+kelasTitik(b,diLuar)} style={{background:warnaTitik(b)}}/><span><strong>{b.nama}</strong><small>{b.tiyuh} · {b.kode}</small>{b.koordinat_estimasi&&<small className="spatial-estimate">Estimasi kecamatan</small>}</span></button>)}</div>
        </details>)}</div>
      </aside>
      <section className="spatial-map-column" aria-label="Peta sebaran bank sampah">
        <div className="spatial-map-toolbar">
          {kecamatan ? (
            <div className="spatial-active-badge">
              <span>Kecamatan: <strong>{kecamatan}</strong> ({tampil.length} bank)</span>
              <button type="button" className="spatial-back-btn" onClick={() => pilihKecamatan('')} title="Kembali ke semua kecamatan">
                <ArrowLeft size={13} /> Semua Kecamatan
              </button>
            </div>
          ) : (
            <span><Layers size={16}/>Lapisan wilayah</span>
          )}
          {['kabupaten','kecamatan','desa'].map(level=><label key={level}><input type="checkbox" checked={lapisan[level]} onChange={e=>setLapisan(s=>({...s,[level]:e.target.checked}))}/>{level==='desa'?'Desa / tiyuh':level[0].toUpperCase()+level.slice(1)}</label>)}
          <select aria-label="Tampilan penanda" value={mode} onChange={e=>setMode(e.target.value)}><option value="lokasi">Titik lokasi</option><option value="volume">Volume bulan ini (kg)</option><option value="jemput">Jemput aktif</option></select>
          <button title="Tampilkan seluruh hasil filter" aria-label="Tampilkan seluruh hasil filter" onClick={()=>{setId(null);setVersi(v=>v+1);}}><LocateFixed size={18}/></button></div>
        <div className="spatial-map-canvas">
          <MapContainer center={PUSAT} zoom={10} maxZoom={19} scrollWheelZoom style={{height:'100%',width:'100%'}}>
            <TileLayer url={URL_PETA_DASAR} maxZoom={19} maxNativeZoom={16} attribution={ATRIBUSI_PETA}/>
            <TileLayer url={URL_PETA_LABEL} maxZoom={19} maxNativeZoom={16}/>
            {mask&&<GeoJSON data={mask} interactive={false} style={{stroke:false,fillColor:'#ffffff',fillOpacity:0.62}}/>}
            {geo&&['kecamatan','desa','kabupaten'].filter(level=>lapisan[level]).map(level=><GeoJSON key={[level,kecamatan,desa,sumber,banks.length].join('|')} data={layerData[level]}
              style={f=>level==='kabupaten'?{color:'#0f5c55',weight:2.4,fillOpacity:0}:level==='kecamatan'?{className:'spatial-kecamatan',color:'#ffffff',weight:1.4,fillColor:warnaKepadatan(jumlahKecamatan(f.properties.nama),maksKecamatan),fillOpacity:0.78}:{color:'#0f5c55',weight:0.7,fillOpacity:0,dashArray:'3 3'}}
              interactive={level!=='kabupaten'} onEachFeature={(feature,layer)=>{
                const p=feature.properties;
                const jumlahKec = level==='kecamatan' ? jumlahKecamatan(p.nama) : 0;
                layer.bindTooltip(
                  aman(p.nama)
                  + (level==='kecamatan' ? ` · ${jumlahKec} Bank Sampah (Klik untuk detail)` : '')
                  + (level==='desa'?' · '+aman(p.kecamatan):''),
                  {sticky:true}
                );
                if(level==='kecamatan') {
                  layer.on('click',()=>pilihKecamatan(p.nama));
                  layer.on('mouseover', () => layer.setStyle({ fillOpacity: 0.92, weight: 2.4 }));
                  layer.on('mouseout', () => layer.setStyle({ fillOpacity: 0.78, weight: 1.4 }));
                }
                if(level==='desa') layer.on('click',()=>pilihDesa(p));
              }}/>)}
            <TitikPeta daftar={tampil} terpilih={selected} onPilih={b=>setId(b.id)} diLuar={diLuar} mode={mode}/>
            <FokusPeta batas={fokus} titik={titikFokus} terpilih={selected} versi={versi}/>
          </MapContainer>
          {selected&&<article className="spatial-selected" aria-label="Detail bank pada peta"><button className="spatial-close" aria-label="Tutup detail bank" onClick={()=>setId(null)}><X size={17}/></button>
            <span className="section-caption">{selected.kode} · {selected.sumber==='demo'?'Data demo':'Data registri'}</span><h2>{selected.nama}</h2><p>{selected.tiyuh} · {selected.kecamatan}</p><p>{selected.alamat}</p>
            <div className="spatial-badges"><Lencana warna={selected.koordinat_estimasi?'kuning':'hijau'}>{selected.koordinat_estimasi?'Estimasi kecamatan':'Koordinat dari data'}</Lencana><Lencana warna={selected.is_aktif?'hijau':'abu'}>{selected.is_aktif?'Aktif':'Nonaktif'}</Lencana></div>
            {diLuar.has(selected.id)&&<p className="spatial-warning">Titik berada di luar batas kabupaten pada lapisan ini. Perlu verifikasi; koordinat tidak digeser.</p>}
            {selected.koordinat_estimasi&&<p className="spatial-warning">Bukan lokasi pasti bank. Perkiraan sekitar pusat kecamatan; perlu verifikasi lapangan.</p>}
            <dl><div><dt>Keaktifan</dt><dd>{tingkatAktivitas(selected.total_kg).label}</dd></div><div><dt>Koordinat</dt><dd>{titikValid(selected)?selected.lat.toFixed(6)+', '+selected.lng.toFixed(6):'Belum tersedia'}</dd></div><div><dt>Setoran bulan ini</dt><dd>{formatKg(selected.total_kg)}</dd></div><div><dt>Nilai setoran</dt><dd>{formatRupiah(selected.nilai_setoran)}</dd></div></dl>
            {titikValid(selected)&&!selected.koordinat_estimasi&&<a className="spatial-directions" href={'https://www.google.com/maps/search/?api=1&query='+selected.lat+','+selected.lng} target="_blank" rel="noreferrer">Buka koordinat di Google Maps ↗</a>}
          </article>}
          {batas.loading&&<span className="spatial-loading">Memuat batas wilayah…</span>}
          {batas.error&&<div className="spatial-map-error"><span>{batas.error.message}</span><button onClick={batas.refetch}>Coba lagi</button></div>}
        </div>
        <div className="spatial-legend">
          <strong>Keaktifan (kg setoran bulan ini)</strong>
          {Object.values(TINGKAT_AKTIVITAS).map(t=><span key={t.label}><i className="dot" style={{background:t.warna}}/>{t.label} · {t.keterangan}</span>)}
          <span className="spatial-legend-break"/>
          <span><i className="dot estimasi"/>Estimasi kecamatan</span>
          <span><i className="dot luar"/>Di luar batas kabupaten</span>
          <span><i className="dot" style={{background:WARNA_NONAKTIF}}/>Bank nonaktif</span>
          <span><span className="spatial-cluster-key">12</span>Kelompok titik · warna dari rata-rata per bank</span>
          <span><i className="spatial-density-key"/>Jumlah bank per kecamatan</span>
        </div>
        <p className="spatial-source">Sumber titik: registri DLH 2026. Batas desa: BIG Semester I 2025 melalui <a href="https://geoportal.pertanian.go.id/arcgis/rest/services/Hosted/Batas_Administrasi_Desa/FeatureServer/0" target="_blank" rel="noreferrer">Geoportal Kementan</a>; kabupaten/kecamatan: <a href="https://geoservices.big.go.id/gis/rest/services/BAPANAS/Batas_Administrasi/MapServer" target="_blank" rel="noreferrer">BIG BAPANAS</a> (kabupaten 2020, kecamatan 2022). Lapisan untuk visualisasi, bukan penetapan batas hukum. Pengelompokan bank mengikuti kolom desa/kecamatan registri.</p>
        {sumber==='registri'&&namaBelumCocok.size>0&&<p className="spatial-warning">{namaBelumCocok.size} bank memakai nama desa yang belum cocok dengan penulisan pada lapisan batas. Seluruh titik tetap ditampilkan; gunakan filter “Nama desa belum cocok” untuk pemeriksaan. Nama asli registri tidak diubah.</p>}
        {desa&&!featureDesa&&!batas.loading&&<p className="spatial-warning">Batas untuk nama desa terpilih belum ditemukan. Titik tetap ditampilkan tanpa membuat batas perkiraan.</p>}
      </section>
    </div>}
  </div>;
}
