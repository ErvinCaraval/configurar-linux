#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Función de ayuda
echo_header() {
  echo
  echo "=============================="
  echo " $1"
  echo "=============================="
}

# Verificar que se ejecute con permisos de sudo
if [[ "$EUID" -ne 0 ]]; then
  echo "Este script necesita ejecutarse con sudo. Usa: sudo $0"
  exit 1
fi

# Variables
GIT_EMAIL="ervin.caravali@correounivalle.edu.co"
GIT_NAME="ErvinCaraval"
DOCKER_COMPOSE_PLUGIN="docker-compose-plugin"

# -------------------------
# Actualizar el sistema
# -------------------------
echo_header "Actualizando el sistema"
apt update -y
apt upgrade -y

# -------------------------
# Instalación de Git
# -------------------------
echo_header "Instalando y configurando Git"
if ! command -v git &> /dev/null; then
  apt install -y git
else
  echo "Git ya está instalado."
fi

git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
echo "Git configurado con usuario y correo."

# -------------------------
# Instalación de Flatpak y Racket
# -------------------------
echo_header "Instalando Flatpak y Racket"
if ! command -v flatpak &> /dev/null; then
  apt install -y flatpak
else
  echo "Flatpak ya está instalado."
fi

# Agregar Flathub si no existe
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Instalar Racket (silencioso si ya está)
if ! flatpak list | grep -q org.racket_lang.Racket; then
  flatpak install -y flathub org.racket_lang.Racket
else
  echo "Racket ya está instalado vía Flatpak."
fi

# -------------------------
# Instalación de Visual Studio Code
# -------------------------
echo_header "Instalando Visual Studio Code"
if ! command -v code &> /dev/null; then
  # Importar clave y repo de forma moderna
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list

  apt update -y
  apt install -y code
else
  echo "Visual Studio Code ya está instalado."
fi

# -------------------------
# Instalación de NVM y Node.js 24
# -------------------------
echo_header "Instalando NVM y Node.js 24"
NVM_DIR="/usr/local/nvm"
export NVM_DIR="$HOME/.nvm"

# Instalar NVM si no existe
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "NVM ya está instalado."
fi

# Cargar NVM en el entorno actual
# shellcheck source=/dev/null
. "$HOME/.nvm/nvm.sh"

# Instalar Node 24 si no está
if ! nvm ls 24 &> /dev/null; then
  nvm install 24
fi

echo "Versiones instaladas:"
echo "Node.js: $(node -v || echo 'no disponible')"
echo "NVM current: $(nvm current || echo 'no disponible')"
echo "npm: $(npm -v || echo 'no disponible')"

# -------------------------
# Instalación de Docker
# -------------------------
echo_header "Instalando Docker"
if ! command -v docker &> /dev/null; then
  apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io ${DOCKER_COMPOSE_PLUGIN}
else
  echo "Docker ya está instalado."
fi

# Habilitar y arrancar Docker
systemctl enable docker
systemctl start docker

# Agregar usuario al grupo docker si no está
if ! groups "${SUDO_USER:-$USER}" | grep -qw docker; then
  usermod -aG docker "${SUDO_USER:-$USER}"
  echo "Se agregó el usuario al grupo docker. Se requiere cerrar sesión o reiniciar sesión para que surta efecto."
else
  echo "Usuario ya pertenece al grupo docker."
fi

# Verificaciones
echo "Versión de Docker:" && docker --version || true
echo "Info de Docker:" && docker info || true
echo "Versión de Docker Compose:" && docker compose version || true

# -------------------------
# Instalación de Google Chrome
# -------------------------
echo_header "Instalando Google Chrome"
if ! command -v google-chrome &> /dev/null; then
  tmpdeb="/tmp/google-chrome-stable_current_amd64.deb"
  wget -qO "$tmpdeb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt install -y "$tmpdeb" || apt --fix-broken install -y
  rm -f "$tmpdeb"
else
  echo "Google Chrome ya está instalado."
fi

echo "Versión de Google Chrome:" && google-chrome --version || true

# -------------------------
# Instalación de Minikube
# -------------------------
echo_header "Instalando Minikube"
if ! command -v minikube &> /dev/null; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f minikube-linux-amd64
else
  echo "Minikube ya está instalado."
fi

echo "Versión de Minikube:" && minikube version || true

# -----------------------------
# Android Studio
# -----------------------------
echo_header "Instalando Android Studio"
if ! snap list | grep -q android-studio; then
  snap install android-studio --classic
else
  echo "Android Studio ya está instalado."
fi

# -----------------------------
# scrcpy y adb
# -----------------------------
echo_header "Instalando scrcpy y android-tools-adb"
apt install -y scrcpy android-tools-adb

# -----------------------------
# VirtualBox
# -----------------------------
echo_header "Instalando VirtualBox 7.1"
if ! command -v virtualbox &> /dev/null; then
  apt install -y wget gnupg2 dkms build-essential linux-headers-$(uname -r)

  # Agregar clave y repo
  mkdir -p /etc/apt/keyrings
  wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox.gpg
  echo "deb [signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" \
    > /etc/apt/sources.list.d/virtualbox.list

  apt update -y
  apt install -y virtualbox-7.1

  # Reconstruir módulos si existe herramienta
  if command -v /sbin/vboxconfig &> /dev/null; then
    /sbin/vboxconfig || true
  fi
else
  echo "VirtualBox ya está instalado."
fi

echo "Versión de VirtualBox:" && virtualbox --version || true

# -------------------------
# Finalización
# -------------------------
echo_header "Finalización"
echo "Instalaciones completadas. Recomendado: cerrar sesión o reiniciar el sistema para aplicar cambios de grupo (docker) y entorno de NVM."
echo "No se reiniciará automáticamente para evitar interrupciones."

