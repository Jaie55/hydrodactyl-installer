<p align="center">
  <a href="https://hydrodactyl.dev/docs/hydrodactyl">
    <img src="https://shieldcn.dev/badge/Docs-hydrodactyl.dev-0ea5e9.svg?logo=readme" alt="Documentation">
  </a>
  <a href="https://github.com/Jaie55/hydrodactyl-installer/issues">
    <img src="https://shieldcn.dev/badge/Support-Issues-5865F2.svg?logo=github" alt="Support">
  </a>
</p>

<br/>

<h1 align="center">hydrodactyl-installer</h1>

<p align="center">
  <a href="https://github.com/Jaie55/hydrodactyl-installer/actions/workflows/shellcheck.yml">
    <img src="https://shieldcn.dev/badge/Shellcheck-Passing-success.svg?logo=githubactions" alt="Shellcheck">
  </a>
  <a href="https://github.com/Jaie55/hydrodactyl-installer/releases">
    <img src="https://shieldcn.dev/badge/Release-v0.1.0-181717.svg?logo=github" alt="Latest release: v0.1.0">
  </a>
  <img src="https://shieldcn.dev/badge/Made%20with-Bash-1f425f.svg?logo=gnubash" alt="Made with Bash">
  <img src="https://shieldcn.dev/badge/Platform-Linux-f0b429.svg?logo=linux" alt="Platform Linux">
  <img src="https://shieldcn.dev/badge/License-GPL%20v3-181717.svg?logo=gnu" alt="License: GPL v3">
</p>

<br/>

Unofficial scripts for installing the [Hydrodactyl](https://github.com/BlueprintFramework/hydrodactyl)
Panel and its game server daemons (Pterodactyl Wings or pyrohost Elytra). Works
with the latest Hydrodactyl stable release and the `main` branch.

This script is not associated with the official Hydrodactyl, Blueprint or
Pterodactyl projects.

> [!NOTE]
> v0.1.0 is an early release. The installer has been statically validated
> (`bash -n`, Shellcheck, EN/ES key parity); test it on a throwaway VM before
> using it on a production machine.

## Features

- Automatic installation of the Hydrodactyl Panel (dependencies, database,
  nginx, queue worker, cronjob) either with **Docker** or **natively**.
- Any panel source: latest stable tag, canary (`main`) or your own fork and
  branch.
- Automatic installation of the **Wings** or **Elytra** daemon (Docker,
  systemd, binary download).
- Panel: (optional) automatic configuration of Let's Encrypt.
- English and Spanish interface, auto-detected from the system locale.

## Help and support

For help and support regarding the script itself and **not the official
Hydrodactyl or Pterodactyl projects**, open an issue at
<https://github.com/Jaie55/hydrodactyl-installer/issues>.

## Supported installations

Operating systems supported by this installation script.

| Operating System | Version | Native panel       | Docker panel       | Daemons            | PHP Version |
| ---------------- | ------- | ------------------ | ------------------ | ------------------ | ----------- |
| Ubuntu           | 22.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                  | 24.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                  | 26.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                  | 20.04   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Debian           | 12      | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                  | 13      | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                  | 11      | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Rocky Linux      | 8 / 9   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| AlmaLinux        | 8 / 9   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Fedora           | 40+     | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Arch Linux       | -       | :red_circle:       | :white_check_mark: | :red_circle:       |             |

- Native panel: Ubuntu 22.04+/Debian 12+, PHP 8.4 from ondrej/php (Ubuntu) or
  packages.sury.org (Debian).
- Daemons: Ubuntu/Debian on amd64 or arm64 (the only architectures published
  by Wings and Elytra).
- Docker panel: any distribution where Docker Engine can be installed.

## Using the installation scripts

To install, run this command as root. The script asks whether you want the
panel, a daemon, or both.

```bash
bash <(curl -s https://raw.githubusercontent.com/Jaie55/hydrodactyl-installer/main/install.sh)
```

_Note: log in as root before executing the one-liner; running `sudo bash <(...)`
does not always work._

You can also clone the repository and run it locally:

```bash
git clone https://github.com/Jaie55/hydrodactyl-installer.git
cd hydrodactyl-installer
sudo bash install.sh
```

Fully scripted installs:

```bash
# Panel with Docker (recommended)
sudo bash install.sh --docker --domain panel.example.com --ssl

# Native panel (Ubuntu/Debian) from the canary branch
sudo bash install.sh --native --source=canary --domain panel.example.com --ssl -y

# Panel from your own fork and branch
sudo bash install.sh --native --repo=https://github.com/you/hydrodactyl --ref=my-branch --domain panel.example.com

# Daemon only, using the config downloaded from the panel
sudo bash install.sh --daemon=wings --daemon-config=/root/config.yml
```

### Options

| Option                           | Description                                                                 |
| -------------------------------- | --------------------------------------------------------------------------- |
| `--docker`                       | Install the panel with Docker Compose                                       |
| `--native`                       | Install the panel natively (nginx + PHP-FPM + MariaDB/MySQL)                |
| `--source=stable\|canary\|custom` | `stable` = latest release tag, `canary` = `main`, `custom` = `--repo`/`--ref` |
| `--repo=URL`                     | Custom panel repository (implies `--source=custom`)                         |
| `--ref=BRANCH`                   | Branch or tag for the custom repository                                     |
| `--domain=DOMAIN`                | Panel domain (used by nginx and HTTPS)                                      |
| `--dir=PATH`                     | Panel directory (default `/var/www/hydrodactyl`)                            |
| `--db=mariadb\|mysql`            | Database engine for the native install                                      |
| `--daemon=wings\|elytra`         | Install a daemon                                                            |
| `--daemon-config=PATH`           | Node config file downloaded from the panel                                  |
| `--panel`                        | Install the panel too (with `--daemon`)                                     |
| `--ssl`                          | Request a free Let's Encrypt certificate                                    |
| `--no-verify`                    | Skip the final check that the panel answers (CI/local tests)                |
| `--lang=en\|es`                  | Interface language                                                          |
| `-y`, `--yes`                    | Non-interactive, assume yes                                                 |
| `-h`, `--help`                   | Show help                                                                   |

## What each mode does

**Docker** — installs Docker when missing, downloads the official
`docker-compose.example.yml`, fills in the database passwords, domain and mail
sender, stores it in `--dir` and runs `docker compose up -d`. Data lives under
`/srv/pterodactyl`. The published stable image is used; the chosen source only
affects where the compose file is taken from.

**Native** — installs nginx, PHP 8.4, MariaDB/MySQL, Node.js 22 + pnpm and
Composer; clones the panel at the selected source; creates the database and
user; writes `.env`; runs `composer install`, `pnpm install`, `pnpm run build`,
`key:generate` and `migrate --seed`; sets permissions for `www-data`; writes
the nginx vhost, the scheduler cronjob and the `pyroq` queue worker service;
and optionally requests a certificate with certbot.

Re-running the native mode updates the checkout to the selected ref
(`git reset --hard`, so local edits are lost), reuses the existing database
password from `.env` and re-applies the configuration.

**Daemons** — installs Docker (required by both daemons), downloads the latest
`wings` or `elytra` binary for your architecture, creates
`/etc/pterodactyl/config.yml` from `--daemon-config` and installs the systemd
unit. Without a config file the unit is created but not started: paste the node
configuration from the panel and run `systemctl restart wings` (or `elytra`).

## After installing

Open the panel URL, finish the setup wizard (first admin account) and, for
daemons, create a node in the panel to download its configuration.

## Local test without DNS

For a throwaway machine there is no need for a public domain or a certificate:

```bash
sudo bash install.sh --native --domain panel.test --no-verify -y
```

The installer verifies the panel against `127.0.0.1` with `curl --resolve`, so
no DNS is involved, and Let's Encrypt is skipped automatically for local
domains (`localhost`, `*.test`, `*.local`, private IPs). To open the panel in
a browser from another machine, point the domain at the panel's IP there:

```bash
echo '192.168.1.50 panel.test' | sudo tee -a /etc/hosts
```

## Development & testing

- Syntax check every script:

```bash
for f in install.sh lib/*.sh lib/modes/*.sh lang/*.sh; do bash -n "$f"; done
```

- [Shellcheck](https://www.shellcheck.net/) runs in CI
  (`.github/workflows/shellcheck.yml`).
- The installer is meant to be tested on a fresh VM or container with systemd.
  Never test it against a live panel: the native mode resets the checkout and
  re-runs migrations.

## License

Copyright (C) 2026 Jaie55 and contributors.

This project is free software licensed under the **GNU General Public License
v3.0**. You may use, modify and redistribute it under the terms of the license;
if you distribute a modified version, you must keep the copyright notices and
release it under the same license. A copy of the full license text is available
in the [LICENSE](./LICENSE) file.

Hydrodactyl itself is licensed under the Apache License 2.0; this installer only
downloads and configures it and does not include its source code.

## Notes

- The full log is written to `/var/log/hydrodactyl-installer.log`.
- The script is idempotent where it can be, but it is designed for fresh
  machines: back up before re-running on a live panel.
- Review the script before running it as root.
