<p align="center">
  <a href="README.md">
    <img src="https://shieldcn.dev/badge/Language-English-181717.svg?logo=github" alt="English">
  </a>
  <a href="README.es.md">
    <img src="https://shieldcn.dev/badge/Language-Espa%C3%B1ol-success.svg?logo=github" alt="Español">
  </a>
</p>

<br/>

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
    <img src="https://shieldcn.dev/badge/Release-v0.8.0-181717.svg?logo=github" alt="Última release: v0.8.0">
  </a>
  <img src="https://shieldcn.dev/badge/Hecho%20con-Bash-1f425f.svg?logo=gnubash" alt="Hecho con Bash">
  <img src="https://shieldcn.dev/badge/Plataforma-Linux-f0b429.svg?logo=linux" alt="Plataforma Linux">
  <img src="https://shieldcn.dev/badge/Licencia-GPL%20v3-181717.svg?logo=gnu" alt="Licencia: GPL v3">
</p>

<br/>

**Instalador, actualizador y desinstalador** no oficial del panel
[Hydrodactyl](https://github.com/BlueprintFramework/hydrodactyl) y de sus
daemons de servidores de juego (Pterodactyl Wings o pyrohost Elytra). Instala
el panel con Docker o de forma nativa, crea el nodo automáticamente, actualiza
el panel y los daemons a la última release, o elimínalo todo con un comando.

Este script no está asociado con los proyectos oficiales de Hydrodactyl,
Blueprint ni Pterodactyl.

> [!NOTE]
> La v0.8.0 es una versión temprana. El instalador se ha validado de forma
> estática (`bash -n`, Shellcheck, paridad de claves EN/ES); pruébalo en una VM
> desechable antes de usarlo en una máquina de producción.

## Características

- **Instalador** — todas las combinaciones: solo panel (Docker o nativo),
  panel + Wings/Elytra (Docker o nativo) o un daemon solo (Wings/Elytra).
- **Actualizador** — detecta las versiones instaladas del panel y de los
  daemons y las actualiza a la última release estable (`--check-updates`,
  `--update`).
- **Desinstalador** — elimina el panel y/o los daemons, sus servicios y su
  configuración (`--uninstall`, `--purge` para borrar bases de datos y datos).
- **Nodo automático** — con una API key de aplicación del panel crea la
  localización, el nodo y las asignaciones de puertos por API, descarga la
  configuración del nodo y arranca el daemon.
- **Detección y resumen** — indica qué hay ya instalado (y su versión) antes de
  empezar y muestra un resumen con la URL del panel y las opciones elegidas al
  terminar.
- Cualquier fuente del panel: última release estable, canary (`main`) o tu
  propio fork y rama.
- **Instalación básica o personalizada** — valores por defecto, o cada opción
  con ejemplos (zona horaria `Europe/Madrid`, locale `es-ES`, puertos, PHP,
  firewall, recursos del nodo...).
- **Modo producción o pruebas**, incluida la instalación totalmente local
  (`--local`, `localhost`, sin DNS ni internet).
- Certificado Let's Encrypt y firewall ufw opcionales.
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

- Panel nativo: Ubuntu 22.04+/Debian 12+, PHP 8.4 desde ondrej/php (releases
  de Ubuntu que aún lo tengan) o packages.sury.org (Debian y Ubuntu nuevos).
- Daemons: Ubuntu/Debian en amd64 o arm64 (las únicas arquitecturas publicadas
  por Wings y Elytra).
- Panel Docker: cualquier distribución donde se pueda instalar Docker Engine.

## Uso de los scripts de instalación

Para instalar, ejecuta este comando como root. El menú ofrece todas las
combinaciones y también las acciones de actualizar y desinstalar.

```bash
# Ubuntu Server minimal no trae curl: instálalo primero
apt update && apt install -y curl

bash <(curl -fsSL https://raw.githubusercontent.com/Jaie55/hydrodactyl-installer/main/install.sh)
```

Si `curl` ya está instalado, solo hace falta la última línea. Una vez en
ejecución, el script instala por su cuenta cualquier dependencia que falte. En
modo interactivo pregunta si quieres una instalación **básica** (por defecto) o
**personalizada**, donde cada opción se pide con un ejemplo.

Ejemplos totalmente automatizados:

```bash
# Panel con Docker (recomendado)
sudo bash install.sh --docker --domain panel.ejemplo.com --ssl

# Panel nativo (Ubuntu/Debian) desde la rama canary
sudo bash install.sh --native --source=canary --domain panel.ejemplo.com --ssl -y

# Panel desde tu propio fork y rama
sudo bash install.sh --native --repo=https://github.com/tu-usuario/hydrodactyl --ref=mi-rama --domain panel.ejemplo.com

# Panel local de pruebas (sin DNS, sin internet, admin en http://localhost)
sudo bash install.sh --native --local -y

# Solo el daemon, creando el nodo por la API del panel
sudo bash install.sh --daemon=wings --panel-url=http://127.0.0.1 --api-key=ptla_xxx -y
```

### Opciones

| Opción                             | Descripción                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `--docker`                         | Instala el panel con Docker Compose                                             |
| `--native`                         | Instala el panel de forma nativa (nginx + PHP-FPM + MariaDB/MySQL)              |
| `--basic` / `--custom`             | Instalación básica (por defecto) o personalizada (pregunta cada opción)         |
| `--local`                          | Instalación local de pruebas: modo test, `localhost` por defecto, sin SSL       |
| `--environment=production\|test`   | Producción: debug off, config cacheada, avisos estrictos de dominio/HTTPS. Test: debug on, config sin cachear |
| `--source=stable\|canary\|custom`  | `stable` = último tag de release, `canary` = `main`, `custom` = `--repo`/`--ref` |
| `--repo=URL`                       | Repositorio del panel personalizado (implica `--source=custom`)                  |
| `--ref=BRANCH`                     | Rama o tag del repositorio personalizado                                         |
| `--domain=DOMAIN`                  | Dominio del panel (opcional en test, por defecto `localhost`)                    |
| `--dir=PATH`                       | Directorio del panel (por defecto `/var/www/hydrodactyl`)                        |
| `--db=mariadb\|mysql`              | Motor de base de datos para la instalación nativa                                |
| `--db-name=NAME`                   | Nombre de la base de datos (por defecto `panel`)                                 |
| `--db-user=USER`                   | Usuario de la base de datos (por defecto `hydrodactyl`)                          |
| `--db-password=PASS`               | Contraseña de la base de datos (por defecto: generada)                           |
| `--php=8.3\|8.4\|8.5`              | Versión de PHP para la instalación nativa (por defecto `8.4`)                    |
| `--timezone=TZ`                    | Zona horaria de la aplicación (por defecto `UTC`)                               |
| `--locale=LOCALE`                  | Locale de la aplicación (por defecto `en-US`)                                   |
| `--http-port=PORT`                 | Puerto HTTP (por defecto `80`)                                                  |
| `--firewall` / `--no-firewall`     | Configurar ufw (SSH, HTTP, HTTPS y puertos del daemon)                          |
| `--daemon=wings\|elytra`           | Instala un daemon                                                               |
| `--daemon-config=PATH`             | Fichero de configuración del nodo descargado del panel                           |
| `--daemon-version=TAG`             | Tag de release del daemon (por defecto: última)                                 |
| `--daemon-port=PORT`               | Puerto de escucha del daemon (por defecto `8080`)                               |
| `--sftp-port=PORT`                 | Puerto SFTP (por defecto `2022`)                                                |
| `--node-scheme=http\|https`        | Esquema panel -> daemon (por defecto `http`)                                    |
| `--behind-proxy`                   | El nodo está detrás de un proxy                                                 |
| `--panel-url=URL`                  | URL del panel para configurar el nodo (por defecto `http://127.0.0.1`)            |
| `--api-key=KEY`                    | API key de aplicación del panel (se pregunta si se omite)                        |
| `--node-name=NAME`                 | Nombre del nodo (por defecto: hostname)                                          |
| `--node-fqdn=HOST`                 | FQDN/IP del nodo accesible desde el panel (por defecto: IP primaria)             |
| `--memory=MB` / `--disk=MB`        | Recursos del nodo (por defecto: detectados)                                      |
| `--ports=LIST`                     | Asignaciones separadas por comas (por defecto `25565-25665,27015-27150`)          |
| `--no-node`                        | No crear el nodo automáticamente                                                 |
| `--check-updates`                  | Muestra las versiones instaladas y las últimas de panel/daemon                   |
| `--update[=panel\|daemon]`         | Actualiza el panel y/o los daemons detectados                                    |
| `--uninstall[=panel\|daemon\|all\|wings\|elytra]` | Desinstala los objetivos indicados                              |
| `--purge`                          | Con `--uninstall`, borra también la base de datos y los directorios de datos     |
| `--ssl`                            | Pide un certificado gratuito con Let's Encrypt                                  |
| `--no-verify`                      | Omite la comprobación final de que el panel responde (CI/pruebas locales)        |
| `--lang=en\|es`                    | Idioma de la interfaz                                                            |
| `-y`, `--yes`                      | No interactivo, asume sí                                                         |
| `-h`, `--help`                     | Muestra la ayuda                                                                 |

## Nodo automático

El daemon se puede configurar sin copiar nada a mano. Crea una **API key de
aplicación** en el panel (Admin → Application API → Create) y el instalador:

1. crea una localización si el panel no tiene ninguna,
2. crea el nodo con la memoria, disco y FQDN detectados (o indicados),
3. crea las asignaciones de puertos,
4. ejecuta `wings configure` / `elytra configure` para descargar la
   configuración del nodo, y
5. arranca el servicio systemd.

Para un panel en la misma máquina usa `--panel-url=http://127.0.0.1`. Sin key la
unidad se crea pero no se arranca: pega la configuración del nodo desde el panel
en `/etc/pterodactyl/config.yml` y ejecuta `systemctl restart wings` (o
`elytra`).

## Actualizar el panel y los daemons

El script también funciona como **actualizador del panel Hydrodactyl**:

```bash
# Ver versiones instaladas y últimas disponibles
sudo bash install.sh --check-updates

# Actualizar el panel y los daemons detectados
sudo bash install.sh --update

# Actualizar solo el panel o solo los daemons
sudo bash install.sh --update=panel
sudo bash install.sh --update=daemon
```

- Panel nativo: baja el último tag estable, recompila frontend y dependencias,
  ejecuta migraciones y recarga nginx/PHP-FPM/cola.
- Panel Docker: descarga la última imagen y recrea los contenedores.
- Daemons: descarga el último binario de Wings/Elytra y reinicia el servicio.

El menú interactivo (opciones 9/10) ofrece las mismas acciones.

## Desinstalar

```bash
# Desinstalar todo lo que esté instalado
sudo bash install.sh --uninstall

# Desinstalar solo el panel o solo los daemons
sudo bash install.sh --uninstall=panel
sudo bash install.sh --uninstall=daemon
sudo bash install.sh --uninstall=wings

# Borrar también la base de datos y los directorios de datos
sudo bash install.sh --uninstall --purge
```

Sin `--purge` se conservan la base de datos del panel y los directorios de
datos de los daemons (`/srv/pterodactyl`, `/var/lib/pterodactyl`).

## Prueba local sin DNS

Para una máquina desechable no hace falta dominio público ni certificado:

```bash
sudo bash install.sh --native --local -y
```

En modo test/local el dominio por defecto es `localhost`, así que no hace falta
DNS ni salida a internet. El instalador comprueba el panel contra `127.0.0.1`
con `curl --resolve`, y Let's Encrypt se omite automáticamente en dominios
locales (`localhost`, `*.test`, `*.local`, IPs privadas). Para abrir el panel
en un navegador desde otra máquina, apunta el dominio a la IP del panel allí:

```bash
echo '192.168.1.50 panel.test' | sudo tee -a /etc/hosts
```

## Qué hace cada modo

**Docker** — instala Docker si falta, descarga el
`docker-compose.example.yml` oficial, rellena las contraseñas de base de datos,
el dominio, la zona horaria, el locale y el remitente de correo, lo guarda en
`--dir` y ejecuta `docker compose up -d`. Los datos viven en
`/srv/pterodactyl`. Se usa la imagen estable publicada; la fuente elegida solo
afecta a de dónde se descarga el compose. Los contenedores se reinician con el
sistema (`unless-stopped`). ufw se omite en modo Docker porque Docker publica
sus propios puertos y lo saltaría.

**Nativo** — instala nginx, PHP, MariaDB/MySQL, Node.js + pnpm y Composer;
clona el panel desde la fuente elegida; crea la base de datos y el usuario;
escribe `.env`; ejecuta `composer install`, `pnpm install`, `pnpm run build` y
`migrate --seed`; ajusta permisos para `www-data`; escribe el vhost de nginx, el
cron del planificador y el servicio `pyroq` del worker de colas; y
opcionalmente pide el certificado con certbot.

Al re-ejecutar el instalador se actualiza el checkout a la ref elegida
(`git reset --hard`, así que se pierden los cambios locales), se reutiliza la
contraseña de base de datos existente en `.env` y se reaplica la configuración.
Al terminar se muestra un resumen con la URL del panel y la configuración
elegida.

## Después de instalar

Abre la URL del panel, completa el asistente de configuración (primer usuario
administrador) y, para los daemons, crea un nodo en el panel o deja que el
instalador lo cree con una API key de aplicación.

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
