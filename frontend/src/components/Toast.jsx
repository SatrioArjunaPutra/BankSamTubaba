import { createContext, useCallback, useContext, useState } from 'react';
import { AlertTriangle, CheckCircle, X } from 'lucide-react';

const ToastContext = createContext(null);

// Toast sukses dipanggil hanya setelah API membalas sukses
export function ToastProvider({ children }) {
  const [daftar, setDaftar] = useState([]);

  const tutup = useCallback((id) => setDaftar((d) => d.filter((t) => t.id !== id)), []);

  const tampil = useCallback(
    (jenis, pesan) => {
      const id = Date.now() + Math.random();
      setDaftar((d) => [...d.slice(-2), { id, jenis, pesan }]);
      setTimeout(() => tutup(id), jenis === 'gagal' ? 6000 : 3500);
    },
    [tutup],
  );

  const api = {
    sukses: useCallback((pesan) => tampil('sukses', pesan), [tampil]),
    gagal: useCallback((pesan) => tampil('gagal', pesan), [tampil]),
  };

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="fixed bottom-4 right-4 left-4 sm:left-auto z-[2000] flex flex-col gap-2 sm:w-96" aria-live="polite">
        {daftar.map((t) => (
          <div
            key={t.id}
            className="flex items-start gap-3 p-4 rounded-2xl border shadow-xl bg-white dark:bg-[#0b1220] border-slate-200 dark:border-white/15 text-slate-800 dark:text-white animate-slideUp"
          >
            {t.jenis === 'sukses' ? (
              <CheckCircle className="w-5 h-5 text-emerald-500 shrink-0" />
            ) : (
              <AlertTriangle className="w-5 h-5 text-red-500 shrink-0" />
            )}
            <p className="flex-1 text-sm">{t.pesan}</p>
            <button onClick={() => tutup(t.id)} className="opacity-60 hover:opacity-100" aria-label="Tutup notifikasi">
              <X className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// eslint-disable-next-line react/only-export-components
export const useToast = () => useContext(ToastContext);
