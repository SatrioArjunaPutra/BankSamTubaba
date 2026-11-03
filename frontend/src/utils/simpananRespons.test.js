import assert from 'node:assert/strict';
import test from 'node:test';
import { buatSimpanan } from './simpananRespons.js';

test('menyimpan dan mengambil respons berdasarkan kunci', () => {
  const s = buatSimpanan();
  assert.equal(s.ambil('/a'), undefined);
  s.simpan('/a', { data: 1 });
  assert.deepEqual(s.ambil('/a'), { data: 1 });
});

test('membuang kunci paling lama saat melewati batas', () => {
  const s = buatSimpanan(2);
  s.simpan('/a', 1);
  s.simpan('/b', 2);
  s.simpan('/a', 3); // /a jadi yang terbaru
  s.simpan('/c', 4);
  assert.equal(s.ukuran, 2);
  assert.equal(s.ambil('/b'), undefined);
  assert.equal(s.ambil('/a'), 3);
  assert.equal(s.ambil('/c'), 4);
});

test('kosongkan menghapus semua respons', () => {
  const s = buatSimpanan();
  s.simpan('/a', 1);
  s.kosongkan();
  assert.equal(s.ukuran, 0);
  assert.equal(s.ambil('/a'), undefined);
});
