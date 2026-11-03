/**
 * Simpanan sementara respons GET di memori tab. Halaman yang pernah dibuka bisa
 * langsung tampil, lalu diperbarui diam-diam setelah data terbaru tiba.
 * Isinya hilang saat tab ditutup atau dimuat ulang.
 */
const BATAS = 60;

export function buatSimpanan(batas = BATAS) {
  const isi = new Map();

  return {
    ambil: (kunci) => isi.get(kunci),
    simpan(kunci, nilai) {
      // Kunci yang baru dipakai pindah ke belakang; yang paling lama dibuang lebih dulu
      isi.delete(kunci);
      isi.set(kunci, nilai);
      if (isi.size > batas) isi.delete(isi.keys().next().value);
    },
    kosongkan: () => isi.clear(),
    get ukuran() {
      return isi.size;
    },
  };
}
