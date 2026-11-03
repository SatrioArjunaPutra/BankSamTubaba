export const normalisasiWilayah = (nama = '') => (nama ?? '').toLowerCase().replace(/\b(desa|tiyuh|kelurahan|kecamatan|kec)\b/g, '').replace(/[^a-z0-9]/g, '');

export function titikValid(bank) {
  return Number.isFinite(bank.lat) && Number.isFinite(bank.lng) && Math.abs(bank.lat) <= 90 && Math.abs(bank.lng) <= 180;
}

function diCincin([x, y], ring) {
  let masuk = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const a = ring[i], b = ring[j];
    const silang = (x - a[0]) * (b[1] - a[1]) - (y - a[1]) * (b[0] - a[0]);
    if (Math.abs(silang) < 1e-10 && x >= Math.min(a[0], b[0]) && x <= Math.max(a[0], b[0]) && y >= Math.min(a[1], b[1]) && y <= Math.max(a[1], b[1])) return true;
    if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) masuk = !masuk;
  }
  return masuk;
}

export function titikDalamWilayah(lat, lng, feature) {
  const geometry = feature?.geometry;
  if (!geometry) return false;
  const polygons = geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.type === 'MultiPolygon' ? geometry.coordinates : [];
  return polygons.some(rings => diCincin([lng, lat], rings[0]) && !rings.slice(1).some(r => diCincin([lng, lat], r)));
}

export function kelompokPeta(daftar, tingkat = 'kecamatan') {
  const groups = new Map();
  for (const bank of daftar) {
    const nama = tingkat === 'tiyuh' ? `${bank.tiyuh || 'Belum diisi'} · ${bank.kecamatan}` : bank.kecamatan || 'Belum diisi';
    const kunci = normalisasiWilayah(bank.kecamatan) + (tingkat === 'tiyuh' ? '|' + normalisasiWilayah(bank.tiyuh) : '');
    if (!groups.has(kunci)) groups.set(kunci, {nama, bank: []});
    groups.get(kunci).bank.push(bank);
  }
  return [...groups.values()].sort((a, b) => a.nama.localeCompare(b.nama, 'id'));
}

export function klasterTitik(daftar, proyeksi, ukuran = 52) {
  const cells = new Map();
  for (const bank of daftar.filter(titikValid)) {
    const p = proyeksi(bank);
    const key = `${Math.floor(p.x / ukuran)}:${Math.floor(p.y / ukuran)}`;
    if (!cells.has(key)) cells.set(key, []);
    cells.get(key).push(bank);
  }
  return [...cells].map(([id, bank]) => ({ id, bank, lat: bank.reduce((n, b) => n + b.lat, 0) / bank.length, lng: bank.reduce((n, b) => n + b.lng, 0) / bank.length }));
}

// Batas kg per bulan; sesuaikan di sini bila DLH menetapkan angka lain.
export const BATAS_AKTIVITAS = {rendah: 100, sedang: 500};

export const TINGKAT_AKTIVITAS = {
  kosong: {label: 'Belum ada aktivitas', keterangan: '0 kg', warna: '#d9dedb'},
  rendah: {label: 'Rendah', keterangan: `di bawah ${BATAS_AKTIVITAS.rendah} kg`, warna: '#fde047'},
  sedang: {label: 'Sedang', keterangan: `${BATAS_AKTIVITAS.rendah}–${BATAS_AKTIVITAS.sedang} kg`, warna: '#f5a623'},
  tinggi: {label: 'Tinggi', keterangan: `di atas ${BATAS_AKTIVITAS.sedang} kg`, warna: '#ea580c'},
};

export function tingkatAktivitas(kg) {
  if (!Number.isFinite(kg) || kg <= 0) return TINGKAT_AKTIVITAS.kosong;
  if (kg < BATAS_AKTIVITAS.rendah) return TINGKAT_AKTIVITAS.rendah;
  return kg <= BATAS_AKTIVITAS.sedang ? TINGKAT_AKTIVITAS.sedang : TINGKAT_AKTIVITAS.tinggi;
}

// Rata-rata per bank agar klaster besar tidak otomatis tampak paling aktif.
export function tingkatKlaster(daftar) {
  if (!daftar.length) return TINGKAT_AKTIVITAS.kosong;
  return tingkatAktivitas(daftar.reduce((n, b) => n + (b.total_kg || 0), 0) / daftar.length);
}

export const ATRIBUSI_PETA = 'Peta &copy; <a href="https://www.esri.com">Esri</a> — sumber: Esri, HERE, Garmin, &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> · Batas: BIG / Kementan';
export const URL_PETA_DASAR = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';
export const URL_PETA_LABEL = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

export async function ambilLapisanWilayah(daftar) {
  const entries = await Promise.all(daftar.map(async level => {
    const res = await fetch('/geo/tubaba-' + level + '.geojson');
    if (!res.ok) throw new Error('Batas wilayah belum dapat dimuat. Coba lagi.');
    const data = await res.json();
    if (data.type !== 'FeatureCollection' || !data.features.length) throw new Error('Data batas wilayah tidak valid.');
    return [level, data];
  }));
  return Object.fromEntries(entries);
}

const WARNA_KEPADATAN = ['#cfe8e3', '#97cfc5', '#5cab9f', '#2c8177'];

export function warnaKepadatan(jumlah, maks) {
  if (!(jumlah > 0) || !(maks > 0)) return '#edf5f3';
  return WARNA_KEPADATAN[Math.min(WARNA_KEPADATAN.length, Math.ceil(jumlah / maks * WARNA_KEPADATAN.length)) - 1];
}

// Poligon selebar dunia dengan wilayah sebagai lubang, untuk memutihkan area di luarnya.
export function maskLuarWilayah(koleksi) {
  const lubang = (koleksi?.features ?? []).flatMap(f => f.geometry.type === 'Polygon' ? [f.geometry.coordinates[0]] : f.geometry.type === 'MultiPolygon' ? f.geometry.coordinates.map(p => p[0]) : []);
  return {type: 'Feature', properties: {}, geometry: {type: 'Polygon', coordinates: [[[-180, -85], [180, -85], [180, 85], [-180, 85], [-180, -85]], ...lubang]}};
}
