#!/usr/bin/env bash
# Prepara el entorno de desarrollo de CarLyrics.
set -euo pipefail

cd "$(dirname "$0")/.."

info() { printf '\033[36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$1"; }
fail() { printf '\033[31mxx\033[0m %s\n' "$1"; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "CarLyrics se compila sólo en macOS con Xcode."
fi

info "Verificando Xcode…"
command -v xcodebuild >/dev/null || fail "No se encontró xcodebuild. Instalá Xcode desde el App Store."
xcodebuild -version | head -1

info "Verificando XcodeGen…"
if ! command -v xcodegen >/dev/null; then
  warn "XcodeGen no está instalado."
  if command -v brew >/dev/null; then
    info "Instalando con Homebrew…"
    brew install xcodegen
  else
    fail "Instalá Homebrew (https://brew.sh) y después: brew install xcodegen"
  fi
fi

if [[ ! -f Configuration/Secrets.xcconfig ]]; then
  info "Creando Configuration/Secrets.xcconfig desde el ejemplo…"
  cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
  warn "Editá Configuration/Secrets.xcconfig con tu DEVELOPMENT_TEAM y tu SPOTIFY_CLIENT_ID."
  warn "Sin el Client ID la app compila y abre, pero no puede conectarse a Spotify."
else
  info "Configuration/Secrets.xcconfig ya existe, no se toca."
fi

info "Generando el proyecto de Xcode…"
xcodegen generate

info "Listo. Próximos pasos:"
echo "  1. Editá Configuration/Secrets.xcconfig (Team ID + Spotify Client ID)."
echo "  2. Cargá 'carlyrics://callback' como Redirect URI en developer.spotify.com/dashboard."
echo "  3. make open"
