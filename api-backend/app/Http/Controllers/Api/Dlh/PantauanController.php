<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\StatusArmada;
use App\Enums\StatusLaporan;
use App\Enums\StatusPenjemputan;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\PantauanRequest;
use App\Http\Resources\SetoranResource;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\LaporanPreloved;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use App\Services\KinerjaService;
use App\Support\SqlWaktu;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\DB;

class PantauanController extends Controller
{
    public function dashboard(PantauanRequest $request, KinerjaService $service): JsonResponse
    {
        [$dari, $sampai] = $request->rentang();
        $sekarang = CarbonImmutable::now();
        $periode = SqlWaktu::periode('created_at', 'bulanan');
        $bulanan = Setoran::whereBetween('created_at', [$sekarang->startOfYear(), $sekarang->endOfYear()])
            ->selectRaw("{$periode} as periode, sum(total_kg) as total_kg")
            ->groupByRaw($periode)->pluck('total_kg', 'periode');
        $tren = collect(range(1, 12))->map(fn (int $bulan): array => [
            'periode' => $sekarang->startOfYear()->addMonths($bulan - 1)->format('Y-m'),
            'total_kg' => (float) ($bulanan[$sekarang->startOfYear()->addMonths($bulan - 1)->format('Y-m')] ?? 0),
        ]);
        $komposisi = DB::table('setoran_items')
            ->join('setoran', 'setoran.id', '=', 'setoran_items.setoran_id')
            ->join('jenis_sampah', 'jenis_sampah.id', '=', 'setoran_items.jenis_sampah_id')
            ->whereNull('setoran.dibatalkan_at')
            ->whereBetween('setoran.created_at', [$dari, $sampai])
            ->groupBy('jenis_sampah.id', 'jenis_sampah.nama')
            ->selectRaw('jenis_sampah.id, jenis_sampah.nama, sum(setoran_items.berat_kg) as total_kg')
            ->orderByDesc('total_kg')->get()
            ->map(fn (object $baris): array => ['id' => $baris->id, 'nama' => $baris->nama, 'total_kg' => (float) $baris->total_kg]);
        $hariIni = Penjemputan::whereDate('created_at', $sekarang->toDateString());
        $aktif = Penjemputan::with(['bankSampah', 'armada.driver'])
            ->whereIn('status', ['dijadwalkan', 'menuju', 'diambil'])
            ->orderBy('jadwal_at')->limit(5)->get()
            ->map(fn (Penjemputan $p): array => [
                'id' => $p->id, 'status' => $p->status->value, 'alamat' => $p->alamat,
                'jadwal_at' => $p->jadwal_at?->toIso8601String(),
                'bank_sampah' => $p->bankSampah?->nama, 'driver' => $p->armada?->driver?->name,
                'lat' => $p->lat, 'lng' => $p->lng,
            ]);
        $durasi = (int) $dari->startOfDay()->diffInDays($sampai->startOfDay()) + 1;
        $sebelumnya = $service->ringkasan($dari->subDays($durasi), $dari->subMicrosecond());

        return $this->sukses('Dashboard berhasil dimuat.', [
            'ringkasan' => $service->ringkasan($dari, $sampai) + [
                'bank_sampah_total' => BankSampah::count(),
                'bank_tanpa_setoran' => BankSampah::aktif()->whereNotIn('id', Setoran::whereBetween('created_at', [$dari, $sampai])->select('bank_sampah_id'))->count(),
                'barang_dilaporkan' => LaporanPreloved::where('status', StatusLaporan::Baru->value)->distinct()->count('preloved_item_id'),
                'warga_baru' => User::where('role', UserRole::Warga)->whereBetween('created_at', [$dari, $sampai])->count(),
                'jemput_hari_ini' => (clone $hariIni)->count(),
                'jemput_selesai_hari_ini' => (clone $hariIni)->where('status', StatusPenjemputan::Selesai)->count(),
                'kg_periode_lalu' => $sebelumnya['total_kg'],
                'total_saldo_warga' => (float) Nasabah::sum('saldo'),
                'warga_aktif_30_hari' => Setoran::where('created_at', '>=', $sekarang->subDays(30))->distinct()->count('warga_id'),
                'bentor_total' => Armada::count(),
                'bentor_bertugas' => Armada::where('status', 'bertugas')->count(),
                'bentor_terjadwal' => Armada::where('status', 'siaga')->has('tugasAktif')->count(),
                'bentor_siaga' => Armada::where('status', 'siaga')->doesntHave('tugasAktif')->count(),
                'bentor_nonaktif' => Armada::where('status', 'nonaktif')->count(),
                'penarikan_nilai' => (float) Penarikan::where('status', 'disetujui')->whereBetween('created_at', [$dari, $sampai])->sum('jumlah'),
                'penarikan_menunggu' => Penarikan::where('status', 'diajukan')->count(),
                'jumlah_penarikan' => Penarikan::whereBetween('created_at', [$dari, $sampai])->count(),
                'donatur' => Setoran::where('tipe', 'donasi')->whereBetween('created_at', [$dari, $sampai])->distinct()->count('warga_id'),
                'donasi_jumlah' => Setoran::where('tipe', 'donasi')->whereBetween('created_at', [$dari, $sampai])->count(),
                'donasi_dijemput' => Setoran::where('tipe', 'donasi')->whereNotNull('penjemputan_id')->whereBetween('created_at', [$dari, $sampai])->count(),
                'donasi_menunggu' => Penjemputan::whereIn('status', StatusPenjemputan::aktif())->where('catatan', 'like', '[DONASI]%')->count(),
            ],
            'tren' => $tren, 'komposisi' => $komposisi,
            'peringkat' => $service->perBankSampah($dari, $sampai), 'penjemputan' => $aktif,
            'dari' => $dari->toIso8601String(), 'sampai' => $sampai->toIso8601String(),
        ]);
    }

    public function warga(PantauanRequest $request): AnonymousResourceCollection
    {
        $users = User::where('role', UserRole::Warga)
            ->select('users.*')
            ->selectSub(Nasabah::selectRaw('coalesce(sum(saldo), 0)')->whereColumn('warga_id', 'users.id'), 'total_saldo')
            ->selectSub(Setoran::selectRaw('count(*)')->whereColumn('warga_id', 'users.id'), 'jumlah_setoran')
            ->selectSub(Setoran::selectRaw('coalesce(sum(total_kg), 0)')->whereColumn('warga_id', 'users.id'), 'total_kg')
            ->selectSub(Setoran::selectRaw('max(created_at)')->whereColumn('warga_id', 'users.id'), 'terakhir_setor')
            ->when($request->filled('q'), fn ($q) => $q->where(fn ($s) => $s->whereLike('name', '%'.$request->string('q').'%')->orWhere('phone', 'like', '%'.$request->string('q').'%')))
            ->when($request->filled('status'), fn ($q) => $q->where('is_aktif', $request->string('status')->toString() === 'aktif'))
            ->when($request->filled('bank_sampah_id'), fn ($q) => $q->whereIn('id', Nasabah::select('warga_id')->where('bank_sampah_id', $request->integer('bank_sampah_id'))))
            ->orderBy('name')->paginate($request->integer('per_page', 20))->withQueryString();
        $rekening = Nasabah::with('bankSampah')->whereIn('warga_id', $users->pluck('id'))->get()->groupBy('warga_id');
        $users->through(fn (User $u): array => [
            'id' => $u->id, 'name' => $u->name, 'phone' => $u->phone ? '08••••'.substr($u->phone, -4) : null,
            'is_aktif' => $u->is_aktif, 'saldo' => (float) $u->total_saldo,
            'jumlah_setoran' => (int) $u->jumlah_setoran, 'created_at' => $u->created_at->toIso8601String(),
            'total_kg' => (float) $u->total_kg,
            'terakhir_setor' => $u->terakhir_setor ? CarbonImmutable::parse($u->terakhir_setor)->toIso8601String() : null,
            'bank_sampah' => ($rekening[$u->id] ?? collect())->map(fn (Nasabah $n): array => ['id' => $n->bank_sampah_id, 'nama' => $n->bankSampah?->nama, 'kecamatan' => $n->bankSampah?->kecamatan])->values(),
        ]);

        return $this->daftar(JsonResource::collection($users), 'Daftar warga berhasil dimuat.');
    }

    public function bentor(PantauanRequest $request): AnonymousResourceCollection
    {
        $armada = Armada::with(['driver', 'bankSampah'])->withCount('tugasAktif')
            ->when($request->filled('q'), fn ($q) => $q->whereHas('driver', fn ($s) => $s->whereLike('name', '%'.$request->string('q').'%')))
            // "Terjadwal" bukan status armada: armada siaga yang sudah punya tugas, tetapi belum berangkat
            ->when($request->filled('status'), fn ($q) => match ($request->string('status')->toString()) {
                'terjadwal' => $q->where('status', 'siaga')->has('tugasAktif'),
                'siaga' => $q->where('status', 'siaga')->doesntHave('tugasAktif'),
                default => $q->where('status', $request->string('status')),
            })
            ->when($request->filled('bank_sampah_id'), fn ($q) => $q->where('bank_sampah_id', $request->integer('bank_sampah_id')))
            ->orderBy('plat_nomor')->paginate($request->integer('per_page', 20))->withQueryString();
        $armada->through(fn (Armada $a): array => [
            'id' => $a->id, 'driver' => $a->driver?->name, 'phone' => $a->driver?->phone,
            'bank_sampah' => $a->bankSampah?->nama, 'plat_nomor' => $a->plat_nomor,
            'kapasitas_kg' => (float) $a->kapasitas_kg, 'status' => $a->status->value,
            'status_tampil' => $a->status === StatusArmada::Siaga && $a->tugas_aktif_count > 0 ? 'terjadwal' : $a->status->value,
            'tugas_aktif' => (int) $a->tugas_aktif_count,
            'lat' => $a->bankSampah?->lat, 'lng' => $a->bankSampah?->lng,
        ]);

        return $this->daftar(JsonResource::collection($armada), 'Daftar bentor berhasil dimuat.');
    }

    public function transaksi(PantauanRequest $request): AnonymousResourceCollection
    {
        [$dari, $sampai] = $request->rentang();
        $setoran = DB::table('setoran')->select('id', 'warga_id', 'bank_sampah_id', 'total_kg', 'total_nilai', 'tipe', 'created_at')->selectRaw("'tercatat' as status")->whereNull('dibatalkan_at');
        $penarikan = DB::table('penarikan')->select('id', 'warga_id', 'bank_sampah_id')->selectRaw("0 as total_kg, jumlah as total_nilai, 'penarikan' as tipe")->addSelect('created_at', 'status');
        $rows = DB::query()->fromSub($setoran->unionAll($penarikan), 'aktivitas')
            ->whereBetween('created_at', [$dari, $sampai])
            ->when($request->filled('tipe'), fn ($q) => $q->where('tipe', $request->validated('tipe')))
            ->when($request->filled('bank_sampah_id'), fn ($q) => $q->where('bank_sampah_id', $request->integer('bank_sampah_id')))
            ->when($request->filled('q'), fn ($q) => $q->whereIn('warga_id', User::select('id')->whereLike('name', '%'.$request->string('q').'%')))
            ->orderByDesc('created_at')->orderByDesc('id')->paginate($request->integer('per_page', 20))->withQueryString();
        $warga = User::whereIn('id', $rows->pluck('warga_id'))->get(['id', 'name'])->keyBy('id');
        $banks = BankSampah::whereIn('id', $rows->pluck('bank_sampah_id'))->get(['id', 'nama', 'kode'])->keyBy('id');
        $rows->through(fn (object $r): array => [
            'id' => $r->id, 'tipe' => $r->tipe, 'status' => $r->status,
            'total_kg' => (float) $r->total_kg, 'total_nilai' => (float) $r->total_nilai,
            'created_at' => CarbonImmutable::parse($r->created_at)->toIso8601String(),
            'warga' => ['id' => $r->warga_id, 'name' => $warga[$r->warga_id]?->name],
            'bank_sampah' => ['id' => $r->bank_sampah_id, 'nama' => $banks[$r->bank_sampah_id]?->nama],
        ]);

        return $this->daftar(JsonResource::collection($rows), 'Daftar transaksi berhasil dimuat.');
    }

    public function donasi(PantauanRequest $request): AnonymousResourceCollection
    {
        return $this->daftarSetoran($request, 'donasi');
    }

    private function daftarSetoran(PantauanRequest $request, ?string $tipe): AnonymousResourceCollection
    {
        [$dari, $sampai] = $request->rentang();
        $setoran = Setoran::with(['bankSampah', 'warga', 'items.jenisSampah'])
            ->whereBetween('created_at', [$dari, $sampai])
            ->when($tipe, fn ($q) => $q->where('tipe', $tipe))
            ->when($request->filled('bank_sampah_id'), fn ($q) => $q->where('bank_sampah_id', $request->integer('bank_sampah_id')))
            ->when($request->filled('q'), fn ($q) => $q->whereHas('warga', fn ($w) => $w->whereLike('name', '%'.$request->string('q').'%')))
            ->latest()->latest('id')->paginate($request->integer('per_page', 20))->withQueryString();

        return $this->daftar(SetoranResource::collection($setoran), 'Daftar setoran berhasil dimuat.');
    }
}
