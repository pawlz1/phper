#!/usr/bin/env bash
set -euo pipefail

# phper install script
# Detects OS/distro and installs all build dependencies required to compile PHP from source.

info() {
    echo "==> $*"
}

die() {
    echo "Error: $*" >&2
    exit 1
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_ID_LIKE="${ID_LIKE:-}"
    else
        die "Cannot detect distro: /etc/os-release not found. Unsupported system."
    fi

    # Normalize to a family
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|alma|ol)
            DISTRO_FAMILY="rhel"
            ;;
        *)
            # Check ID_LIKE as fallback
            if [[ "$DISTRO_ID_LIKE" == *"debian"* || "$DISTRO_ID_LIKE" == *"ubuntu"* ]]; then
                DISTRO_FAMILY="debian"
            elif [[ "$DISTRO_ID_LIKE" == *"rhel"* || "$DISTRO_ID_LIKE" == *"fedora"* || "$DISTRO_ID_LIKE" == *"centos"* ]]; then
                DISTRO_FAMILY="rhel"
            else
                die "Unsupported distro: $DISTRO_ID (ID_LIKE=$DISTRO_ID_LIKE)"
            fi
            ;;
    esac

    info "Detected distro: $DISTRO_ID (family: $DISTRO_FAMILY)"
}

install_debian_deps() {
    local packages=(
        # Core build tools
        build-essential
        autoconf
        bison
        re2c
        pkg-config

        # Mandatory: libxml2, sqlite
        libxml2-dev
        libsqlite3-dev

        # Extensions used by phper's configure flags
        libcurl4-openssl-dev    # --with-curl
        libssl-dev              # --with-openssl
        zlib1g-dev              # --with-zlib
        libreadline-dev         # --with-readline
        libzip-dev              # --with-zip
        libonig-dev             # --enable-mbstring
        libicu-dev              # --enable-intl
        libsodium-dev           # --with-sodium
        libpng-dev              # --enable-gd
        libjpeg-dev             # --with-jpeg (GD)
        libwebp-dev             # --with-webp (GD)
        libfreetype6-dev        # --with-freetype (GD)
    )

    info "Updating package index..."
    sudo apt-get update -qq

    info "Installing ${#packages[@]} packages..."
    sudo apt-get install -y -qq "${packages[@]}"
}

install_rhel_deps() {
    local pkg_mgr="dnf"
    if ! command -v dnf &>/dev/null; then
        pkg_mgr="yum"
    fi

    local packages=(
        # Core build tools
        gcc
        gcc-c++
        make
        autoconf
        bison
        re2c
        pkg-config

        # Mandatory: libxml2, sqlite
        libxml2-devel
        sqlite-devel

        # Extensions used by phper's configure flags
        libcurl-devel           # --with-curl
        openssl-devel           # --with-openssl
        zlib-devel              # --with-zlib
        readline-devel          # --with-readline
        libzip-devel            # --with-zip
        oniguruma-devel         # --enable-mbstring
        libicu-devel            # --enable-intl
        libsodium-devel         # --with-sodium
        libpng-devel            # --enable-gd
        libjpeg-devel           # --with-jpeg (GD)
        libwebp-devel           # --with-webp (GD)
        freetype-devel          # --with-freetype (GD)
    )

    info "Installing ${#packages[@]} packages..."
    sudo "$pkg_mgr" install -y "${packages[@]}"
}

install_phper() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local phper_src="$script_dir/phper"

    if [[ ! -f "$phper_src" ]]; then
        die "phper script not found at $phper_src"
    fi

    local dest="/usr/local/bin/phper"
    info "Installing phper to $dest..."
    sudo install -m 755 "$phper_src" "$dest"
    info "phper installed to $dest"
}

setup_phper_dir() {
    local phper_dir="${PHPER_DIR:-$HOME/.phper}"
    mkdir -p "$phper_dir/versions" "$phper_dir/bin"
    info "Created $phper_dir/{versions,bin}"

    # Check if $phper_dir/bin is in PATH
    if [[ ":$PATH:" != *":$phper_dir/bin:"* ]]; then
        echo ""
        info "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
        echo ""
        echo "  export PATH=\"$phper_dir/bin:\$PATH\""
        echo ""
    fi
}

main() {
    echo "phper — install script"
    echo ""

    detect_distro

    case "$DISTRO_FAMILY" in
        debian) install_debian_deps ;;
        rhel)   install_rhel_deps ;;
    esac

    echo ""
    info "All build dependencies installed."

    install_phper
    setup_phper_dir

    echo ""
    info "Done! You can now run: phper 8.4"
}

main "$@"
