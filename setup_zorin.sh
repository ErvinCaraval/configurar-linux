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

# Ubuntu 25.10 codename
UBUNTU_CODENAME="oracular" # Ubuntu 25.10 Oracular Oriole

## Update the system

echo_header "Updating the system"
echo "Running 'apt update'..."
apt update -y
echo "Running 'apt upgrade'..."
apt upgrade -y
echo "Cleaning up unnecessary packages..."
apt autoremove -y

## Install essential tools

echo_header "Installing essential tools"
echo "Installing curl, wget, and other essential packages..."
apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
echo "Essential tools installed successfully."

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

## Instalo driver nvidia (opcional, descomentar si es necesario)
#apt install -y nvidia-driver-550

## Flatpak and Racket Installation

echo_header "Installing Flatpak and Racket (via Flatpak)"
if ! command -v flatpak &> /dev/null; then
  echo "Flatpak not found. Installing..."
  apt install -y flatpak
  echo "Flatpak installed successfully."
else
  echo "Flatpak is already installed."
fi

echo "Adding Flathub repository if it doesn't exist (user-level)..."
runuser -l "${CURRENT_USER}" -c "flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
echo "Flathub repository configured for user ${CURRENT_USER}."

if ! runuser -l "${CURRENT_USER}" -c "flatpak list --user" | grep -q org.racket_lang.Racket; then
  echo "Racket not found in Flatpak. Installing for user ${CURRENT_USER}..."
  runuser -l "${CURRENT_USER}" -c "flatpak install --user -y flathub org.racket_lang.Racket"
  echo "Racket installed via Flatpak."
else
  echo "Racket is already installed via Flatpak."
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
    software-properties-common

  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Use 'oracular' for Ubuntu 25.10 - fallback to 'noble' if oracular not available yet
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update -y
  
  # If oracular repo doesn't exist yet, fallback to noble
  if ! apt-cache search docker-ce | grep -q docker-ce; then
    echo "Docker repository for ${UBUNTU_CODENAME} not available yet. Using 'noble' as fallback..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update -y
  fi
  
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

## Snap Installation (Ubuntu viene con Snap por defecto, pero verificamos)

echo_header "Verificando instalación de Snap"
if ! command -v snap &> /dev/null; then
  echo "Snap no encontrado. Instalando..."
  apt install -y snapd
  systemctl enable --now snapd.socket
  echo "Snap instalado correctamente."
else
  echo "Snap ya está instalado."
fi

## Android Studio (Snap)

echo_header "Instalando Android Studio"
if ! snap list | grep -q android-studio; then
  echo "Android Studio no encontrado. Instalando vía Snap..."
  snap install android-studio --classic
  echo "Android Studio instalado correctamente."
else
  echo "Android Studio ya está instalado."
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

## Unity Hub Installation

echo_header "Instalando Unity Hub"
if ! command -v unityhub &> /dev/null; then
  echo "Unity Hub no encontrado. Configurando repositorio e instalando..."
  wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
  
  echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list
  
  apt update -y
  apt install -y unityhub
  echo "Unity Hub instalado correctamente."
else
  echo "Unity Hub ya está instalado."
fi

## Brave Browser Installation

echo_header "Instalando Brave Browser"
if ! command -v brave-browser &> /dev/null; then
  echo "Brave Browser no encontrado. Instalando..."
  curl -fsS https://dl.brave.com/install.sh | sh
  echo "Brave Browser instalado correctamente."
else
  echo "Brave Browser ya está instalado."
fi

## VirtualBox Installation

echo_header "Instalando VirtualBox"

if ! command -v virtualbox &> /dev/null; then
  echo "VirtualBox no está instalado. Instalando desde repositorios de Ubuntu..."
  
  # Instalar dependencias necesarias primero
  echo "Instalando dependencias del kernel..."
  apt install -y dkms build-essential linux-headers-"$(uname -r)"
  
  # Instalar VirtualBox desde los repositorios oficiales de Ubuntu
  echo "Instalando VirtualBox..."
  apt install -y virtualbox virtualbox-ext-pack || {
    echo "No se pudo instalar virtualbox-ext-pack automáticamente."
    echo "Puedes instalarlo manualmente después con: sudo apt install virtualbox-ext-pack"
    apt install -y virtualbox
  }
  
  echo "VirtualBox instalado correctamente."

  # Configurar módulos del kernel de VirtualBox
  if command -v /sbin/vboxconfig &> /dev/null; then
    echo "Ejecutando /sbin/vboxconfig para configurar módulos del kernel..."
    /sbin/vboxconfig || true
  else
    echo "Advertencia: /sbin/vboxconfig no se encontró. Puede que necesites configurar módulos manualmente o reiniciar."
  fi
  
  # Añadir usuario al grupo vboxusers
  echo "Añadiendo usuario ${CURRENT_USER} al grupo 'vboxusers'..."
  if ! groups "${CURRENT_USER}" | grep -qw vboxusers; then
    usermod -aG vboxusers "${CURRENT_USER}"
    echo "Usuario ${CURRENT_USER} añadido al grupo 'vboxusers'."
  else
    echo "Usuario ${CURRENT_USER} ya pertenece al grupo 'vboxusers'."
  fi
else
  echo "VirtualBox ya está instalado."
fi

echo "Versión de VirtualBox:" && virtualbox --version || true

echo ""
echo "NOTA: Si necesitas VirtualBox 7.1 específicamente y tienes problemas de dependencias,"
echo "puedes intentar instalar manualmente el paquete .deb desde:"
echo "https://www.virtualbox.org/wiki/Linux_Downloads"

## Finalization

echo_header "Installation Process Completed"
echo "All main tools have been processed."
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "===================="
echo "1. For Docker group permissions to take effect, log out and back in, or run: newgrp docker"
echo "2. For VirtualBox USB support, you need to be in the 'vboxusers' group"
echo "3. NVM configuration will be available in new terminal sessions"
echo ""
echo "Optional: You may want to restart your system for all changes to take full effect."
echo "The script will not reboot automatically to prevent interruptions."
echo ""
echo "Enjoy your development environment on Ubuntu 25.10!"
