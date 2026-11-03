import { formatAngka, formatKg, formatRupiah } from '../utils/format';
export default function StatistikPantauan({jenis, data={}}) {
  const r=data;
  const list=jenis==='warga'?[
    ['Warga terdaftar',formatAngka(r.jumlah_warga??0),'Di seluruh bank sampah','warga'],
    ['Aktif menyetor (30 hari)',formatAngka(r.warga_aktif_30_hari??0),'Warga dengan setoran tercatat','sampah'],
    ['Warga baru bulan ini',formatAngka(r.warga_baru??0),'Bergabung pada periode terpilih','warga'],
    ['Total saldo warga',formatRupiah(r.total_saldo_warga??0),'Di semua bank sampah','bank'],
  ]:jenis==='bentor'?[
    ['Bentor terdaftar',formatAngka(r.bentor_total??0),'Di seluruh bank sampah','bentor'],
    ['Sedang bertugas',formatAngka(r.bentor_bertugas??0),(r.bentor_siaga??0)+' tersedia · '+(r.bentor_terjadwal??0)+' terjadwal · '+(r.bentor_nonaktif??0)+' istirahat','bentor'],
    ['Penjemputan hari ini',formatAngka(r.jemput_hari_ini??0),(r.jemput_selesai_hari_ini??0)+' selesai','sampah'],
    ['Bank sampah aktif',formatAngka(r.bank_sampah_aktif??0),'Lokasi operasional armada','bank'],
  ]:jenis==='donasi'?[
    ['Sampah didonasikan',formatKg(r.kg_donasi??0),'Pada periode terpilih','sampah'],
    ['Warga donatur',formatAngka(r.donatur??0),'Berkontribusi tanpa menambah saldo','warga'],
    ['Kali donasi',formatAngka(r.donasi_jumlah??0),(r.donasi_dijemput??0)+' dijemput bentor','bank'],
    ['Menunggu ditimbang',formatAngka(r.donasi_menunggu??0),'Permintaan donasi warga','bentor'],
  ]:[
    ['Nilai setoran',formatRupiah(r.nilai_transaksi??0),formatKg(r.total_kg??0)+' sampah','sampah'],
    ['Penarikan',formatRupiah(r.penarikan_nilai??0),(r.penarikan_menunggu??0)+' menunggu diproses','bank'],
    ['Donasi',formatKg(r.kg_donasi??0),'dari '+(r.donatur??0)+' warga','warga'],
    ['Jumlah transaksi',formatAngka((r.jumlah_setoran??0)+(r.jumlah_penarikan??0)),'Setoran, donasi, dan penarikan','bentor'],
  ];
  return <section className="reference-stats" aria-label={'Indikator '+jenis}>{list.map(([label,nilai,catatan,gambar],i)=><article className={'reference-stat '+(i===0?'featured':'')} key={label}><div className="reference-stat-top"><span>{label}</span><span className={'reference-illustration illustration-'+gambar}><img src={'/illustrations/'+gambar+'.svg'} alt=""/></span></div><div className="reference-stat-value" style={{fontSize:28}}>{nilai}</div><div className="reference-stat-caption">{catatan}</div></article>)}</section>;
}
