<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\HapusAkunRequest;
use App\Services\AkunService;
use Illuminate\Http\JsonResponse;

class HapusAkunController extends Controller
{
    public function __invoke(HapusAkunRequest $request, AkunService $service): JsonResponse
    {
        $service->hapusWarga($request->user());

        return $this->sukses('Akun Anda sudah dihapus.');
    }
}
