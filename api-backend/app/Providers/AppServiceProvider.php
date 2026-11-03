<?php

namespace App\Providers;

use App\Support\GambarAman;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Gagal keras jika GD tidak ada: foto tidak boleh tersimpan bersama EXIF/GPS
        GambarAman::pastikanTersedia();

        // Login: 5 percobaan/menit per email + IP, dan 20/menit per IP
        // (mencegah password spraying ke banyak email dari satu IP)
        RateLimiter::for('login', function (Request $request) {
            $email = $request->input('email');

            return [
                Limit::perMinute(5)->by('login|'.Str::lower(is_string($email) ? $email : '').'|'.$request->ip()),
                Limit::perMinute(20)->by('login-ip|'.$request->ip()),
            ];
        });

        // Daftar akun: 5/menit dan 20/jam per IP (mencegah pembuatan akun massal)
        RateLimiter::for('register', fn (Request $request) => [
            Limit::perMinute(5)->by('register|'.$request->ip()),
            Limit::perHour(20)->by('register-jam|'.$request->ip()),
        ]);

        // Kirim pesan chat: 30/menit per user
        RateLimiter::for('pesan', fn (Request $request) => Limit::perMinute(30)->by('pesan|'.$request->user()?->id));

        // Batas spam per user (warga/operator)
        RateLimiter::for('jemput', fn (Request $request) => Limit::perHour(10)->by('jemput|'.$request->user()?->id));
        RateLimiter::for('preloved-pasang', fn (Request $request) => Limit::perDay(20)->by('preloved-pasang|'.$request->user()?->id));
        RateLimiter::for('preloved-lapor', fn (Request $request) => Limit::perDay(20)->by('preloved-lapor|'.$request->user()?->id));
        RateLimiter::for('cari-nasabah', fn (Request $request) => Limit::perMinute(60)->by('cari-nasabah|'.$request->user()?->id));

        // Etalase preloved, statistik, berita, dan teks berjalan beranda tanpa login: 60/menit per IP
        RateLimiter::for('etalase', fn (Request $request) => Limit::perMinute(60)->by('etalase|'.$request->ip()));

        // Kuota kiriman per perangkat. Dipasang SETELAH 'device.auth' sehingga
        // kuncinya perangkat yang sudah terautentikasi, bukan device_id dari body.
        RateLimiter::for('sensor', function (Request $request) {
            $device = $request->attributes->get('device');

            return Limit::perMinute(60)->by('sensor|'.($device?->device_id ?? $request->ip()));
        });
    }
}
