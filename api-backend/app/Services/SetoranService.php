<?php

namespace App\Services;

use App\Enums\StatusPenjemputan;
use App\Enums\TipeSetoran;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\Nasabah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use App\Support\Uang;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SetoranService
{
    public function __construct(private PenjemputanService $penjemputan) {}

    /**
     * Catat setoran di bank sampah milik pencatat (operator atau bentor).
     *
     * - jual: subtotal = berat × harga bank itu (disalin ke item sebagai
     *   snapshot), saldo nasabah bertambah total_nilai.
     * - donasi: item & berat tetap dicatat, nilai 0, saldo tidak berubah.
     *
     * Baris nasabah dikunci (lockForUpdate) agar setoran/penarikan bersamaan
     * tidak saling menimpa saldo.
     *
     * @param  array{warga_id: int, tipe: string, items: array<int, array{jenis_sampah_id: int, berat_kg: string|float}>, penjemputan_id?: int|null, catatan?: string|null}  $data
     */
    public function catat(User $pencatat, array $data): Setoran
    {
        $bankId = $pencatat->bank_sampah_id;
        $tipe = TipeSetoran::from($data['tipe']);
        $requestId = isset($data['request_id']) ? strtolower($data['request_id']) : null;
        $requestHash = $requestId ? $this->sidikPermintaan($data) : null;

        return DB::transaction(function () use ($pencatat, $data, $bankId, $tipe, $requestId, $requestHash) {
            if ($requestId !== null) {
                // Baris pencatat selalu ada, termasuk sebelum setoran pertama.
                // Kunci ini menserialisasi request bersamaan di PostgreSQL;
                // indeks unique menjadi pertahanan tambahan di database.
                User::whereKey($pencatat->id)->lockForUpdate()->firstOrFail();
                $lama = Setoran::denganBatal()->where('dicatat_oleh', $pencatat->id)
                    ->where('request_id', $requestId)->first();
                if ($lama) {
                    if ((int) $lama->bank_sampah_id !== $bankId || ! hash_equals($lama->request_hash, $requestHash)) {
                        throw ValidationException::withMessages([
                            'request_id' => 'Permintaan ini sudah diproses dengan rincian berbeda. Periksa riwayat setoran.',
                        ]);
                    }

                    return $lama;
                }
            }

            $items = $this->hitungItems($bankId, $tipe, $data['items']);
            $totalKgSen = array_sum(array_column($items, 'berat_sen'));
            $totalNilaiSen = array_sum(array_column($items, 'subtotal_sen'));
            $penjemputanId = $data['penjemputan_id'] ?? null;

            if ($penjemputanId) {
                $this->selesaikanPenjemputan((int) $penjemputanId, $bankId, (int) $data['warga_id']);
            }

            $setoran = Setoran::create([
                'bank_sampah_id' => $bankId,
                'warga_id' => $data['warga_id'],
                'tipe' => $tipe,
                'total_kg' => Uang::dariSen($totalKgSen),
                'total_nilai' => Uang::dariSen($totalNilaiSen),
                'penjemputan_id' => $penjemputanId,
                'dicatat_oleh' => $pencatat->id,
                'catatan' => $data['catatan'] ?? null,
                'request_id' => $requestId,
                'request_hash' => $requestHash,
            ]);

            $setoran->items()->createMany(array_map(fn (array $item) => [
                'jenis_sampah_id' => $item['jenis_sampah_id'],
                'berat_kg' => Uang::dariSen($item['berat_sen']),
                'harga_per_kg' => Uang::dariSen($item['harga_sen']),
                'subtotal' => Uang::dariSen($item['subtotal_sen']),
            ], $items));

            // Rekening nasabah dibuat otomatis pada setoran pertama (jual maupun donasi)
            if (! Nasabah::where('warga_id', $data['warga_id'])->where('bank_sampah_id', $bankId)->exists()) {
                $this->bukaRekening((int) $data['warga_id'], $bankId);
            }
            $nasabah = Nasabah::where('warga_id', $data['warga_id'])
                ->where('bank_sampah_id', $bankId)
                ->lockForUpdate()
                ->firstOrFail();

            if ($tipe === TipeSetoran::Jual && $totalNilaiSen > 0) {
                $nasabah->saldo = Uang::dariSen(Uang::keSen($nasabah->saldo) + $totalNilaiSen);
                $nasabah->save();
            }

            $setoran->saldo_setelah = $nasabah->saldo;
            $setoran->save();

            return $setoran->setRelation('nasabah', $nasabah);
        }, 3);
    }

    /**
     * Hasil timbang bentor di lokasi. Warga dan penjemputan selalu diambil dari
     * tugas, sehingga aplikasi tidak bisa mengarahkan saldo ke warga lain.
     *
     * @param  array{tipe: string, items: array<int, array{jenis_sampah_id: int, berat_kg: string|float}>, catatan?: string|null, request_id?: string|null}  $data
     */
    public function catatOlehBentor(User $bentor, Penjemputan $penjemputan, array $data): Setoran
    {
        return $this->catat($bentor, [
            ...$data,
            'warga_id' => $penjemputan->warga_id,
            'penjemputan_id' => $penjemputan->id,
        ]);
    }

    /**
     * Batalkan setoran yang salah timbang. Nilainya dikurangkan kembali dari saldo,
     * dan ditolak bila saldo sudah tidak cukup karena telah ditarik warga.
     * Penjemputan tetap selesai; operator mencatat ulang setoran yang benar.
     */
    public function batalkan(Setoran $setoran, User $operator, string $alasan): Setoran
    {
        return DB::transaction(function () use ($setoran, $operator, $alasan) {
            $baris = Setoran::denganBatal()->whereKey($setoran->id)->lockForUpdate()->firstOrFail();

            if ($baris->dibatalkan_at !== null) {
                throw ValidationException::withMessages(['alasan' => 'Setoran ini sudah dibatalkan.']);
            }

            $nilaiSen = Uang::keSen($baris->total_nilai);

            if ($baris->tipe === TipeSetoran::Jual && $nilaiSen > 0) {
                $nasabah = Nasabah::where('warga_id', $baris->warga_id)
                    ->where('bank_sampah_id', $baris->bank_sampah_id)
                    ->lockForUpdate()
                    ->first();
                $saldoSen = $nasabah ? Uang::keSen($nasabah->saldo) : 0;

                if ($nilaiSen > $saldoSen) {
                    throw ValidationException::withMessages([
                        'alasan' => 'Saldo warga tinggal '.Uang::rupiah($saldoSen / 100).', kurang dari nilai setoran ini. Selesaikan langsung dengan warga.',
                    ]);
                }

                $nasabah->saldo = Uang::dariSen($saldoSen - $nilaiSen);
                $nasabah->save();
            }

            $baris->forceFill([
                'dibatalkan_at' => now(),
                'dibatalkan_oleh' => $operator->id,
                'alasan_batal' => $alasan,
            ])->save();

            return $baris;
        }, 3);
    }

    /** Sidik rincian, bukan harga terkini; urutan item dan format angka tidak memengaruhi retry. */
    private function sidikPermintaan(array $data): string
    {
        $items = array_map(fn (array $i): array => [
            'jenis_sampah_id' => (int) $i['jenis_sampah_id'],
            'berat_sen' => Uang::keSen($i['berat_kg']),
        ], $data['items']);
        usort($items, fn (array $a, array $b): int => $a['jenis_sampah_id'] <=> $b['jenis_sampah_id']);

        return hash('sha256', json_encode([
            'warga_id' => (int) $data['warga_id'],
            'tipe' => $data['tipe'],
            'items' => $items,
            'penjemputan_id' => isset($data['penjemputan_id']) ? (int) $data['penjemputan_id'] : null,
            'catatan' => $data['catatan'] ?? null,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * Buka rekening nasabah; aman dipanggil walau rekeningnya sudah ada.
     *
     * Dua setoran pertama bersamaan bisa sama-sama lolos cek "belum ada" lalu
     * mencoba INSERT; yang kalah kena unique(warga_id, bank_sampah_id). INSERT
     * dijalankan di savepoint (transaksi bersarang) agar transaksi luar tetap
     * sah di PostgreSQL, lalu baris milik pemenang dipakai pemanggil.
     */
    public function bukaRekening(int $wargaId, int $bankId): void
    {
        try {
            DB::transaction(fn () => Nasabah::create(['warga_id' => $wargaId, 'bank_sampah_id' => $bankId]));
        } catch (UniqueConstraintViolationException) {
            // Sudah dibuat setoran lain yang berjalan bersamaan
        }
    }

    /**
     * @param  array<int, array{jenis_sampah_id: int, berat_kg: string|float}>  $items
     * @return array<int, array{jenis_sampah_id: int, berat_sen: int, harga_sen: int, subtotal_sen: int}>
     */
    private function hitungItems(int $bankId, TipeSetoran $tipe, array $items): array
    {
        $jenisIds = array_map(fn ($item) => (int) $item['jenis_sampah_id'], $items);
        $harga = HargaSampah::where('bank_sampah_id', $bankId)->whereIn('jenis_sampah_id', $jenisIds)
            ->pluck('harga_per_kg', 'jenis_sampah_id');

        $hasil = [];

        foreach ($items as $i => $item) {
            $jenisId = (int) $item['jenis_sampah_id'];
            $hargaSen = 0;

            if ($tipe === TipeSetoran::Jual) {
                if (! $harga->has($jenisId)) {
                    $nama = JenisSampah::whereKey($jenisId)->value('nama') ?? 'ini';
                    throw ValidationException::withMessages([
                        "items.{$i}.jenis_sampah_id" => "Harga {$nama} belum diatur di bank sampah ini.",
                    ]);
                }

                $hargaSen = Uang::keSen($harga[$jenisId]);
            }

            $hasil[] = [
                'jenis_sampah_id' => $jenisId,
                'berat_sen' => Uang::keSen($item['berat_kg']),
                'harga_sen' => $hargaSen,
                'subtotal_sen' => Uang::kali($item['berat_kg'], $hargaSen / 100),
            ];
        }

        return $hasil;
    }

    private function selesaikanPenjemputan(int $penjemputanId, int $bankId, int $wargaId): void
    {
        $penjemputan = Penjemputan::whereKey($penjemputanId)->lockForUpdate()->first();

        if (! $penjemputan || (int) $penjemputan->bank_sampah_id !== $bankId || (int) $penjemputan->warga_id !== $wargaId) {
            throw ValidationException::withMessages([
                'penjemputan_id' => 'Penjemputan tidak ditemukan untuk warga ini di bank sampah Anda.',
            ]);
        }

        if ($penjemputan->status !== StatusPenjemputan::Diambil) {
            throw ValidationException::withMessages([
                'penjemputan_id' => 'Setoran hanya bisa dicatat untuk penjemputan berstatus diambil.',
            ]);
        }

        $this->penjemputan->selesaikan($penjemputan);
    }
}
