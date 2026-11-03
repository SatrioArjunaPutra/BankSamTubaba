import { BarChart3, FileText, Gift, LayoutDashboard, MapPin, Newspaper, Recycle, ShoppingBag, Store, Truck, Users, ArrowLeftRight } from 'lucide-react';

export const MENU = [
  { id: 'ringkasan', grup: 'Pantauan', label: 'Ringkasan', ikon: LayoutDashboard },
  { id: 'bank-sampah', grup: 'Pantauan', label: 'Bank sampah', ikon: Store },
  { id: 'peta', grup: 'Pantauan', label: 'Peta bank sampah', ikon: MapPin },
  { id: 'bentor', grup: 'Pantauan', label: 'Bentor', ikon: Truck },
  { id: 'warga', grup: 'Aktivitas warga', label: 'Warga', ikon: Users },
  { id: 'transaksi', grup: 'Aktivitas warga', label: 'Transaksi', ikon: ArrowLeftRight },
  { id: 'donasi', grup: 'Aktivitas warga', label: 'Donasi', ikon: Gift },
  { id: 'preloved', grup: 'Aktivitas warga', label: 'Preloved', ikon: ShoppingBag },
  { id: 'berita', grup: 'Publikasi', label: 'Berita', ikon: Newspaper },
  { id: 'laporan', grup: 'Publikasi', label: 'Laporan', ikon: FileText },
];
export const MENU_TAMBAHAN = [
  { id: 'kinerja', label: 'Tren kinerja', ikon: BarChart3 },
  { id: 'jenis-sampah', label: 'Master jenis sampah', ikon: Recycle },
  { id: 'moderasi', label: 'Laporan preloved', ikon: ShoppingBag },
];
