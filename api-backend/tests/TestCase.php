<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Route;

abstract class TestCase extends BaseTestCase
{
    /**
     * Route /api/sensor dibaca saat aplikasi boot, jadi mengubah config saja
     * tidak cukup: routes/api.php perlu dimuat ulang setelah saklar dinyalakan.
     */
    protected function aktifkanFiturIot(): void
    {
        config(['banksampah.fitur_iot' => true]);

        Route::middleware('api')->prefix('api')->group(base_path('routes/api.php'));

        $routes = $this->app['router']->getRoutes();
        $routes->refreshNameLookups();
        $routes->refreshActionLookups();
    }
}
