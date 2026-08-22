# varelad-cirunner-arch

El CI de taller-diagnostics corre en una Steam Deck (SteamOS = Arch,
x86_64): dos runners self-hosted que compilan wasm y android **en
paralelo**, cada job dentro de un contenedor
`ghcr.io/catthehacker/ubuntu:act-24.04` para que los pasos del workflow
sean idénticos a los runners hospedados. Este repo es todo lo que la
consola necesita para ser ese CI — y para **volver a serlo sola** después
de cada update de SteamOS.

## El modelo de supervivencia

Los updates de SteamOS reemplazan el rootfs (`/usr`) y se llevan lo
instalado con pacman. Pero `/home`, `/var` y el overlay de `/etc`
**sobreviven**. Por eso:

| Pieza | Vive en | ¿Sobrevive updates? |
|---|---|---|
| Runners (binarios + `_work`) | `/home/deck/runner-*` | ✅ |
| Servicios systemd (runners y reinstalador) | `/etc` (overlay) | ✅ |
| `daemon.json` de docker | `/etc/docker` (overlay) | ✅ |
| `gai.conf` (IPv4 primero — sin él, timeouts de 100 s a codeload) | `/etc` (overlay) | ✅ |
| Imágenes y estado de docker | `/var/lib/docker` | ✅ |
| **Binarios de docker** | `/usr` (rootfs) | ❌ → los repone `reinstalar-docker.service` al arrancar |

Los runners además se **auto-actualizan solos**: GitHub les baja la
versión nueva cuando la publica — cero mantenimiento.

## Armado desde cero

```bash
scripts/instalar.sh
scripts/registrar-runner.sh deck-a https://github.com/varelad19/taller-diagnostics <token>
scripts/registrar-runner.sh deck-b https://github.com/varelad19/taller-diagnostics <token>
```

(cada token sale de repo → Settings → Actions → Runners → *New self-hosted
runner*; son efímeros, genera uno por registro).

## Las cicatrices que este repo encapsula (20-ago-2026)

- **Redes**: sin `daemon.json`, las redes por-job del runner chocan con
  `docker0` («overlapping IPv4»). `bip` 10.98.0.1/24 + pool 10.99.0.0/16.
- **Estado rancio**: si docker corrió con otra config de red, su registro
  interno truena el arranque («networks have same bridge name») —
  `instalar.sh` limpia `local-kv.db` antes de levantar.
- **Dos runners, dos `_work`**: compartir carpeta envenena los workspaces
  (la CMakeCache del kit ajeno, el árbol de Qt mezclado). Una carpeta por
  runner, siempre.
- **Los self-hosted no estrenan máquina**: todo paso del workflow debe ser
  idempotente y no confiar en env de actions sobre árboles compartidos.
  Esos candados viven en el `ci.yaml` de taller-diagnostics, no aquí.
- **`grep -q` + `pipefail`** sobre un pipe = SIGPIPE del productor = fallo
  en falso por carrera de timing. `grep patrón >/dev/null`, nunca `-q`.
