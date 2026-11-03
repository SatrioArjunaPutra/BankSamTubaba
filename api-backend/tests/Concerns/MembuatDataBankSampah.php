<?php

namespace Tests\Concerns;

use App\Enums\StatusArmada;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\Nasabah;
use App\Models\User;

trait MembuatDataBankSampah
{
    protected function jenis(string $nama): JenisSampah
    {
        return JenisSampah::firstOrCreate(['nama' => $nama], ['satuan' => 'kg', 'is_aktif' => true]);
    }

    /**
     * @param  array<string, int|float>  $harga  nama jenis => harga per kg
     */
    protected function bank(array $harga = []): BankSampah
    {
        $bank = BankSampah::factory()->create();

        foreach ($harga as $nama => $nilai) {
            HargaSampah::create([
                'bank_sampah_id' => $bank->id,
                'jenis_sampah_id' => $this->jenis($nama)->id,
                'harga_per_kg' => $nilai,
            ]);
        }

        return $bank;
    }

    protected function operator(BankSampah $bank): User
    {
        return User::factory()->bankSampah()->create(['bank_sampah_id' => $bank->id]);
    }

    protected function warga(): User
    {
        return User::factory()->warga()->create();
    }

    protected function armada(BankSampah $bank, StatusArmada $status = StatusArmada::Siaga): Armada
    {
        $driver = User::factory()->bentor()->create(['bank_sampah_id' => $bank->id]);

        return Armada::create([
            'bank_sampah_id' => $bank->id,
            'driver_id' => $driver->id,
            'plat_nomor' => 'BE '.random_int(1000, 9999).' XX',
            'kapasitas_kg' => 150,
            'status' => $status,
        ]);
    }

    protected function beriSaldo(User $warga, BankSampah $bank, float $saldo): Nasabah
    {
        $nasabah = Nasabah::firstOrCreate(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id]);
        $nasabah->forceFill(['saldo' => $saldo])->save();

        return $nasabah;
    }

    protected function saldo(User $warga, BankSampah $bank): float
    {
        return (float) Nasabah::where('warga_id', $warga->id)->where('bank_sampah_id', $bank->id)->value('saldo');
    }
}
