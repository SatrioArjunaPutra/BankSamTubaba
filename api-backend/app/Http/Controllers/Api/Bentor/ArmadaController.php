<?php

namespace App\Http\Controllers\Api\Bentor;

use App\Enums\StatusArmada;
use App\Http\Controllers\Api\Bs\ArmadaController as BsArmadaController;
use App\Http\Controllers\Controller;
use App\Http\Requests\Bentor\UbahStatusRequest;
use App\Http\Resources\ArmadaResource;
use Illuminate\Http\Request;

class ArmadaController extends Controller
{
    // Armada milik bentor (untuk menampilkan status siaga/bertugas/nonaktif)
    public function show(Request $request)
    {
        $armada = $request->user()->armada;
        abort_unless($armada, 404);

        return $this->sukses('Data armada berhasil dimuat.', new ArmadaResource($armada->loadCount('tugasAktif')));
    }

    // Bentor mengatur ketersediaan armadanya sendiri: siaga | nonaktif
    public function ubahStatus(UbahStatusRequest $request)
    {
        $armada = $request->user()->armada;
        abort_unless($armada, 404);

        $status = StatusArmada::from($request->validated('status'));

        if ($status === StatusArmada::Nonaktif) {
            BsArmadaController::pastikanTidakSedangMenjemput($armada);
        }

        $armada->update(['status' => $status]);

        return $this->sukses('Status armada diperbarui.', new ArmadaResource($armada));
    }
}
