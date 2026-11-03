import { useEffect, useId, useRef } from 'react';
import { AlertTriangle, Inbox, Loader2, X } from 'lucide-react';

export function Kartu({ className = '', children }) {
  return <div className={`liquid-glass-card rounded-3xl p-5 sm:p-6 ${className}`}>{children}</div>;
}

export function JudulHalaman({ ikon: Ikon, judul, keterangan, aksi }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-6">
      <div>
        <div className="flex items-center gap-2 mb-1">
          {Ikon && <Ikon className="page-title-icon" aria-hidden="true" />}
          <h1 className="page-heading">{judul}</h1>
        </div>
        {keterangan && <p className="page-description">{keterangan}</p>}
      </div>
      {aksi && <div className="flex flex-wrap items-center gap-2">{aksi}</div>}
    </div>
  );
}

export function Tombol({ varian = 'utama', loading = false, className = '', children, ...props }) {
  const gaya = {
    utama: 'ui-button-primary',
    sekunder: 'ui-button-secondary',
    bahaya: 'bg-red-600 hover:bg-red-500 text-white border-red-600',
  }[varian];

  return (
    <button
      {...props}
      disabled={loading || props.disabled}
      className={`ui-button inline-flex items-center justify-center gap-2 px-3.5 py-2 border transition disabled:opacity-50 disabled:cursor-not-allowed ${gaya} ${className}`}
    >
      {loading && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
      {children}
    </button>
  );
}

const gayaInput =
  'form-input';

export function Field({ label, error, children }) {
  return (
    <label className="block">
      <span className="field-label">{label}</span>
      {children}
      {error && <span className="block mt-1 text-xs text-red-600 dark:text-red-400">{error}</span>}
    </label>
  );
}

export function Input({ className = '', ...props }) {
  return <input {...props} className={`${gayaInput} ${className}`} />;
}

export function Pilihan({ className = '', children, ...props }) {
  return (
    <select {...props} className={`${gayaInput} ${className}`}>
      {children}
    </select>
  );
}

export function Skeleton({ className = '' }) {
  return <div className={`animate-pulse rounded-xl bg-slate-200 dark:bg-white/10 ${className}`} />;
}

export function SkeletonBaris({ jumlah = 5 }) {
  return (
    <div className="space-y-2">
      {Array.from({ length: jumlah }, (_, i) => (
        <Skeleton key={i} className="h-10" />
      ))}
    </div>
  );
}

export function Kosong({ judul = 'Belum ada data', keterangan }) {
  return (
    <div className="py-12 flex flex-col items-center text-center text-slate-500 dark:text-zinc-400">
      <Inbox className="w-10 h-10 mb-3 opacity-60" />
      <p className="font-mono text-xs uppercase tracking-wider font-bold">{judul}</p>
      {keterangan && <p className="text-xs mt-1 max-w-sm">{keterangan}</p>}
    </div>
  );
}

export function GagalMuat({ error, onUlang }) {
  return (
    <div className="py-10 flex flex-col items-center text-center">
      <AlertTriangle className="w-9 h-9 mb-3 text-amber-500" />
      <p className="text-sm text-slate-700 dark:text-zinc-200">{error?.message || 'Gagal memuat data.'}</p>
      {onUlang && (
        <Tombol varian="sekunder" className="mt-4" onClick={onUlang}>
          Coba lagi
        </Tombol>
      )}
    </div>
  );
}

export function Lencana({ warna = 'abu', children }) {
  const gaya = {
    hijau: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30',
    merah: 'bg-red-500/15 text-red-700 dark:text-red-300 border-red-500/30',
    kuning: 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30',
    biru: 'bg-cyan-500/15 text-cyan-700 dark:text-cyan-300 border-cyan-500/30',
    abu: 'bg-slate-500/10 text-slate-600 dark:text-zinc-300 border-slate-500/20',
  }[warna];
  return <span className={`status-badge inline-flex items-center rounded-full ${gaya}`}>{children}</span>;
}

export function Modal({ judul, keterangan, logo, polos = false, onTutup, children, lebar = 'max-w-lg' }) {
  const panelRef = useRef(null);
  const tutupRef = useRef(onTutup);
  const judulId = useId();
  useEffect(() => { tutupRef.current = onTutup; }, [onTutup]);
  useEffect(() => {
    const sebelumnya = document.activeElement;
    const gulir = document.body.style.overflow;
    const panel = panelRef.current;
    const fokus = () => [...panel.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), a[href], [tabindex="0"]')].filter((el) => el.getClientRects().length);
    document.body.style.overflow = 'hidden';
    (panel.querySelector('[data-fokus-awal]') ?? fokus()[0] ?? panel).focus();
    const keyboard = (e) => {
      if (e.key === 'Escape') { e.stopPropagation(); tutupRef.current(); }
      if (e.key !== 'Tab') return;
      const elemen = fokus();
      const pertama = elemen[0];
      const terakhir = elemen.at(-1);
      if (!pertama) { e.preventDefault(); panel.focus(); return; }
      if (e.shiftKey && (document.activeElement === pertama || document.activeElement === panel)) {
        e.preventDefault(); terakhir.focus();
      } else if (!e.shiftKey && document.activeElement === terakhir) {
        e.preventDefault(); pertama.focus();
      }
    };
    panel.addEventListener('keydown', keyboard);
    return () => {
      panel.removeEventListener('keydown', keyboard);
      document.body.style.overflow = gulir;
      if (sebelumnya?.isConnected) sebelumnya.focus();
    };
  }, []);

  return (
    <div className={`fixed inset-0 z-[1000] flex items-start sm:items-center justify-center p-4 bg-black/50 overflow-y-auto ${logo ? 'backdrop-blur-md' : 'backdrop-blur-sm'}`} onClick={onTutup}>
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={judulId}
        tabIndex={-1}
        className={`ui-modal w-full ${lebar} my-8 rounded-3xl border p-6 shadow-2xl`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={logo ? 'ui-modal-pusat' : polos ? 'ui-modal-polos' : 'flex items-center justify-between mb-5'}>
          {logo}
          <h2 id={judulId} className={polos ? 'sr-only' : 'section-heading'}>{judul}</h2>
          {keterangan && <p>{keterangan}</p>}
          <button type="button" onClick={onTutup} className="p-1 opacity-60 hover:opacity-100" aria-label="Tutup">
            <X className="w-4 h-4" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Paginasi({ meta, onHalaman }) {
  if (!meta || meta.last_page <= 1) return null;
  return (
    <div className="flex items-center justify-between mt-4 text-xs font-mono text-slate-500 dark:text-zinc-400">
      <span>
        {meta.from}–{meta.to} dari {meta.total}
      </span>
      <div className="flex gap-2">
        <Tombol varian="sekunder" disabled={meta.current_page <= 1} onClick={() => onHalaman(meta.current_page - 1)}>
          Sebelumnya
        </Tombol>
        <Tombol varian="sekunder" disabled={meta.current_page >= meta.last_page} onClick={() => onHalaman(meta.current_page + 1)}>
          Berikutnya
        </Tombol>
      </div>
    </div>
  );
}
