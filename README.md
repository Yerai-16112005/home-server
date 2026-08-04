<div align="center">

# 🏡 Home Server

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Nginx Proxy Manager](https://img.shields.io/badge/Nginx_Proxy_Manager-009639?style=for-the-badge&logo=nginx&logoColor=white)
![AdGuard Home](https://img.shields.io/badge/AdGuard_Home-008332?style=for-the-badge&logo=adguard&logoColor=white)
![Nextcloud](https://img.shields.io/badge/Nextcloud-0082C9?style=for-the-badge&logo=nextcloud&logoColor=white)
![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?style=for-the-badge&logo=jellyfin&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

**Infraestructura self-hosted completa: nube privada, servidor de medios, NAS y DNS local, todo desplegado con Docker Compose y segmentado por redes.**

</div>

---

> **⚠️ Aviso importante:** Esta configuración está pensada como punto de partida funcional, no como solución de producción endurecida. Cubre los fundamentos de seguridad (redes aisladas, puertos restringidos, sin credenciales en el código), pero cada servicio admite configuración adicional mucho más avanzada: autenticación de dos factores, cifrado en reposo, auditoría de accesos, alertas, backups automatizados, hardening de Samba, HTTPS forzado, cabeceras de seguridad HTTP, fail2ban, etc. Se recomienda encarecidamente investigar y aplicar las medidas adicionales que correspondan a tu caso de uso antes de almacenar datos sensibles.

---

## ⚠️ Descargo de Responsabilidad

**Este repositorio se proporciona tal cual, sin garantías de ningún tipo.**

El autor no se hace responsable de ningún daño, pérdida de datos, fallo de seguridad, acceso no autorizado, interrupción del servicio ni cualquier otro perjuicio que pueda derivarse del uso, modificación o despliegue de este proyecto, ya sea de forma directa o indirecta.

Al clonar y utilizar este repositorio aceptas que:

- Eres el único responsable de la seguridad de tu infraestructura y de los datos que almacenes en ella.
- Debes realizar copias de seguridad periódicas de tus datos. Este stack no incluye ningún mecanismo de backup por defecto.
- Si expones algún servicio a Internet (por ejemplo mediante Cloudflare Tunnel), la responsabilidad de securizarlo adecuadamente es exclusivamente tuya.
- El uso de este proyecto en entornos de producción o con datos críticos queda bajo tu propio riesgo.

---

## 📦 Servicios

| Servicio | URL local | Descripción |
| :--- | :--- | :--- |
| **Nginx Proxy Manager** | `http://127.0.0.1:81` *(solo setup)* | Reverse proxy y gestión de certificados SSL |
| **AdGuard Home** | `http://adguard.home` | DNS local con bloqueo de publicidad |
| **Nextcloud** | `http://cloud.home` | Nube privada y sincronización de archivos |
| **Jellyfin** | `http://media.home` | Servidor de medios (películas, series, música) |
| **Portainer** | `http://portainer.home` | Panel de gestión de contenedores Docker |
| **Dozzle** | `http://dozzle.home` | Visor de logs de contenedores en tiempo real |
| **Samba (NAS)** | `smb://nas.home` | Almacenamiento compartido en red local |

> **Requisito para acceder por nombre de dominio:** Para que `cloud.home`, `media.home` y el resto de dominios `.home` funcionen, el dispositivo desde el que accedes debe tener configurado como **servidor DNS primario la IP de tu servidor** (donde corre AdGuard Home). Si el DNS de tu dispositivo o router sigue apuntando a otro servidor (Google, tu ISP, etc.), los dominios `.home` no resolverán. Consulta la sección [Configuración del DNS en tus dispositivos](#-configuración-del-dns-en-tus-dispositivos) para más detalles.

---

## 📐 Arquitectura de Red

El stack utiliza **cinco redes Docker completamente aisladas entre sí** para segmentar el tráfico y reducir la superficie de ataque. Cada contenedor solo tiene acceso a las redes que necesita y ninguna más.

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                      RED LOCAL (LAN)                            │
  │   Dispositivos: PCs, móviles, Smart TVs, etc.                   │
  └──────────┬──────────────────────────────────────────────────────┘
             │  DNS (UDP/TCP 53)
             ▼
  ┌──────────────────────────────────────────────────────────────┐
  │               dns_cloudflare_net  10.10.0.0/27               │
  │  ┌─────────────────────────────┐  ┌────────────────────────┐ │
  │  │      AdGuard Home           │  │   Cloudflare Tunnel    │ │
  │  │      10.10.0.20             │  │   10.10.0.30           │ │
  │  │  Resuelve *.home → SERVER_IP│  │  (perfil opcional)     │ │
  │  └──────────────┬──────────────┘  └────────────┬───────────┘ │
  └─────────────────│────────────────────────────── │ ────────────┘
                    │                               │
                    │  HTTP/HTTPS (80/443)          │ HTTPS cifrado
                    ▼                               ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                    edge_net  10.0.0.0/27                      │
  │  ┌──────────────────────────────────────────────────────────┐ │
  │  │               Nginx Proxy Manager  10.0.0.10             │ │
  │  │    Enruta cada dominio .home al contenedor correcto       │ │
  │  │    adguard.home  cloud.home  media.home  portainer.home   │ │
  │  └──────────────────────────┬───────────────────────────────┘ │
  └─────────────────────────────│────────────────────────────────┘
                                │
  ┌─────────────────────────────│────────────────────────────────┐
  │              apps_net  10.20.0.0/24                           │
  │                             │                                 │
  │     ┌───────────┬───────────┼────────────┬──────────┐        │
  │     ▼           ▼           ▼            ▼          ▼        │
  │ ┌────────┐ ┌─────────┐ ┌────────┐ ┌──────────┐ ┌───────┐   │
  │ │  NPM   │ │Nextcloud│ │Jellyfin│ │Portainer │ │Dozzle │   │
  │ │.10     │ │.40      │ │.50     │ │.20       │ │.30    │   │
  │ └────────┘ └────┬────┘ └────────┘ └──────────┘ └───────┘   │
  └─────────────────│────────────────────────────────────────────┘
                    │
  ┌─────────────────│──────────────────┐
  │  nextcloud_db_net  10.40.0.0/27    │   ← internal: true
  │       (red completamente aislada)  │     Sin acceso al exterior
  │  ┌────────────────────────────┐    │
  │  │     MariaDB  10.40.0.20    │    │
  │  │  Solo accesible desde      │    │
  │  │  Nextcloud (10.40.0.10)    │    │
  │  └────────────────────────────┘    │
  └────────────────────────────────────┘

  ┌────────────────────────────────────────────────────────┐
  │              storage_net  10.30.0.0/28                  │
  │  ┌──────────────────────────────────────────────────┐  │
  │  │              Samba  10.30.0.10                   │  │
  │  │  Puerto 445 expuesto SOLO a SERVER_IP (no 0.0.0.0)│  │
  │  │  /storage/public  /storage/media  /storage/users  │  │
  │  └──────────────────────────────────────────────────┘  │
  └────────────────────────────────────────────────────────┘
```

### Tabla de redes

| Red | Subred | Propósito | Contenedores |
| :--- | :--- | :--- | :--- |
| `edge_net` | `10.0.0.0/27` | Tráfico HTTP/HTTPS entrante | NPM |
| `dns_cloudflare_net` | `10.10.0.0/27` | DNS y túnel Cloudflare | AdGuard, Cloudflared, NPM |
| `apps_net` | `10.20.0.0/24` | Aplicaciones de usuario | NPM, Nextcloud, Jellyfin, Portainer, Dozzle |
| `storage_net` | `10.30.0.0/28` | NAS | Samba |
| `nextcloud_db_net` | `10.40.0.0/27` | Base de datos *(aislada)* | Nextcloud, MariaDB |

---

## 📁 Estructura del Proyecto

```
home-server/
├── config/
│   ├── npm/            # Datos y certificados SSL de Nginx Proxy Manager
│   ├── adguard/        # Configuración de AdGuard Home
│   ├── nextcloud/      # Archivos de la aplicación Nextcloud
│   ├── nextcloud_db/   # Base de datos MariaDB
│   ├── jellyfin/       # Configuración de Jellyfin
│   ├── jellyfin_cache/ # Caché de Jellyfin
│   ├── portainer/      # Datos de Portainer
│   └── samba/          # config.yml de Samba (generado por setup.sh, no en el repo)
├── storage/
│   ├── public/         # Carpeta compartida pública (sin autenticación)
│   ├── media/          # Biblioteca de medios (Jellyfin + Samba)
│   └── users/          # Carpeta privada por usuario + datos de Nextcloud
├── docker-compose.yml
├── setup.sh            # Script de configuración inicial
├── .env                # Variables de entorno (no en el repo)
├── .env.example        # Plantilla de variables
└── .gitignore
```

---

## 🚀 Despliegue

### Requisitos

- Linux con **Docker Engine** y **Docker Compose V2**
- Puerto `53` libre en el host (para AdGuard como DNS)
- Puerto `445` libre en el host (para Samba)
- IP fija en el servidor dentro de tu red local

### 1. Clonar el repositorio

```bash
git clone https://github.com/Yerai-16112005/home-server.git
cd home-server
```

### 2. Configurar las variables de entorno

```bash
cp .env.example .env
```

Edita `.env` con tus valores:

```env
TZ=Europe/Madrid
SERVER_IP=192.168.1.X        # IP fija de tu servidor en la red local

SAMBA_USER=tuusuario
SAMBA_PASSWORD=tucontraseña

NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=tucontraseña
NEXTCLOUD_DB_PASSWORD=tucontraseña
NEXTCLOUD_DB_ROOT_PASSWORD=tucontraseña

CLOUDFLARE_TUNNEL_TOKEN=     # Solo si usas acceso externo vía Cloudflare
```

### 3. Ejecutar el script de setup

```bash
bash setup.sh
```

El script crea la estructura de directorios, genera el `config.yml` de Samba con tus credenciales y valida que todas las variables estén definidas.

### 4. Descomentar los puertos de configuración inicial

Antes del primer arranque, abre `docker-compose.yml` y descomenta temporalmente:

- Puerto `81` de NPM → panel de administración del reverse proxy
- Puertos `3000` y `8080` de AdGuard → asistente de configuración inicial

### 5. Arrancar los servicios

```bash
docker compose up -d
```

Para activar también el túnel de Cloudflare:

```bash
docker compose --profile external_access up -d
```

---

## ⚙️ Configuración Inicial

### AdGuard Home

1. Accede a `http://127.0.0.1:3000` y completa el asistente de instalación.
2. Una vez instalado, entra en `http://127.0.0.1:8080`.
3. Ve a **Filtros → Reescritura DNS → Añadir reescritura DNS** y crea la regla:
   - Dominio: `*.home`
   - IP: la IP fija de tu servidor (`SERVER_IP`)

Esto hace que cualquier URL terminada en `.home` resuelva a tu servidor, donde NPM se encarga de enrutarla al contenedor correcto.

### Nginx Proxy Manager

1. Accede a `http://127.0.0.1:81` y crea la cuenta de administrador.
2. Ve a **Hosts → Proxy Hosts → Add Proxy Host** y añade una entrada por cada servicio:

| Domain | Scheme | Forward Hostname | Forward Port |
| :--- | :--- | :--- | :--- |
| `adguard.home` | http | `adguardhome` | `80` |
| `portainer.home` | http | `portainer` | `9000` |
| `dozzle.home` | http | `dozzle` | `8080` |
| `cloud.home` | http | `nextcloud` | `80` |
| `media.home` | http | `jellyfin` | `8096` |

> En todos los proxy hosts se recomienda activar **Block Common Exploits** y **Websockets Support**.

### Resto de servicios

Accede uno a uno por su URL y completa la configuración inicial. El usuario y contraseña de **Nextcloud** son los definidos en `.env` (`NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`). El de **Samba** son `SAMBA_USER` / `SAMBA_PASSWORD`.

En **Jellyfin**, al crear la biblioteca de medios usa `/media` como ruta. Esa carpeta está mapeada a `./storage/media` en el host — copia ahí tus películas, series y música.

### Cerrar puertos de configuración

Una vez terminada la configuración inicial, vuelve a comentar en `docker-compose.yml` los puertos `81` (NPM), `3000` y `8080` (AdGuard) y reinicia los contenedores afectados:

```bash
docker compose up -d --force-recreate npm adguardhome
```

---

## 🌐 Configuración del DNS en tus Dispositivos

Para acceder a `cloud.home`, `media.home` y el resto de dominios `.home`, **cada dispositivo desde el que quieras acceder debe usar AdGuard Home como servidor DNS primario**. Sin esto, los dominios no resolverán, ya que son dominios locales que no existen en Internet.

Tienes dos opciones:

**Opción A — Configurar el router (recomendado):**
Entra en la configuración de tu router y establece la IP de tu servidor como servidor DNS primario. Todos los dispositivos de la red que obtengan su configuración por DHCP lo usarán automáticamente.

**Opción B — Configurar cada dispositivo manualmente:**
En la configuración de red de cada dispositivo (red Wi-Fi o Ethernet), cambia el DNS primario a la IP de tu servidor. El proceso varía según el sistema operativo.

> Si tras configurar el DNS los dominios siguen sin resolver, asegúrate de que la regla `*.home → SERVER_IP` está correctamente creada en AdGuard Home y de que el contenedor está corriendo con `docker ps`.

---

## 💾 NAS — Acceso a las carpetas compartidas

El NAS es accesible desde cualquier dispositivo de la red local:

| Carpeta | Ruta | Acceso |
| :--- | :--- | :--- |
| `Public` | `smb://nas.home/Public` | Sin autenticación |
| `Media` | `smb://nas.home/Media` | Sin autenticación (solo lectura) |
| `Users` | `smb://nas.home/Users` | Usuario y contraseña (`.env`) |

> La carpeta `Users` no aparece al explorar `smb://nas.home` por diseño. Hay que acceder directamente con la ruta completa.

---

## 🌐 Acceso Externo (Opcional)

El stack incluye soporte para **Cloudflare Tunnel**, que permite acceder a los servicios desde Internet sin abrir puertos en el router.

1. Crea un túnel en el [dashboard de Cloudflare Zero Trust](https://one.dash.cloudflare.com/).
2. Copia el token del túnel y ponlo en `.env` como `CLOUDFLARE_TUNNEL_TOKEN`.
3. Arranca con el perfil correspondiente:

```bash
docker compose --profile external_access up -d
```

---

## 🔒 Notas de Seguridad

Esta configuración cubre una base de seguridad razonable para uso doméstico, pero **no es una solución endurecida para producción**. Algunas de las medidas ya implementadas:

- La base de datos de Nextcloud (`nextcloud_db_net`) está en una red `internal: true`: ningún contenedor ni el host pueden alcanzarla salvo Nextcloud.
- El puerto 445 de Samba está restringido a la IP local del servidor, no expuesto a `0.0.0.0`.
- Los puertos de administración (81, 3000, 8080) deben permanecer comentados salvo durante la configuración inicial.
- `config/samba/config.yml` contiene credenciales en texto plano y está excluido del repositorio vía `.gitignore`.

Algunas mejoras adicionales que puedes implementar según tu nivel de exigencia:

- HTTPS con certificados Let's Encrypt desde NPM para todos los servicios.
- Autenticación de dos factores en Nextcloud y Portainer.
- Fail2ban para bloquear intentos de acceso por fuerza bruta.
- Backups automáticos de `config/` y `storage/` a un destino externo.
- Auditoría de accesos y alertas en AdGuard Home.
- VPN (WireGuard, Tailscale) como alternativa más segura al túnel de Cloudflare.

---

## 📄 Licencia

MIT — consulta el archivo [LICENSE](LICENSE) para más detalles.
