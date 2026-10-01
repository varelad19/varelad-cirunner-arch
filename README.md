# varelad-cirunner-arch

La imagen de contenedor en la que compila el CI de taller-diagnostics y de
escuela-app: `ghcr.io/varelad19/cirunner:act-24.04`. Los jobs corren en
runners estándar de GitHub (`ubuntu-24.04`) y entran a esta imagen con
`container:`, así que cada uno arranca con el toolchain ya puesto en vez de
instalarlo en cada corrida.

Hasta el 30-sep-2026 este repo era además todo lo que una Steam Deck
necesitaba para SER ese CI. Esa parte está retirada: ver «La Steam Deck» al
final.

## Qué trae la imagen

Parte de `ghcr.io/catthehacker/ubuntu:act-24.04` —la de act, que replica los
runners hospedados— y le hornea lo que antes se instalaba en cada corrida.
Los pines viven en el `Dockerfile`.

| Pieza | Para qué |
|---|---|
| Temurin 17, cmake, ninja, ccache | compilar la app Qt en todas sus plataformas |
| SDK de Android: NDK 27.2.12479018, platform 35, build-tools 35.0.0 | el APK |
| Bibliotecas de GL, xcb y xkbcommon | las pruebas Qt Quick en offscreen y el AppImage |
| linuxdeployqt (tag `continuous`: no publica otro, así que no tiene pin) | el AppImage del kiosko |
| Chromium de Playwright 1.62.1 y xvfb | los journeys e2e de las releases |

El pin de Playwright va EXACTO al de `e2e/package.json` de los repos que lo
usan: subir uno es subir el otro y republicar. Con versiones distintas,
`npm ci` bajaría un navegador nuevo en cada corrida, que es justo lo que esta
imagen existe para evitar.

## Cómo se publica

`.github/workflows/imagen.yaml` construye y publica la imagen en cada push a
`main` que toque el `Dockerfile` o el propio workflow, y también a mano.

**Cualquier cambio en esos dos archivos republica la imagen para los dos
repos, aunque sea un comentario.** Se reconstruye con los paquetes de apt de
ese día y con el linuxdeployqt que haya en `continuous`, así que tocar el
`Dockerfile` es un cambio en el CI de dos productos: después conviene mirar
una corrida de cada uno.

## La Steam Deck (retirada el 1-oct-2026)

Del 20-ago al 30-sep-2026 el CI corrió en una Steam Deck (SteamOS = Arch,
x86_64): dos runners self-hosted, `deck-a` y `deck-b`, cada job dentro de
esta misma imagen. Se mudó a runners de GitHub por la cola —dos runners para
dos productos— y por depender de una consola en una red doméstica. La
historia completa, con sus mediciones, está en varelad19/varelad-cluster#254.

Lo que quedó de aquella época ya no se usa. Se conserva por si un día hay que
volver a armarla:

- `scripts/instalar.sh`: docker en SteamOS, con las redes bien puestas.
- `scripts/registrar-runner.sh`: un runner por carpeta, como servicio.
- `systemd/reinstalar-docker.service`: repone docker tras cada update de
  SteamOS.
- `docker/daemon.json`: los rangos de red que evitan el choque con `docker0`.

### Cómo se armaba

```bash
scripts/instalar.sh
scripts/registrar-runner.sh deck-a https://github.com/varelad19/taller-diagnostics <token>
scripts/registrar-runner.sh deck-b https://github.com/varelad19/taller-diagnostics <token>
```

(cada token sale de repo → Settings → Actions → Runners → *New self-hosted
runner*; son efímeros, genera uno por registro).

### El modelo de supervivencia

Los updates de SteamOS reemplazan el rootfs (`/usr`) y se llevan lo
instalado con pacman. Pero `/home`, `/var` y el overlay de `/etc`
**sobreviven**. Por eso:

| Pieza | Vivía en | ¿Sobrevivía a los updates? |
|---|---|---|
| Runners (binarios + `_work`) | `/home/deck/runner-*` | ✅ |
| Servicios systemd (runners y reinstalador) | `/etc` (overlay) | ✅ |
| `daemon.json` de docker | `/etc/docker` (overlay) | ✅ |
| `gai.conf` (IPv4 primero — sin él, timeouts de 100 s a codeload) | `/etc` (overlay) | ✅ |
| Imágenes y estado de docker | `/var/lib/docker` | ✅ |
| **Binarios de docker** | `/usr` (rootfs) | ❌ → los reponía `reinstalar-docker.service` al arrancar |

Los runners además se auto-actualizaban solos: GitHub les bajaba la versión
nueva cuando la publicaba.

### Las cicatrices que dejó (20-ago-2026)

- **Redes**: sin `daemon.json`, las redes por-job del runner chocan con
  `docker0` («overlapping IPv4»). `bip` 10.98.0.1/24 + pool 10.99.0.0/16.
- **Estado rancio**: si docker corrió con otra config de red, su registro
  interno truena el arranque («networks have same bridge name») —
  `instalar.sh` limpia `local-kv.db` antes de levantar.
- **Dos runners, dos `_work`**: compartir carpeta envenena los workspaces
  (la CMakeCache del kit ajeno, el árbol de Qt mezclado). Una carpeta por
  runner, siempre.
- **Los self-hosted no estrenan máquina**: todo paso del workflow debe ser
  idempotente y no confiar en env de actions sobre árboles compartidos. Un
  runner de GitHub sí la estrena, y eso destapó pasos que en la Deck nunca
  habían corrido de verdad.
- **`grep -q` + `pipefail`** sobre un pipe = SIGPIPE del productor = fallo
  en falso por carrera de timing. `grep patrón >/dev/null`, nunca `-q`. Esta
  vale en cualquier runner.
