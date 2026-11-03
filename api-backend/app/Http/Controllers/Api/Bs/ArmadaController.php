<?php

namespace App\Http\Controllers\Api\Bs;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\BuatBentorRequest;
use App\Http\Requests\Bs\SimpanArmadaRequest;
use App\Http\Requests\UbahStatusAkunRequest;
use App\Http\Resources\ArmadaResource;
use App\Http\Resources\UserResource;
use App\Models\Armada;
use App\Models\User;
use App\Services\AkunService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class ArmadaController extends Controller
{
    public function index(Request $request)
    {
        $armada = Armada::milik($request->user())
            ->with('driver')
            ->withCount('tugasAktif')
            ->orderBy('plat_nomor')
            ->get();

        // Bentor bank ini yang belum punya armada, untuk pilihan saat tambah armada
        $tanpaArmada = User::where('role', UserRole::Bentor->value)
            ->where('bank_sampah_id', $request->user()->bank_sampah_id)
            ->whereDoesntHave('armada')
            ->orderBy('name')
            ->get();

        return $this->sukses('Daftar armada berhasil dimuat.', [
            'armada' => ArmadaResource::collection($armada),
            'bentor_tanpa_armada' => UserResource::collection($tanpaArmada),
        ]);
    }

    public function store(SimpanArmadaRequest $request)
    {
        $bankId = $request->user()->bank_sampah_id;
        $driver = User::whereKey($request->integer('driver_id'))
            ->where('role', UserRole::Bentor->value)
            ->where('bank_sampah_id', $bankId)
            ->first();

        if (! $driver) {
            throw ValidationException::withMessages(['driver_id' => 'Driver harus akun bentor di bank sampah ini.']);
        }

        $armada = Armada::create($request->validated() + ['bank_sampah_id' => $bankId]);

        return $this->sukses('Armada berhasil ditambahkan.', new ArmadaResource($armada->refresh()->load('driver')), 201);
    }

    public function update(SimpanArmadaRequest $request, Armada $armada)
    {
        Gate::authorize('kelola', $armada);

        if ($request->validated('status') === StatusArmada::Nonaktif->value) {
            $this->pastikanTidakSedangMenjemput($armada);
        }

        $armada->update($request->validated());

        return $this->sukses('Armada berhasil diperbarui.', new ArmadaResource($armada->load('driver')));
    }

    // Buat akun bentor di bank ini; armada ikut dibuat jika plat_nomor diisi
    public function buatBentor(BuatBentorRequest $request)
    {
        $bankId = $request->user()->bank_sampah_id;

        [$bentor, $armada] = DB::transaction(function () use ($request, $bankId) {
            $bentor = new User($request->safe()->only(['name', 'email', 'phone', 'password']));
            $bentor->forceFill(['role' => UserRole::Bentor, 'bank_sampah_id' => $bankId, 'is_aktif' => true])->save();

            $armada = $request->filled('plat_nomor')
                ? Armada::create([
                    'bank_sampah_id' => $bankId,
                    'driver_id' => $bentor->id,
                    'plat_nomor' => $request->validated('plat_nomor'),
                    'kapasitas_kg' => $request->validated('kapasitas_kg'),
                    'status' => StatusArmada::Siaga,
                ])
                : null;

            return [$bentor, $armada];
        });

        return $this->sukses('Akun bentor berhasil dibuat.', [
            'bentor' => new UserResource($bentor),
            'armada' => $armada ? new ArmadaResource($armada->refresh()) : null,
        ], 201);
    }

    // Aktif/nonaktifkan akun bentor di bank ini (nonaktif = semua token dicabut)
    public function ubahStatusBentor(UbahStatusAkunRequest $request, User $user, AkunService $service)
    {
        Gate::authorize('kelolaBentor', $user);

        $user = $service->ubahStatus($user, $request->boolean('is_aktif'));

        return $this->sukses(
            $user->is_aktif ? 'Akun bentor diaktifkan.' : 'Akun bentor dinonaktifkan dan dikeluarkan dari semua perangkat.',
            new UserResource($user),
        );
    }

    public static function pastikanTidakSedangMenjemput(Armada $armada): void
    {
        $sedangJalan = $armada->tugasAktif()
            ->whereIn('status', [StatusPenjemputan::Menuju->value, StatusPenjemputan::Diambil->value])
            ->exists();

        if ($sedangJalan) {
            throw ValidationException::withMessages(['status' => 'Armada sedang menjalankan penjemputan dan tidak bisa dinonaktifkan.']);
        }
    }
}
