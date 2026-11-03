/**
 * Perhitungan posisi kartu etalase. Kartu tersusun melingkar: posisi 0 dan 1 kartu
 * besar (di HP hanya 0), posisi di luarnya kartu kecil yang dipotong di kedua sisi.
 */

const LEBAR_SAMPING_LEBAR = 104;
const LEBAR_SAMPING_HP = 44;
const JARAK_LEBAR = 18;
const JARAK_HP = 8;
const SKALA_SAMPING = 0.6;
const KELUAR = 70;

export function ukuranKarusel(lebarWadah, hp, jumlahBarang) {
  const pasangan = !hp && jumlahBarang >= 2;
  const adaSamping = jumlahBarang >= 2;
  const lebarSamping = hp ? LEBAR_SAMPING_HP : LEBAR_SAMPING_LEBAR;
  const jarak = hp ? JARAK_HP : JARAK_LEBAR;
  const ruangSamping = adaSamping ? 2 * (lebarSamping + jarak) : 0;
  const lebar = pasangan
    ? Math.min(300, (lebarWadah - ruangSamping - jarak) / 2)
    : Math.min(hp ? 280 : 300, lebarWadah - ruangSamping);
  const tengahBesar = pasangan ? (lebar + jarak) / 2 : 0;
  const tengahSamping = tengahBesar + lebar / 2 + jarak + lebarSamping / 2;

  return {
    pasangan,
    lebar,
    tinggi: Math.round(Math.max(lebar * 1.36, 300)),
    lebarSamping,
    tengahBesar,
    tengahSamping,
    // Jarak satu kali geser
    langkah: pasangan ? tengahBesar * 2 : tengahSamping,
  };
}

/** Ulangi daftar sampai cukup panjang untuk mengisi semua posisi tanpa kartu yang sama bertabrakan. */
export function ulangiBarang(barang, minimal) {
  if (barang.length < 2) return barang;
  const hasil = [...barang];
  while (hasil.length < minimal) hasil.push(...barang);
  return hasil;
}

/** Posisi kartu ke-k terhadap kartu aktif, lewat jalur terpendek pada lingkaran. */
export function posisiCincin(k, indeks, panjang, pasangan) {
  const selisih = ((k - indeks) % panjang + panjang) % panjang;
  return selisih > panjang / 2 + (pasangan ? 0.5 : 0) ? selisih - panjang : selisih;
}

const antara = (a, b, t) => a + (b - a) * t;

/** Gaya kartu pada posisi p (boleh pecahan saat sedang diseret). */
export function gayaKartu(p, ukuran) {
  const { pasangan, lebar, lebarSamping, tengahBesar, tengahSamping } = ukuran;
  const potong = Math.max(0, (1 - lebarSamping / (lebar * SKALA_SAMPING)) / 2) * 100;
  const samping = (x) => ({ x, skala: SKALA_SAMPING, potong, redup: 0.32, info: 0, tampak: 1 });
  const hilang = (x) => ({ x, skala: 0.5, potong, redup: 0.6, info: 0, tampak: 0 });
  const besar = (x) => ({ x, skala: 1, potong: 0, redup: 0, info: 1, tampak: 1 });
  const titik = pasangan
    ? [[-2, hilang(-tengahSamping - KELUAR)], [-1, samping(-tengahSamping)], [0, besar(-tengahBesar)], [1, besar(tengahBesar)], [2, samping(tengahSamping)], [3, hilang(tengahSamping + KELUAR)]]
    : [[-2, hilang(-tengahSamping - KELUAR)], [-1, samping(-tengahSamping)], [0, besar(0)], [1, samping(tengahSamping)], [2, hilang(tengahSamping + KELUAR)]];

  if (p <= titik[0][0]) return titik[0][1];
  if (p >= titik.at(-1)[0]) return titik.at(-1)[1];
  const i = titik.findIndex(([q]) => p <= q);
  const [q0, a] = titik[i - 1];
  const [q1, b] = titik[i];
  const t = (p - q0) / (q1 - q0);
  return Object.fromEntries(Object.keys(a).map((k) => [k, antara(a[k], b[k], t)]));
}
