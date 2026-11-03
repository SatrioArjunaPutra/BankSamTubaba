const fs = require('fs');
const path = require('path');

// CSV berisi data pribadi, disimpan di data-private/ (tidak di-commit)
const csvPath = path.join(__dirname, 'data-private', 'DAFTAR BANK SAMPAH TUBABA 2026.csv');
const rawText = fs.readFileSync(csvPath, 'utf-8');

// Split CSV lines taking into account multiline quotes if any
function parseCSV(text) {
  const lines = [];
  let currentLine = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === '"') {
      inQuotes = !inQuotes;
      currentLine += char;
    } else if ((char === '\n' || (char === '\r' && text[i+1] === '\n')) && !inQuotes) {
      if (char === '\r') i++; // skip \n
      lines.push(currentLine);
      currentLine = '';
    } else {
      currentLine += char;
    }
  }
  if (currentLine.trim()) lines.push(currentLine);
  return lines;
}

const rawLines = parseCSV(rawText);
console.log('Total parsed rows:', rawLines.length);

const headers = rawLines[0].split(';').map(h => h.trim());

// Kecamatan coordinates reference in Tubaba as fallback centers
const kecamatanCenters = {
  'GUNUNG AGUNG': { lat: -4.2650, lng: 105.0650 },
  'TULANG BAWANG TENGAH': { lat: -4.5850, lng: 105.1320 },
  'TULANG BAWANG UDIK': { lat: -4.6150, lng: 105.0450 },
  'BATU PUTIH': { lat: -4.3290, lng: 105.0120 },
  'LAMBU KIBANG': { lat: -4.3570, lng: 105.1480 },
  'TUMIJAJAR': { lat: -4.5120, lng: 105.1520 },
  'PAGAR DEWA': { lat: -4.3380, lng: 105.1930 },
  'WAY KENANGA': { lat: -4.1520, lng: 105.2510 },
  'GUNUNG TERANG': { lat: -4.2250, lng: 105.1220 },
};

function parseCoord(raw, kecName) {
  if (!raw) return null;
  let str = raw.trim();

  // Pattern 1: DMS
  const dmsMatch = str.match(/(\d+)[\*°\s](\d+)[\'\'\s](\d+(?:\.\d+)?)[^\d]*(?:S)?.*?(\d+)[\*°\s](\d+)[\'\'\s](\d+(?:\.\d+)?)/i);
  if (dmsMatch) {
    const lat = -(parseInt(dmsMatch[1], 10) + parseInt(dmsMatch[2], 10)/60 + parseFloat(dmsMatch[3])/3600);
    const lng = parseInt(dmsMatch[4], 10) + parseInt(dmsMatch[5], 10)/60 + parseFloat(dmsMatch[6])/3600;
    return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
  }

  // Replace commas inside numbers e.g. -4,5762732 -> -4.5762732
  const clean = str.replace(/(\d+),(\d+)/g, '$1.$2');

  // Pattern 2: Decimal -4.xxx, 105.xxx
  const decMatch = clean.match(/([-]?\s*4\.\d{3,})[^\d.-]+(10[45]\.\d{3,})/);
  if (decMatch) {
    let lat = parseFloat(decMatch[1].replace(/\s+/g, ''));
    if (lat > 0) lat = -lat;
    let lng = parseFloat(decMatch[2]);
    return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
  }

  // Pattern 3: Reversed 105.xxx, -4.xxx
  const revMatch = clean.match(/(10[45]\.\d{3,})[^\d.-]+([-]?\s*4\.\d{3,})/);
  if (revMatch) {
    let lng = parseFloat(revMatch[1]);
    let lat = parseFloat(revMatch[2].replace(/\s+/g, ''));
    if (lat > 0) lat = -lat;
    return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
  }

  // Pattern 4: squashed -4113410536489m -> -4.1134, 105.3648
  const squashMatch = str.match(/-4(\d{4})105(\d{4})/);
  if (squashMatch) {
    return { lat: Number('-4.' + squashMatch[1]), lng: Number('105.' + squashMatch[2]) };
  }

  // Fallback to Kecamatan center + slight jitter
  const normalizedKec = (kecName || '').trim().toUpperCase();
  if (kecamatanCenters[normalizedKec]) {
    const base = kecamatanCenters[normalizedKec];
    const jitterLat = (Math.random() - 0.5) * 0.02;
    const jitterLng = (Math.random() - 0.5) * 0.02;
    return {
      lat: Number((base.lat + jitterLat).toFixed(6)),
      lng: Number((base.lng + jitterLng).toFixed(6)),
      isEstimated: true
    };
  }

  return null;
}

const bankSampahList = [];

for (let i = 1; i < rawLines.length; i++) {
  const cols = rawLines[i].split(';').map(c => c.replace(/^"|"$/g, '').trim());
  if (!cols[1]) continue;

  const nama = cols[1];
  const tiyuh = cols[2] || '';
  const kecamatan = (cols[3] || '').toUpperCase();
  const tahun = cols[4] || '-';
  // cols[5] = no. HP ketua: sengaja tidak dibaca (data pribadi)
  const pengurus = cols[6] || '-';
  const nasabah = cols[7] || '-';
  const alamat = cols[8] || `${tiyuh}, Kec. ${kecamatan}`;
  const coordRaw = cols[9] || '';
  const kendaraan = cols[36] || cols[37] || 'Bentor / Motor Roda 3';
  const volumeKgBulan = cols[43] || '150 kg';
  const jenisSampah = cols[44] || 'Plastik, Kertas, Logam';
  const dijualKe = cols[45] || 'Pengepul Mitra';
  const omset = cols[46] || 'Rp 350.000';

  const coord = parseCoord(coordRaw, kecamatan);
  if (coord) {
    // Generate simulated sensor reading based on real data
    const volumePercentage = Math.floor(Math.random() * 65) + 25; // 25% - 90%
    const isPenuh = volumePercentage >= 80;

    bankSampahList.push({
      id: i,
      device_id: `BS-TUBABA-${String(i).padStart(2, '0')}`,
      nama: nama,
      tiyuh: tiyuh,
      kecamatan: kecamatan,
      lokasi: `${nama} - Tiyuh ${tiyuh}, Kec. ${kecamatan}`,
      alamat_lengkap: alamat,
      lat: coord.lat,
      lng: coord.lng,
      isEstimated: coord.isEstimated || false,
      tahun_terbentuk: tahun,
      jumlah_nasabah: nasabah,
      jumlah_pengurus: pengurus,
      volume_percentage: volumePercentage,
      berat_kg: Math.floor(volumePercentage * 0.65),
      kapasitas_maks_kg: 70,
      status: isPenuh ? 'penuh' : 'aman',
      terakhir_update: 'Baru saja',
      jenis_sampah: jenisSampah,
      volume_bulanan: volumeKgBulan,
      omset_bulanan: omset,
      dijual_ke: dijualKe,
      kendaraan_angkut: kendaraan,
    });
  }
}

console.log('Successfully processed Bank Sampah entries:', bankSampahList.length);
console.log('Sample entry:', JSON.stringify(bankSampahList[0], null, 2));

// Save to frontend/src/data/tubabaBankSampah.json
const outPath = path.join(__dirname, 'frontend', 'src', 'data', 'tubabaBankSampah.json');
fs.writeFileSync(outPath, JSON.stringify(bankSampahList, null, 2), 'utf-8');
console.log('Saved to', outPath);
