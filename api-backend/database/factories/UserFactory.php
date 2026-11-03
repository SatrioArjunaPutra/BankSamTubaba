<?php

namespace Database\Factories;

use App\Enums\UserRole;
use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'role' => UserRole::Warga,
            'is_aktif' => true,
        ];
    }

    public function dlh(): static
    {
        return $this->state(fn (array $attributes) => ['role' => UserRole::Dlh]);
    }

    public function bankSampah(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::BankSampah,
            'bank_sampah_id' => $attributes['bank_sampah_id'] ?? BankSampah::factory(),
        ]);
    }

    public function bentor(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::Bentor,
            'bank_sampah_id' => $attributes['bank_sampah_id'] ?? BankSampah::factory(),
        ]);
    }

    public function warga(): static
    {
        return $this->state(fn (array $attributes) => ['role' => UserRole::Warga]);
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
