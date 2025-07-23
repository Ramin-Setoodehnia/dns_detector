#!/bin/bash

set -e

DNS_SERVICES=(
    "systemd-resolved"
    "resolvconf"
    "dnsmasq"
    "unbound"
    "bind9"
    "named"
    "NetworkManager"
)

declare -A DETECTED_SERVICES_STATUS

print_separator() {
    echo "-----------------------------------------------------"
}

detect_dns_services() {
    echo "Detecting DNS-related services..."
    print_separator

    for svc in "${DNS_SERVICES[@]}"; do
        status="not found"

        if systemctl list-unit-files | grep -qw "$svc.service"; then
            # Service is installed
            if systemctl is-active "$svc" &>/dev/null; then
                status="running"
            elif systemctl is-enabled "$svc" &>/dev/null; then
                status="installed (enabled but not running)"
            else
                status="installed (inactive)"
            fi
        elif service "$svc" status &>/dev/null; then
            status="installed (service command)"
        elif pgrep -x "$svc" &>/dev/null; then
            status="running (by process)"
        fi

        if [[ "$status" != "not found" ]]; then
            DETECTED_SERVICES_STATUS["$svc"]="$status"
        fi
    done

    if [ ${#DETECTED_SERVICES_STATUS[@]} -eq 0 ]; then
        echo "No known DNS-related services were found."
        exit 0
    fi

    echo "Detected DNS services and their status:"
    i=1
    for svc in "${!DETECTED_SERVICES_STATUS[@]}"; do
        echo "$i. $svc — ${DETECTED_SERVICES_STATUS[$svc]}"
        ((i++))
    done
}

choose_action() {
    echo ""
    print_separator
    echo "Choose an action:"
    echo "1) Disable detected DNS services"
    echo "2) Disable and remove detected DNS services"
    echo "3) Exit"
    read -rp "Enter your choice [1-3]: " choice
}

disable_service() {
    local svc="$1"
    echo "Disabling $svc..."

    if systemctl list-unit-files | grep -qw "$svc.service"; then
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        echo "-> $svc stopped and disabled."
    elif service "$svc" status &>/dev/null; then
        service "$svc" stop 2>/dev/null || true
        echo "-> $svc stopped via service command."
    elif pgrep -x "$svc" &>/dev/null; then
        killall "$svc" 2>/dev/null || true
        echo "-> $svc processes killed."
    else
        echo "-> $svc not active or already disabled."
    fi
}

remove_service() {
    local svc="$1"
    echo "Removing $svc..."

    if command -v apt &>/dev/null; then
        apt purge -y "$svc" 2>/dev/null || apt remove -y "$svc" 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        dnf remove -y "$svc" 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum remove -y "$svc" 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        pacman -Rns --noconfirm "$svc" 2>/dev/null || true
    else
        echo "-> Unable to auto-remove. Please uninstall $svc manually."
    fi
}

set_resolv_conf() {
    echo ""
    print_separator
    echo "Setting default DNS resolvers..."

    if [ -L /etc/resolv.conf ]; then
        echo "-> /etc/resolv.conf is a symlink. Removing..."
        rm -f /etc/resolv.conf
    fi

    cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

    chmod 644 /etc/resolv.conf
    echo "-> /etc/resolv.conf updated:"
    cat /etc/resolv.conf
}

main() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi

    detect_dns_services
    choose_action

    case "$choice" in
        1)
            echo ""
            print_separator
            echo "Disabling selected services..."
            for svc in "${!DETECTED_SERVICES_STATUS[@]}"; do
                disable_service "$svc"
            done
            ;;
        2)
            echo ""
            print_separator
            echo "Disabling and removing selected services..."
            for svc in "${!DETECTED_SERVICES_STATUS[@]}"; do
                disable_service "$svc"
                remove_service "$svc"
            done
            ;;
        3)
            echo "Exiting without making changes."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    set_resolv_conf
    echo ""
    echo "All done."
    print_separator
}

main "$@"
