<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UbahPasswordRequest;
use App\Http\Requests\UpdateProfilRequest;
use App\Http\Resources\UserResource;
use Illuminate\Http\Request;

class ProfilController extends Controller
{
    public function show(Request $request)
    {
        return $this->sukses('Data pengguna berhasil dimuat.', new UserResource($request->user()->load('bankSampah')));
    }

    public function update(UpdateProfilRequest $request)
    {
        $user = $request->user();
        $user->update($request->validated());

        return $this->sukses('Profil berhasil diperbarui.', new UserResource($user->load('bankSampah')));
    }

    // Token lain dicabut agar perangkat yang mungkin dicuri ikut logout
    public function ubahPassword(UbahPasswordRequest $request)
    {
        $user = $request->user();
        $user->update(['password' => $request->validated('password')]);
        $user->tokens()->whereKeyNot($user->currentAccessToken()->getKey())->delete();

        return $this->sukses('Password berhasil diubah. Perangkat lain telah dikeluarkan.');
    }
}
