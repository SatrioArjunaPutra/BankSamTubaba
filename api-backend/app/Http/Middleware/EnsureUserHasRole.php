<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Pemakaian: ->middleware('role:dlh,bank_sampah')
 */
class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $allowed = array_map(function (string $role) {
            // Salah ketik role di definisi route adalah bug developer, bukan 403
            return UserRole::tryFrom($role) ?? throw new InvalidArgumentException(
                "Role '{$role}' pada middleware role tidak dikenal. Pilihan: ".implode(', ', UserRole::values()).'.'
            );
        }, $roles);

        $user = $request->user();

        if (! $user || ! $user->hasRole(...$allowed)) {
            return response()->json([
                'status' => 'gagal',
                'pesan' => 'Anda tidak memiliki akses ke fitur ini.',
            ], 403);
        }

        return $next($request);
    }
}
