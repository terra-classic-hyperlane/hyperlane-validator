# 🐳 Docker and Docker Compose Installation Guide for Ubuntu

**Last Updated**: January 9, 2026 at 09:47:53 AM EST (US Eastern Time)

---

This guide provides step-by-step instructions for installing Docker and Docker Compose on Ubuntu Linux.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install Docker Engine](#install-docker-engine)
3. [Install Docker Compose](#install-docker-compose)
4. [Post-Installation Configuration](#post-installation-configuration)
5. [Verify Installation](#verify-installation)
6. [Troubleshooting](#troubleshooting)
7. [Uninstall Docker (if needed)](#uninstall-docker-if-needed)

---

## Prerequisites

- Ubuntu 20.04 LTS, 22.04 LTS, or later
- sudo privileges
- Internet connection

**Check your Ubuntu version:**
```bash
lsb_release -a
```

---

## Install Docker Engine

### Method 1: Install from Docker's Official Repository (Recommended)

#### Step 1: Remove Old Versions

```bash
# Remove old Docker versions if installed
sudo apt-get remove docker docker-engine docker.io containerd runc
```

#### Step 2: Update Package Index

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

#### Step 3: Add Docker's Official GPG Key

```bash
# Create keyrings directory
sudo install -m 0755 -d /etc/apt/keyrings

# Download and add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set proper permissions
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

#### Step 4: Set Up Docker Repository

```bash
# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### Step 5: Install Docker Engine

```bash
# Update package index again
sudo apt-get update

# Install Docker Engine, CLI, and Containerd
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Expected output:**
```
Docker is now installed!
```

#### Step 6: Verify Docker Installation

```bash
# Check Docker version
docker --version

# Run hello-world container to verify
sudo docker run hello-world
```

**Expected output:**
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

---

### Method 2: Install Using Convenience Script (Quick Install)

**⚠️ WARNING**: This method is for convenience and should only be used for development environments.

```bash
# Download and run Docker installation script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify installation
docker --version
sudo docker run hello-world
```

---

## Install Docker Compose

### Method 1: Install Docker Compose Plugin (Recommended - Docker 20.10+)

Docker Compose V2 is included as a plugin in newer Docker installations. If you installed Docker using Method 1 above, Docker Compose plugin is already installed.

**Verify Docker Compose plugin:**
```bash
docker compose version
```

**Usage:**
```bash
# Note: Use 'docker compose' (with space) instead of 'docker-compose' (with hyphen)
docker compose up -d
docker compose down
docker compose ps
```

### Method 2: Install Standalone Docker Compose Binary

If you need the standalone `docker-compose` command (with hyphen):

#### Step 1: Download Docker Compose

```bash
# Get latest version number
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make it executable
sudo chmod +x /usr/local/bin/docker-compose
```

#### Step 2: Verify Installation

```bash
# Check version
docker-compose --version

# Or create a symlink if needed
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

**Expected output:**
```
Docker Compose version v2.x.x
```

---

## Post-Installation Configuration

### Add User to Docker Group (Run Docker Without sudo)

**⚠️ IMPORTANT**: Adding a user to the docker group grants them root-equivalent privileges. Only add trusted users.

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout and login again, or use newgrp)
newgrp docker

# Verify you can run Docker without sudo
docker run hello-world
```

**Alternative**: Log out and log back in for group changes to take effect.

### Configure Docker to Start on Boot

```bash
# Enable Docker service to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Start Docker service
sudo systemctl start docker.service
```

### Verify Docker Service Status

```bash
# Check Docker service status
sudo systemctl status docker

# Check if Docker is running
sudo systemctl is-active docker
```

**Expected output:**
```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
```

---

## Verify Installation

### Check Docker Version

```bash
# Docker version
docker --version

# Docker Compose version (plugin)
docker compose version

# Docker Compose version (standalone)
docker-compose --version

# Detailed Docker information
docker info
```

### Test Docker Installation

```bash
# Run a test container
docker run hello-world

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Pull and run a simple container
docker run -d -p 80:80 nginx

# Check if container is running
docker ps

# Stop the container
docker stop $(docker ps -q)

# Remove the container
docker rm $(docker ps -aq)
```

### Test Docker Compose

**Create a test `docker-compose.yml`:**

```bash
# Create test directory
mkdir ~/docker-test
cd ~/docker-test

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    container_name: test-nginx
EOF

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs

# Stop services
docker compose down
```

---

## Troubleshooting

### Error: "Cannot connect to the Docker daemon"

**Problem**: Docker daemon is not running.

**Solution:**
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check Docker status
sudo systemctl status docker
```

### Error: "Permission denied while trying to connect to the Docker daemon socket"

**Problem**: User doesn't have permission to access Docker socket.

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or use:
newgrp docker

# Verify
docker run hello-world
```

### Error: "docker: command not found"

**Problem**: Docker is not installed or not in PATH.

**Solution:**
```bash
# Check if Docker is installed
which docker

# If not found, reinstall Docker (see installation steps above)

# Or check if Docker is in PATH
echo $PATH
```

### Error: "docker-compose: command not found"

**Problem**: Docker Compose is not installed or not in PATH.

**Solution:**
```bash
# For Docker Compose plugin (recommended)
docker compose version

# For standalone docker-compose
which docker-compose

# If not found, install Docker Compose (see installation steps above)
```

### Docker Service Won't Start

**Problem**: Docker service fails to start.

**Solution:**
```bash
# Check Docker service status
sudo systemctl status docker

# View Docker service logs
sudo journalctl -u docker.service

# Restart Docker service
sudo systemctl restart docker

# Check for errors
sudo systemctl status docker
```

### WSL 2 Integration Issues

**Problem**: Docker not working in WSL 2.

**Solution:**

1. **Enable WSL Integration in Docker Desktop:**
   - Open Docker Desktop on Windows
   - Go to **Settings** → **Resources** → **WSL Integration**
   - Enable **"Enable integration with my default WSL distro"**
   - Enable integration for your specific WSL distro (e.g., "Ubuntu")
   - Click **"Apply & Restart"**

2. **Verify WSL 2 is being used:**
   ```bash
   # Check WSL version
   wsl --list --verbose
   
   # If using WSL 1, convert to WSL 2
   wsl --set-version Ubuntu 2
   ```

3. **Restart WSL:**
   ```bash
   # From Windows PowerShell or CMD
   wsl --shutdown
   
   # Then restart your WSL terminal
   ```

### Clean Up Docker Resources

```bash
# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune -a

# Remove all unused volumes
docker volume prune

# Remove all unused networks
docker network prune

# Remove everything (containers, images, volumes, networks)
docker system prune -a --volumes
```

---

## Uninstall Docker (if needed)

### Uninstall Docker Engine

```bash
# Stop Docker service
sudo systemctl stop docker

# Uninstall Docker packages
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Remove Docker images, containers, volumes, and configuration
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# Remove Docker repository
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.gpg
```

### Uninstall Docker Compose (Standalone)

```bash
# Remove Docker Compose binary
sudo rm /usr/local/bin/docker-compose

# Remove symlink if exists
sudo rm /usr/bin/docker-compose
```

---

## Quick Reference Commands

### Docker Commands

```bash
# Container management
docker ps                    # List running containers
docker ps -a                 # List all containers
docker start <container>     # Start container
docker stop <container>      # Stop container
docker restart <container>   # Restart container
docker rm <container>        # Remove container
docker rm -f <container>     # Force remove running container

# Image management
docker images                # List images
docker pull <image>          # Pull image
docker rmi <image>           # Remove image
docker build -t <tag> .      # Build image

# Logs and inspection
docker logs <container>      # View container logs
docker logs -f <container>   # Follow logs
docker exec -it <container> <command>  # Execute command in container
docker inspect <container>  # Inspect container details

# System information
docker info                  # Docker system information
docker version               # Docker version
docker stats                 # Container resource usage
```

### Docker Compose Commands

**Using Docker Compose Plugin (recommended):**
```bash
docker compose up -d         # Start services in background
docker compose down          # Stop and remove services
docker compose ps            # List services
docker compose logs          # View logs
docker compose logs -f       # Follow logs
docker compose restart      # Restart services
docker compose build        # Build images
docker compose pull         # Pull images
docker compose exec <service> <command>  # Execute command in service
```

**Using Standalone Docker Compose:**
```bash
docker-compose up -d         # Start services in background
docker-compose down          # Stop and remove services
docker-compose ps            # List services
docker-compose logs          # View logs
docker-compose logs -f       # Follow logs
docker-compose restart       # Restart services
docker-compose build         # Build images
docker-compose pull          # Pull images
docker-compose exec <service> <command>  # Execute command in service
```

---

## Additional Resources

- **Docker Official Documentation**: https://docs.docker.com/
- **Docker Compose Documentation**: https://docs.docker.com/compose/
- **Docker Hub**: https://hub.docker.com/
- **Docker Installation Guide**: https://docs.docker.com/engine/install/ubuntu/

---

## ✅ Installation Checklist

- [ ] Docker Engine installed
- [ ] Docker Compose installed (plugin or standalone)
- [ ] Docker service running
- [ ] Docker service enabled on boot
- [ ] User added to docker group (optional, for running without sudo)
- [ ] Docker version verified
- [ ] Docker Compose version verified
- [ ] Test container runs successfully
- [ ] Docker Compose test works

---

---

## Running Hyperlane Validator and Relayer

### ⚠️ Important: Testnet vs Production

This repository contains **two Docker Compose configuration files**:

1. **`docker-compose-testnet.yml`** - For testing on testnet networks
2. **`docker-compose.yml`** - For production/mainnet networks

### 🧪 Recommended Workflow: Test First on Testnet

**⚠️ CRITICAL**: Always test your configuration on testnet before running in production!

1. **First, test everything on testnet:**
   ```bash
   # Start testnet services
   docker-compose -f docker-compose-testnet.yml up -d
   
   # Check logs
   docker-compose -f docker-compose-testnet.yml logs -f
   
   # Check status
   docker-compose -f docker-compose-testnet.yml ps
   
   # Stop testnet services
   docker-compose -f docker-compose-testnet.yml down
   ```

2. **Only after successful testing, proceed to production:**
   ```bash
   # Start production services
   docker-compose -f docker-compose.yml up -d
   
   # Check logs
   docker-compose -f docker-compose.yml logs -f
   
   # Check status
   docker-compose -f docker-compose.yml ps
   
   # Stop production services
   docker-compose -f docker-compose.yml down
   ```

### 📝 Key Differences

| Feature | Testnet (`docker-compose-testnet.yml`) | Production (`docker-compose.yml`) |
|---------|----------------------------------------|-----------------------------------|
| **Network** | Testnet | Mainnet |
| **Container Names** | `hpl-relayer-testnet`, `hpl-validator-terraclassic-testnet` | `hpl-relayer`, `hpl-validator-terraclassic` |
| **Config Files** | `agent-config.docker-testnet.json`, `relayer-testnet.json` | `agent-config.docker-mainnet.json`, `relayer-mainnet.json` |
| **Relayer Port** | `9112:9090` | `9110:9090` |
| **Validator Port** | `9122:9090` | `9121:9090` |
| **Relayer Data Volume** | `./relayer-testnet:/etc/data` | `./relayer:/etc/data` |
| **Validator Data Volume** | `./validator-testnet:/etc/data` | `./validator:/etc/data` |
| **Purpose** | Testing and validation | Production deployment |
| **Risk Level** | Low (test tokens) | High (real tokens) |
| **Can Run Simultaneously** | ✅ Yes (different ports & volumes) | ✅ Yes (different ports & volumes) |

### 🔍 Common Commands for Both Environments

**For Testnet:**
```bash
# Start in background
docker-compose -f docker-compose-testnet.yml up -d

# View logs
docker-compose -f docker-compose-testnet.yml logs -f

# View logs for specific service
docker-compose -f docker-compose-testnet.yml logs -f validator-terraclassic
docker-compose -f docker-compose-testnet.yml logs -f relayer

# Check status
docker-compose -f docker-compose-testnet.yml ps

# Stop services
docker-compose -f docker-compose-testnet.yml down

# Restart services
docker-compose -f docker-compose-testnet.yml restart
```

**For Production:**
```bash
# Start in background
docker-compose -f docker-compose.yml up -d

# View logs
docker-compose -f docker-compose.yml logs -f

# View logs for specific service
docker-compose -f docker-compose.yml logs -f validator-terraclassic
docker-compose -f docker-compose.yml logs -f relayer

# Check status
docker-compose -f docker-compose.yml ps

# Stop services
docker-compose -f docker-compose.yml down

# Restart services
docker-compose -f docker-compose.yml restart
```

### 🌐 Accessing Services (Ports)

Since testnet and production use different ports, you can run both environments simultaneously:

**Testnet Services:**
- Relayer metrics/API: `http://localhost:9112`
- Validator metrics: `http://localhost:9122`

**Production Services:**
- Relayer metrics/API: `http://localhost:9110`
- Validator metrics: `http://localhost:9121`

**Example: Access testnet relayer metrics:**
```bash
curl http://localhost:9112/metrics
```

**Example: Access production validator metrics:**
```bash
curl http://localhost:9121/metrics
```

### ⚠️ Error: "docker-compose-testnet: command not found"

If you see this error, remember that `docker-compose-testnet.yml` is a **configuration file**, not a command. Always use:

```bash
docker-compose -f docker-compose-testnet.yml <command>
```

Or with Docker Compose v2:
```bash
docker compose -f docker-compose-testnet.yml <command>
```

The `-f` flag specifies which configuration file to use.

---

**🎉 Docker and Docker Compose are now installed and ready to use!**

You can now proceed with running Hyperlane validator and relayer using Docker Compose. **Remember to test on testnet first!**


