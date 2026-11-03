<?php

namespace App\Http\Controllers\Api\Bs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\CatatPenjualanPengepulRequest;
use App\Http\Resources\PenjualanPengepulResource;
use App\Models\PenjualanPengepul;
use App\Support\Uang;
use Illuminate\Http\Request;

class PenjualanPengepulController extends Controller
{
    public function index(Request $request)
    {
        $penjualan = PenjualanPengepul::milik($request->user())
            ->with('jenisSampah')
            ->when($request->filled('dari'), fn ($q) => $q->whereDate('tanggal', '>=', $request->date('dari')))
            ->when($request->filled('sampai'), fn ($q) => $q->whereDate('tanggal', '<=', $request->date('sampai')))
            ->orderByDesc('tanggal')
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenjualanPengepulResource::collection($penjualan), 'Riwayat penjualan ke pengepul berhasil dimuat.');
    }

    public function store(CatatPenjualanPengepulRequest $request)
    {
        $data = $request->validated();

        $penjualan = PenjualanPengepul::create([
            'bank_sampah_id' => $request->user()->bank_sampah_id,
            'nama_pengepul' => $data['nama_pengepul'],
            'jenis_sampah_id' => $data['jenis_sampah_id'],
            'berat_kg' => $data['berat_kg'],
            'harga_per_kg' => $data['harga_per_kg'],
            'total' => Uang::dariSen(Uang::kali($data['berat_kg'], $data['harga_per_kg'])),
            'tanggal' => $data['tanggal'] ?? now()->toDateString(),
            'dicatat_oleh' => $request->user()->id,
        ]);

        return $this->sukses('Penjualan ke pengepul berhasil dicatat.', new PenjualanPengepulResource($penjualan->load('jenisSampah')), 201);
    }
}
