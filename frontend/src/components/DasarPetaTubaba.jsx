import { useMemo } from 'react';
import { GeoJSON, Pane, TileLayer } from 'react-leaflet';
import useFetch from '../hooks/useFetch';
import { ambilStatistikPublik } from '../services/api';
import { ATRIBUSI_PETA, URL_PETA_DASAR, URL_PETA_LABEL, ambilLapisanWilayah, maskLuarWilayah, normalisasiWilayah as norm, warnaKepadatan } from '../utils/peta';

const ambilBatasDasar = () => ambilLapisanWilayah(['kabupaten', 'kecamatan']);

/**
 * Peta dasar bergaya peta bank sampah DLH: kecamatan berwarna menurut jumlah
 * bank sampah, area luar Tubaba dipudarkan, dan garis batas wilayah.
 */
export default function DasarPetaTubaba() {
  const batas = useFetch(ambilBatasDasar);
  const statistik = useFetch(ambilStatistikPublik);
  const geo = batas.data;
  const mask = useMemo(() => geo ? maskLuarWilayah(geo.kabupaten) : null, [geo]);
  const jumlah = useMemo(() => {
    const hasil = new Map();
    for (const [nama, n] of Object.entries(statistik.data?.data?.bank_per_kecamatan ?? {})) hasil.set(norm(nama), n);
    return hasil;
  }, [statistik.data]);
  const maks = Math.max(0, ...jumlah.values());

  return (
    <>
      <TileLayer url={URL_PETA_DASAR} maxZoom={19} maxNativeZoom={16} attribution={ATRIBUSI_PETA} />
      <TileLayer url={URL_PETA_LABEL} maxZoom={19} maxNativeZoom={16} />
      {geo && (
        <Pane name="wilayah-tubaba" style={{ zIndex: 350 }}>
          <GeoJSON data={mask} interactive={false} style={{ stroke: false, fillColor: '#ffffff', fillOpacity: 0.62 }} />
          <GeoJSON
            key={maks}
            data={geo.kecamatan}
            interactive={false}
            style={(f) => ({ color: '#ffffff', weight: 1.4, fillColor: warnaKepadatan(jumlah.get(norm(f.properties.nama)) ?? 0, maks), fillOpacity: 0.78 })}
          />
          <GeoJSON data={geo.kabupaten} interactive={false} style={{ color: '#0f5c55', weight: 2.4, fillOpacity: 0 }} />
        </Pane>
      )}
    </>
  );
}
