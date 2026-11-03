import { useCallback, useLayoutEffect, useRef, useState } from 'react';

/**
 * Muat data dari fungsi API. Dijalankan ulang setiap `kunci` berubah atau
 * refetch() dipanggil. Selama memuat ulang, data sebelumnya tetap tersedia
 * (tidak berkedip); respons yang datang terlambat diabaikan. Data yang pernah
 * dimuat langsung tampil tanpa kerangka, lalu diganti data terbaru begitu tiba.
 *
 * @param {() => Promise<object>} fn  mengembalikan body JSON API
 * @param {string|number} kunci  nilai primitif yang mewakili parameter fn
 * @returns {{ data: object|null, loading: boolean, error: import('../services/api').ApiError|null, refetch: () => void }}
 */
export default function useFetch(fn, kunci = '') {
  const [versi, setVersi] = useState(0);
  const [hasil, setHasil] = useState({ untuk: null, data: null, error: null });
  const fnRef = useRef(fn);
  const permintaan = `${kunci}#${versi}`;

  useLayoutEffect(() => {
    fnRef.current = fn;
  });

  useLayoutEffect(() => {
    let batal = false;
    const janji = fnRef.current();
    if (janji.tersimpan) setHasil({ untuk: permintaan, data: janji.tersimpan, error: null });
    janji
      .then((data) => !batal && setHasil({ untuk: permintaan, data, error: null }))
      .catch((error) => !batal && setHasil((h) => ({ untuk: permintaan, data: h.data, error })));
    return () => {
      batal = true;
    };
  }, [permintaan]);

  const refetch = useCallback(() => setVersi((v) => v + 1), []);
  const loading = hasil.untuk !== permintaan;

  return { data: hasil.data, loading, error: loading ? null : hasil.error, refetch };
}
