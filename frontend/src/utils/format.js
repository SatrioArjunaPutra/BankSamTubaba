export const formatRupiah = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID', { maximumFractionDigits: 0 });

export const formatKg = (n) => Number(n || 0).toLocaleString('id-ID', { maximumFractionDigits: 2 }) + ' kg';

export const formatAngka = (n) => Number(n || 0).toLocaleString('id-ID');

export const formatTanggal = (iso) =>
  iso ? new Date(iso).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '-';

// 'YYYY-MM-DD' atau 'YYYY-MM' → label singkat sumbu grafik
export const labelPeriode = (p) => {
  const [y, m, d] = p.split('-').map(Number);
  const tgl = new Date(y, m - 1, d || 1);
  return d
    ? tgl.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })
    : tgl.toLocaleDateString('id-ID', { month: 'short', year: '2-digit' });
};

export const KATEGORI_BERITA = { berita: 'Berita', pengumuman: 'Pengumuman', kegiatan: 'Kegiatan' };

export const tanggalPanjang = (iso) =>
  iso ? new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }) : '-';

// Judul di alamat hanya pelengkap agar link mudah dibaca; artikel dicari lewat id-nya
export const urlBerita = (berita) => {
  const judul = berita.judul.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  return `#/berita/${berita.id}-${judul}`;
};
