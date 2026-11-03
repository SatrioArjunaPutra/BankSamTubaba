import { useCallback } from 'react';

/**
 * Menghentikan animasi terus-menerus selama elemennya di luar layar, agar browser
 * tidak menghitungnya setiap frame saat halaman digulir. Pasang hasilnya sebagai `ref`.
 */
export default function useDiamDiLuarLayar() {
  return useCallback((elemen) => {
    if (!elemen) return undefined;
    const pengamat = new IntersectionObserver(([masuk]) => {
      elemen.classList.toggle('diam-luar-layar', !masuk.isIntersecting);
    });
    pengamat.observe(elemen);
    return () => pengamat.disconnect();
  }, []);
}
