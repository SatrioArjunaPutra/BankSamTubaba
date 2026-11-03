import { useEffect, useRef } from 'react';

// [nomor gambar, posisi di bak, posisi di tumpukan], sebagai pecahan dari lebar bentor
const KARUNG = [
  [1, 0.03, -0.44],
  [2, 0.13, -0.33],
  [3, 0.22, -0.22],
  [4, 0.31, -0.11],
];

// [gambar, posisi dari kiri, skala terhadap rumah, kelas]. Urutannya dari yang paling belakang.
// khusus-lebar disembunyikan di HP, khusus-besar disembunyikan di tablet dan HP.
const LATAR_JAUH = [
  ['mangga', '51cqw', 1.4, 'khusus-besar'],
  ['rumah', 'calc(37cqw + var(--tinggi-rumah) * 1.52)', 0.62, 'khusus-besar dibalik'],
];
const HIASAN = [
  ['karet', '10cqw', 1.15, 'khusus-besar dibalik'],
  ['karet', '15cqw', 1.05, 'khusus-besar'],
  ['karet', '20cqw', 1.35, 'khusus-besar'],
  ['karet', '46.5cqw', 1.2, 'khusus-besar dibalik'],
  ['karet', '62cqw', 1.3, 'khusus-besar'],
  ['karet', '71cqw', 1.5, 'khusus-besar dibalik'],
  ['karet', '79.5cqw', 1.25, 'khusus-besar'],
  ['pagar', '17cqw', 0.36, 'khusus-besar'],
  ['pagar', '49cqw', 0.42, 'khusus-besar'],
  ['sawit', '0cqw', 1.45, ''],
  ['pisang', '25cqw', 0.8, 'khusus-lebar'],
  ['sawit', '29cqw', 1.2, 'khusus-lebar'],
  ['gapura', '37cqw', 1.2, 'khusus-lebar'],
  ['pisang', '59cqw', 0.72, 'khusus-lebar'],
  ['sawit', '84cqw', 1.5, ''],
  ['pisang', '91cqw', 0.8, 'khusus-lebar'],
  ['sawit', '94cqw', 1.15, 'khusus-lebar'],
  ['semak', '31.5cqw', 0.26, 'khusus-besar'],
  ['semak', '48cqw', 0.26, 'khusus-besar'],
  ['semak', '81cqw', 0.32, 'khusus-besar'],
  ['ayam', '40.5cqw', 0.16, 'khusus-besar'],
  ['petugas', '63.5cqw', 0.66, 'khusus-besar'],
];

// Layar HP terlalu sempit untuk daftar di atas. Gapura ditaruh di tengah antara rumah dan bank sampah.
const HIASAN_HP = [
  ['semak', '42cqw', 0.26, 'khusus-hp'],
  ['gapura', 'calc(26cqw + 4px)', 0.82, 'khusus-hp'],
  ['semak', '80cqw', 0.34, 'khusus-hp'],
  ['ayam', 'calc(26cqw + 24px)', 0.26, 'khusus-hp'],
  // Tukang timbang di depan dinding kiri bank sampah, agar tidak terpotong di tepi layar
  ['petugas', 'calc(var(--bank-kiri) - var(--tinggi-bank) * 0.12)', 0.72, 'khusus-kecil di-depan'],
];

function GambarHiasan({ daftar }) {
  return daftar.map(([gambar, kiri, skala, kelas]) => {
    const gaya = { '--kiri': kiri, '--skala': skala };
    const kunci = `${gambar}-${kiri}`;
    if (gambar === 'gapura') {
      return (
        <div className={`jalan-dekor jalan-gapura ${kelas}`} style={gaya} key={kunci}>
          <img src="/beranda/gapura.webp" alt="" decoding="async" />
          <span>TUBABA</span>
        </div>
      );
    }
    return <img className={`jalan-dekor ${kelas}`} style={gaya} src={`/beranda/${gambar}.webp`} alt="" decoding="async" key={kunci} />;
  });
}

function GambarKarung({ tempat }) {
  return KARUNG.map(([nomor, bak, tumpuk]) => (
    <img
      className={`jalan-karung ${tempat}`}
      style={{ '--bak': bak, '--tumpuk': tumpuk }}
      src={`/beranda/karung-${nomor}.webp`}
      alt=""
      decoding="async"
      key={nomor}
    />
  ));
}

// Tiap langkah menunggu langkah sebelumnya selesai, jadi bentor tidak mungkin jalan saat karung masih bergerak.
function mulaiCerita(akar) {
  const unit = akar.querySelector('.jalan-unit');
  const badan = akar.querySelector('.jalan-badan');
  const diBak = [...akar.querySelectorAll('.di-bak')];
  const diRumah = [...akar.querySelectorAll('.di-rumah')];
  const diBank = [...akar.querySelectorAll('.di-bank')];
  const animasi = new Set();
  let terlihat = false;
  let berjalan = false;
  let dihentikan = false;

  const jeda = (ms) => new Promise((selesai) => { setTimeout(selesai, ms); });
  const tampilkan = (elemen, nilai) => elemen.forEach((e) => { e.style.opacity = nilai; });

  const mainkan = async (elemen, bingkai, opsi) => {
    const a = elemen.animate(bingkai, { fill: 'forwards', ...opsi });
    animasi.add(a);
    await a.finished;
    a.commitStyles();
    a.cancel();
    animasi.delete(a);
  };

  const melaju = async (ke, duration, easing) => {
    const goyang = badan.animate(
      [{ transform: 'none' }, { transform: 'scaleY(1.06)' }, { transform: 'none' }],
      { duration: 1500, iterations: Infinity, easing: 'ease-in-out' },
    );
    animasi.add(goyang);
    await mainkan(unit, [{ transform: `translateX(${ke}px)` }], { duration, easing });
    goyang.cancel();
    animasi.delete(goyang);
  };

  const lintasan = (i) => {
    const lebar = unit.offsetWidth;
    const geser = (KARUNG[i][2] - KARUNG[i][1]) * lebar;
    return [
      { transform: `translate(${geser}px, ${lebar * 0.285}px)` },
      { transform: `translate(${geser / 2}px, ${lebar * -0.16}px)`, offset: 0.5 },
      { transform: 'translate(0, 0)' },
    ];
  };

  // Posisi berhenti mengikuti tumpukan karung, yang letaknya diatur CSS sesuai lebar layar
  const berhentiDi = (tumpukan) => tumpukan[0].offsetLeft - KARUNG[0][2] * unit.offsetWidth;

  const satuPutaran = async () => {
    unit.style.transform = `translateX(${-unit.offsetWidth}px)`;
    tampilkan(diBak, 0);
    tampilkan(diBank, 0);
    tampilkan(diRumah, 1);

    await melaju(berhentiDi(diRumah), 2600, 'ease-out');
    await jeda(500);
    for (let i = 0; i < KARUNG.length; i += 1) {
      diRumah[i].style.opacity = 0;
      diBak[i].style.opacity = 1;
      await mainkan(diBak[i], lintasan(i), { duration: 1100, easing: 'ease-in-out' });
      await jeda(250);
    }
    await jeda(900);

    await melaju(berhentiDi(diBank), 3400, 'ease-in-out');
    await jeda(500);
    for (let i = 0; i < KARUNG.length; i += 1) {
      await mainkan(diBak[i], lintasan(i).reverse(), { duration: 1100, easing: 'ease-in-out' });
      diBak[i].style.opacity = 0;
      diBank[i].style.opacity = 1;
      await jeda(250);
    }
    await jeda(900);

    await melaju(akar.clientWidth, 3000, 'ease-in');
    await Promise.all([
      ...diBank.map((e) => mainkan(e, [{ opacity: 0 }], { duration: 300 })),
      ...diRumah.map((e) => mainkan(e, [{ opacity: 1 }], { duration: 300 })),
    ]);
  };

  const jalankan = async () => {
    if (berjalan) return;
    berjalan = true;
    try {
      while (terlihat && !dihentikan) await satuPutaran();
    } catch {
      // Animasi dibatalkan karena halaman ditinggalkan
    }
    berjalan = false;
  };

  const pengamat = new IntersectionObserver(([masuk]) => {
    terlihat = masuk.isIntersecting;
    akar.classList.toggle('diam-luar-layar', !terlihat);
    if (terlihat) jalankan();
  });
  pengamat.observe(akar);

  return () => {
    dihentikan = true;
    pengamat.disconnect();
    animasi.forEach((a) => a.cancel());
  };
}

// Hiasan beranda: bentor menjemput karung dari rumah warga, lalu menurunkannya di bank sampah.
export default function JalanBentor() {
  const akar = useRef(null);

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;
    return mulaiCerita(akar.current);
  }, []);

  return (
    <div className="jalan-bentor" ref={akar} aria-hidden="true">
      <GambarHiasan daftar={LATAR_JAUH} />
      <div className="jalan-bentor-jauh"><img src="/beranda/bentor-kosong.webp" alt="" loading="lazy" decoding="async" /></div>
      <GambarHiasan daftar={HIASAN} />
      <GambarHiasan daftar={HIASAN_HP} />
      <img className="jalan-rumah" src="/beranda/rumah.webp" alt="" decoding="async" />
      <img className="jalan-warga" src="/beranda/warga.webp" alt="" decoding="async" />
      <img className="jalan-ibu" src="/beranda/warga-ibu.webp" alt="" decoding="async" />
      <div className="jalan-bank">
        <img src="/beranda/bank.webp" alt="" decoding="async" />
        <span>BANK SAMPAH</span>
      </div>
      <GambarKarung tempat="di-rumah" />
      <GambarKarung tempat="di-bank" />
      <div className="jalan-unit">
        <GambarKarung tempat="di-bak" />
        <img className="jalan-badan" src="/beranda/bentor-kosong.webp" alt="" decoding="async" />
      </div>
    </div>
  );
}
