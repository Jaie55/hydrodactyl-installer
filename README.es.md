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
    <img src="https://shieldcn.dev/badge/Versi%C3%B3n-v0.9.0-181717.svg?logo=github" alt="Última versión: v0.9.0">
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
el panel y los daemons a la última versión, o elimínalo todo con un comando.

Este script no está asociado con los proyectos oficiales de Hydrodactyl,
Blueprint ni Pterodactyl.

> [!NOTE]
> La v0.9.0 es una versión temprana. El instalador se ha validado de forma
> estática (`bash -n`, Shellcheck, paridad de claves EN/ES); pruébalo en una VM
> desechable antes de usarlo en una máquina de producción.

## Características

- **Instalador** — todas las combinaciones: solo panel (Docker o nativo),
  panel + Wings/Elytra (Docker o nativo) o un daemon solo (Wings/Elytra).
- **Actualizador** — detecta las versiones instaladas del panel y de los
  daemons y las actualiza a la última versión estable (`--check-updates`,
  `--update`).
- **Desinstalador** — elimina el panel, los daemons o ambos, junto con sus
  servicios y su configuración (`--uninstall`, `--purge` para borrar bases de datos y datos).
- **Nodo automático** — el instalador crea la clave de API de aplicación
  automáticamente para un panel local, crea o reutiliza el nodo, añade solo las
  asignaciones que faltan, descarga la configuración del nodo y arranca el
  daemon. También crea el primer administrador si el panel no tiene usuarios.
- **Servidor de prueba opcional** — pregunta si crear un servidor
  Vanilla/Paper en el puerto 25565 (configurable) usando la IP del nodo, y lo
  arranca.
- **Detección y resumen** — indica qué hay ya instalado (y su versión) antes de
  empezar y muestra un resumen con la URL del panel y las opciones elegidas al
  terminar.
- Cualquier fuente del panel: última versión estable, canary (`main`) o tu
  propio repositorio y rama.
- **Instalación básica o personalizada** — valores por defecto, o cada opción
  con ejemplos (zona horaria `Europe/Madrid`, configuración regional `es-ES`, puertos, PHP,
  cortafuegos, recursos del nodo...).
- **Modo producción o pruebas**, incluida la instalación totalmente local
  (`--local`, `localhost`, sin DNS ni internet).
- Certificado Let's Encrypt y cortafuegos ufw opcionales.
- Interfaz en inglés y castellano, detectada de la configuración regional del sistema.

## Ayuda y soporte

Para ayuda y soporte sobre el script y **no sobre los proyectos oficiales de
Hydrodactyl o Pterodactyl**, abre una incidencia en
<https://github.com/Jaie55/hydrodactyl-installer/issues>.

## Instalaciones compatibles

Sistemas operativos compatibles con este script de instalación.

| Sistema operativo | Versión | Panel nativo       | Panel Docker       | Daemons            | Versión de PHP |
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

- Panel nativo: Ubuntu 22.04+/Debian 12+, PHP 8.4 desde ondrej/php (versiones
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

Para fijar el instalador a una etiqueta o rama, define `HYDRODACTYL_SCRIPT_REF` (por
ejemplo `HYDRODACTYL_SCRIPT_REF=v0.9.0 bash <(curl ...)`).

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

# Panel desde tu propio repositorio y rama
sudo bash install.sh --native --repo=https://github.com/tu-usuario/hydrodactyl --ref=mi-rama --domain panel.ejemplo.com

# Panel local de pruebas (sin DNS, sin internet, administrador en http://localhost)
sudo bash install.sh --native --local -y

# Solo el daemon, creando el nodo por la API del panel
sudo bash install.sh --daemon=wings --panel-url=http://127.0.0.1 --api-key=hydro_xxx -y
```

### Opciones

| Opción                             | Descripción                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `--docker`                         | Instala el panel con Docker Compose                                             |
| `--native`                         | Instala el panel de forma nativa (nginx + PHP-FPM + MariaDB/MySQL)              |
| `--basic` / `--custom`             | Instalación básica (por defecto) o personalizada (pregunta cada opción)         |
| `--local`                          | Instalación local de pruebas: `localhost` por defecto, sin SSL                  |
| `--environment=production\|test`   | Producción: depuración desactivada, configuración en caché, avisos estrictos de dominio/HTTPS. Pruebas: depuración activada, configuración sin caché |
| `--source=stable\|canary\|custom`  | `stable` = última etiqueta de versión, `canary` = `main`, `custom` = `--repo`/`--ref` |
| `--repo=URL`                       | Repositorio del panel personalizado (implica `--source=custom`)                  |
| `--ref=BRANCH`                     | Rama o etiqueta del repositorio personalizado                                   |
| `--domain=DOMAIN`                  | Dominio del panel (opcional en pruebas, por defecto `localhost`)                 |
| `--dir=PATH`                       | Directorio del panel (por defecto `/var/www/hydrodactyl`)                        |
| `--db=mariadb\|mysql`              | Motor de base de datos para la instalación nativa                                |
| `--db-name=NAME`                   | Nombre de la base de datos (por defecto `panel`)                                 |
| `--db-user=USER`                   | Usuario de la base de datos (por defecto `hydrodactyl`)                          |
| `--db-password=PASS`               | Contraseña de la base de datos (por defecto: generada)                           |
| `--php=8.4\|8.5`                   | Versión de PHP para la instalación nativa (por defecto `8.4`)                    |
| `--timezone=TZ`                    | Zona horaria de la aplicación (por defecto `UTC`)                               |
| `--locale=LOCALE`                  | Configuración regional de la aplicación (por defecto `en-US`)                   |
| `--http-port=PORT`                 | Puerto HTTP (por defecto `80`)                                                  |
| `--firewall` / `--no-firewall`     | Configurar ufw (SSH, HTTP, HTTPS y puertos del daemon)                          |
| `--daemon=wings\|elytra`           | Instala un daemon                                                               |
| `--daemon-config=PATH`             | Fichero de configuración del nodo descargado del panel                           |
| `--daemon-version=TAG`             | Etiqueta de versión del daemon (por defecto: la última)                         |
| `--daemon-port=PORT`               | Puerto de escucha del daemon (por defecto `8080`)                               |
| `--sftp-port=PORT`                 | Puerto SFTP (por defecto `2022`)                                                |
| `--node-scheme=http\|https`        | Esquema del panel al daemon (por defecto `http`)                                |
| `--behind-proxy`                   | El nodo está detrás de un proxy                                                 |
| `--panel-url=URL`                  | URL del panel para configurar el nodo (por defecto: la detectada)                 |
| `--api-key=KEY`                    | Clave de API de aplicación del panel (se crea automáticamente para un panel local) |
| `--node-name=NAME`                 | Nombre del nodo (por defecto: nombre de host)                                    |
| `--node-fqdn=HOST`                 | FQDN/IP del nodo accesible desde el panel (por defecto: IP primaria)             |
| `--memory=MB` / `--disk=MB`        | Recursos del nodo (por defecto: detectados)                                      |
| `--ports=LIST`                     | Asignaciones separadas por comas (por defecto `25565-25665,27015-27150`)          |
| `--no-node`                        | No crear el nodo automáticamente                                                 |
| `--test-server` / `--no-test-server` | Crear un servidor de prueba de Minecraft en el puerto 25565 (u omitirlo)        |
| `--test-server-egg=EGG`            | Plantilla (egg) del servidor de prueba (por defecto `vanilla`)                   |
| `--test-server-port=PORT`          | Puerto del servidor de prueba (por defecto `25565`)                             |
| `--test-server-memory=MB`          | Memoria del servidor de prueba en MiB (por defecto `1024`)                      |
| `--test-server-disk=MB`            | Disco del servidor de prueba en MiB (por defecto `5120`)                        |
| `--admin-email=EMAIL`              | Correo del primer administrador (por defecto `admin@example.com`)                |
| `--admin-username=NAME`            | Usuario del primer administrador (por defecto `admin`)                           |
| `--admin-password=PASS`            | Contraseña del primer administrador (por defecto: generada)                      |
| `--no-auto-admin`                  | No crear el primer administrador automáticamente                                 |
| `--check-updates`                  | Muestra las versiones instaladas y las últimas del panel y de los daemons       |
| `--update[=panel\|daemon]`         | Actualiza el panel, los daemons o ambos                                         |
| `--uninstall[=panel\|daemon\|all\|wings\|elytra]` | Desinstala los objetivos indicados                              |
| `--purge`                          | Con `--uninstall`, borra también la base de datos y los directorios de datos     |
| `--ssl`                            | Pide un certificado gratuito con Let's Encrypt                                  |
| `--no-verify`                      | Omite la comprobación final de que el panel responde (CI/pruebas locales)        |
| `--dry-run`                        | Muestra el plan y sale sin instalar                                             |
| `--version`                        | Muestra la versión del instalador                                               |
| `--lang=en\|es`                    | Idioma de la interfaz                                                            |
| `-y`, `--yes`                      | No interactivo, usa los valores por defecto                                      |
| `-h`, `--help`                     | Muestra la ayuda                                                                 |

## Nodo automático

El daemon se puede configurar sin copiar nada a mano. Cuando el panel está en la
misma máquina, el instalador crea la clave de API de aplicación automáticamente (con
permisos limitados) y:

1. crea el primer usuario administrador si el panel no tiene ninguno (las
   credenciales se muestran en el resumen y se guardan en
   `/root/hydrodactyl-admin.txt`),
2. crea una localización si el panel no tiene ninguna,
3. reutiliza un nodo existente con el mismo FQDN o crea uno nuevo,
4. crea solo las asignaciones de puertos que faltan,
5. ejecuta `wings configure` / `elytra configure` para descargar la
   configuración del nodo,
6. arranca el servicio systemd y comprueba que está escuchando, y
7. opcionalmente crea un servidor de prueba de Minecraft en el puerto 25565.

Para un panel remoto, crea una clave de API de aplicación en el panel y pásala con
`--api-key`; el instalador seguirá creando el nodo y las asignaciones. Si no se
puede configurar el nodo, pega la configuración desde el panel en
`/etc/pterodactyl/config.yml` y ejecuta `systemctl restart wings` (o `elytra`).

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

- Panel nativo: descarga la última etiqueta estable, recompila la interfaz web y las
  dependencias, ejecuta las migraciones y recarga nginx, PHP-FPM y la cola.
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

En modo de pruebas local el dominio por defecto es `localhost`, así que no hace falta
DNS ni salida a internet. El instalador comprueba el panel contra `127.0.0.1`
con `curl --resolve`, y Let's Encrypt se omite automáticamente en dominios
locales (`localhost`, `*.test`, `*.local`, direcciones IP privadas). Para abrir el panel
en un navegador desde otra máquina, apunta el dominio a la IP del panel allí:

```bash
echo '192.168.1.50 panel.test' | sudo tee -a /etc/hosts
```

## Qué hace cada modo

**Docker** — instala Docker si falta, descarga el
`docker-compose.example.yml` oficial, rellena las contraseñas de base de datos,
el dominio, la zona horaria, la configuración regional y el remitente de correo, lo guarda en
`--dir` y ejecuta `docker compose up -d`. Los datos viven en
`/srv/pterodactyl`. Se usa la imagen estable publicada; la fuente elegida solo
afecta al origen del compose. Los contenedores se reinician con el
sistema (`unless-stopped`). ufw se omite en modo Docker porque Docker publica
sus propios puertos y ufw no los filtraría.

**Nativo** — instala nginx, PHP, MariaDB/MySQL, Node.js + pnpm y Composer;
clona el panel desde la fuente elegida; crea la base de datos y el usuario;
escribe `.env`; ejecuta `composer install`, `pnpm install`, `pnpm run build` y
`migrate --seed`; ajusta permisos para `www-data`; escribe el host virtual de nginx, el
cron del planificador y el servicio `pyroq` de la cola de trabajos; y
opcionalmente pide el certificado con certbot.

Al reejecutar el instalador se actualiza el repositorio a la referencia elegida
(`git reset --hard`, así que se pierden los cambios locales), se reutiliza la
contraseña de base de datos existente en `.env` y se reaplica la configuración.
Al terminar se muestra un resumen con la URL del panel y la configuración
elegida.

## Después de instalar

El instalador crea el primer administrador automáticamente si el panel no tiene
usuarios; el correo electrónico y la contraseña generada se muestran en el resumen y se
guardan en `/root/hydrodactyl-admin.txt`. Cambia la contraseña al entrar. La clave
de API y el nodo se crean automáticamente para paneles locales. Si pediste un
servidor de prueba, conéctate a `<ip-del-nodo>:25565`.

## Solución de problemas

- **WebSocket de Wings 403 / `request origin not allowed`**: Wings solo acepta
  el origen del navegador que coincide con la URL `remote` configurada en Wings. Usa en el
  navegador la misma URL que el panel (`APP_URL`). Vuelve a ejecutar el
  instalador o edita `/etc/pterodactyl/config.yml` (`remote: http://localhost`)
  y ejecuta `systemctl restart wings`.
- **Wings no escucha en 8080**: `systemctl status wings`,
  `journalctl -u wings -n 100 --no-pager`, `ss -ltnp | grep -E ':8080|:2022'`.
  Comprueba que Docker está en marcha (`docker info`).
- **Panel local inaccesible desde la LAN**: `localhost` solo funciona en el
  servidor. Usa `--domain=<ip-del-servidor>` y accede por esa IP.
- **Let's Encrypt falla**: el dominio debe resolver al servidor y el puerto 80
  debe ser accesible desde internet.
- **Actualización Docker**: haz una copia de seguridad de la base de datos antes
  de ejecutar `--update`.

## Desarrollo y pruebas

- Comprueba la sintaxis de todos los scripts:

```bash
for f in install.sh lib/*.sh lib/modes/*.sh lang/*.sh tests/*.sh; do bash -n "$f"; done
```

- Pruebas unitarias: `bash tests/run.sh` (requiere `jq`).
- Sintaxis de PHP: `php -l config/panel-key.php`.
- [Shellcheck](https://www.shellcheck.net/) se ejecuta en CI
  (`.github/workflows/shellcheck.yml`).
- El instalador está pensado para probarse en una VM o un contenedor nuevos con
  systemd. Nunca lo pruebes contra un panel en producción: el modo nativo
  restablece el repositorio y vuelve a ejecutar las migraciones.

## Licencia

Derechos de autor (C) 2026 Jaie55 y colaboradores.

Este proyecto es software libre bajo la **GNU General Public License v3.0**.
Puedes usarlo, modificarlo y redistribuirlo según los términos de la licencia;
si distribuyes una versión modificada, debes conservar los avisos de derechos de autor
y publicarla bajo la misma licencia. El texto completo está disponible en el
fichero [LICENSE](./LICENSE).

Hydrodactyl en sí está bajo la licencia Apache 2.0; este instalador solo lo
descarga y configura, no incluye su código fuente.

## Notas

- El registro completo se escribe en `/var/log/hydrodactyl-installer.log`.
- El script es idempotente en lo posible, pero está pensado para máquinas
  nuevas: haz una copia de seguridad antes de reejecutarlo en un panel en
  producción.
- Revisa el script antes de ejecutarlo como root.
