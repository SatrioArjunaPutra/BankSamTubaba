<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Device extends Model
{
    protected $fillable = ['device_id', 'nama', 'is_active'];

    protected $hidden = ['api_key_hash'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'last_seen_at' => 'datetime',
        ];
    }

    /**
     * API key disimpan sebagai SHA-256 (bukan bcrypt) karena sensor mengirim
     * data berkala dan verifikasinya harus cepat.
     */
    public static function hashKey(string $plainKey): string
    {
        return hash('sha256', $plainKey);
    }

    /**
     * Buat API key baru dan kembalikan versi plaintext-nya (hanya sekali ini).
     */
    public function issueApiKey(): string
    {
        $plainKey = Str::random(48);
        $this->forceFill(['api_key_hash' => self::hashKey($plainKey)])->save();

        return $plainKey;
    }

    public function keyMatches(string $plainKey): bool
    {
        return hash_equals($this->api_key_hash, self::hashKey($plainKey));
    }
}
