// Klien API Laravel Bank Sampah (/api/v1). Semua panggilan lewat request().
import { buatSimpanan } from '../utils/simpananRespons';

const BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1').replace(/\/+$/, '');
const KUNCI_TOKEN = 'BANK_SAMPAH_TOKEN';
// Server yang tidak menjawab tidak boleh membuat halaman menunggu selamanya
const BATAS_TUNGGU_GET_MS = 20000;

export const EVENT_SESI_BERAKHIR = 'sesi-berakhir';

export class ApiError extends Error {
  constructor(status, pesan, errors = null) {
    super(pesan);
    this.status = status;
    this.errors = errors;
  }

  // Pesan validasi pertama per field: { nama: 'Nama wajib diisi.' }
  get pesanField() {
    if (!this.errors) return {};
    return Object.fromEntries(Object.entries(this.errors).map(([k, v]) => [k, v[0]]));
  }
}

const simpanan = buatSimpanan();
const sedangDiminta = new Map();
let generasi = 0;

// Data berubah atau ganti akun: respons lama tidak boleh tampil lagi, termasuk yang masih di jalan
function lupakanRespons() {
  simpanan.kosongkan();
  sedangDiminta.clear();
  generasi += 1;
}

export const token = {
  ambil: () => sessionStorage.getItem(KUNCI_TOKEN),
  simpan: (nilai) => {
    lupakanRespons();
    sessionStorage.setItem(KUNCI_TOKEN, nilai);
  },
  hapus: () => {
    lupakanRespons();
    sessionStorage.removeItem(KUNCI_TOKEN);
  },
};

const PESAN_STATUS = {
  401: 'Sesi berakhir. Silakan login kembali.',
  403: 'Anda tidak memiliki akses ke fitur ini.',
  404: 'Data tidak ditemukan.',
  422: 'Data yang dikirim tidak valid.',
  429: 'Terlalu banyak permintaan. Coba lagi sebentar lagi.',
};

function buatUrl(path, query) {
  const url = new URL(BASE_URL + path);
  Object.entries(query || {}).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, v);
  });
  return url;
}

async function kirim(path, { method = 'GET', body, query, tokenKhusus } = {}) {
  const headers = { Accept: 'application/json' };
  const bearer = tokenKhusus ?? token.ambil();
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  // FormData menentukan Content-Type multipart beserta boundary-nya sendiri
  const multipart = body instanceof FormData;
  if (body !== undefined && !multipart) headers['Content-Type'] = 'application/json';

  let res;
  try {
    res = await fetch(buatUrl(path, query), {
      method,
      headers,
      body: multipart || body === undefined ? body : JSON.stringify(body),
      signal: method === 'GET' ? AbortSignal.timeout(BATAS_TUNGGU_GET_MS) : undefined,
    });
  } catch {
    throw new ApiError(0, 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
  }

  const json = await res.json().catch(() => null);

  if (!res.ok) {
    if (res.status === 401 && !tokenKhusus) {
      token.hapus();
      window.dispatchEvent(new Event(EVENT_SESI_BERAKHIR));
    }
    const pesan = res.status === 422 || res.status === 401 ? json?.pesan : null;
    throw new ApiError(res.status, pesan || PESAN_STATUS[res.status] || json?.pesan || 'Terjadi kesalahan pada server.', json?.errors);
  }

  return json;
}

/**
 * GET yang sama tidak dikirim dua kali selagi masih berjalan. Bila respons
 * sebelumnya masih tersimpan, janji yang dikembalikan membawanya di `tersimpan`
 * agar halaman bisa langsung tampil sambil menunggu data terbaru.
 *
 * @returns {Promise<object> & {tersimpan?: object}} body JSON lengkap ({status, pesan, data, meta?, links?})
 * @throws {ApiError}
 */
export function request(path, opsi = {}) {
  const { method = 'GET', query, tokenKhusus } = opsi;

  if (method !== 'GET') {
    return kirim(path, opsi).then((json) => {
      lupakanRespons();
      return json;
    });
  }
  if (tokenKhusus) return kirim(path, opsi);

  const kunci = buatUrl(path, query).href;
  let janji = sedangDiminta.get(kunci);
  if (!janji) {
    const generasiAwal = generasi;
    janji = kirim(path, opsi)
      .then((json) => {
        if (generasiAwal === generasi) simpanan.simpan(kunci, json);
        return json;
      })
      .finally(() => {
        if (sedangDiminta.get(kunci) === janji) sedangDiminta.delete(kunci);
      });
    sedangDiminta.set(kunci, janji);
  }
  janji.tersimpan = simpanan.ambil(kunci);
  return janji;
}

// --- Auth ---
export const login = (email, password) =>
  request('/auth/login', { method: 'POST', body: { email, password, device_name: 'web-dlh' } });
export const logout = (tokenKhusus) => request('/auth/logout', { method: 'POST', tokenKhusus });
export const ambilProfil = () => request('/me');

// --- Publik ---
export const ambilEtalasePreloved = (query) => request('/etalase-preloved', { query });
export const ambilStatistikPublik = () => request('/statistik-publik');
export const ambilBerita = (query) => request('/berita', { query });
export const ambilDetailBerita = (id) => request(`/berita/${id}`);
export const ambilTeksBerjalan = () => request('/teks-berjalan');

// --- DLH ---
export const ambilDashboard = (query) => request('/dlh/dashboard', { query });
export const ambilPantauan = (jenis, query) => request(`/dlh/${jenis}`, { query });
export const ambilRingkasan = (query) => request('/dlh/ringkasan', { query });
export const ambilKinerja = (query) => request('/dlh/kinerja', { query });
export const ambilPeta = (query) => request('/dlh/peta', { query });
export const ambilTren = (bankId, query) => request(`/dlh/kinerja/${bankId}/tren`, { query });

export const ambilDaftarBankSampah = (query) => request('/dlh/bank-sampah', { query });
export const tambahBankSampah = (data) => request('/dlh/bank-sampah', { method: 'POST', body: data });
export const ubahBankSampah = (id, data) => request(`/dlh/bank-sampah/${id}`, { method: 'PATCH', body: data });
export const buatOperator = (bankId, data) => request(`/dlh/bank-sampah/${bankId}/operator`, { method: 'POST', body: data });
export const ambilAkunBankSampah = (bankId) => request(`/dlh/bank-sampah/${bankId}/akun`);
export const ubahStatusAkun = (userId, aktif) => request(`/dlh/akun/${userId}/status`, { method: 'PATCH', body: { is_aktif: aktif } });

export const ambilJenisSampah = () => request('/dlh/jenis-sampah');
export const tambahJenisSampah = (data) => request('/dlh/jenis-sampah', { method: 'POST', body: data });
export const ubahJenisSampah = (id, data) => request(`/dlh/jenis-sampah/${id}`, { method: 'PATCH', body: data });

export const ambilBeritaDlh = (query) => request('/dlh/berita', { query });
// Unggah foto saat ubah harus lewat POST + _method: PHP tidak membaca multipart pada PATCH asli
export const simpanBerita = (id, form) => {
  if (id) form.append('_method', 'PATCH');
  return request(id ? `/dlh/berita/${id}` : '/dlh/berita', { method: 'POST', body: form });
};
export const hapusBerita = (id) => request(`/dlh/berita/${id}`, { method: 'DELETE' });

export const ambilTeksBerjalanDlh = (query) => request('/dlh/teks-berjalan', { query });
export const simpanTeksBerjalan = (id, data) =>
  request(id ? `/dlh/teks-berjalan/${id}` : '/dlh/teks-berjalan', { method: id ? 'PATCH' : 'POST', body: data });
export const hapusTeksBerjalan = (id) => request(`/dlh/teks-berjalan/${id}`, { method: 'DELETE' });


export const ambilDaftarPrelovedDlh = (query) => request('/dlh/preloved', { query });
export const ambilPrelovedDlh = ambilDaftarPrelovedDlh;
export const ambilLaporanPreloved = (query) => request('/dlh/laporan-preloved', { query });
export const ubahStatusPreloved = (id, status) => request(`/dlh/preloved/${id}`, { method: 'PATCH', body: { status } });
export const hapusPrelovedDlh = (id) => request(`/dlh/preloved/${id}`, { method: 'DELETE' });
