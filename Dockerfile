# La imagen del CI de taller-diagnostics: la de act (que replica los runners
# hospedados: sudo, python, git, curl) MÁS todo lo que antes se instalaba en
# CADA run — cmake/ninja/ccache, el JDK 17, y el SDK de Android completo con
# el NDK pineado. Los pines viven aquí; subirlos = editar esta imagen y
# publicarla (.github/workflows/imagen.yaml lo hace solo al push).
#
# La Deck la jala UNA vez (~6 GB) y queda en /var/lib/docker — que sobrevive
# los updates de SteamOS.
FROM ghcr.io/catthehacker/ubuntu:act-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Temurin 17 (el repo de Adoptium) + las herramientas que el workflow usaba
# vía apt en cada run. libgl1-mesa-dev es la dependencia que install-qt-action
# instala por su cuenta — horneada, su primera corrida tampoco toca apt.
RUN apt-get update && apt-get install -y --no-install-recommends wget gpg apt-transport-https \
 && wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor > /usr/share/keyrings/adoptium.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" > /etc/apt/sources.list.d/adoptium.list \
 && apt-get update && apt-get install -y --no-install-recommends \
      temurin-17-jdk cmake ninja-build ccache unzip libgl1-mesa-dev \
      libxkbcommon0 libpulse0 file desktop-file-utils \
 && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64

# El SDK de Android con los MISMOS pines que el ci.yaml usaba por sdkmanager.
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" && cd /tmp \
 && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
 && unzip -q commandlinetools-linux-11076708_latest.zip -d "$ANDROID_HOME/cmdline-tools" \
 && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
 && rm commandlinetools-linux-11076708_latest.zip \
 && set +o pipefail \
 && yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null \
 && "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
      "ndk;27.2.12479018" "platforms;android-35" "build-tools;35.0.0" >/dev/null

ENV PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

# linuxdeployqt para el AppImage del kiosko (taller-diagnostics#185): viaja
# como AppImage y el contenedor no tiene FUSE — se extrae al hornear y se
# enlaza su AppRun. Solo publica el tag `continuous` (sin pin posible); si un
# día se mueve y rompe, este es el lugar.
RUN cd /opt \
 && wget -q https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage \
 && chmod +x linuxdeployqt-continuous-x86_64.AppImage \
 && ./linuxdeployqt-continuous-x86_64.AppImage --appimage-extract >/dev/null \
 && rm linuxdeployqt-continuous-x86_64.AppImage \
 && ln -s /opt/squashfs-root/AppRun /usr/local/bin/linuxdeployqt
