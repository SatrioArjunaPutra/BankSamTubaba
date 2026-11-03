<?php

namespace App\Http\Requests\Bentor;

use App\Http\Requests\Bs\CatatSetoranRequest;
use Illuminate\Support\Arr;

/**
 * Sama dengan setoran operator, tetapi warga dan penjemputan selalu diambil
 * dari tugas di server, bukan dari isian aplikasi.
 */
class CatatSetoranTugasRequest extends CatatSetoranRequest
{
    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return Arr::except(parent::rules(), ['warga_id', 'penjemputan_id']);
    }
}
