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

## 📦 Servicios

| Servicio | URL local | Descripción |
| :--- | :--- | :--- |
| **Nginx Proxy Manager** | `http://127.0.0.1:81` *(setup)* | Reverse proxy y gestión de certificados SSL |
| **AdGuard Home** | `http://adguard.home` | DNS local con bloqueo de publicidad |
| **Nextcloud** | `http://cloud.home` | Nube privada y sincronización de archivos |
| **Jellyfin** | `http://media.home` | Servidor de medios (películas, series, música) |
| **Portainer** | `http://portainer.home` | Panel de gestión de contenedores Docker |
| **Dozzle** | `http://dozzle.home` | Visor de logs de contenedores en tiempo real |
| **Samba (NAS)** | `smb://nas.home` | Almacenamiento compartido en red local |

---

## 📐 Arquitectura de Red

El stack utiliza **cinco redes Docker aisladas** para segmentar el tráfico y reducir la superficie de ataque. La base de datos de Nextcloud vive en una red `internal: true` sin acceso al exterior.

```
  Dispositivos de la red local
           │
           ▼
  ┌─────────────────────┐
  │    AdGuard Home     │  dns_cloudflare_net (10.10.0.0/27)
  │  DNS · Puerto 53    │  *.home  ──►  IP del servidor
  └──────────┬──────────┘
             │
             ▼
  ┌─────────────────────┐
  │  Nginx Proxy Manager│  edge_net (10.0.0.0/27)
  │  Puerto 80 / 443    │  Enruta por hostname al contenedor correcto
  └──────────┬──────────┘
             │
      apps_net (10.20.0.0/24)
    ┌─────────┼──────────┬──────────┬──────────┐
    ▼         ▼          ▼          ▼          ▼
Nextcloud  Jellyfin  Portainer  Dozzle   (Cloudflare
    │                                      Tunnel)
    │  nextcloud_db_net (10.40.0.0/27 · internal)
    ▼
 MariaDB          storage_net (10.30.0.0/28)
                       │
                       ▼
                     Samba
```

### Redes

| Red | Subred | Propósito |
| :--- | :--- | :--- |
| `edge_net` | `10.0.0.0/27` | Tráfico HTTP/HTTPS entrante |
| `dns_cloudflare_net` | `10.10.0.0/27` | DNS y túnel Cloudflare |
| `apps_net` | `10.20.0.0/24` | Aplicaciones de usuario |
| `storage_net` | `10.30.0.0/28` | NAS (Samba) |
| `nextcloud_db_net` | `10.40.0.0/27` | Base de datos Nextcloud *(aislada)* |

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

- La base de datos de Nextcloud (`nextcloud_db_net`) está en una red `internal: true`: ningún otro contenedor ni el host pueden alcanzarla salvo Nextcloud.
- El puerto 445 de Samba está restringido a la IP local del servidor (`SERVER_IP`), no expuesto a `0.0.0.0`.
- Los puertos de administración (81, 3000, 8080) deben permanecer comentados excepto durante la configuración inicial.
- `config/samba/config.yml` contiene credenciales en texto plano y está excluido del repositorio vía `.gitignore`.

---

## 📄 Licencia

MIT — consulta el archivo [LICENSE](LICENSE) para más detalles.
