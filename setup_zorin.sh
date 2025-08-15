#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Helper function
echo_header() {
  echo
  echo "=================================================="
  echo " $1"
  echo "=================================================="
}

# Verify sudo permissions
if [[ "$EUID" -ne 0 ]]; then
  echo "This script needs to be run with sudo. Please use: sudo $0"
  exit 1
fi

# Configuration variables
GIT_EMAIL="ervin.caravali@correounivalle.edu.co"
GIT_NAME="ErvinCaraval"
DOCKER_COMPOSE_PLUGIN="docker-compose-plugin" # Package name for Docker Compose v2
CURRENT_USER="${SUDO_USER:-$USER}" # Get the original user who ran sudo

## Update the system

echo_header "Updating the system"
echo "Running 'apt update'..."
apt update -y
echo "Running 'apt upgrade'..."
apt upgrade -y
echo "Cleaning up unnecessary packages..."
apt autoremove -y

## Git Installation and Configuration

echo_header "Installing and configuring Git"
if ! command -v git &> /dev/null; then
  echo "Git not found. Installing..."
  apt install -y git
  echo "Git installed successfully."
else
  echo "Git is already installed."
fi

echo "Configuring Git globally for user ${CURRENT_USER}..."
# Configurar Git como el usuario que ejecutó el script, no como root
runuser -l "${CURRENT_USER}" -c "git config --global user.email \"${GIT_EMAIL}\""
runuser -l "${CURRENT_USER}" -c "git config --global user.name \"${GIT_NAME}\""
echo "Git configured with user (${GIT_NAME}) and email (${GIT_EMAIL})."

runuser -l "${CURRENT_USER}" -c "git config --global --list"

## Instalo driver nvidia
apt install -y nvidia-driver-470

## Flatpak and Racket Installation

echo_header "Installing Flatpak and Racket (via Flatpak)"
if ! command -v flatpak &> /dev/null; then
  echo "Flatpak not found. Installing..."
  apt install -y flatpak
  echo "Flatpak installed successfully."
else
  echo "Flatpak is already installed."
fi

echo "Adding Flathub repository if it doesn't exist..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
echo "Flathub repository configured."

if ! flatpak list | grep -q org.racket_lang.Racket; then
  echo "Racket not found in Flatpak. Installing..."
  runuser -l "${CURRENT_USER}" -c "flatpak install -y flathub org.racket_lang.Racket"
  echo "Racket installed via Flatpak."
else
  echo "Racket is already installed via Flatpak."
fi

## Visual Studio Code Installation

echo_header "Installing Visual Studio Code"
if ! command -v code &> /dev/null; then
  echo "Visual Studio Code not found. Adding repository and installing..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/vscode-archive-keyring.gpg > /dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null

  apt update -y
  apt install -y code
  echo "Visual Studio Code installed successfully."
else
  echo "Visual Code is already installed."
fi

## NVM (Node Version Manager) and Node.js 24 Installation

echo_header "Installing NVM (Node Version Manager) and Node.js 24"
NVM_INSTALL_SCRIPT="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
NVM_PROFILE_SCRIPT="/home/${CURRENT_USER}/.nvm/nvm.sh"

if ! runuser -l "${CURRENT_USER}" -c "test -s ${NVM_PROFILE_SCRIPT}"; then
  echo "NVM not found for user ${CURRENT_USER}. Installing..."
  runuser -l "${CURRENT_USER}" -c "curl -o- ${NVM_INSTALL_SCRIPT} | bash"
  echo "NVM installed for user ${CURRENT_USER}."
else
  echo "NVM is already installed for user ${CURRENT_USER}."
fi

if ! runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && nvm ls 24 &> /dev/null"; then
  echo "Node.js 24 is not installed. Installing with NVM..."
  runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && nvm install 24 && nvm use 24"
  echo "Node.js 24 installed and configured as default version."
else
  echo "Node.js 24 is already installed."
  runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && nvm use 24"
fi

echo "Verifying versions for user ${CURRENT_USER}:"
runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && node -v" || echo "Node.js: not available"
runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && nvm current" || echo "NVM current: not available"
runuser -l "${CURRENT_USER}" -c "source ${NVM_PROFILE_SCRIPT} && npm -v" || echo "npm: not available"

## Docker Installation

echo_header "Installing Docker and Docker Compose"
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Adding repository and installing..."
  apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common # Needed for add-apt-repository

  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Use 'noble' for Linux Mint 22.1 "Xia" (based on Ubuntu 24.04 LTS "Noble Numbat")
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io "${DOCKER_COMPOSE_PLUGIN}"
  echo "Docker and Docker Compose plugin installed successfully."
else
  echo "Docker is already installed."
fi

echo "Enabling and starting Docker service..."
systemctl enable docker --now
echo "Docker service enabled and running."

echo "Adding user ${CURRENT_USER} to 'docker' group if not already a member..."
if ! groups "${CURRENT_USER}" | grep -qw docker; then
  usermod -aG docker "${CURRENT_USER}"
  echo "User ${CURRENT_USER} added to 'docker' group. You will need to log out and back in (or restart) for changes to take effect and use Docker without 'sudo'."
else
  echo "User ${CURRENT_USER} already belongs to 'docker' group."
fi

echo "Verifying Docker installations:"
echo "Docker Version:" && docker --version || true
echo "Docker Info (may require sudo permissions if group not applied):" && docker info || true
echo "Docker Compose Version:" && docker compose version || true

## Google Chrome Installation

echo_header "Installing Google Chrome"
if ! command -v google-chrome &> /dev/null; then
  echo "Google Chrome not found. Downloading and installing..."
  TMP_DEB_FILE="/tmp/google-chrome-stable_current_amd64.deb"
  wget -qO "$TMP_DEB_FILE" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt install -y "$TMP_DEB_FILE" || apt --fix-broken install -y
  rm -f "$TMP_DEB_FILE"
  echo "Google Chrome installed successfully."
else
  echo "Google Chrome is already installed."
fi
echo "Google Chrome Version:" && google-chrome --version || true

## Minikube Installation

echo_header "Installing Minikube"
if ! command -v minikube &> /dev/null; then
  echo "Minikube not found. Downloading and installing..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f minikube-linux-amd64
  echo "Minikube installed successfully."
else
  echo "Minikube is already installed."
fi
echo "Minikube Version:" && minikube version || true

# -------------------------
## Desbloqueo e instalación de Snap
# -------------------------
echo_header "Desbloqueando Snap en Linux Mint/Zorin"
if [[ -f /etc/apt/preferences.d/nosnap.pref ]]; then
  mv /etc/apt/preferences.d/nosnap.pref /etc/apt/preferences.d/nosnap.backup
  echo "Archivo nosnap.pref renombrado para permitir Snap."
fi
apt update -y
apt install -y snapd

# -------------------------
## Android Studio (Snap)
# -------------------------
echo_header "Instalando Android Studio"
if ! snap list | grep -q android-studio; then
  snap install android-studio --classic
fi

## Scrcpy and ADB Installation

echo_header "Installing scrcpy and android-tools-adb"
echo "Checking if scrcpy is installed..."
if ! command -v scrcpy &> /dev/null; then
  echo "scrcpy not found. Installing..."
  apt install -y scrcpy
else
  echo "scrcpy is already installed."
fi

echo "Checking if android-tools-adb is installed..."
if ! command -v adb &> /dev/null; then
  echo "android-tools-adb (ADB) not found. Installing..."
  apt install -y android-tools-adb
else
  echo "android-tools-adb (ADB) is already installed."
fi
echo "scrcpy and android-tools-adb installed/verified."

## VirtualBox 7.1 Installation

# -------------------------
# VirtualBox 7.1
# -------------------------
echo_header "Instalando VirtualBox 7.1"

# Para Linux Mint 22.1 (Xia), el repositorio de VirtualBox debe usar 'noble' (Ubuntu 24.04 LTS).
VBOX_REPO_CODENAME="noble"

echo "Configurando repositorio de VirtualBox para usar codename: ${VBOX_REPO_CODENAME}"

# Solo intentar instalar si VirtualBox 7.1 no está presente
if ! command -v virtualbox &> /dev/null || ! virtualbox --version | grep -q "7\.1"; then
  echo "VirtualBox 7.1 no está presente o es otra versión. Preparando instalación..."
  
  # Instalar dependencias necesarias primero
  apt install -y wget gnupg2 dkms build-essential linux-headers-"$(uname -r)"

  # Añadir la clave GPG de Oracle para VirtualBox
  mkdir -p /etc/apt/keyrings
  wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox.gpg
  
  # Añadir el repositorio de VirtualBox usando 'noble'
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian ${VBOX_REPO_CODENAME} contrib" \
    | tee /etc/apt/sources.list.d/virtualbox.list > /dev/null # Usar tee con > /dev/null para evitar salida a stdout

  # Actualizar la lista de paquetes después de añadir el nuevo repositorio
  apt update -y
  
  # Instalar VirtualBox 7.1
  apt install -y virtualbox-7.1
  echo "VirtualBox 7.1 instalado correctamente."

  # Configurar módulos del kernel de VirtualBox
  if command -v /sbin/vboxconfig &> /dev/null; then
    echo "Ejecutando /sbin/vboxconfig para configurar módulos del kernel..."
    /sbin/vboxconfig || true # '|| true' para que el script no falle si vboxconfig devuelve un error no crítico
  else
    echo "Advertencia: /sbin/vboxconfig no se encontró. Puede que necesites configurar módulos manualmente o reiniciar."
  fi
else
  echo "VirtualBox 7.1 ya está instalado."
fi

echo "Versión de VirtualBox:" && virtualbox --version || true

## Finalization

echo_header "Installation Process Completed"
echo "All main tools have been processed."
echo "For changes to take full effect (especially adding to the 'docker' group and NVM configuration), it is **highly recommended to log out and back in, or restart your system**."
echo "The script will not reboot automatically to prevent interruptions."
echo "Enjoy your development environment on Linux Mint Cinnamon!"
