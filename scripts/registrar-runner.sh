#!/usr/bin/env bash
# RETIRADO el 1-oct-2026 (varelad19/varelad-cluster#254): el CI ya no corre en
# la Steam Deck, que quedó sin runners y sin docker. Se conserva por si un día
# hay que volver a armarla; ver «La Steam Deck» en el README.
#
# Registra UN runner en su propia carpeta bajo /home (sobrevive updates de
# SteamOS) y lo deja como servicio systemd (el unit va al overlay de /etc,
# que también sobrevive).
#
#   scripts/registrar-runner.sh deck-a https://github.com/varelad19/taller-diagnostics TOKEN
#
# El token sale de: repo -> Settings -> Actions -> Runners -> New self-hosted
# runner (efímero, ~1h). DOS runners = dos carpetas con dos nombres — cada
# uno con su _work: compartirlo envenena los workspaces (aprendido a golpes).
#
# El runner se AUTO-ACTUALIZA solo (lo baja GitHub cuando publica versión
# nueva) y como vive en /home, ni los updates de SteamOS lo tocan.
set -euo pipefail

NOMBRE="${1:?nombre del runner (deck-a, deck-b)}"
URL="${2:?url del repo}"
TOKEN="${3:?token de registro}"

DIR="$HOME/runner-$NOMBRE"
mkdir -p "$DIR"
cd "$DIR"

if [ ! -f config.sh ]; then
    VER=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -o '"tag_name": "v[^"]*' | cut -d'v' -f2)
    curl -sL "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz" | tar xz
fi

# --replace: re-registrar sobre un nombre existente es válido (idempotencia,
# la ley de la casa). El token de registro vive ~1 HORA: si config responde
# 404 en Authentication, es que venció — genera otro en la web y reintenta.
./config.sh --url "$URL" --token "$TOKEN" --name "$NOMBRE" --unattended --replace
sudo ./svc.sh install "$USER"
sudo ./svc.sh start

echo "Runner $NOMBRE corriendo desde $DIR"
