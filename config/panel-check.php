<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

$base = getcwd();
require $base . '/vendor/autoload.php';

$app = require $base . '/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

try {
    $encrypted = [];

    if (Schema::hasTable('nodes')) {
        $encrypted = array_merge($encrypted, DB::table('nodes')
            ->whereNotNull('daemon_token')
            ->where('daemon_token', '<>', '')
            ->pluck('daemon_token')
            ->all());
    }

    if (Schema::hasTable('api_keys')) {
        $encrypted = array_merge($encrypted, DB::table('api_keys')
            ->whereNotNull('token')
            ->where('token', '<>', '')
            ->pluck('token')
            ->all());
    }

    foreach ($encrypted as $value) {
        decrypt($value);
    }
} catch (\Illuminate\Contracts\Encryption\DecryptException) {
    // The APP_KEY does not match the data stored in the database.
    exit(2);
} catch (\Throwable) {
    // Connection or schema problems are reported by artisan migrate.
}

exit(0);
