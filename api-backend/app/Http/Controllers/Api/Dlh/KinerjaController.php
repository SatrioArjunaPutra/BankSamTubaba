<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\KinerjaRequest;
use App\Models\BankSampah;
use App\Services\KinerjaService;
use Carbon\CarbonImmutable;
use Illuminate\Validation\ValidationException;

class KinerjaController extends Controller
{
    private const MAKS_TITIK_TREN = 400;

    public function __construct(private KinerjaService $service) {}

    // Ringkasan se-Tubaba; tanpa periode/dari = sepanjang waktu
    public function ringkasan(KinerjaRequest $request)
    {
        [$dari, $sampai] = $request->filled('periode') || $request->filled('dari')
            ? $request->rentang()
            : [CarbonImmutable::create(2000), CarbonImmutable::now()];

        return $this->sukses('Ringkasan berhasil dimuat.', $this->service->ringkasan($dari, $sampai) + [
            'dari' => $dari->toIso8601String(),
            'sampai' => $sampai->toIso8601String(),
        ]);
    }

    public function index(KinerjaRequest $request)
    {
        [$dari, $sampai] = $request->rentang();

        return $this->sukses('Kinerja bank sampah berhasil dimuat.', [
            'dari' => $dari->toIso8601String(),
            'sampai' => $sampai->toIso8601String(),
            'daftar' => $this->service->perBankSampah($dari, $sampai),
        ]);
    }

    // ?interval=harian|bulanan (default harian untuk rentang ≤ 62 hari, selain itu bulanan)
    public function tren(KinerjaRequest $request, BankSampah $bankSampah)
    {
        [$dari, $sampai] = $request->rentang();
        $interval = $request->validated('interval') ?? ($dari->diffInDays($sampai) <= 62 ? 'harian' : 'bulanan');

        if ($interval === 'harian' && $dari->diffInDays($sampai) > self::MAKS_TITIK_TREN) {
            throw ValidationException::withMessages(['interval' => 'Rentang terlalu panjang untuk interval harian. Gunakan bulanan.']);
        }

        return $this->sukses('Tren kinerja berhasil dimuat.', [
            'bank_sampah' => ['id' => $bankSampah->id, 'kode' => $bankSampah->kode, 'nama' => $bankSampah->nama],
            'interval' => $interval,
            'dari' => $dari->toIso8601String(),
            'sampai' => $sampai->toIso8601String(),
            'data' => $this->service->tren($bankSampah, $dari, $sampai, $interval),
        ]);
    }
}
