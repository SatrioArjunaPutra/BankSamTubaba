// Ubah state filter periode menjadi query API. Rentang kustom yang belum lengkap diabaikan.
export function queryPeriode({ periode, dari, sampai }) {
  if (periode === 'kustom') return dari && sampai ? { dari, sampai } : {};
  return periode ? { periode } : {};
}
