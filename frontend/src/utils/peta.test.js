import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { BATAS_AKTIVITAS, TINGKAT_AKTIVITAS, kelompokPeta, klasterTitik, maskLuarWilayah, normalisasiWilayah, tingkatAktivitas, tingkatKlaster, titikDalamWilayah, titikValid, warnaKepadatan } from './peta.js';

test('nama wilayah mengabaikan kapitalisasi, spasi, dan awalan; nilai kosong aman', () => {
  assert.equal(normalisasiWilayah('Tiyuh Daya Murni'), normalisasiWilayah('DAYAMURNI'));
  assert.equal(normalisasiWilayah('Kec. Tulang Bawang Tengah'), 'tulangbawangtengah');
  assert.equal(normalisasiWilayah(null), '');
});

test('titik memakai urutan latitude/longitude yang benar, termasuk lubang dan multipoligon', () => {
  const luar = [[104,-5],[106,-5],[106,-3],[104,-3],[104,-5]];
  const lubang = [[104.5,-4.5],[105.5,-4.5],[105.5,-3.5],[104.5,-3.5],[104.5,-4.5]];
  const polygon = {geometry:{type:'Polygon',coordinates:[luar,lubang]}};
  assert.equal(titikDalamWilayah(-4.8,105,polygon), true);
  assert.equal(titikDalamWilayah(-4,105,polygon), false);
  assert.equal(titikDalamWilayah(-6,105,polygon), false);
  assert.equal(titikDalamWilayah(-5,104,polygon), true);
  assert.equal(titikDalamWilayah(-4,105,{geometry:{type:'MultiPolygon',coordinates:[[luar]]}}), true);
  assert.equal(titikValid({lat:null,lng:105}), false);
  assert.equal(titikValid({lat:-4,lng:105}), true);
});

test('pengelompokan tidak mencampurkan desa bernama sama di kecamatan berbeda', () => {
  const data = [{id:1,tiyuh:'Murni',kecamatan:'A'},{id:2,tiyuh:'Murni',kecamatan:'B'},{id:3,tiyuh:'MURNI',kecamatan:'A'}];
  assert.deepEqual(kelompokPeta(data,'tiyuh').map(g=>g.bank.length),[2,1]);
  assert.equal(kelompokPeta(data,'kecamatan').length,2);
});

test('klaster mempertahankan semua ID termasuk titik berhimpit tanpa menggeser koordinat bank', () => {
  const data = [{id:1,lat:-4,lng:105},{id:2,lat:-4,lng:105},{id:3,lat:-4.5,lng:105.5}];
  const before = structuredClone(data);
  const groups = klasterTitik(data,b=>({x:b.lng*1000,y:b.lat*1000}));
  assert.equal(groups.length,2);
  assert.deepEqual(groups.flatMap(g=>g.bank.map(b=>b.id)).sort(),[1,2,3]);
  assert.deepEqual(data,before);
});

test('lapisan resmi berisi 1 kabupaten, 9 kecamatan dan 103 desa dengan cincin GeoJSON valid', () => {
  for (const [level,count] of [['kabupaten',1],['kecamatan',9],['desa',103]]) {
    const data=JSON.parse(readFileSync(new URL('../../public/geo/tubaba-'+level+'.geojson',import.meta.url),'utf8'));
    assert.equal(data.type,'FeatureCollection');
    assert.equal(data.features.length,count);
    assert.equal(new Set(data.features.map(f=>f.properties.kode)).size,count);
    for(const feature of data.features) {
      assert.ok(feature.properties.nama);
      const polys=feature.geometry.type==='Polygon'?[feature.geometry.coordinates]:feature.geometry.coordinates;
      for(const polygon of polys) for(const ring of polygon) {
        assert.ok(ring.length>=4);
        assert.deepEqual(ring[0],ring.at(-1));
        for(const [lng,lat] of ring) { assert.ok(lng>104&&lng<106); assert.ok(lat>-5&&lat<-3); }
      }
    }
  }
});

test('tingkat keaktifan mengikuti batas kg dan nilai kosong dianggap belum aktif', () => {
  const {kosong, rendah, sedang, tinggi} = TINGKAT_AKTIVITAS;
  assert.equal(tingkatAktivitas(0), kosong);
  assert.equal(tingkatAktivitas(null), kosong);
  assert.equal(tingkatAktivitas(undefined), kosong);
  assert.equal(tingkatAktivitas(0.5), rendah);
  assert.equal(tingkatAktivitas(BATAS_AKTIVITAS.rendah - 0.01), rendah);
  assert.equal(tingkatAktivitas(BATAS_AKTIVITAS.rendah), sedang);
  assert.equal(tingkatAktivitas(BATAS_AKTIVITAS.sedang), sedang);
  assert.equal(tingkatAktivitas(BATAS_AKTIVITAS.sedang + 0.01), tinggi);
});

test('warna klaster memakai rata-rata per bank, bukan jumlah total', () => {
  const banyakKecil = Array.from({length: 40}, () => ({total_kg: 50}));
  assert.equal(tingkatKlaster(banyakKecil), TINGKAT_AKTIVITAS.rendah);
  assert.equal(tingkatKlaster([{total_kg: 900}, {total_kg: 300}]), TINGKAT_AKTIVITAS.tinggi);
  assert.equal(tingkatKlaster([{total_kg: 0}, {}]), TINGKAT_AKTIVITAS.kosong);
  assert.equal(tingkatKlaster([]), TINGKAT_AKTIVITAS.kosong);
});

test('warna kecamatan makin gelap seiring jumlah bank dan aman untuk nilai nol', () => {
  assert.equal(warnaKepadatan(0, 10), warnaKepadatan(0, 0));
  assert.notEqual(warnaKepadatan(1, 10), warnaKepadatan(10, 10));
  assert.equal(warnaKepadatan(10, 10), warnaKepadatan(8, 10));
  assert.ok(warnaKepadatan(1, 1));
});

test('mask memutihkan area di luar kabupaten dan membiarkan wilayah Tubaba terbuka', () => {
  const kabupaten = JSON.parse(readFileSync(new URL('../../public/geo/tubaba-kabupaten.geojson', import.meta.url), 'utf8'));
  const mask = maskLuarWilayah(kabupaten);
  assert.equal(titikDalamWilayah(-4.585, 105.132, mask), false, 'Panaragan berada di dalam Tubaba');
  assert.equal(titikDalamWilayah(-6.2, 106.8, mask), true, 'Jakarta berada di luar Tubaba');
  assert.equal(maskLuarWilayah(null).geometry.coordinates.length, 1);
});
