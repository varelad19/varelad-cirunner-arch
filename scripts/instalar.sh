#!/usr/bin/env bash
# Bootstrap del CI en la Steam Deck (una sola vez por consola):
# docker con las redes bien puestas + el servicio que lo revive tras cada
# update de SteamOS. Los runners se registran aparte (registrar-runner.sh),
# porque cada registro necesita un token efímero de la web de GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate
sudo pacman -Sy --noconfirm docker

# Las redes por-job del runner chocan con docker0 si el daemon elige rangos
# solapados (visto en vivo 20-ago-2026): bip y pools disjuntos lo eliminan.
sudo mkdir -p /etc/docker
sudo cp docker/daemon.json /etc/docker/daemon.json

# Si docker ya corrió antes con otra config de red, su registro interno
# guarda el docker0 viejo y el arranque truena con "networks have same
# bridge name" — se limpia el estado de redes (imágenes no se tocan).
sudo systemctl stop docker 2>/dev/null || true
sudo rm -f /var/lib/docker/network/files/local-kv.db
sudo ip link del docker0 2>/dev/null || true
sudo systemctl enable --now docker

sudo cp systemd/reinstalar-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable reinstalar-docker.service

echo "Listo. Registra los runners con: scripts/registrar-runner.sh <nombre> <url-repo> <token>"
