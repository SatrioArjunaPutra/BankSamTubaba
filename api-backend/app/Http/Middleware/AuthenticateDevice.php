<?php

namespace App\Http\Middleware;

use App\Models\Device;
use Closure;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

/**
 * Autentikasi perangkat IoT lewat header X-Device-Key + device_id di body.
 *
 * Percobaan GAGAL dibatasi per IP. Request yang berhasil tidak dihitung di
 * sini, supaya banyak sensor asli di balik satu IP (mis. CGNAT operator
 * seluler) tidak saling memblokir; kuota per perangkat diatur limiter 'sensor'.
 */
class AuthenticateDevice
{
    public const MAX_FAILED_PER_MINUTE = 120;

    public function handle(Request $request, Closure $next): Response
    {
        $failKey = 'sensor-gagal|'.$request->ip();

        if (RateLimiter::tooManyAttempts($failKey, self::MAX_FAILED_PER_MINUTE)) {
            throw new ThrottleRequestsException(headers: ['Retry-After' => RateLimiter::availableIn($failKey)]);
        }

        $plainKey = $request->header('X-Device-Key');
        $deviceId = $request->input('device_id');

        $device = is_string($plainKey) && is_string($deviceId)
            ? Device::where('device_id', $deviceId)->where('is_active', true)->first()
            : null;

        if (! $device || ! $device->keyMatches($plainKey)) {
            RateLimiter::hit($failKey, 60);

            return response()->json([
                'status' => 'gagal',
                'pesan' => 'Perangkat tidak dikenali atau API key salah.',
            ], 401);
        }

        $device->forceFill(['last_seen_at' => now()])->save();
        $request->attributes->set('device', $device);

        return $next($request);
    }
}
