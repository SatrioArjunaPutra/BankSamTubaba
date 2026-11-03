<?php

namespace App\Http\Requests\Dlh;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Rentang waktu laporan. Prioritas: dari/sampai jika diisi, selain itu
 * periode (hari|minggu|bulan|tahun) yang berjalan. Default: bulan ini.
 */
class KinerjaRequest extends FormRequest
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
            'periode' => ['nullable', 'in:hari,minggu,bulan,tahun'],
            'dari' => ['nullable', 'date', 'required_with:sampai'],
            'sampai' => ['nullable', 'date', 'after_or_equal:dari', 'required_with:dari'],
            'interval' => ['nullable', 'in:harian,bulanan'],
        ];
    }

    /**
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    public function rentang(): array
    {
        if ($this->filled('dari')) {
            return [
                CarbonImmutable::parse($this->validated('dari'))->startOfDay(),
                CarbonImmutable::parse($this->validated('sampai'))->endOfDay(),
            ];
        }

        $sekarang = CarbonImmutable::now();

        return match ($this->validated('periode') ?? 'bulan') {
            'hari' => [$sekarang->startOfDay(), $sekarang->endOfDay()],
            'minggu' => [$sekarang->startOfWeek(), $sekarang->endOfWeek()],
            'tahun' => [$sekarang->startOfYear(), $sekarang->endOfYear()],
            default => [$sekarang->startOfMonth(), $sekarang->endOfMonth()],
        };
    }
}
