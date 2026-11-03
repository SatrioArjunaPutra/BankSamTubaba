<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\CariTerdekatRequest;
use App\Http\Resources\BankSampahResource;
use App\Models\BankSampah;
use Illuminate\Http\Request;

/**
 * Data bank sampah untuk semua user login (hanya yang aktif).
 */
class BankSampahController extends Controller
{
    private const RADIUS_DEFAULT_KM = 10;
    private const RADIUS_PENDAFTARAN_KM = 50.0;

    private const MAKS_HASIL_PENDAFTARAN = 3;


    private const MAKS_HASIL_TERDEKAT = 50;

    public function index(Request $request)
    {
        $bankSampah = BankSampah::aktif()
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->string('kecamatan')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->string('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(nama) like ?', [$kata])->orWhereRaw('lower(tiyuh) like ?', [$kata]));
            })
            ->orderBy('kecamatan')
            ->orderBy('nama')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(BankSampahResource::collection($bankSampah), 'Daftar bank sampah berhasil dimuat.');
    }

    /**
     * Bank sampah dalam radius tertentu, urut dari yang terdekat. Kotak batas
     * disaring di database (pakai index), jarak tepat dihitung di PHP agar
     * sama di SQLite dan PostgreSQL.
     */
    public function terdekat(CariTerdekatRequest $request)
    {
        $hasil = $this->cariTerdekat(
            (float) $request->validated('lat'),
            (float) $request->validated('lng'),
            (float) ($request->validated('radius_km') ?? self::RADIUS_DEFAULT_KM),
            self::MAKS_HASIL_TERDEKAT,
        );

        return $this->daftar(BankSampahResource::collection($hasil), 'Bank sampah terdekat berhasil dimuat.');
    }

    /**
     * Tanpa login, agar calon warga melihat jaraknya saat mengisi formulir daftar.
     * Titik yang dikirim tidak disimpan.
     */
    public function terdekatPublik(CariTerdekatRequest $request)
    {
        $hasil = $this->cariTerdekat(
            (float) $request->validated('lat'),
            (float) $request->validated('lng'),
            self::RADIUS_PENDAFTARAN_KM,
            self::MAKS_HASIL_PENDAFTARAN,
        );

        return $this->daftar(BankSampahResource::collection($hasil), 'Bank sampah terdekat berhasil dimuat.');
    }

    /**
     * @return \Illuminate\Support\Collection<int, BankSampah>
     */
    private function cariTerdekat(float $lat, float $lng, float $radius, int $maks)
    {
        $dLat = $radius / 111.0;
        $dLng = $radius / (111.0 * max(cos(deg2rad($lat)), 0.01));

        return BankSampah::aktif()
            ->whereBetween('lat', [$lat - $dLat, $lat + $dLat])
            ->whereBetween('lng', [$lng - $dLng, $lng + $dLng])
            ->get()
            ->each(fn (BankSampah $b) => $b->jarak_km = round($this->jarakKm($lat, $lng, $b->lat, $b->lng), 2))
            ->filter(fn (BankSampah $b) => $b->jarak_km <= $radius)
            ->sortBy('jarak_km')
            ->take($maks)
            ->values();
    }

    public function show(BankSampah $bankSampah)
    {
        abort_unless($bankSampah->is_aktif, 404);

        $bankSampah->load(['harga' => fn ($q) => $q->whereHas('jenisSampah', fn ($q) => $q->aktif())->with('jenisSampah')]);

        return $this->sukses('Detail bank sampah berhasil dimuat.', new BankSampahResource($bankSampah));
    }

    // Rumus haversine, radius bumi 6371 km
    private function jarakKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return 6371 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
