<?php

namespace Database\Factories;

use App\Models\BankSampah;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<BankSampah>
 */
class BankSampahFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'kode' => 'BS-UJI-'.fake()->unique()->numerify('####'),
            'nama' => 'Bank Sampah '.fake()->unique()->lastName(),
            'tiyuh' => fake()->city(),
            'kecamatan' => fake()->randomElement(['Tulang Bawang Tengah', 'Tumijajar', 'Gunung Agung']),
            'alamat' => fake()->streetAddress(),
            'lat' => fake()->randomFloat(6, -4.62, -4.15),
            'lng' => fake()->randomFloat(6, 105.0, 105.26),
            'koordinat_estimasi' => false,
            'no_hp_publik' => null,
            'is_aktif' => true,
        ];
    }

    public function nonaktif(): static
    {
        return $this->state(fn (array $attributes) => ['is_aktif' => false]);
    }
}
