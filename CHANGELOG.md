# Changelog

## 1.0.0 (2026-03-04)

Initial release.

### Features

- **Install PHP from source** — builds from official php.net tarballs, no distro repos needed
- **Version switching** — symlink-based switching via `~/.phper/bin/`, no sudo required
- **Version picker** — shows all available patch versions, lets you choose or auto-select latest
- **Exact version install** — `phper 8.4.1` installs that specific version
- **Major version support** — `phper 8` shows all 8.x versions across branches
- **Auto-confirm** — `-y` flag skips prompts, selects latest
- **Remove versions** — `phper remove 8.0` cleans up completely
- **Dynamic configure flags** — probes `./configure --help` to detect supported extensions per PHP version
- **Two-era support** — handles both pre-7.4 (`--with-gd-dir`) and 7.4+ (`--enable-gd`) configure styles
- **ICU compatibility detection** — skips intl extension when ICU version is too new for PHP version
- **OpenSSL compatibility detection** — warns and skips when OpenSSL 3.0+ is incompatible with PHP <= 8.0
- **Source patching** — fixes known build bugs (PHP 8.2.0 atomic builtins, PHP 8.1.0-8.1.2)
- **SHA256 verification** — validates downloaded tarballs against php.net checksums
- **php.ini auto-setup** — copies php.ini-production after build
- **install.sh** — one-command setup of all build dependencies (Debian/Ubuntu, RHEL/Fedora)

### Supported PHP Versions

- PHP 8.0 – 8.4 (fully tested)
- PHP 7.0 – 7.4 (best-effort, older versions may need additional system libraries)
- PHP 5.6 (best-effort)

### Extensions Included

bcmath, bz2, curl, exif, ftp, gd (jpeg/webp/freetype), intl, mbstring,
mysqli, openssl, pdo-mysql, readline, soap, sockets, sodium, zip, zlib

Extensions are included when the PHP version supports them and system libraries are available.
