import assert from 'node:assert/strict';
import test from 'node:test';
import { gayaKartu, posisiCincin, ukuranKarusel, ulangiBarang } from './karusel.js';

test('desktop memakai dua kartu besar yang muat bersama kartu samping', () => {
  const u = ukuranKarusel(1136, false, 4);
  assert.equal(u.pasangan, true);
  assert.equal(u.lebar, 300);
  assert.ok(u.tengahSamping + u.lebarSamping / 2 <= 1136 / 2);
  const sempit = ukuranKarusel(736, false, 4);
  assert.ok(sempit.tengahSamping + sempit.lebarSamping / 2 <= 736 / 2 + 0.01);
});

test('HP memakai satu kartu besar yang muat di layar sempit', () => {
  const u = ukuranKarusel(288, true, 4);
  assert.equal(u.pasangan, false);
  assert.ok(u.tengahSamping + u.lebarSamping / 2 <= 288 / 2 + 0.01);
});

test('satu barang tampil tanpa kartu samping', () => {
  const u = ukuranKarusel(1136, false, 1);
  assert.equal(u.pasangan, false);
  assert.equal(u.lebar, 300);
});

test('daftar pendek diulang, daftar panjang dibiarkan', () => {
  assert.equal(ulangiBarang([1], 6).length, 1);
  assert.equal(ulangiBarang([1, 2], 6).length, 6);
  assert.equal(ulangiBarang([1, 2, 3, 4], 6).length, 8);
  assert.equal(ulangiBarang([1, 2, 3, 4, 5, 6, 7], 6).length, 7);
});

test('posisi melingkar selalu lewat jalur terpendek', () => {
  assert.deepEqual([0, 1, 2, 3, 4, 5].map((k) => posisiCincin(k, 0, 6, true)), [0, 1, 2, 3, -2, -1]);
  assert.deepEqual([0, 1, 2, 3, 4].map((k) => posisiCincin(k, 0, 5, false)), [0, 1, 2, -2, -1]);
  assert.equal(posisiCincin(0, 7, 6, true), -1);
  assert.equal(posisiCincin(0, -1, 6, true), 1);
});

test('kartu besar utuh, kartu samping dipotong, kartu di luar tidak terlihat', () => {
  const u = ukuranKarusel(1136, false, 4);
  const kiri = gayaKartu(0, u);
  assert.equal(kiri.skala, 1);
  assert.equal(kiri.potong, 0);
  assert.equal(kiri.info, 1);
  assert.equal(gayaKartu(1, u).x, -kiri.x);

  const samping = gayaKartu(2, u);
  assert.equal(samping.skala, 0.6);
  assert.equal(samping.info, 0);
  assert.ok(Math.abs(u.lebar * samping.skala * (1 - (samping.potong * 2) / 100) - u.lebarSamping) < 0.01);

  assert.equal(gayaKartu(3, u).tampak, 0);
  assert.equal(gayaKartu(9, u).tampak, 0);
  assert.equal(gayaKartu(-9, u).tampak, 0);
});

test('posisi pecahan berada di antara dua titik saat kartu diseret', () => {
  const u = ukuranKarusel(1136, false, 4);
  const tengah = gayaKartu(1.5, u);
  assert.equal(tengah.x, (gayaKartu(1, u).x + gayaKartu(2, u).x) / 2);
  assert.ok(tengah.skala < 1 && tengah.skala > 0.6);
});
