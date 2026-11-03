<?php

namespace App\Http\Requests\Bs;

use App\Enums\TipeSetoran;
use App\Enums\UserRole;
use App\Models\Setoran;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CatatSetoranRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('request_id'))) {
            $this->merge(['request_id' => strtolower($this->input('request_id'))]);
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        // Retry transaksi yang sudah tersimpan tidak bergantung pada status
        // warga/jenis saat ini. Hash tetap diperiksa service sebelum replay.
        $ulang = is_string($this->input('request_id')) && Str::isUuid($this->input('request_id')) && Setoran::denganBatal()->where('dicatat_oleh', $this->user()->id)
            ->where('bank_sampah_id', $this->user()->bank_sampah_id)
            ->where('request_id', $this->input('request_id'))->exists();

        return [
            'request_id' => ['nullable', 'uuid'],
            'warga_id' => [
                'required',
                'integer',
                ...($ulang ? [] : [Rule::exists('users', 'id')->where('role', UserRole::Warga->value)->where('is_aktif', true)]),
            ],
            'tipe' => ['required', Rule::enum(TipeSetoran::class)],
            'items' => ['required', 'array', 'min:1', 'max:20'],
            'items.*.jenis_sampah_id' => ['required', 'integer', 'distinct', ...($ulang ? [] : [Rule::exists('jenis_sampah', 'id')->where('is_aktif', true)])],
            // decimal:0,2 mengikuti kolom decimal(8,2) agar berat & nilai tidak selisih karena pembulatan DB
            'items.*.berat_kg' => ['required', 'numeric', 'gt:0', 'max:1000', 'decimal:0,2'],
            'penjemputan_id' => ['nullable', 'integer'],
            'catatan' => ['nullable', 'string', 'max:500'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return [
            'warga_id' => 'warga',
            'items' => 'daftar sampah',
            'items.*.jenis_sampah_id' => 'jenis sampah',
            'items.*.berat_kg' => 'berat',
            'penjemputan_id' => 'penjemputan',
        ];
    }
}
