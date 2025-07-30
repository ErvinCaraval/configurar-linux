#!/bin/bash

# -------------------------
# Actualizar el sistema
# -------------------------
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# -------------------------
# Instalación de Git
# -------------------------
echo "Instalando Git..."
sudo apt install git -y

# Configurar usuario de Git
git config --global user.email "ervin.caravali@correounivalle.edu.co"
git config --global user.name "ErvinCaraval"
echo "Git configurado con usuario y correo."

# -------------------------
# Instalación de Flatpak
# -------------------------
echo "Instalando Flatpak..."
sudo apt install -y flatpak

# Agregar el repositorio Flathub (si no existe)
echo "Agregando Flathub..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# -------------------------
# Instalación de Racket
# -------------------------
echo "Instalando Racket con Flatpak..."
flatpak install -y flathub org.racket_lang.Racket

# -------------------------
# Instalación de Visual Studio Code (versión clásica)
# -------------------------
echo "Instalando Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install code -y
rm packages.microsoft.gpg

# -------------------------
# Instalación de Node.js usando NVM
# -------------------------
echo "Instalando NVM y Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

echo "en lugar de reiniciar la shell"
\. "$HOME/.nvm/nvm.sh"
echo "Instalando 24 ..."
nvm install 24

# Verificar versiones
echo "Versión de Node.js instalada:"
node -v
echo "Versión actual de NVM:"
nvm current
echo "Versión de npm instalada:"
npm -v

# -------------------------
# Instalación de Docker
# -------------------------
echo "Instalando Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Verificar estado del servicio Docker
echo "Verificando estado de Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Agregar usuario al grupo docker
sudo usermod -aG docker ${USER}
echo "Docker instalado. Es posible que necesites reiniciar la sesión para aplicar los cambios."

# Verificar la instalación de Docker
echo "Verificando la instalación de Docker..."
docker --version
docker info

# -------------------------
# Instalación de Docker Compose
# -------------------------
echo "Instalando Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.0"
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Asignar permisos de ejecución
sudo chmod +x /usr/local/bin/docker-compose

# Verificar instalación de Docker Compose
echo "Versión de Docker Compose instalada:"
docker-compose --version

# -------------------------
# Instalación de Google Chrome
# -------------------------
echo "Instalando Google Chrome..."
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp
sudo apt install -y /tmp/google-chrome-stable_current_amd64.deb

# Verificar instalación de Chrome
echo "Versión de Google Chrome instalada:"
google-chrome --version

# -------------------------
# Instalación de Minikube
# -------------------------
echo "Instalando Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verificar instalación de Minikube
echo "Versión de Minikube instalada:"
minikube version

# -------------------------
# Finalización
# -------------------------
echo "Instalación completa. Recuerda reiniciar la terminal o cerrar sesión para que los cambios surtan efecto."

# Reiniciar el sistema
echo "Reiniciando el sistema..."
sudo reboot

