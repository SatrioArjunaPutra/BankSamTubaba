<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\SimpanJenisSampahRequest;
use App\Http\Resources\JenisSampahResource;
use App\Models\JenisSampah;

/**
 * Master jenis sampah. Tidak ada hapus: jenis yang sudah dipakai di setoran
 * cukup dinonaktifkan (is_aktif=false).
 */
class JenisSampahController extends Controller
{
    public function index()
    {
        return $this->daftar(
            JenisSampahResource::collection(JenisSampah::orderBy('nama')->get()),
            'Daftar jenis sampah berhasil dimuat.',
        );
    }

    public function store(SimpanJenisSampahRequest $request)
    {
        $jenisSampah = JenisSampah::create($request->validated());

        return $this->sukses('Jenis sampah berhasil ditambahkan.', new JenisSampahResource($jenisSampah->refresh()), 201);
    }

    public function update(SimpanJenisSampahRequest $request, JenisSampah $jenisSampah)
    {
        $jenisSampah->update($request->validated());

        return $this->sukses('Jenis sampah berhasil diperbarui.', new JenisSampahResource($jenisSampah));
    }
}
