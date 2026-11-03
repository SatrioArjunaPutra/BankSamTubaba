<?php

namespace App\Services;

use App\Enums\StatusPenarikan;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\User;
use App\Support\Uang;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Saldo baru DIKURANGI saat penarikan disetujui (bukan saat diajukan), dan
 * dicek ulang di dalam kunci baris nasabah. Maksimal 1 penarikan berstatus
 * diajukan per nasabah (warga + bank sampah).
 */
class PenarikanService
{
    public function ajukan(User $warga, int $bankId, string|float $jumlah, ?string $catatan): Penarikan
    {
        $jumlahSen = Uang::keSen($jumlah);

        return DB::transaction(function () use ($warga, $bankId, $jumlahSen, $catatan) {
            // Kunci rekening agar dua pengajuan bersamaan diproses berurutan
            $nasabah = Nasabah::where('warga_id', $warga->id)->where('bank_sampah_id', $bankId)->lockForUpdate()->first();
            $saldoSen = $nasabah ? Uang::keSen($nasabah->saldo) : 0;

            if ($jumlahSen > $saldoSen) {
                throw ValidationException::withMessages([
                    'jumlah' => 'Saldo tidak mencukupi. Saldo Anda di bank sampah ini '.Uang::rupiah($saldoSen / 100).'.',
                ]);
            }

            $masihDiajukan = Penarikan::where('warga_id', $warga->id)
                ->where('bank_sampah_id', $bankId)
                ->where('status', StatusPenarikan::Diajukan->value)
                ->exists();

            if ($masihDiajukan) {
                throw ValidationException::withMessages([
                    'jumlah' => 'Masih ada penarikan yang menunggu persetujuan di bank sampah ini.',
                ]);
            }

            $penarikan = new Penarikan([
                'warga_id' => $warga->id,
                'bank_sampah_id' => $bankId,
                'jumlah' => Uang::dariSen($jumlahSen),
                'catatan' => $catatan,
            ]);
            $penarikan->status = StatusPenarikan::Diajukan;
            $penarikan->save();

            return $penarikan->refresh();
        });
    }

    public function setujui(Penarikan $penarikan, User $operator, ?string $catatan): Penarikan
    {
        return DB::transaction(function () use ($penarikan, $operator, $catatan) {
            $p = $this->kunciDiajukan($penarikan);

            $nasabah = Nasabah::where('warga_id', $p->warga_id)
                ->where('bank_sampah_id', $p->bank_sampah_id)
                ->lockForUpdate()
                ->first();
            $saldoSen = $nasabah ? Uang::keSen($nasabah->saldo) : 0;
            $jumlahSen = Uang::keSen($p->jumlah);

            if ($jumlahSen > $saldoSen) {
                throw ValidationException::withMessages([
                    'aksi' => 'Saldo nasabah tidak mencukupi ('.Uang::rupiah($saldoSen / 100).'). Tolak penarikan ini.',
                ]);
            }

            $nasabah->saldo = Uang::dariSen($saldoSen - $jumlahSen);
            $nasabah->save();

            return $this->tandai($p, StatusPenarikan::Disetujui, $operator, $catatan);
        });
    }

    public function tolak(Penarikan $penarikan, User $operator, ?string $catatan): Penarikan
    {
        return DB::transaction(function () use ($penarikan, $operator, $catatan) {
            return $this->tandai($this->kunciDiajukan($penarikan), StatusPenarikan::Ditolak, $operator, $catatan);
        });
    }

    private function kunciDiajukan(Penarikan $penarikan): Penarikan
    {
        $p = Penarikan::whereKey($penarikan->getKey())->lockForUpdate()->firstOrFail();

        if ($p->status !== StatusPenarikan::Diajukan) {
            throw ValidationException::withMessages(['aksi' => "Penarikan ini sudah {$p->status->value}."]);
        }

        return $p;
    }

    private function tandai(Penarikan $p, StatusPenarikan $status, User $operator, ?string $catatan): Penarikan
    {
        $p->status = $status;
        $p->diproses_oleh = $operator->id;
        $p->catatan = $catatan ?? $p->catatan;
        $p->save();

        return $p;
    }
}
