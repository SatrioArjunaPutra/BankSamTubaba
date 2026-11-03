<?php

use App\Http\Middleware\AuthenticateDevice;
use App\Http\Middleware\EnsureAkunAktif;
use App\Http\Middleware\EnsureUserHasRole;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'akun.aktif' => EnsureAkunAktif::class,
            'role' => EnsureUserHasRole::class,
            'device.auth' => AuthenticateDevice::class,
        ]);

        // Laravel mengurutkan middleware berdasarkan daftar prioritas, dan
        // ThrottleRequests ada di daftar itu. Tanpa baris ini 'throttle:sensor'
        // selalu jalan sebelum 'device.auth' apa pun urutan di route, sehingga
        // kuota dihitung sebelum perangkat terautentikasi.
        $middleware->prependToPriorityList(before: ThrottleRequests::class, prepend: AuthenticateDevice::class);

        // Cek akun & role sebelum route model binding, agar role yang salah
        // selalu dapat 403 dan tidak bisa menebak ID mana yang ada (404).
        $middleware->prependToPriorityList(before: SubstituteBindings::class, prepend: EnsureAkunAktif::class);
        $middleware->prependToPriorityList(before: SubstituteBindings::class, prepend: EnsureUserHasRole::class);

        // Tidak ada halaman login web; tamu dijawab 401 JSON, bukan redirect
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $isApi = fn (Request $request) => $request->is('api/*') || $request->expectsJson();

        $exceptions->shouldRenderJsonWhen($isApi);

        // Seragamkan format error API: { status: "gagal", pesan: "..." }
        $exceptions->render(function (AuthenticationException $e, Request $request) use ($isApi) {
            if ($isApi($request)) {
                return response()->json([
                    'status' => 'gagal',
                    'pesan' => 'Sesi tidak valid atau sudah berakhir. Silakan login kembali.',
                ], 401);
            }
        });

        $exceptions->render(function (ValidationException $e, Request $request) use ($isApi) {
            if ($isApi($request)) {
                return response()->json([
                    'status' => 'gagal',
                    'pesan' => 'Data yang dikirim tidak valid.',
                    'errors' => $e->errors(),
                ], $e->status);
            }
        });

        $exceptions->render(function (ThrottleRequestsException $e, Request $request) use ($isApi) {
            if ($isApi($request)) {
                $retryAfter = $e->getHeaders()['Retry-After'] ?? 60;

                return response()->json([
                    'status' => 'gagal',
                    'pesan' => "Terlalu banyak percobaan. Silakan coba lagi dalam {$retryAfter} detik.",
                ], 429, $e->getHeaders());
            }
        });

        $exceptions->render(function (HttpExceptionInterface $e, Request $request) use ($isApi) {
            if ($isApi($request)) {
                $pesan = match ($e->getStatusCode()) {
                    403 => 'Anda tidak memiliki akses ke fitur ini.',
                    404 => 'Data tidak ditemukan.',
                    405 => 'Metode request tidak diizinkan.',
                    default => $e->getMessage() ?: 'Terjadi kesalahan pada permintaan.',
                };

                return response()->json([
                    'status' => 'gagal',
                    'pesan' => $pesan,
                ], $e->getStatusCode(), $e->getHeaders());
            }
        });
    })->create();
