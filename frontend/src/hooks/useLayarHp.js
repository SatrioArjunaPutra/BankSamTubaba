import { useSyncExternalStore } from 'react';

// Sama dengan batas CSS .tabel-kartu di index.css
const media = window.matchMedia('(max-width: 640px)');

const ikuti = (ubah) => {
  media.addEventListener('change', ubah);
  return () => media.removeEventListener('change', ubah);
};

export default function useLayarHp() {
  return useSyncExternalStore(ikuti, () => media.matches);
}
