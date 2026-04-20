#!/bin/bash
# ============================================================
# Name       : Metiwilson APN Proxy Manager
# Author     : Metiwilson
# Version    : 3.0.0
# GitHub     : github.com/Metiwilson
# Domain     : codeepic.ir
# Safe, Stable, APN Compatible Proxy Manager
# ============================================================

set -euo pipefail

# ======================= Rang ha =======================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ======================= Default haye proxy =======================
CONFIG_DIR="/etc/metiwilson"
CONFIG_FILE="$CONFIG_DIR/proxy.conf"

PROXY_PORT="8080"
PROXY_USER="metiwilson"
PROXY_PASS="metiwilson"
DOMAIN="codeepic.ir"

GITHUB_RAW="https://raw.githubusercontent.com/Metiwilson/proxy-panel/main/Metiwilson-Proxy.sh"

# ======================= Load config =======================
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# ======================= Save config =======================
save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
PROXY_PORT="$PROXY_PORT"
PROXY_USER="$PROXY_USER"
PROXY_PASS="$PROXY_PASS"
DOMAIN="$DOMAIN"
EOF
}

# ======================= Header =======================
show_header() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}       Metiwilson APN Proxy Manager - Version 3.0.0${NC}"
    echo -e "${YELLOW}       sazgar ba hame operator ha | bedone tadelok ba tanzimat server${NC}"
    echo -e "${GREEN}       Domain: codeepic.ir${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ======================= Root check =======================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}baraye ejraye script bayad root bashid.${NC}"
        exit 1
    fi
}

# ======================= Validate input =======================
validate_port() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || (( "$1" < 1 || "$1" > 65535 )); then
        echo -e "${RED}port namotabar ast.${NC}"
        exit 1
    fi
}

# ======================= Install proxy =======================
install_proxy() {
    echo -e "${YELLOW}[1/6] update package ha...${NC}"
    apt update -y

    echo -e "${YELLOW}[2/6] nasb dependency ha...${NC}"
    apt install -y build-essential git curl iptables-persistent net-tools || true

    echo -e "${YELLOW}[3/6] nasb 3proxy...${NC}"
    if ! [[ -d /opt/3proxy ]]; then
        git clone https://github.com/3proxy/3proxy.git /opt/3proxy
        cd /opt/3proxy
        make -f Makefile.Linux
        make -f Makefile.Linux install
    fi

    echo -e "${YELLOW}[4/6] ijade config...${NC}"
    mkdir -p /etc/3proxy
    cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
nscache 65536
log /var/log/3proxy.log D
rotate 14

users ${PROXY_USER}:CL:${PROXY_PASS}
auth strong
allow ${PROXY_USER}
proxy -n -a -p${PROXY_PORT}
EOF

    echo -e "${YELLOW}[5/6] ijade service systemd...${NC}"
    cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy APN Proxy Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${YELLOW}[6/6] faal sazi...${NC}"

    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl restart 3proxy

    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${PROXY_PORT}/tcp || true
    fi

    echo -e "${GREEN}nasb ba movafaghiat anjam shod.${NC}"
    sleep 2
}

# ======================= Remove proxy =======================
remove_proxy() {
    systemctl stop 3proxy 2>/dev/null || true
    systemctl disable 3proxy 2>/dev/null || true

    rm -rf /etc/3proxy
    rm -rf /opt/3proxy
    rm -f /etc/systemd/system/3proxy.service

    systemctl daemon-reload
    echo -e "${GREEN}proxy ba movafaghiat hazf shod.${NC}"
    sleep 2
}

# ======================= Update Script =======================
update_panel() {
    BACKUP="$0.bak"
    cp "$0" "$BACKUP"

    echo -e "${YELLOW}download version jadid...${NC}"
    curl -o /tmp/update.sh "$GITHUB_RAW"

    if [[ -s /tmp/update.sh ]]; then
        mv /tmp/update.sh "$0"
        chmod +x "$0"
        echo -e "${GREEN}update anjam shod. lotfan script ra dobare ejra konid.${NC}"
        exit 0
    fi

    echo -e "${RED}download version jadid ba moshkel movajeh shod.${NC}"
}

# ======================= Change settings =======================
change_settings() {
    echo -e "${CYAN}tanzimat fa'eli:${NC}"
    echo "User: $PROXY_USER"
    echo "Pass: $PROXY_PASS"
    echo "Port: $PROXY_PORT"

    read -p "username jadid: " u || true
    read -p "password jadid: " p || true
    read -p "port jadid: " pr || true

    [[ -n "$u" ]] && PROXY_USER="$u"
    [[ -n "$p" ]] && PROXY_PASS="$p"
    [[ -n "$pr" ]] && validate_port "$pr" && PROXY_PORT="$pr"

    save_config

    if systemctl is-active --quiet 3proxy; then
        sed -i "s/users .*/users ${PROXY_USER}:CL:${PROXY_PASS}/" /etc/3proxy/3proxy.cfg
        sed -i "s/proxy .*/proxy -n -a -p${PROXY_PORT}/" /etc/3proxy/3proxy.cfg
        systemctl restart 3proxy
    fi

    echo -e "${GREEN}tanzimat save shod.${NC}"
}

# ======================= Status =======================
view_status() {
    if systemctl is-active --quiet 3proxy; then
        echo -e "${GREEN}3proxy dar hal ejra ast.${NC}"
    else
        echo -e "${RED}3proxy ejra nemishavad.${NC}"
    fi
    systemctl status 3proxy --no-pager
    read -p "continue..." _
}

# ======================= Logs =======================
view_logs() {
    tail -n 50 /var/log/3proxy.log || echo -e "${RED}log yaft nashod.${NC}"
    read -p "continue..." _
}

# ======================= APN Information =======================
show_info() {
    echo -e "${GREEN}etela'at proxy (vizhe APN):${NC}"
    echo "Server: $DOMAIN"
    echo "Port  : $PROXY_PORT"
    echo "User  : $PROXY_USER"
    echo "Pass  : $PROXY_PASS"
    echo ""
    echo "APN Example:"
    echo "APN: internet"
    echo "Proxy: $DOMAIN"
    echo "Port: $PROXY_PORT"
    echo ""
    read -p "continue..." _
}

# ======================= Menu =======================
main_menu() {
    while true; do
        show_header
        echo -e "${GREEN}[1] nasb proxy"
        echo -e "${RED}[2] hazf proxy"
        echo -e "${CYAN}[3] update panel"
        echo -e "${YELLOW}[4] taghir tanzimat"
        echo -e "${BLUE}[5] vaziat"
        echo -e "${BLUE}[6] log ha"
        echo -e "${GREEN}[7] etela'at APN"
        echo -e "${RED}[0] khoroj${NC}"
        read -p "entekhab: " c

        case $c in
            1) install_proxy ;;
            2) remove_proxy ;;
            3) update_panel ;;
            4) change_settings ;;
            5) view_status ;;
            6) view_logs ;;
            7) show_info ;;
            0) exit 0 ;;
            *) echo "gozine eshtebah!" ;;
        esac
    done
}

check_root
load_config
save_config
main_menu
