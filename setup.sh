#!/usr/bin/env bash
# =============================================================================
#  setup.sh — Configuración inicial del Home Server
#  Ejecutar UNA SOLA VEZ antes del primer 'docker compose up -d'
# =============================================================================

set -euo pipefail

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}$*${NC}"; }

# =============================================================================
#  1. COMPROBACIONES PREVIAS
# =============================================================================
section "── Comprobaciones previas ──────────────────────────────────────────"

# Debe ejecutarse desde el directorio raíz del proyecto
[[ -f "docker-compose.yml" ]] || error "Ejecuta este script desde la raíz del proyecto (donde está docker-compose.yml)"

# Docker disponible
command -v docker &>/dev/null || error "Docker no está instalado o no está en el PATH"

# Docker Compose V2
docker compose version &>/dev/null || error "Se requiere Docker Compose V2 ('docker compose', no 'docker-compose')"

# Archivo .env presente
if [[ ! -f ".env" ]]; then
    if [[ -f ".env.example" ]]; then
        warn "No se encontró .env — copiando desde .env.example"
        cp .env.example .env
        warn "Edita .env con tus valores reales antes de continuar."
        warn "Luego vuelve a ejecutar: bash setup.sh"
        exit 0
    else
        error "No existe .env ni .env.example. Crea el archivo .env antes de continuar."
    fi
fi

ok "docker OK"
ok "docker compose V2 OK"
ok ".env encontrado"

# =============================================================================
#  2. ESTRUCTURA DE DIRECTORIOS
# =============================================================================
section "── Creando estructura de directorios ──────────────────────────────"

DIRS=(
    # Nginx Proxy Manager
    config/npm/data
    config/npm/letsencrypt

    # AdGuard Home
    config/adguard/work
    config/adguard/conf

    # Portainer
    config/portainer

    # Nextcloud (app)
    config/nextcloud/html

    # Nextcloud (base de datos)
    config/nextcloud_db

    # Jellyfin
    config/jellyfin
    config/jellyfin_cache

    # Samba
    config/samba

    # Almacenamiento compartido
    storage/public
    storage/media
    storage/users
    storage/users/nextcloud_data
)

for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        info "Ya existe: $dir"
    else
        mkdir -p "$dir"
        ok "Creado:    $dir"
    fi
done

# =============================================================================
#  3. ARCHIVO DE CONFIGURACIÓN DE SAMBA
# =============================================================================
section "── Configuración de Samba ───────────────────────────────────────"

SAMBA_CONFIG="config/samba/config.yml"

if [[ -f "$SAMBA_CONFIG" ]]; then
    info "config/samba/config.yml ya existe, no se sobreescribe"
else
    # Leer variables del .env para interpolar
    source <(grep -v '^#' .env | grep '=' | sed 's/^/export /')

    SAMBA_USER="${SAMBA_USER:-sambauser}"

    cat > "$SAMBA_CONFIG" << EOF
auth:
  - user: ${SAMBA_USER}
    group: ${SAMBA_USER}
    uid: 1000
    gid: 1000
    password: \${SAMBA_PASSWORD}

global:
  - "server min protocol = SMB2"

share:
  # Carpeta pública: accesible por todos sin autenticación
  - name: Public
    path: /storage/public
    browsable: yes
    readonly: no
    guestok: yes

  # Biblioteca de medios: accesible por todos en modo lectura
  - name: Media
    path: /storage/media
    browsable: yes
    readonly: yes
    guestok: yes

  # Carpeta de usuarios: solo accesible con credenciales
  - name: Users
    path: /storage/users
    browsable: no
    readonly: no
    guestok: no
    validusers: ${SAMBA_USER}
    writelist: ${SAMBA_USER}
EOF
    ok "Creado: $SAMBA_CONFIG"
fi

# =============================================================================
#  4. PERMISOS
# =============================================================================
section "── Ajustando permisos ──────────────────────────────────────────"

# storage/public y storage/media son accesibles para todos (Samba guest)
chmod -R 755 storage/public storage/media
ok "storage/public y storage/media → 755"

# storage/users solo para el propietario
chmod -R 750 storage/users
ok "storage/users → 750"

# nextcloud_data necesita ser escribible por el contenedor (uid 33 = www-data en Nextcloud)
chmod -R 770 storage/users/nextcloud_data
ok "storage/users/nextcloud_data → 770"

# =============================================================================
#  5. VALIDACIÓN DEL .env
# =============================================================================
section "── Validando variables en .env ─────────────────────────────────"

REQUIRED_VARS=(
    TZ
    SERVER_IP
    SAMBA_USER
    SAMBA_PASSWORD
    NEXTCLOUD_ADMIN_USER
    NEXTCLOUD_ADMIN_PASSWORD
    NEXTCLOUD_DB_PASSWORD
    NEXTCLOUD_DB_ROOT_PASSWORD
    CLOUDFLARE_TUNNEL_TOKEN
)

MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=.\+" .env; then
        ok "$var definida"
    else
        warn "$var — FALTA o está vacía en .env"
        MISSING+=("$var")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    warn "Hay ${#MISSING[@]} variable(s) sin definir en .env:"
    for v in "${MISSING[@]}"; do echo "    - $v"; done
    warn "El stack puede no funcionar correctamente hasta que las completes."
fi

# =============================================================================
#  6. RESUMEN FINAL
# =============================================================================
section "── Listo ────────────────────────────────────────────────────────"

echo ""
echo -e "  Estructura de directorios creada."
echo -e "  Para arrancar todos los servicios base:"
echo -e ""
echo -e "    ${BOLD}docker compose up -d${NC}"
echo -e ""
echo -e "  Para arrancar también el túnel de Cloudflare:"
echo -e ""
echo -e "    ${BOLD}docker compose --profile external_access up -d${NC}"
echo -e ""
echo -e "  ${YELLOW}Recuerda:${NC} la primera vez que levantes AdGuard Home, descomenta"
echo -e "  temporalmente los puertos 3000 y 8080 en docker-compose.yml para"
echo -e "  acceder al asistente de configuración inicial."
echo ""
