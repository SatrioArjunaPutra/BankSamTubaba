<?php

namespace App\Http\Controllers\Api\Bs;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\WargaNasabahResource;
use App\Models\Nasabah;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

class NasabahController extends Controller
{
    /**
     * Cari warga untuk dicatat setorannya.
     *
     * - Nasabah bank ini: cocok sebagian nama/HP/email (tanpa q: semua nasabah).
     * - Warga lain: hanya jika nomor HP atau email dicocokkan PERSIS, agar
     *   operator tidak bisa menelusuri data pribadi seluruh warga Tubaba.
     */
    public function index(Request $request)
    {
        $request->validate(['q' => ['nullable', 'string', 'min:3', 'max:100']], [], ['q' => 'kata kunci']);

        $bankId = $request->user()->bank_sampah_id;
        $q = trim((string) $request->input('q'));
        $saldo = Nasabah::select('saldo')->whereColumn('warga_id', 'users.id')->where('bank_sampah_id', $bankId);
        $nasabahBankIni = fn (Builder $query) => $query->whereExists(
            fn ($sub) => $sub->from('nasabah')->whereColumn('warga_id', 'users.id')->where('bank_sampah_id', $bankId)
        );

        $warga = User::where('role', UserRole::Warga->value)
            ->where('is_aktif', true)
            ->select(['id', 'name', 'email', 'phone', 'alamat'])
            ->addSelect(['saldo_di_bank' => $saldo])
            ->when($q === '', $nasabahBankIni)
            ->when($q !== '', function (Builder $query) use ($q, $nasabahBankIni) {
                $kata = '%'.mb_strtolower($q).'%';
                $query->where(function (Builder $query) use ($q, $kata, $nasabahBankIni) {
                    $query->where(fn (Builder $query) => $nasabahBankIni($query)->where(fn (Builder $query) => $query
                        ->whereRaw('lower(name) like ?', [$kata])
                        ->orWhere('phone', 'like', $kata)
                        ->orWhereRaw('lower(email) like ?', [$kata])))
                        ->orWhereRaw('lower(email) = ?', [mb_strtolower($q)])
                        ->orWhereIn('phone', self::variasiNomorHp($q));
                });
            })
            ->orderBy('name')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(WargaNasabahResource::collection($warga), 'Daftar warga berhasil dimuat.');
    }

    /**
     * Bentuk penulisan nomor yang sama: 0812..., 62812..., +62812...
     *
     * @return array<int, string>
     */
    private static function variasiNomorHp(string $q): array
    {
        $angka = preg_replace('/\D/', '', $q);

        $lokal = match (true) {
            str_starts_with($angka, '62') => '0'.substr($angka, 2),
            str_starts_with($angka, '0') => $angka,
            default => null,
        };

        if ($lokal === null || strlen($lokal) < 9) {
            return [];
        }

        $tanpaNol = substr($lokal, 1);

        return [$lokal, '62'.$tanpaNol, '+62'.$tanpaNol];
    }
}
