<?php

namespace App\Http\Controllers\Api\Bs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\SimpanHargaRequest;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HargaController extends Controller
{
    // Semua jenis sampah aktif; harga_per_kg null jika belum diatur bank ini
    public function index(Request $request)
    {
        return $this->sukses('Daftar harga berhasil dimuat.', $this->daftarHarga($request->user()->bank_sampah_id));
    }

    // Harga baru hanya berlaku untuk setoran berikutnya (setoran lama menyimpan snapshot)
    public function update(SimpanHargaRequest $request)
    {
        $bankId = $request->user()->bank_sampah_id;

        DB::transaction(function () use ($request, $bankId) {
            foreach ($request->validated('harga') as $baris) {
                HargaSampah::updateOrCreate(
                    ['bank_sampah_id' => $bankId, 'jenis_sampah_id' => $baris['jenis_sampah_id']],
                    ['harga_per_kg' => $baris['harga_per_kg']],
                );
            }
        });

        return $this->sukses('Harga berhasil disimpan.', $this->daftarHarga($bankId));
    }

    /**
     * @return array<int, array{jenis_sampah_id: int, nama: string, satuan: string, harga_per_kg: float|null}>
     */
    private function daftarHarga(int $bankId): array
    {
        $harga = HargaSampah::where('bank_sampah_id', $bankId)->pluck('harga_per_kg', 'jenis_sampah_id');

        return JenisSampah::aktif()->orderBy('nama')->get()->map(fn (JenisSampah $jenis) => [
            'jenis_sampah_id' => $jenis->id,
            'nama' => $jenis->nama,
            'satuan' => $jenis->satuan,
            'harga_per_kg' => $harga->has($jenis->id) ? (float) $harga[$jenis->id] : null,
        ])->all();
    }
}
