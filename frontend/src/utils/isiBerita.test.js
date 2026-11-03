import test from 'node:test';
import assert from 'node:assert/strict';
import { uraiIsiBerita } from './isiBerita.js';

test('memisahkan paragraf, subjudul, dan kutipan', () => {
  assert.deepEqual(uraiIsiBerita('Pembuka.\n\n> Kata kepala dinas.\n\n## Tahap berikutnya\nLanjutan.'), [
    { jenis: 'paragraf', teks: 'Pembuka.' },
    { jenis: 'kutipan', teks: 'Kata kepala dinas.' },
    { jenis: 'subjudul', teks: 'Tahap berikutnya' },
    { jenis: 'paragraf', teks: 'Lanjutan.' },
  ]);
});

test('baris berurutan tetap satu blok, baris kosong memisahkan', () => {
  assert.deepEqual(uraiIsiBerita('Satu\nDua\n\nTiga\r\n\r\n> A\n> B\n\n> C'), [
    { jenis: 'paragraf', teks: 'Satu\nDua' },
    { jenis: 'paragraf', teks: 'Tiga' },
    { jenis: 'kutipan', teks: 'A\nB' },
    { jenis: 'kutipan', teks: 'C' },
  ]);
});

test('kode HTML tetap teks dan tanda tanpa spasi bukan subjudul', () => {
  assert.deepEqual(uraiIsiBerita('<script>x</script>\n\n##Bukan judul'), [
    { jenis: 'paragraf', teks: '<script>x</script>' },
    { jenis: 'paragraf', teks: '##Bukan judul' },
  ]);
});

test('isi kosong menghasilkan daftar kosong', () => {
  assert.deepEqual(uraiIsiBerita(''), []);
  assert.deepEqual(uraiIsiBerita(null), []);
});
