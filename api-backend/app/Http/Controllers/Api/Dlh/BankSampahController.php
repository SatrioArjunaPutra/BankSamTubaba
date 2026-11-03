<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\BuatOperatorRequest;
use App\Http\Requests\Dlh\SimpanBankSampahRequest;
use App\Http\Resources\BankSampahResource;
use App\Http\Resources\UserResource;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\Nasabah;
use App\Models\Setoran;
use App\Models\User;
use Illuminate\Http\Request;

/**
 * Kelola bank sampah oleh DLH (termasuk yang nonaktif).
 */
class BankSampahController extends Controller
{
    public function index(Request $request)
    {
        $bankSampah = BankSampah::withCount('operator')
            ->selectSub(Setoran::selectRaw('coalesce(sum(total_kg), 0)')->whereColumn('bank_sampah_id', 'bank_sampah.id')->whereBetween('created_at', [now()->startOfMonth(), now()->endOfMonth()]), 'sampah_bulan_ini_kg')
            ->selectSub(Nasabah::selectRaw('count(*)')->whereColumn('bank_sampah_id', 'bank_sampah.id'), 'jumlah_nasabah')
            ->selectSub(Armada::selectRaw('count(*)')->whereColumn('bank_sampah_id', 'bank_sampah.id'), 'jumlah_bentor')
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->string('kecamatan')))
            ->when($request->has('is_aktif'), fn ($q) => $q->where('is_aktif', $request->boolean('is_aktif')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->string('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(nama) like ?', [$kata])
                    ->orWhereRaw('lower(tiyuh) like ?', [$kata])
                    ->orWhereRaw('lower(kode) like ?', [$kata]));
            })
            ->orderBy('kode')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(BankSampahResource::collection($bankSampah), 'Daftar bank sampah berhasil dimuat.');
    }

    public function store(SimpanBankSampahRequest $request)
    {
        $data = $request->validated();
        $data['kode'] ??= BankSampah::kodeBerikutnya();
        $data['koordinat_estimasi'] = false;

        $bankSampah = BankSampah::create($data);

        return $this->sukses('Bank sampah berhasil ditambahkan.', new BankSampahResource($bankSampah->refresh()), 201);
    }

    public function update(SimpanBankSampahRequest $request, BankSampah $bankSampah)
    {
        $data = $request->validated();

        // Koordinat yang diisi DLH dianggap sudah pasti, bukan estimasi
        if (array_key_exists('lat', $data)) {
            $data['koordinat_estimasi'] = false;
        }

        $bankSampah->update($data);

        return $this->sukses('Bank sampah berhasil diperbarui.', new BankSampahResource($bankSampah));
    }

    public function buatOperator(BuatOperatorRequest $request, BankSampah $bankSampah)
    {
        $operator = new User($request->safe()->only(['name', 'email', 'phone', 'password']));
        $operator->forceFill([
            'role' => UserRole::BankSampah,
            'bank_sampah_id' => $bankSampah->id,
            'is_aktif' => true,
        ])->save();

        return $this->sukses('Akun operator berhasil dibuat.', new UserResource($operator->load('bankSampah')), 201);
    }
}
