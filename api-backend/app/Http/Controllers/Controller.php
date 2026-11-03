<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

abstract class Controller
{
    /**
     * Format sukses kontrak API: {"status":"sukses","pesan":"...","data":...}
     */
    protected function sukses(string $pesan, mixed $data = null, int $kode = 200): JsonResponse
    {
        $body = ['status' => 'sukses', 'pesan' => $pesan];

        if ($data !== null) {
            $body['data'] = $data;
        }

        return response()->json($body, $kode);
    }

    /**
     * Collection (termasuk hasil paginate) dengan status & pesan; pagination
     * otomatis menambahkan "meta" dan "links".
     */
    protected function daftar(AnonymousResourceCollection $collection, string $pesan): AnonymousResourceCollection
    {
        return $collection->additional(['status' => 'sukses', 'pesan' => $pesan]);
    }
}
