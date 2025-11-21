#!/bin/bash
#
# Example Vulnerable Lab Provisioning Script
# This script installs and configures the Example Vulnerable lab environment
#

set -e

# Suppress debconf warnings
export DEBIAN_FRONTEND=noninteractive

echo "============================================"
echo "Example Vulnerable Lab Provisioning Started"
echo "============================================"

# Update system
echo "[*] Updating system packages..."
sudo apt-get update

# Removing needrestart package
echo "[*] Removing needrestart package to prevent interactive prompts..."
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y needrestart 2>/dev/null || true

sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo "[*] Installing required dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    git \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    gnupg \
    lsb-release

# Install Docker
echo "[*] Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    echo "[+] Docker installed successfully"
else
    echo "[+] Docker already installed"
fi

# Move lab files to /opt
echo "[*] Setting up lab files..."

# =========================================================================
# NOVOS COMANDOS DE DEBUG ADICIONADOS AQUI
# =========================================================================

echo "[DEBUG] Verificando se a pasta /tmp existe e suas permissões:"
ls -ld /tmp

echo "[DEBUG] Listando o topo do /tmp (para ver se a pasta de arquivos está lá):"
ls -la /tmp | head

echo "[DEBUG] Verificando status detalhado da pasta /tmp/build-files:"
if [ -d "/tmp/build-files" ]; then
    echo "[DEBUG] Pasta /tmp/build-files ENCONTRADA."
    ls -ld /tmp/build-files
    echo "[DEBUG] Listando conteúdo de /tmp/build-files (os arquivos do lab):"
    ls -la /tmp/build-files
else
    echo "[DEBUG] Pasta /tmp/build-files NÃO ENCONTRADA. Verifique a configuração de 'file provisioner'."
fi

# =========================================================================

if [ -d "/tmp/build-files" ]; then
    sudo mkdir -p /opt/example-vuln
    echo "[DEBUG] Copiando arquivos de /tmp/build-files/* para /opt/example-vuln/"
    sudo cp -r /tmp/build-files/* /opt/example-vuln/
    cd /opt/example-vuln

    # Build Docker image
    echo "[*] Building Docker image..."
    sudo docker compose build

    # Start containers to test
    echo "[*] Starting Docker containers for initial test..."
    sudo docker compose up -d

    # Wait for container to be healthy
    echo "[*] Waiting for container to be healthy..."
    sleep 10

    # Test the API
    echo "[*] Testing API endpoint..."
    curl -s http://localhost:5000/health || echo "[-] API not responding yet (will start on boot)"

    # Stop containers (will be started by systemd on boot)
    echo "[*] Stopping containers (will be managed by systemd)..."
    sudo docker compose down

    echo "[+] Lab containers configured successfully"
else
    # MENSAGEM DE ERRO MAIS CLARA
    echo "[-] Lab files not found at /tmp/build-files. O provisionamento será abortado."
    exit 1
fi

# Create systemd service for auto-start
echo "[*] Creating systemd service for auto-start..."
sudo tee /etc/systemd/system/example-vuln-api.service > /dev/null <<'EOF'
[Unit]
Description=Example Vulnerable API Lab
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/example-vuln
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable example-vuln-api.service

echo "[+] Systemd service created and enabled"

# System hardening and configuration
echo "[*] Configuring system..."

# Set hostname
sudo hostnamectl set-hostname example-vuln

# Set root password
echo 'root:ExampleVuln2025$' | sudo chpasswd

# # # Clear bash history
# # sudo ln -sf /dev/null /root/.bash_history

# # # Disable unnecessary services
# # echo "[*] Disabling unnecessary services..."
# # sudo systemctl disable cloud-init.service 2>/dev/null || true
# # sudo systemctl disable cloud-final.service 2>/dev/null || true
# # sudo systemctl disable cloud-config.service 2>/dev/null || true
# # sudo systemctl disable cloud-init-local.service 2>/dev/null || true
# # sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true

# # # Set default target to multi-user (no GUI)
# # sudo systemctl set-default multi-user.target

# # # Clear logs
# # echo "[*] Clearing logs..."
# # sudo find /var/log -type f -exec sh -c "cat /dev/null > {}" \;

# # # Clean up temporary files
# # sudo rm -rf /tmp/*
# # sudo rm -rf /var/tmp/*

# # # Clean up apt cache
# # sudo apt-get clean
# # sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

echo "============================================"
echo "Example Vulnerable Lab Provisioning Completed!"
echo "============================================"
echo ""
echo "Lab Details:"
echo "  - Hostname: example-vuln"
echo "  - Root Password: ExampleVuln2025$"
echo "  - Lab Location: /opt/example-vuln"
echo "  - API Port: 5000"
echo "  - Vulnerability: Command Injection on /ping endpoint"
echo "  - Auto-start: Enabled via systemd"
echo ""
echo "API Endpoints:"
echo "  - GET  /           - API information"
echo "  - GET  /health     - Health check"
echo "  - GET  /ping?host=<target> - Vulnerable ping endpoint"
echo "  - POST /ping       - Vulnerable ping endpoint (JSON: {\"host\": \"<target>\"})"
echo "  - GET  /info       - System information"
echo ""
echo "Example exploit:"
echo "  curl 'http://<IP>:5000/ping?host=127.0.0.1;cat%20/etc/passwd'"
echo ""
echo "AMI is ready to be created."
echo "============================================"