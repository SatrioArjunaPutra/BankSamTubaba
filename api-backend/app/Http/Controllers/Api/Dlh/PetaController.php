<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\StatusPenjemputan;
use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\PetaRequest;
use App\Http\Resources\PetaBankSampahResource;
use App\Models\BankSampah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use Illuminate\Http\JsonResponse;

class PetaController extends Controller
{
    public function __invoke(PetaRequest $request): JsonResponse
    {
        [$dari, $sampai] = $request->rentang();
        $setoran = Setoran::whereBetween('created_at', [$dari, $sampai])
            ->groupBy('bank_sampah_id')->select('bank_sampah_id')
            ->selectRaw('sum(total_kg) as total_kg, sum(total_nilai) as nilai_setoran')
            ->selectRaw("sum(case when tipe = 'donasi' then total_kg else 0 end) as kg_donasi");
        $jemput = Penjemputan::whereIn('status', StatusPenjemputan::aktif())
            ->groupBy('bank_sampah_id')->selectRaw('bank_sampah_id, count(*) as jemput_aktif');
        $sumber = $request->validated('sumber') ?? 'registri';
        $banks = BankSampah::query()
            ->leftJoinSub($setoran, 'volume', fn ($join) => $join->on('bank_sampah.id', '=', 'volume.bank_sampah_id'))
            ->leftJoinSub($jemput, 'jemput', fn ($join) => $join->on('bank_sampah.id', '=', 'jemput.bank_sampah_id'))
            ->select('bank_sampah.*')
            ->selectRaw('coalesce(volume.total_kg, 0) as total_kg, coalesce(volume.nilai_setoran, 0) as nilai_setoran, coalesce(volume.kg_donasi, 0) as kg_donasi, coalesce(jemput.jemput_aktif, 0) as jemput_aktif')
            ->when($sumber !== 'semua', fn ($q) => $q->where('kode', $sumber === 'demo' ? 'like' : 'not like', 'BS-DEMO-%'))
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->validated('kecamatan')))
            ->when($request->filled('tiyuh'), fn ($q) => $q->where('tiyuh', $request->validated('tiyuh')))
            ->when($request->has('is_aktif'), fn ($q) => $q->where('is_aktif', $request->boolean('is_aktif')))
            ->when($request->filled('q'), fn ($q) => $q->where(fn ($s) => $s->whereLike('nama', '%'.$request->validated('q').'%')->orWhereLike('kode', '%'.$request->validated('q').'%')->orWhereLike('tiyuh', '%'.$request->validated('q').'%')))
            ->when($request->validated('koordinat') === 'estimasi', fn ($q) => $q->where('koordinat_estimasi', true)->whereNotNull('lat')->whereNotNull('lng'))
            ->when($request->validated('koordinat') === 'terisi', fn ($q) => $q->where('koordinat_estimasi', false)->whereNotNull('lat')->whereNotNull('lng'))
            ->when($request->validated('koordinat') === 'kosong', fn ($q) => $q->where(fn ($s) => $s->whereNull('lat')->orWhereNull('lng')))
            ->orderBy('kecamatan')->orderBy('tiyuh')->orderBy('nama')->get();
        $denganTitik = $banks->filter(fn (BankSampah $b): bool => $b->lat !== null && $b->lng !== null);
        $wilayah = $banks->groupBy('kecamatan')->map(fn ($kelompok, string $nama): array => [
            'nama' => $nama, 'jumlah' => $kelompok->count(),
            'tiyuh' => $kelompok->groupBy('tiyuh')->map(fn ($desa, string $namaDesa): array => ['nama' => $namaDesa, 'jumlah' => $desa->count()])->values(),
        ])->values();

        return $this->sukses('Peta bank sampah berhasil dimuat.', [
            'bank_sampah' => PetaBankSampahResource::collection($banks),
            'wilayah' => $wilayah,
            'ringkasan' => [
                'jumlah' => $banks->count(), 'dengan_koordinat' => $denganTitik->count(),
                'koordinat_terisi' => $denganTitik->where('koordinat_estimasi', false)->count(),
                'koordinat_estimasi' => $denganTitik->where('koordinat_estimasi', true)->count(),
                'tanpa_koordinat' => $banks->count() - $denganTitik->count(),
            ],
            'dari' => $dari->toIso8601String(), 'sampai' => $sampai->toIso8601String(),
        ]);
    }
}
