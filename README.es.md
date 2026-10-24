<p align="center">
  <a href="https://hydrodactyl.dev/docs/hydrodactyl">
    <img src="https://shieldcn.dev/badge/Docs-hydrodactyl.dev-0ea5e9.svg?logo=readme" alt="Documentación">
  </a>
  <a href="https://github.com/Jaie55/hydrodactyl-installer/issues">
    <img src="https://shieldcn.dev/badge/Soporte-Issues-5865F2.svg?logo=github" alt="Soporte">
  </a>
</p>

<br/>

<h1 align="center">hydrodactyl-installer</h1>

<p align="center">
  <a href="https://github.com/Jaie55/hydrodactyl-installer/actions/workflows/shellcheck.yml">
    <img src="https://shieldcn.dev/badge/Shellcheck-Passing-success.svg?logo=githubactions" alt="Shellcheck">
  </a>
  <a href="https://github.com/Jaie55/hydrodactyl-installer/releases">
    <img src="https://shieldcn.dev/badge/Release-v0.1.0-181717.svg?logo=github" alt="Última release: v0.1.0">
  </a>
  <img src="https://shieldcn.dev/badge/Hecho%20con-Bash-1f425f.svg?logo=gnubash" alt="Hecho con Bash">
  <img src="https://shieldcn.dev/badge/Plataforma-Linux-f0b429.svg?logo=linux" alt="Plataforma Linux">
  <img src="https://shieldcn.dev/badge/Licencia-GPL%20v3-181717.svg?logo=gnu" alt="Licencia: GPL v3">
</p>

<br/>

Scripts no oficiales para instalar el panel [Hydrodactyl](https://github.com/BlueprintFramework/hydrodactyl)
y sus daemons de servidores de juego (Pterodactyl Wings o pyrohost Elytra).
Funciona con la última release estable de Hydrodactyl y con la rama `main`.

Este script no está asociado con los proyectos oficiales de Hydrodactyl,
Blueprint ni Pterodactyl.

> [!NOTE]
> La v0.1.0 es una versión temprana. El instalador se ha validado de forma
> estática (`bash -n`, Shellcheck, paridad de claves EN/ES); pruébalo en una VM
> desechable antes de usarlo en una máquina de producción.

## Características

- Instalación automática del panel Hydrodactyl (dependencias, base de datos,
  nginx, worker de colas, cron) con **Docker** o de forma **nativa**.
- Cualquier fuente del panel: última release estable, canary (`main`) o tu
  propio fork y rama.
- Instalación automática del daemon **Wings** o **Elytra** (Docker, systemd,
  descarga del binario).
- Panel: (opcional) configuración automática de Let's Encrypt.
- Interfaz en inglés y castellano, detectada del locale del sistema.

## Ayuda y soporte

Para ayuda y soporte sobre el script y **no sobre los proyectos oficiales de
Hydrodactyl o Pterodactyl**, abre una issue en
<https://github.com/Jaie55/hydrodactyl-installer/issues>.

## Instalaciones soportadas

Sistemas operativos soportados por este script de instalación.

| Sistema Operativo | Versión | Panel nativo       | Panel Docker       | Daemons            | Versión PHP |
| ----------------- | ------- | ------------------ | ------------------ | ------------------ | ----------- |
| Ubuntu            | 22.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                   | 24.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                   | 26.04   | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                   | 20.04   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Debian            | 12      | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                   | 13      | :white_check_mark: | :white_check_mark: | :white_check_mark: | 8.4         |
|                   | 11      | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Rocky Linux       | 8 / 9   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| AlmaLinux         | 8 / 9   | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Fedora            | 40+     | :red_circle:       | :white_check_mark: | :red_circle:       |             |
| Arch Linux        | -       | :red_circle:       | :white_check_mark: | :red_circle:       |             |

- Panel nativo: Ubuntu 22.04+/Debian 12+, PHP 8.4 desde ondrej/php (Ubuntu) o
  packages.sury.org (Debian).
- Daemons: Ubuntu/Debian en amd64 o arm64 (las únicas arquitecturas publicadas
  por Wings y Elytra).
- Panel Docker: cualquier distribución donde se pueda instalar Docker Engine.

## Uso de los scripts de instalación

Para instalar, ejecuta este comando como root. El script pregunta si quieres el
panel, un daemon o ambos.

```bash
# Ubuntu Server minimal no trae curl: instálalo primero
apt update && apt install -y curl

bash <(curl -fsSL https://raw.githubusercontent.com/Jaie55/hydrodactyl-installer/main/install.sh)
```

Si `curl` ya está instalado, solo hace falta la última línea. Una vez en
ejecución, el script instala por su cuenta cualquier dependencia que falte.

_Nota: inicia sesión como root antes de ejecutar el comando de una línea; usar
`sudo bash <(...)` no siempre funciona._

También puedes clonar el repositorio y ejecutarlo en local:

```bash
git clone https://github.com/Jaie55/hydrodactyl-installer.git
cd hydrodactyl-installer
sudo bash install.sh
```

Instalaciones totalmente automatizadas:

```bash
# Panel con Docker (recomendado)
sudo bash install.sh --docker --domain panel.ejemplo.com --ssl

# Panel nativo (Ubuntu/Debian) desde la rama canary
sudo bash install.sh --native --source=canary --domain panel.ejemplo.com --ssl -y

# Panel desde tu propio fork y rama
sudo bash install.sh --native --repo=https://github.com/tu-usuario/hydrodactyl --ref=mi-rama --domain panel.ejemplo.com

# Solo el daemon, con la configuración descargada del panel
sudo bash install.sh --daemon=wings --daemon-config=/root/config.yml
```

### Opciones

| Opción                             | Descripción                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `--docker`                         | Instala el panel con Docker Compose                                             |
| `--native`                         | Instala el panel de forma nativa (nginx + PHP-FPM + MariaDB/MySQL)              |
| `--source=stable\|canary\|custom`  | `stable` = último tag de release, `canary` = `main`, `custom` = `--repo`/`--ref` |
| `--repo=URL`                       | Repositorio del panel personalizado (implica `--source=custom`)                  |
| `--ref=BRANCH`                     | Rama o tag del repositorio personalizado                                         |
| `--domain=DOMAIN`                  | Dominio del panel (lo usan nginx y HTTPS)                                       |
| `--dir=PATH`                       | Directorio del panel (por defecto `/var/www/hydrodactyl`)                        |
| `--db=mariadb\|mysql`              | Motor de base de datos para la instalación nativa                                |
| `--daemon=wings\|elytra`           | Instala un daemon                                                                |
| `--daemon-config=PATH`             | Fichero de configuración del nodo descargado del panel                           |
| `--panel`                          | Instala también el panel (junto con `--daemon`)                                  |
| `--ssl`                            | Pide un certificado gratuito con Let's Encrypt                                  |
| `--no-verify`                      | Omite la comprobación final de que el panel responde (CI/pruebas locales)        |
| `--lang=en\|es`                    | Idioma de la interfaz                                                            |
| `-y`, `--yes`                      | No interactivo, asume sí                                                         |
| `-h`, `--help`                     | Muestra la ayuda                                                                 |

## Qué hace cada modo

**Docker** — instala Docker si falta, descarga el
`docker-compose.example.yml` oficial, rellena las contraseñas de base de datos,
el dominio y el remitente de correo, lo guarda en `--dir` y ejecuta
`docker compose up -d`. Los datos viven en `/srv/pterodactyl`. Se usa la imagen
estable publicada; la fuente elegida solo afecta a de dónde se descarga el
compose.

**Nativo** — instala nginx, PHP 8.4, MariaDB/MySQL, Node.js 22 + pnpm y
Composer; clona el panel desde la fuente elegida; crea la base de datos y el
usuario; escribe `.env`; ejecuta `composer install`, `pnpm install`,
`pnpm run build`, `key:generate` y `migrate --seed`; ajusta permisos para
`www-data`; escribe el vhost de nginx, el cron del planificador y el servicio
`pyroq` del worker de colas; y opcionalmente pide el certificado con certbot.

Al re-ejecutar el modo nativo se actualiza el checkout a la ref elegida
(`git reset --hard`, así que se pierden los cambios locales), se reutiliza la
contraseña de base de datos existente en `.env` y se reaplica la configuración.

**Daemons** — instala Docker (lo necesitan ambos daemons), descarga el binario
más reciente de `wings` o `elytra` para tu arquitectura, crea
`/etc/pterodactyl/config.yml` a partir de `--daemon-config` e instala la unidad
systemd. Sin fichero de configuración la unidad se crea pero no se arranca:
pega la configuración del nodo desde el panel y ejecuta
`systemctl restart wings` (o `elytra`).

## Después de instalar

Abre la URL del panel, completa el asistente de configuración (primer usuario
administrador) y, para los daemons, crea un nodo en el panel para descargar su
configuración.

## Prueba local sin DNS

Para una máquina desechable no hace falta dominio público ni certificado:

```bash
sudo bash install.sh --native --domain panel.test --no-verify -y
```

El instalador comprueba el panel contra `127.0.0.1` con `curl --resolve`, así
que no interviene el DNS, y Let's Encrypt se omite automáticamente en dominios
locales (`localhost`, `*.test`, `*.local`, IPs privadas). Para abrir el panel
en un navegador desde otra máquina, apunta el dominio a la IP del panel allí:

```bash
echo '192.168.1.50 panel.test' | sudo tee -a /etc/hosts
```

## Desarrollo y pruebas

- Comprueba la sintaxis de todos los scripts:

```bash
for f in install.sh lib/*.sh lib/modes/*.sh lang/*.sh; do bash -n "$f"; done
```

- [Shellcheck](https://www.shellcheck.net/) se ejecuta en CI
  (`.github/workflows/shellcheck.yml`).
- El instalador está pensado para probarse en una VM o contenedor nuevos con
  systemd. Nunca lo pruebes contra un panel en producción: el modo nativo
  resetea el checkout y vuelve a ejecutar las migraciones.

## Licencia

Copyright (C) 2026 Jaie55 y colaboradores.

Este proyecto es software libre bajo la **GNU General Public License v3.0**.
Puedes usarlo, modificarlo y redistribuirlo según los términos de la licencia;
si distribuyes una versión modificada, debes conservar los avisos de copyright
y publicarla bajo la misma licencia. El texto completo está disponible en el
fichero [LICENSE](./LICENSE).

Hydrodactyl en sí está bajo la licencia Apache 2.0; este instalador solo lo
descarga y configura, no incluye su código fuente.

## Notas

- El log completo se escribe en `/var/log/hydrodactyl-installer.log`.
- El script es idempotente en lo posible, pero está pensado para máquinas
  nuevas: haz copia de seguridad antes de re-ejecutarlo en un panel en
  producción.
- Revisa el script antes de ejecutarlo como root.
