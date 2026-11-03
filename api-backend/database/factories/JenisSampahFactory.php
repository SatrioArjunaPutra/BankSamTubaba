<?php

namespace Database\Factories;

use App\Models\JenisSampah;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<JenisSampah>
 */
class JenisSampahFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'nama' => 'Sampah '.fake()->unique()->word(),
            'satuan' => 'kg',
            'is_aktif' => true,
        ];
    }
}
