<p align="center">
  <a href="README.md">
    <img src="https://shieldcn.dev/badge/Language-English-success.svg?logo=github" alt="English">
  </a>
  <a href="README.es.md">
    <img src="https://shieldcn.dev/badge/Language-Espa%C3%B1ol-181717.svg?logo=github" alt="Español">
  </a>
</p>

<br/>

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
    <img src="https://shieldcn.dev/badge/Release-v0.9.0-181717.svg?logo=github" alt="Latest release: v0.9.0">
  </a>
  <img src="https://shieldcn.dev/badge/Made%20with-Bash-1f425f.svg?logo=gnubash" alt="Made with Bash">
  <img src="https://shieldcn.dev/badge/Platform-Linux-f0b429.svg?logo=linux" alt="Platform Linux">
  <img src="https://shieldcn.dev/badge/License-GPL%20v3-181717.svg?logo=gnu" alt="License: GPL v3">
</p>

<br/>

Unofficial **installer, updater and uninstaller** for the
[Hydrodactyl](https://github.com/BlueprintFramework/hydrodactyl) panel and its
game server daemons (Pterodactyl Wings or pyrohost Elytra). Install the panel
with Docker or natively, create the node automatically, update the panel and
daemons to the latest release, or remove everything with one command.

This script is not associated with the official Hydrodactyl, Blueprint or
Pterodactyl projects.

> [!NOTE]
> v0.9.0 is an early release. The installer has been statically validated
> (`bash -n`, Shellcheck, EN/ES key parity); test it on a throwaway VM before
> using it on a production machine.

## Features

- **Installer** — every combination: panel only (Docker or native), panel +
  Wings/Elytra (Docker or native) or a daemon alone (Wings/Elytra).
- **Updater** — detects the installed panel and daemon versions and updates
  them to the latest stable release (`--check-updates`, `--update`).
- **Uninstaller** — removes the panel and/or daemons, their services and
  configuration (`--uninstall`, `--purge` to delete databases and data).
- **Automatic node setup** — the installer creates the panel application API
  key automatically for a local panel, creates or reuses the node, adds only the
  missing port allocations, fetches the node configuration and starts the
  daemon. It also creates the first admin if the panel has none.
- **Optional Minecraft test server** — asks whether to create a Vanilla/Paper
  server on port 25565 (configurable) using the node IP, and starts it.
- **Detection and summary** — reports what is already installed (and its
  version) before starting and prints a summary with the panel URL and every
  chosen option when it finishes.
- Any panel source: latest stable tag, canary (`main`) or a custom fork/ref.
- **Basic or custom installs** — defaults, or every option prompted with
  examples (timezone `Europe/Madrid`, locale `es-ES`, ports, PHP, firewall,
  node resources...).
- **Production or test** mode, including fully local installs (`--local`,
  `localhost`, no DNS or internet needed).
- Optional Let's Encrypt certificate and ufw firewall.
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

- Native panel: Ubuntu 22.04+/Debian 12+, PHP 8.4 from ondrej/php (Ubuntu
  releases that still have it) or packages.sury.org (Debian and newer Ubuntu).
- Daemons: Ubuntu/Debian on amd64 or arm64 (the only architectures published
  by Wings and Elytra).
- Docker panel: any distribution where Docker Engine can be installed.

## Using the installation scripts

To install, run this command as root. The menu offers every combination and
also the update and uninstall actions.

```bash
# Ubuntu Server minimal does not ship curl: install it first
apt update && apt install -y curl

bash <(curl -fsSL https://raw.githubusercontent.com/Jaie55/hydrodactyl-installer/main/install.sh)
```

To pin the installer itself to a tag or branch, set
`HYDRODACTYL_SCRIPT_REF` (for example
`HYDRODACTYL_SCRIPT_REF=v0.9.0 bash <(curl ...)`).

If `curl` is already installed, only the last line is needed. Once the script
is running it installs any missing dependency by itself. Interactive runs then
ask for a **basic** install (defaults) or a **custom** one, where every option
is prompted with an example.

Fully scripted examples:

```bash
# Panel with Docker (recommended)
sudo bash install.sh --docker --domain panel.example.com --ssl

# Native panel (Ubuntu/Debian) from the canary branch
sudo bash install.sh --native --source=canary --domain panel.example.com --ssl -y

# Panel from your own fork and branch
sudo bash install.sh --native --repo=https://github.com/you/hydrodactyl --ref=my-branch --domain panel.example.com

# Local panel for testing (no DNS, no internet, admin at http://localhost)
sudo bash install.sh --native --local -y

# Daemon only, creating the node through the panel API
sudo bash install.sh --daemon=wings --panel-url=http://127.0.0.1 --api-key=ptla_xxx -y
```

### Options

| Option                           | Description                                                                 |
| -------------------------------- | --------------------------------------------------------------------------- |
| `--docker`                       | Install the panel with Docker Compose                                       |
| `--native`                       | Install the panel natively (nginx + PHP-FPM + MariaDB/MySQL)                |
| `--basic` / `--custom`           | Basic install (defaults) or custom install (asks every option)              |
| `--local`                        | Local test install: test mode, `localhost` by default, no SSL               |
| `--environment=production\|test` | Production: debug off, config cached, strict domain/HTTPS warnings. Test: debug on, config not cached |
| `--source=stable\|canary\|custom` | `stable` = latest release tag, `canary` = `main`, `custom` = `--repo`/`--ref` |
| `--repo=URL`                     | Custom panel repository (implies `--source=custom`)                         |
| `--ref=BRANCH`                   | Branch or tag for the custom repository                                     |
| `--domain=DOMAIN`                | Panel domain (optional in test mode, defaults to `localhost`)               |
| `--dir=PATH`                     | Panel directory (default `/var/www/hydrodactyl`)                            |
| `--db=mariadb\|mysql`            | Database engine for the native install                                      |
| `--db-name=NAME`                 | Database name (default `panel`)                                             |
| `--db-user=USER`                 | Database user (default `hydrodactyl`)                                       |
| `--db-password=PASS`             | Database password (default: generated)                                      |
| `--php=8.4\|8.5`                 | PHP version for the native install (default `8.4`)                          |
| `--timezone=TZ`                  | Application timezone (default `UTC`)                                        |
| `--locale=LOCALE`                | Application locale (default `en-US`)                                        |
| `--http-port=PORT`               | HTTP port (default `80`)                                                    |
| `--firewall` / `--no-firewall`   | Configure ufw (SSH, HTTP, HTTPS and daemon ports)                           |
| `--daemon=wings\|elytra`         | Install a daemon                                                            |
| `--daemon-config=PATH`           | Node config file downloaded from the panel                                  |
| `--daemon-version=TAG`           | Daemon release tag (default: latest)                                        |
| `--daemon-port=PORT`             | Daemon listen port (default `8080`)                                         |
| `--sftp-port=PORT`               | SFTP port (default `2022`)                                                  |
| `--node-scheme=http\|https`      | Panel to daemon scheme (default `http`)                                     |
| `--behind-proxy`                 | The node is behind a proxy                                                  |
| `--panel-url=URL`                | Panel URL for automatic node setup (default: detected panel URL)            |
| `--api-key=KEY`                  | Panel application API key (created automatically for a local panel)         |
| `--node-name=NAME`               | Node name (default: hostname)                                               |
| `--node-fqdn=HOST`               | Node FQDN/IP reachable from the panel (default: primary IP)                 |
| `--memory=MB` / `--disk=MB`      | Node resources (default: detected)                                          |
| `--ports=LIST`                   | Allocations, comma separated (default `25565-25665,27015-27150`)            |
| `--no-node`                      | Do not create the node automatically                                        |
| `--test-server` / `--no-test-server` | Create a Minecraft test server on port 25565 (or skip it)                |
| `--test-server-egg=EGG`          | Test server egg (default `vanilla`)                                         |
| `--test-server-port=PORT`        | Test server port (default `25565`)                                          |
| `--test-server-memory=MB`        | Test server memory in MiB (default `1024`)                                  |
| `--test-server-disk=MB`          | Test server disk in MiB (default `5120`)                                    |
| `--admin-email=EMAIL`            | First admin email (default `admin@example.com`)                             |
| `--admin-username=NAME`          | First admin username (default `admin`)                                      |
| `--admin-password=PASS`          | First admin password (default: generated)                                   |
| `--no-auto-admin`                | Do not create the first admin automatically                                 |
| `--check-updates`                | Show installed and latest panel/daemon versions                             |
| `--update[=panel\|daemon]`       | Update the detected panel and/or daemons                                    |
| `--uninstall[=panel\|daemon\|all\|wings\|elytra]` | Uninstall the given targets                               |
| `--purge`                        | With `--uninstall`, also delete the database and data directories           |
| `--ssl`                          | Request a free Let's Encrypt certificate                                    |
| `--no-verify`                    | Skip the final check that the panel answers (CI/local tests)                |
| `--dry-run`                      | Show the plan and exit without installing                                   |
| `--version`                      | Show the installer version                                                  |
| `--lang=en\|es`                  | Interface language                                                          |
| `-y`, `--yes`                    | Non-interactive, use defaults                                               |
| `-h`, `--help`                   | Show help                                                                   |

## Automatic node setup

The daemon can be configured without copying anything by hand. When the panel
is on the same machine, the installer creates the application API key
automatically (with scoped permissions) and:

1. creates the first admin user if the panel has none (credentials are printed
   in the summary and saved to `/root/hydrodactyl-admin.txt`),
2. creates a location if the panel has none,
3. reuses an existing node with the same FQDN or creates a new one,
4. creates only the missing port allocations,
5. runs `wings configure` / `elytra configure` to download the node
   configuration,
6. starts the systemd service and checks that it is listening, and
7. optionally creates a Minecraft test server on port 25565.

For a remote panel, create an application API key in the panel and pass it with
`--api-key`; the installer will still create the node and allocations. If the
node cannot be configured, paste the node configuration from the panel into
`/etc/pterodactyl/config.yml` and run `systemctl restart wings` (or `elytra`).

## Updating the panel and daemons

The script also works as a **Hydrodactyl panel updater**:

```bash
# Show the installed and latest versions
sudo bash install.sh --check-updates

# Update the detected panel and daemons
sudo bash install.sh --update

# Update only the panel or only the daemons
sudo bash install.sh --update=panel
sudo bash install.sh --update=daemon
```

- Native panel: fetches the latest stable tag, rebuilds the frontend and
  dependencies, runs migrations and reloads nginx/PHP-FPM/queue.
- Docker panel: pulls the latest image and recreates the containers.
- Daemons: downloads the latest Wings/Elytra binary and restarts the service.

The interactive menu (option 9/10) offers the same actions.

## Uninstalling

```bash
# Uninstall everything that is installed
sudo bash install.sh --uninstall

# Uninstall only the panel or only the daemons
sudo bash install.sh --uninstall=panel
sudo bash install.sh --uninstall=daemon
sudo bash install.sh --uninstall=wings

# Also delete the database and data directories
sudo bash install.sh --uninstall --purge
```

Without `--purge` the panel database and the daemon data directories
(`/srv/pterodactyl`, `/var/lib/pterodactyl`) are kept.

## Local test without DNS

For a throwaway machine there is no need for a public domain or a certificate:

```bash
sudo bash install.sh --native --local -y
```

The domain defaults to `localhost` in test/local mode, so no DNS or internet
access is needed. The installer verifies the panel against `127.0.0.1` with
`curl --resolve`, and Let's Encrypt is skipped automatically for local domains
(`localhost`, `*.test`, `*.local`, private IPs). To open the panel in a browser
from another machine, point the domain at the panel's IP there:

```bash
echo '192.168.1.50 panel.test' | sudo tee -a /etc/hosts
```

## What each mode does

**Docker** — installs Docker when missing, downloads the official
`docker-compose.example.yml`, fills in the database passwords, domain, timezone,
locale and mail sender, stores it in `--dir` and runs `docker compose up -d`.
Data lives under `/srv/pterodactyl`. The published stable image is used; the
chosen source only affects where the compose file is taken from. Containers
restart on boot (`unless-stopped`). ufw is skipped in Docker mode because
Docker publishes its own ports and would bypass it.

**Native** — installs nginx, PHP, MariaDB/MySQL, Node.js + pnpm and Composer;
clones the panel at the selected source; creates the database and user; writes
`.env`; runs `composer install`, `pnpm install`, `pnpm run build` and
`migrate --seed`; sets permissions for `www-data`; writes the nginx vhost, the
scheduler cronjob and the `pyroq` queue worker service; and optionally requests
a certificate with certbot.

Re-running the installer updates the checkout to the selected ref
(`git reset --hard`, so local edits are lost), reuses the existing database
password from `.env` and re-applies the configuration. A summary with the panel
URL and the chosen configuration is printed at the end.

## After installing

The installer creates the first admin automatically if the panel has no users;
the email and generated password are printed in the summary and saved to
`/root/hydrodactyl-admin.txt`. Change the password after logging in. The
application API key and node are created automatically for local panels. If you
asked for a test server, connect to `<node-ip>:25565`.

## Troubleshooting

- **Wings WebSocket 403 / `request origin not allowed`**: Wings only accepts
  the browser origin that matches its `remote` panel URL. Use the same URL in
  the browser as the panel URL (`APP_URL`). Re-run the installer or edit
  `/etc/pterodactyl/config.yml` (`remote: http://localhost`) and run
  `systemctl restart wings`.
- **Wings does not listen on 8080**: `systemctl status wings`,
  `journalctl -u wings -n 100 --no-pager`, `ss -ltnp | grep -E ':8080|:2022'`.
  Check that Docker is running (`docker info`).
- **Panel local but inaccessible from the LAN**: `localhost` is only reachable
  on the server. Use `--domain=<server-ip>` and access the panel through that
  IP.
- **Let's Encrypt fails**: the domain must resolve to the server and port 80
  must be reachable from the internet.
- **Docker update**: back up the database before running `--update`.

## Development & testing

- Syntax check every script:

```bash
for f in install.sh lib/*.sh lib/modes/*.sh lang/*.sh tests/*.sh; do bash -n "$f"; done
```

- Unit tests: `bash tests/run.sh` (requires `jq`).
- PHP syntax: `php -l config/panel-key.php`.
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
