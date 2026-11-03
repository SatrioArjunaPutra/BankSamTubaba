<?php

namespace App\Services;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Models\Armada;
use App\Models\Penjemputan;
use App\Models\User;
use App\Support\GambarAman;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * State machine penjemputan (lihat StatusPenjemputan::bolehMenjadi).
 * Setiap perubahan status mengunci baris agar dua aksi bersamaan tidak
 * melompati urutan. Transisi tidak sah → 422.
 */
class PenjemputanService
{
    /** Permintaan yang belum dijalankan bentor (diajukan/dijadwalkan) per warga per bank sampah. */
    public const MAKS_JEMPUT_MENUNGGU = 3;

    /**
     * Foto dibersihkan dari EXIF/GPS (GambarAman) sebelum disimpan.
     *
     * @param  array<string, mixed>  $data
     */
    public function ajukan(User $warga, array $data, ?UploadedFile $foto = null): Penjemputan
    {
        return DB::transaction(function () use ($warga, $data, $foto) {
            // Kunci baris warga agar dua pengajuan bersamaan tidak melewati batas
            User::whereKey($warga->id)->lockForUpdate()->first();

            $menunggu = Penjemputan::where('warga_id', $warga->id)
                ->where('bank_sampah_id', $data['bank_sampah_id'])
                ->whereIn('status', [StatusPenjemputan::Diajukan->value, StatusPenjemputan::Dijadwalkan->value])
                ->count();

            if ($menunggu >= self::MAKS_JEMPUT_MENUNGGU) {
                throw ValidationException::withMessages([
                    'bank_sampah_id' => 'Masih ada '.self::MAKS_JEMPUT_MENUNGGU.' permintaan jemput yang berjalan di bank sampah ini.',
                ]);
            }

            $penjemputan = new Penjemputan($data);
            $penjemputan->warga_id = $warga->id;
            $penjemputan->status = StatusPenjemputan::Diajukan;
            $penjemputan->foto_path = $foto ? GambarAman::simpan($foto, 'penjemputan') : null;

            try {
                $penjemputan->save();
            } catch (Throwable $e) {
                if ($penjemputan->foto_path) {
                    Storage::disk(config('filesystems.upload_disk'))->delete($penjemputan->foto_path);
                }

                throw $e;
            }

            return $penjemputan->refresh();
        });
    }

    public function jadwalkan(Penjemputan $penjemputan, int $armadaId, string $jadwalAt): Penjemputan
    {
        return DB::transaction(function () use ($penjemputan, $armadaId, $jadwalAt) {
            $p = $this->kunci($penjemputan, StatusPenjemputan::Dijadwalkan);

            $armada = Armada::whereKey($armadaId)->where('bank_sampah_id', $p->bank_sampah_id)->first();

            if (! $armada) {
                throw ValidationException::withMessages(['armada_id' => 'Armada tidak ditemukan di bank sampah ini.']);
            }

            if ($armada->status === StatusArmada::Nonaktif) {
                throw ValidationException::withMessages(['armada_id' => 'Armada sedang nonaktif.']);
            }

            $p->armada_id = $armada->id;
            $p->jadwal_at = $jadwalAt;
            $p->status = StatusPenjemputan::Dijadwalkan;
            $p->dijadwalkan_at = now();
            $p->save();

            return $p;
        });
    }

    public function tolak(Penjemputan $penjemputan, string $alasan): Penjemputan
    {
        return DB::transaction(function () use ($penjemputan, $alasan) {
            $p = $this->kunci($penjemputan, StatusPenjemputan::Ditolak);
            $p->status = StatusPenjemputan::Ditolak;
            $p->alasan_tolak = $alasan;
            $p->save();

            return $p;
        });
    }

    public function batal(Penjemputan $penjemputan): Penjemputan
    {
        return DB::transaction(function () use ($penjemputan) {
            $p = $this->kunci($penjemputan, StatusPenjemputan::Dibatalkan);
            $p->status = StatusPenjemputan::Dibatalkan;
            $p->save();

            return $p;
        });
    }

    /**
     * Bentor: menuju (armada jadi bertugas) atau diambil.
     */
    public function ubahOlehBentor(Penjemputan $penjemputan, StatusPenjemputan $tujuan): Penjemputan
    {
        return DB::transaction(function () use ($penjemputan, $tujuan) {
            $p = $this->kunci($penjemputan, $tujuan);
            $p->status = $tujuan;

            if ($tujuan === StatusPenjemputan::Diambil) {
                $p->diambil_at = now();
            }

            $p->save();

            if ($tujuan === StatusPenjemputan::Menuju) {
                Armada::whereKey($p->armada_id)->update(['status' => StatusArmada::Bertugas->value]);
            }

            return $p;
        });
    }

    /**
     * Dipanggil SetoranService di dalam transaksinya saat setoran hasil
     * jemput dicatat. Armada kembali siaga jika tidak ada tugas lain berjalan.
     */
    public function selesaikan(Penjemputan $penjemputan): Penjemputan
    {
        $p = $this->kunci($penjemputan, StatusPenjemputan::Selesai);
        $p->status = StatusPenjemputan::Selesai;
        $p->selesai_at = now();
        $p->save();

        $masihBertugas = Penjemputan::where('armada_id', $p->armada_id)
            ->whereIn('status', [StatusPenjemputan::Menuju->value, StatusPenjemputan::Diambil->value])
            ->exists();

        if (! $masihBertugas) {
            Armada::whereKey($p->armada_id)
                ->where('status', StatusArmada::Bertugas->value)
                ->update(['status' => StatusArmada::Siaga->value]);
        }

        return $p;
    }

    /**
     * Ambil ulang baris dengan kunci dan pastikan transisi sah.
     */
    private function kunci(Penjemputan $penjemputan, StatusPenjemputan $tujuan): Penjemputan
    {
        $p = Penjemputan::whereKey($penjemputan->getKey())->lockForUpdate()->firstOrFail();

        if (! $p->status->bisaMenjadi($tujuan)) {
            throw ValidationException::withMessages([
                'status' => "Penjemputan berstatus {$p->status->value} tidak bisa diubah menjadi {$tujuan->value}.",
            ]);
        }

        return $p;
    }
}
