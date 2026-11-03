<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Hash bcrypt (cost 12) dari string acak, dicek saat email tidak terdaftar
     * agar waktu respons sama dan email terdaftar tidak bisa ditebak dari durasinya.
     */
    private const DUMMY_HASH = '$2y$12$BBC68x0PBV8n1BJ0BtY60.p4RE1dfiRY35iq/5J9yEVAG01aJTcfi';

    // Daftar mandiri hanya untuk warga
    public function register(RegisterRequest $request)
    {
        $user = new User($request->safe()->only(['name', 'email', 'phone', 'password', 'alamat', 'lat', 'lng']));
        $user->forceFill(['role' => UserRole::Warga, 'is_aktif' => true])->save();

        return $this->sukses('Pendaftaran berhasil.', $this->dataLogin($user, $request->validated('device_name')), 201);
    }

    public function login(LoginRequest $request)
    {
        $user = User::where('email', $request->validated('email'))->first();
        $passwordValid = Hash::check($request->validated('password'), $user?->password ?? self::DUMMY_HASH);

        if (! $user || ! $passwordValid) {
            return response()->json([
                'status' => 'gagal',
                'pesan' => 'Email atau password salah.',
            ], 401);
        }

        if (! $user->is_aktif) {
            return response()->json([
                'status' => 'gagal',
                'pesan' => 'Akun Anda dinonaktifkan. Hubungi pengelola.',
            ], 403);
        }

        // Dicek setelah password valid agar peran akun tidak bisa ditebak dari email saja
        $peran = $request->validated('role');

        if ($peran !== null && $peran !== $user->role->value) {
            return response()->json([
                'status' => 'gagal',
                'pesan' => $this->pesanPeranTidakCocok($user->role),
            ], 403);
        }

        return $this->sukses('Login berhasil.', $this->dataLogin($user, $request->validated('device_name')));
    }

    // Hapus hanya token yang sedang dipakai (perangkat lain tetap login)
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return $this->sukses('Logout berhasil.');
    }

    private function pesanPeranTidakCocok(UserRole $role): string
    {
        return match ($role) {
            UserRole::Dlh => 'Akun DLH hanya bisa masuk lewat web dashboard.',
            UserRole::BankSampah => "Akun ini terdaftar sebagai Bank sampah. Pilih 'Bank sampah' lalu coba lagi.",
            UserRole::Bentor => "Akun ini terdaftar sebagai Bentor. Pilih 'Bentor' lalu coba lagi.",
            UserRole::Warga => "Akun ini terdaftar sebagai Warga. Pilih 'Warga' lalu coba lagi.",
        };
    }

    /**
     * @return array<string, mixed>
     */
    private function dataLogin(User $user, ?string $deviceName): array
    {
        $expiration = config('sanctum.expiration');
        $expiresAt = $expiration ? now()->addMinutes($expiration) : null;

        $token = $user->createToken($deviceName ?: 'web', ['*'], $expiresAt);

        return [
            'user' => new UserResource($user->load('bankSampah')),
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expiresAt?->toIso8601String(),
        ];
    }
}
