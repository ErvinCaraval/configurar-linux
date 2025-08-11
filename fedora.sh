#!/bin/bash

# Este script adapta la instalación de herramientas de desarrollo para Fedora 42 con KDE Plasma.
# Usa DNF para la gestión de paquetes y ajusta los repositorios y comandos según corresponda.

set -euo pipefail
export DNF_FRONTEND=noninteractive

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
CURRENT_USER="${SUDO_USER:-$USER}" # Get the original user who ran sudo

# ---
## Update the system
# ---
echo_header "Updating the system"
echo "Running 'dnf update'..."
dnf update -y
echo "Cleaning up unnecessary packages..."
dnf autoremove -y

# ---
## NVIDIA Driver Installation (Proprietary)
# ---
echo_header "Installing NVIDIA Proprietary Drivers"
echo "Adding RPM Fusion repositories..."
# Instalar los repositorios RPM Fusion (free y nonfree)
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo "Installing nvidia-driver-470..."
# El paquete para el driver 470 en RPM Fusion es 'akmod-nvidia-470xx'.
# Se necesita 'akmod' para construir el módulo del kernel.
# También se instala 'xorg-x11-drv-nvidia-470xx-32bit' si es necesario para aplicaciones de 32 bits.
dnf install -y akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-32bit nvidia-settings

# Asegurar que el driver de nouveau esté deshabilitado.
echo "Disabling nouveau driver..."
dracut --force --omit-drivers "nouveau" -f

echo "NVIDIA driver installation is complete. A system reboot is highly recommended."

# ---
## Git Installation and Configuration
# ---
echo_header "Installing and configuring Git"
if ! command -v git &> /dev/null; then
  echo "Git not found. Installing..."
  dnf install -y git
  echo "Git installed successfully."
else
  echo "Git is already installed."
fi

echo "Configuring Git globally for user ${CURRENT_USER}..."
git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
echo "Git configured with user (${GIT_NAME}) and email (${GIT_EMAIL})."

# ---
## Flatpak and Racket Installation
# ---
echo_header "Installing Flatpak and Racket (via Flatpak)"
if ! command -v flatpak &> /dev/null; then
  echo "Flatpak not found. Installing..."
  dnf install -y flatpak
  echo "Flatpak installed successfully."
else
  echo "Flatpak is already installed."
fi

echo "Adding Flathub repository if it doesn't exist..."
runuser -l "${CURRENT_USER}" -c "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
echo "Flathub repository configured."

if ! runuser -l "${CURRENT_USER}" -c "flatpak list | grep -q org.racket_lang.Racket"; then
  echo "Racket not found in Flatpak. Installing..."
  runuser -l "${CURRENT_USER}" -c "flatpak install -y flathub org.racket_lang.Racket"
  echo "Racket installed via Flatpak."
else
  echo "Racket is already installed via Flatpak."
fi

# ---
## Visual Studio Code Installation
# ---
echo_header "Installing Visual Studio Code"
if ! command -v code &> /dev/null; then
  echo "Visual Studio Code not found. Adding repository and installing..."
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  
  dnf check-update
  dnf install -y code
  echo "Visual Studio Code installed successfully."
else
  echo "Visual Code is already installed."
fi

# ---
## NVM (Node Version Manager) and Node.js 24 Installation
# ---
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

# ---
## Docker Installation
# ---
echo_header "Installing Docker and Docker Compose"
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Adding repository and installing..."
  dnf -y install dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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

# ---
## Google Chrome Installation
# ---
echo_header "Installing Google Chrome"
if ! command -v google-chrome-stable &> /dev/null; then
  echo "Google Chrome not found. Adding repository and installing..."
  # Añadir el repositorio de Google Chrome
  tee /etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
  dnf install -y google-chrome-stable
  echo "Google Chrome installed successfully."
else
  echo "Google Chrome is already installed."
fi
echo "Google Chrome Version:" && google-chrome-stable --version || true

# ---
## Minikube Installation
# ---
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

# ---
## Android Studio (via Snap) - Snap is not a default in Fedora, but we can install it
# ---
echo_header "Installing Snapd and Android Studio"
if ! command -v snap &> /dev/null; then
  echo "Snapd not found. Installing..."
  dnf install -y snapd
  systemctl enable --now snapd.socket
  echo "Snapd installed. A reboot might be needed for full functionality."
else
  echo "Snapd is already installed."
fi

if ! snap list | grep -q android-studio; then
  echo "Android Studio not found in Snap. Installing..."
  snap install android-studio --classic
else
  echo "Android Studio is already installed via Snap."
fi

# ---
## Scrcpy and ADB Installation
# ---
echo_header "Installing scrcpy and android-tools-adb"
echo "Checking if scrcpy is installed..."
if ! command -v scrcpy &> /dev/null; then
  echo "scrcpy not found. Installing..."
  dnf install -y scrcpy
else
  echo "scrcpy is already installed."
fi

echo "Checking if android-tools-adb is installed..."
if ! command -v adb &> /dev/null; then
  echo "android-tools-adb (ADB) not found. Installing..."
  dnf install -y android-tools
else
  echo "android-tools-adb (ADB) is already installed."
fi
echo "scrcpy and android-tools-adb installed/verified."

# ---
## VirtualBox 7.1 Installation (from Oracle repository)
# ---
echo_header "Installing VirtualBox 7.1"

if ! command -v virtualbox &> /dev/null || ! virtualbox --version | grep -q "7\.1"; then
  echo "VirtualBox 7.1 not present. Preparing installation..."
  
  # Instalar dependencias necesarias
  dnf install -y kernel-devel kernel-headers dkms make gcc
  
  # Añadir el repositorio de VirtualBox
  dnf config-manager --add-repo https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
  
  # Instalar VirtualBox 7.1
  dnf install -y VirtualBox-7.1
  echo "VirtualBox 7.1 installed correctly."
  
  # Configurar módulos del kernel de VirtualBox
  if command -v /sbin/vboxconfig &> /dev/null; then
    echo "Ejecutando /sbin/vboxconfig para configurar módulos del kernel..."
    /sbin/vboxconfig || true
  else
    echo "Advertencia: /sbin/vboxconfig no se encontró. Puede que necesites configurar módulos manualmente o reiniciar."
  fi
else
  echo "VirtualBox 7.1 is already installed."
fi

echo "VirtualBox Version:" && virtualbox --version || true

# ---
## Finalization
# ---
echo_header "Installation Process Completed"
echo "All main tools have been processed."
echo "For changes to take full effect (especially NVIDIA drivers, docker group, and NVM), it is **highly recommended to log out and back in, or restart your system**."
echo "The script will not reboot automatically to prevent interruptions."
echo "Enjoy your development environment on Fedora 42 with KDE Plasma!"