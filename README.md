<div align="center">

# 🏡 Personal Home Server Infrastructure

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Fedora](https://img.shields.io/badge/Fedora-51A2DA?style=for-the-badge&logo=fedora&logoColor=white)
![Nginx Proxy Manager](https://img.shields.io/badge/Nginx_Proxy_Manager-20B2AA?style=for-the-badge&logo=nginx&logoColor=white)
![AdGuard Home](https://img.shields.io/badge/AdGuard_Home-008332?style=for-the-badge&logo=adguard&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

**Infraestructura de servidor doméstico autohospedado (*Self-Hosted*) con gestión avanzada de redes, resolución DNS local y Reverse Proxy.**

</div>

---

## 📐 Arquitectura de Red

El sistema utiliza **Docker IPAM** para segmentar y aislar el tráfico entre contenedores, aumentando la seguridad y el control de la red:

```text
               [ Tráfico Local / Dispositivos ]
                              │
                              ▼
        ┌──────────────────────────────────────────┐
        │  AdGuard Home (10.20.0.10 / UDP 53)      │
        │  - Bloqueo de publicidad                 │
        │  - Reescritura DNS: *.home ──> IP Servidor│
        └─────────────────────┬────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────────┐
        │  Nginx Proxy Manager (10.0.0.10 / Port 80)│
        │  - Reverse Proxy HTTP / HTTPS            │
        │  - Gestión de certificados SSL           │
        └─────────────────────┬────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│     Apps Network      │           │    Storage Network    │
│    (10.30.0.0/24)     │           │ (10.40.0.0/24 Interna)│
└───────────────────────┘           └───────────────────────┘
```

---

## 🛠️ Servicios Desplegados

| Servicio | Subred Interna | IP Estática | Puertos Expuestos | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| **Nginx Proxy Manager** | `edge_net` | `10.0.0.10` | `80`, `443`, `81` | Enrutamiento web y gestión de Proxy Inverso |
| **AdGuard Home** | `dns_net`, `edge_net` | `10.20.0.10` | `53/tcp`, `53/udp` | Servidor DNS y filtrado de publicidad a nivel de red |

---

## 🌐 Subredes Docker Configuradas

```yaml
edge_net:    10.0.0.0/24   # Tráfico HTTP/HTTPS y Proxy Reverse
tunnel_net:  10.10.0.0/24  # Conexiones externas seguras (Cloudflare Tunnel)
dns_net:     10.20.0.0/24  # Infraestructura DNS y resolución local
apps_net:    10.30.0.0/24  # Aplicaciones de usuario
storage_net: 10.40.0.0/24  # Almacenamiento y bases de datos (Red Aislada)
```

---

## 📁 Estructura del Proyecto

```text
home-server/
├── config/
│   ├── adguard/        # Datos y configuración de AdGuard Home
│   └── npm/            # Datos y certificados SSL de Nginx Proxy Manager
├── storage/            # Volúmenes persistentes de aplicaciones
├── docker-compose.yml  # Definición de servicios y redes
├── .gitignore          # Exclusión de datos sensibles y claves privadas
└── README.md           # Documentación del proyecto
```

---

## 🚀 Despliegue

### Requisitos Previos
* Servidor con **Fedora Linux** (o cualquier distro basada en RHEL/Debian).
* **Docker Engine** y **Docker Compose V2** instalados.

### Pasos
1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/Yerai-16112005/home-server.git](https://github.com/Yerai-16112005/home-server.git)
   cd home-server
   ```

2. **Iniciar los servicios:**
   ```bash
   docker compose up -d
   ```

3. **Configuración de DNS Local:**
   * Apuntar el DNS del sistema/router a la IP del servidor.
   * Configurar en AdGuard la reescritura de DNS: `*.home` hacia la IP local del servidor.
