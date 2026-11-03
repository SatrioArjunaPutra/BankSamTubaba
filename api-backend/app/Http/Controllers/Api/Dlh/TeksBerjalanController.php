<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\SimpanTeksBerjalanRequest;
use App\Http\Resources\TeksBerjalanDlhResource;
use App\Models\TeksBerjalan;

class TeksBerjalanController extends Controller
{
    public function index()
    {
        $teks = TeksBerjalan::query()->urut()->paginate(20)->withQueryString();

        return $this->daftar(TeksBerjalanDlhResource::collection($teks), 'Daftar teks berjalan berhasil dimuat.');
    }

    public function store(SimpanTeksBerjalanRequest $request)
    {
        // Tanpa urutan, teks baru tampil paling akhir
        $teks = TeksBerjalan::create($request->validated() + ['urutan' => (int) TeksBerjalan::max('urutan') + 1]);

        return $this->sukses('Teks berjalan berhasil ditambahkan.', new TeksBerjalanDlhResource($teks->refresh()), 201);
    }

    public function update(SimpanTeksBerjalanRequest $request, TeksBerjalan $teksBerjalan)
    {
        $teksBerjalan->update($request->validated());

        return $this->sukses('Teks berjalan berhasil diubah.', new TeksBerjalanDlhResource($teksBerjalan->refresh()));
    }

    public function destroy(TeksBerjalan $teksBerjalan)
    {
        $teksBerjalan->delete();

        return $this->sukses('Teks berjalan berhasil dihapus.');
    }
}
