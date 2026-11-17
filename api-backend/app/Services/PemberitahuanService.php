<?php

namespace App\Services;

use App\Enums\StatusPenarikan;
use App\Enums\TipeSetoran;
use App\Enums\UserRole;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\Pemberitahuan;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\PrelovedItem;
use App\Models\Setoran;
use App\Models\User;
use App\Support\Uang;
use Carbon\CarbonInterface;

/**
 * Semua teks pemberitahuan ada di sini. Dipanggil dari service lain di dalam
 * transaksi kejadiannya; kejadian satu bank sampah hanya dikirim ke pengelola
 * bank itu.
 */
class PemberitahuanService
{
    public function jemputDiajukan(Penjemputan $jemput): void
    {
        $this->kePengelola($jemput->bank_sampah_id, 'jemput_baru', 'Permintaan jemput baru',
            "{$this->namaWarga($jemput->warga_id)} minta dijemput di {$jemput->alamat}.",
            ['penjemputan' => $jemput->id]);
    }

    public function jemputDijadwalkan(Penjemputan $jemput, Armada $armada): void
    {
        $waktu = $this->waktu($jemput->jadwal_at);
        $driver = $armada->driver;

        $this->kirim($jemput->warga_id, 'jemput_dijadwalkan', 'Penjemputan dijadwalkan',
            "Bentor {$driver?->name} ({$armada->plat_nomor}) akan menjemput pada {$waktu}.",
            ['penjemputan' => $jemput->id]);

        if ($driver) {
            $this->kirim($driver->id, 'tugas_baru', 'Tugas jemput baru',
                "{$this->namaWarga($jemput->warga_id)}, {$jemput->alamat}. Jadwal {$waktu}.",
                ['tugas' => $jemput->id]);
        }
    }

    public function jemputDitolak(Penjemputan $jemput): void
    {
        $this->kirim($jemput->warga_id, 'jemput_ditolak', 'Permintaan jemput ditolak',
            "Alasan: {$jemput->alasan_tolak}", ['penjemputan' => $jemput->id]);
    }

    public function bentorMenuju(Penjemputan $jemput): void
    {
        $this->kirim($jemput->warga_id, 'jemput_menuju', 'Bentor sedang menuju',
            'Siapkan sampahmu, bentor sedang dalam perjalanan ke lokasimu.', ['penjemputan' => $jemput->id]);
    }

    public function sampahDiambil(Penjemputan $jemput): void
    {
        $this->kirim($jemput->warga_id, 'jemput_diambil', 'Sampah sudah diambil',
            'Sampahmu sedang ditimbang. Hasilnya akan masuk ke riwayat setoran.', ['penjemputan' => $jemput->id]);
    }

    /**
     * @param  string  $saldoSetelah  saldo nasabah setelah setoran
     */
    public function setoranDicatat(Setoran $setoran, User $pencatat, string $saldoSetelah): void
    {
        $bank = $this->namaBank($setoran->bank_sampah_id);
        $berat = $this->kg($setoran->total_kg);

        if ($setoran->tipe === TipeSetoran::Donasi) {
            $this->kirim($setoran->warga_id, 'donasi_diterima', 'Terima kasih atas donasimu',
                "{$berat} sampah diterima {$bank}.", ['setoran' => $setoran->id]);
        } else {
            $this->kirim($setoran->warga_id, 'setoran_tercatat', 'Setoran tercatat',
                '+'.Uang::rupiah($setoran->total_nilai)." dari {$berat} sampah di {$bank}. Saldomu kini ".Uang::rupiah($saldoSetelah).'.',
                ['setoran' => $setoran->id]);
        }

        if ($pencatat->hasRole(UserRole::Bentor)) {
            $this->kePengelola($setoran->bank_sampah_id, 'timbang_bentor', 'Bentor selesai menimbang',
                "{$pencatat->name} mencatat {$berat} dari {$this->namaWarga($setoran->warga_id)}.",
                ['setoran' => $setoran->id]);
        }
    }

    public function setoranDibatalkan(Setoran $setoran): void
    {
        $nilai = (float) $setoran->total_nilai;
        $isi = "Setoran {$this->kg($setoran->total_kg)} dibatalkan petugas. Alasan: {$setoran->alasan_batal}";

        if ($setoran->tipe === TipeSetoran::Jual && $nilai > 0) {
            $isi .= ' Saldo dikurangi '.Uang::rupiah($nilai).'.';
        }

        $this->kirim($setoran->warga_id, 'setoran_dibatalkan', 'Setoran dibatalkan', $isi, ['setoran' => $setoran->id]);
    }

    public function penarikanDiajukan(Penarikan $penarikan): void
    {
        $this->kePengelola($penarikan->bank_sampah_id, 'penarikan_baru', 'Penarikan saldo baru',
            "{$this->namaWarga($penarikan->warga_id)} mengajukan tarik ".Uang::rupiah($penarikan->jumlah).'.',
            ['penarikan' => $penarikan->id]);
    }

    public function penarikanDiproses(Penarikan $penarikan): void
    {
        $jumlah = Uang::rupiah($penarikan->jumlah);

        if ($penarikan->status === StatusPenarikan::Disetujui) {
            $this->kirim($penarikan->warga_id, 'penarikan_disetujui', 'Penarikan disetujui',
                "{$jumlah} siap diambil di {$this->namaBank($penarikan->bank_sampah_id)}.", ['penarikan' => $penarikan->id]);

            return;
        }

        $this->kirim($penarikan->warga_id, 'penarikan_ditolak', 'Penarikan ditolak',
            "Penarikan {$jumlah} ditolak. ".($penarikan->catatan ?: 'Hubungi bank sampah untuk keterangan.'),
            ['penarikan' => $penarikan->id]);
    }

    public function barangDisembunyikan(PrelovedItem $barang): void
    {
        $this->kirim($barang->penjual_id, 'barang_disembunyikan', 'Barangmu disembunyikan',
            "\"{$barang->judul}\" disembunyikan DLH karena tidak sesuai aturan preloved.", ['preloved' => $barang->id]);
    }

    /**
     * @param  array<string, int>  $tujuan  halaman yang dibuka saat pemberitahuan diketuk
     */
    private function kirim(int $penerimaId, string $jenis, string $judul, string $isi, array $tujuan): void
    {
        Pemberitahuan::create([
            'user_id' => $penerimaId,
            'jenis' => $jenis,
            'judul' => $judul,
            'isi' => mb_strimwidth($isi, 0, 500, '…'),
            'tujuan' => $tujuan,
        ]);
    }

    /**
     * @param  array<string, int>  $tujuan
     */
    private function kePengelola(int $bankId, string $jenis, string $judul, string $isi, array $tujuan): void
    {
        $pengelola = User::where('role', UserRole::BankSampah->value)
            ->where('bank_sampah_id', $bankId)
            ->where('is_aktif', true)
            ->pluck('id');

        foreach ($pengelola as $id) {
            $this->kirim($id, $jenis, $judul, $isi, $tujuan);
        }
    }

    private function namaWarga(int $id): string
    {
        return User::whereKey($id)->value('name') ?? 'Warga';
    }

    private function namaBank(int $id): string
    {
        return BankSampah::whereKey($id)->value('nama') ?? 'bank sampah';
    }

    /** "4 kg", "2,5 kg" */
    private function kg(string|float $berat): string
    {
        return rtrim(rtrim(number_format((float) $berat, 2, ',', '.'), '0'), ',').' kg';
    }

    /** Jadwal dalam WIB, mis. "18 November 2026, 09.30 WIB" */
    private function waktu(?CarbonInterface $waktu): string
    {
        return $waktu === null
            ? 'waktu yang akan dikabarkan'
            : $waktu->copy()->timezone('Asia/Jakarta')->locale('id')->translatedFormat('j F Y, H.i').' WIB';
    }
}
