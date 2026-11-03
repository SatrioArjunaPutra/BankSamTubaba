/**
 * Mengurai isi berita (teks biasa) menjadi blok tampilan:
 * "## judul" = subjudul, "> teks" = kutipan, baris kosong = pemisah paragraf.
 * Hasilnya dirender sebagai teks oleh React, jadi kode HTML di dalamnya tidak berjalan.
 *
 * @param {string} teks
 * @returns {{jenis: 'paragraf'|'subjudul'|'kutipan', teks: string}[]}
 */
export function uraiIsiBerita(teks) {
  const blok = [];
  let sela = true;

  for (const mentah of String(teks ?? '').split(/\r?\n/)) {
    const baris = mentah.trim();
    if (!baris) {
      sela = true;
      continue;
    }

    const terakhir = blok.at(-1);
    if (baris.startsWith('## ')) {
      blok.push({ jenis: 'subjudul', teks: baris.slice(3).trim() });
    } else if (baris.startsWith('>')) {
      const isi = baris.slice(1).trim();
      if (!sela && terakhir?.jenis === 'kutipan') terakhir.teks += `\n${isi}`;
      else blok.push({ jenis: 'kutipan', teks: isi });
    } else if (!sela && terakhir?.jenis === 'paragraf') {
      terakhir.teks += `\n${baris}`;
    } else {
      blok.push({ jenis: 'paragraf', teks: baris });
    }
    sela = false;
  }

  return blok;
}
