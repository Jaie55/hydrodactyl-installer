<?php

use Pterodactyl\Models\ApiKey;
use Pterodactyl\Models\User;
use Pterodactyl\Services\Api\KeyCreationService;
use Pterodactyl\Services\Acl\Api\AdminAcl;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

$base = getcwd();
require $base . '/vendor/autoload.php';

$app = require $base . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$locale = config('app.locale', 'en-US');
$languages = array_keys((new User())->getAvailableLanguages());
if (!in_array($locale, $languages, true)) {
    $locale = in_array('en-US', $languages, true) ? 'en-US' : ($languages[0] ?? 'en-US');
}

$created = 0;
$user = User::query()->where('root_admin', true)->orderBy('id')->first();
if (!$user) {
    $email = getenv('HYDRO_ADMIN_EMAIL') ?: 'admin@example.com';
    $username = getenv('HYDRO_ADMIN_USER') ?: 'admin';
    $first = getenv('HYDRO_ADMIN_FIRST') ?: 'Admin';
    $last = getenv('HYDRO_ADMIN_LAST') ?: '';
    $password = getenv('HYDRO_ADMIN_PASS') ?: Str::random(16);

    $user = new User();
    $user->forceFill([
        'uuid' => (string) Str::uuid(),
        'email' => $email,
        'username' => $username,
        'name_first' => $first,
        'name_last' => $last,
        'password' => Hash::make($password),
        'language' => $locale,
        'root_admin' => true,
    ])->save();
    $created = 1;
}

echo 'user_id=' . $user->id . PHP_EOL;
echo 'user_email=' . $user->email . PHP_EOL;
echo 'created=' . $created . PHP_EOL;

ApiKey::query()
    ->where('user_id', $user->id)
    ->where('memo', 'hydrodactyl-installer')
    ->delete();

$permissions = [];
foreach (AdminAcl::getResourceList() as $resource) {
    $permissions['r_' . $resource] = AdminAcl::READ | AdminAcl::WRITE;
}

$key = $app->make(KeyCreationService::class)
    ->setKeyType(ApiKey::TYPE_APPLICATION)
    ->handle([
        'memo' => 'hydrodactyl-installer',
        'user_id' => $user->id,
    ], $permissions);

echo 'key=' . $key->identifier . decrypt($key->token) . PHP_EOL;
