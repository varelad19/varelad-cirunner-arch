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

# IPv4 primero (aprendido el 22-ago a golpes de timeout): la red publica AAAA
# que no alcanza, y todo lo que no hace Happy Eyeballs —el runner de Actions
# incluido— muere esperando 100 s por conexión a codeload.github.com. Es la
# MISMA enfermedad que la app curó con Ipv4Nam, ahora a nivel sistema: la
# tabla RFC 6724 completa con ::ffff:0:0/96 subido de 35 a 100 (una sola
# línea `precedence` NO basta: glibc descarta el resto del default). Vive en
# el overlay de /etc: sobrevive updates de SteamOS. Idempotente.
sudo tee /etc/gai.conf > /dev/null <<'GAI'
precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence ::/96          20
precedence ::ffff:0:0/96 100
GAI

echo "Listo. Registra los runners con: scripts/registrar-runner.sh <nombre> <url-repo> <token>"
