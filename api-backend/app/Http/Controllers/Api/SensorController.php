<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSensorRequest;
use App\Http\Resources\SensorDataResource;
use App\Models\SensorData;

class SensorController extends Controller
{
    // Untuk dashboard (GET, wajib login) - 10 data sensor terbaru
    public function index()
    {
        return SensorDataResource::collection(SensorData::latest()->latest('id')->take(10)->get())->additional([
            'status' => 'sukses',
            'pesan' => 'Data sensor berhasil dimuat.',
        ]);
    }

    // Untuk perangkat IoT (POST, wajib X-Device-Key)
    public function store(StoreSensorRequest $request)
    {
        $volume = (float) $request->validated('volume_percentage');

        $sensor = SensorData::create([
            'device_id' => $request->attributes->get('device')->device_id, // dari perangkat terautentikasi
            'volume_percentage' => $volume,
            'status' => $volume >= 80 ? 'penuh' : 'aman', // Jika >= 80% maka otomatis 'penuh'
        ]);

        return response()->json([
            'status' => 'sukses',
            'pesan' => 'Data sensor tercatat.',
            'data' => new SensorDataResource($sensor),
        ], 201);
    }
}
