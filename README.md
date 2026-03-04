# phper

A lightweight Bash tool to install, switch, and manage multiple PHP versions — built from official php.net source.

Unlike package-based version managers, phper compiles PHP directly from source tarballs. This means you get any PHP version immediately, even when distro repos haven't caught up yet.

## Features

- Builds PHP from official php.net source tarballs
- No sudo required for builds (installs to `~/.phper/`)
- Installs any PHP version from 5.6 to 8.4+
- Switches between versions instantly via symlinks
- Auto-detects compatible extensions per PHP version
- SHA256 verification of all downloads
- One-command dependency setup for Debian/Ubuntu and RHEL/Fedora

## Requirements

- **Linux** (Debian/Ubuntu, RHEL/Fedora, and derivatives)
- **Bash** 4.3+
- **Git** (for fetching version lists)
- Build tools: gcc, make, autoconf, bison, re2c, pkg-config

## Quick Start

```bash
# 1. Install build dependencies (requires sudo)
./install.sh

# 2. Install a PHP version
phper 8.4

# 3. Switch to it
phper use 8.4

# 4. Verify
phper ver
```

Add `~/.phper/bin` to your PATH (install.sh will remind you):

```bash
export PATH="$HOME/.phper/bin:$PATH"
```

## Usage

### Install a PHP version

```bash
phper 8.4           # Show available 8.4.x versions, pick one
phper 8.4 -y        # Auto-select latest 8.4.x
phper 8.4.1         # Install exact version 8.4.1
phper 8             # Show all PHP 8.x versions across branches
```

### Switch versions

```bash
phper use 8.3       # Switch to PHP 8.3 (installs if missing)
phper use 8.3 -y    # Same, auto-select latest patch
```

### List installed versions

```bash
phper --list
```

Output:
```
  8.0
  8.2
* 8.4
```

### Show active version

```bash
phper ver
```

### Remove a version

```bash
phper remove 8.0
```

### Show phper version

```bash
phper --version
```

## How It Works

1. **Fetches version list** from GitHub tags (`php/php-src`)
2. **Downloads source tarball** from php.net with SHA256 verification
3. **Detects extensions** by probing `./configure --help` — only enables what the PHP version supports and system libraries provide
4. **Builds from source** with `./configure && make && make install`
5. **Installs to** `~/.phper/versions/X.Y/` (no sudo needed)
6. **Switches versions** by updating symlinks in `~/.phper/bin/`

### File Layout

```
~/.phper/
├── active              # Current version string (e.g. "8.4")
├── bin/                # Symlinks to active version's binaries
│   ├── php -> ../versions/8.4/bin/php
│   ├── phpize -> ../versions/8.4/bin/phpize
│   └── ...
└── versions/
    ├── 8.0/            # Complete PHP 8.0 installation
    ├── 8.2/
    └── 8.4/
        ├── bin/
        ├── etc/php.ini
        ├── include/
        └── lib/
```

## Included Extensions

When system libraries are available, phper builds PHP with:

bcmath, bz2, curl, exif, ftp, gd (jpeg/webp/freetype/avif), intl, mbstring,
mysqli, openssl, pdo-mysql, readline, soap, sockets, sodium, zip, zlib

Extensions are automatically skipped when:
- The PHP version doesn't support them (e.g. `--with-avif` before PHP 8.1)
- System libraries are missing (e.g. libffi for FFI)
- Incompatible library versions (e.g. ICU 76 with PHP < 8.2)

## Compatibility

### PHP Versions

| PHP | Status |
|-----|--------|
| 8.0 – 8.4 | Fully supported and tested |
| 7.0 – 7.4 | Best-effort (may need older system libraries) |
| 5.6 | Best-effort |

### Known Limitations

- **OpenSSL 3.0+** — PHP <= 8.0 cannot compile against OpenSSL 3.0+. phper detects this and skips OpenSSL. Use PHP 8.1+ on modern distros, or install OpenSSL 1.1.1 separately.
- **ICU 70+** — PHP < 8.1 incompatible with ICU >= 70. PHP < 8.2 incompatible with ICU >= 74. phper detects this and skips intl.
- **Linux only** — uses GNU grep, sort -V, sha256sum. macOS is not currently supported.

## Testing

Run the quick PHP 8.x test suite:

```bash
./test-php8.sh
```

This builds the latest version of each PHP 8.x branch (8.0–8.4) in parallel.

Full test suite (all patch versions):

```bash
./tests/test-install-all.sh        # Sequential
./tests/test-install-parallel.sh   # Parallel
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PHPER_DIR` | `~/.phper` | Installation directory |
| `PHPER_MAKE_JOBS` | `$(nproc)` | Parallel make jobs |
| `PHPER_TEST_JOBS` | auto-detected | Parallel test workers |

## Comparison with Other Tools

| Feature | phper | phpbrew | phpenv | asdf-php |
|---------|-------|---------|--------|----------|
| Builds from source | Yes | Yes | Via php-build | Via php-build |
| No sudo for builds | Yes | Yes | Yes | Yes |
| Single file | Yes | No | No | No |
| Bash only | Yes | Yes | Yes + ruby | Yes + bash |
| Auto-detects extensions | Yes | Manual | Manual | Manual |
| Patches known bugs | Yes | No | No | No |

## License

MIT
