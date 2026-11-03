<?php

namespace App\Http\Requests\Bs;

use Illuminate\Foundation\Http\FormRequest;

class CatatPenjualanPengepulRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'nama_pengepul' => ['required', 'string', 'max:150'],
            'jenis_sampah_id' => ['required', 'integer', 'exists:jenis_sampah,id'],
            'berat_kg' => ['required', 'numeric', 'gt:0', 'max:100000', 'decimal:0,2'],
            'harga_per_kg' => ['required', 'numeric', 'gte:0', 'max:10000000', 'decimal:0,2'],
            'tanggal' => ['nullable', 'date', 'before_or_equal:today'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return [
            'nama_pengepul' => 'nama pengepul',
            'jenis_sampah_id' => 'jenis sampah',
            'berat_kg' => 'berat',
            'harga_per_kg' => 'harga per kg',
            'tanggal' => 'tanggal',
        ];
    }
}
