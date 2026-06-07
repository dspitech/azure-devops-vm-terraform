#!/bin/bash
# =============================================================
#  CLOUD-INIT — Installation automatique complète
#  DevOps / DataOps / Network Admin / SRE
#  Ubuntu 22.04 LTS
# =============================================================

set -euo pipefail
LOG="/var/log/devops-install.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo " DevOps Pro VM — Installation démarrée"
echo " $(date)"
echo "=============================================="

ADMIN_USER="${admin_username:-devopsadmin}"
HOME_DIR="/home/$ADMIN_USER"
DATA_DISK="/dev/sdc"
DATA_MOUNT="/data"

# ==============================================================
# 0. MISE À JOUR SYSTÈME
# ==============================================================
echo "[0/12] Mise à jour système..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git vim nano htop tmux tree \
  unzip zip tar gzip bzip2 \
  build-essential gcc g++ make cmake \
  software-properties-common apt-transport-https \
  ca-certificates gnupg lsb-release \
  jq yq xmlstarlet \
  net-tools nmap traceroute tcpdump wireshark-common \
  dnsutils whois mtr-tiny iperf3 \
  sshpass openssh-client \
  rsync netcat-openbsd socat \
  python3 python3-pip python3-venv python3-dev \
  libssl-dev libffi-dev \
  fail2ban ufw \
  zsh fzf bat exa fd-find ripgrep

echo "[0/12] ✅ Système mis à jour"

# ==============================================================
# 1. DISQUE DE DONNÉES
# ==============================================================
echo "[1/12] Configuration du disque de données..."
if [ -b "$DATA_DISK" ]; then
  if ! blkid "$DATA_DISK" | grep -q ext4; then
    mkfs.ext4 -L datadisk "$DATA_DISK"
  fi
  mkdir -p "$DATA_MOUNT"
  if ! grep -q "$DATA_DISK" /etc/fstab; then
    echo "$DATA_DISK  $DATA_MOUNT  ext4  defaults,nofail  0  2" >> /etc/fstab
  fi
  mount -a || true
  chown -R "$ADMIN_USER:$ADMIN_USER" "$DATA_MOUNT" || true
fi
mkdir -p "$DATA_MOUNT"/{projects,datasets,backups,docker-volumes}
echo "[1/12] ✅ Disque données configuré → $DATA_MOUNT"

# ==============================================================
# 2. ZSH + OH MY ZSH + POWERLEVEL10K
# ==============================================================
echo "[2/12] Installation ZSH + Oh My Zsh..."
chsh -s "$(which zsh)" "$ADMIN_USER" || true
sudo -u "$ADMIN_USER" sh -c \
  'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' || true

# Plugins Oh My Zsh
sudo -u "$ADMIN_USER" git clone --depth=1 \
  https://github.com/zsh-users/zsh-autosuggestions \
  "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions" || true
sudo -u "$ADMIN_USER" git clone --depth=1 \
  https://github.com/zsh-users/zsh-syntax-highlighting \
  "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" || true

cat > "$HOME_DIR/.zshrc" << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git docker docker-compose kubectl terraform ansible python pip zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Aliases pratiques
alias ll='ls -alFh --color=auto'
alias k='kubectl'
alias d='docker'
alias dc='docker compose'
alias tf='terraform'
alias ans='ansible'
alias py='python3'
alias pip='pip3'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias update='sudo apt update && sudo apt upgrade -y'
alias cls='clear'

# PATH
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"
export EDITOR=vim

# Docker
export DOCKER_BUILDKIT=1

# Python
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Kubernetes
[[ -f /usr/local/bin/kubectl ]] && source <(kubectl completion zsh)
[[ -f /usr/local/bin/helm ]] && source <(helm completion zsh)
[[ -f /usr/local/bin/terraform ]] && complete -o nospace -C /usr/local/bin/terraform terraform

echo "🚀 DevOps Pro VM — Bienvenue $USER"
ZSHRC
chown "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.zshrc"
echo "[2/12] ✅ ZSH configuré"

# ==============================================================
# 3. DOCKER + DOCKER COMPOSE
# ==============================================================
echo "[3/12] Installation Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker "$ADMIN_USER"
systemctl enable docker
systemctl start docker

# Portainer (Docker UI)
docker volume create portainer_data || true
docker run -d \
  --name portainer \
  --restart always \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest || true

echo "[3/12] ✅ Docker + Portainer installés"

# ==============================================================
# 4. KUBERNETES TOOLS
# ==============================================================
echo "[4/12] Outils Kubernetes..."

# kubectl
KUBECTL_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k9s
K9S_VER=$(curl -s "https://api.github.com/repos/derailed/k9s/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/derailed/k9s/releases/download/$K9S_VER/k9s_Linux_amd64.tar.gz"
tar xzf k9s_Linux_amd64.tar.gz k9s && install k9s /usr/local/bin/ && rm -f k9s k9s_Linux_amd64.tar.gz

# kubectx + kubens
git clone https://github.com/ahmetb/kubectx /opt/kubectx || true
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# kind (local Kubernetes)
KIND_VER=$(curl -s "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/$KIND_VER/kind-linux-amd64"
chmod +x /usr/local/bin/kind

echo "[4/12] ✅ kubectl / Helm / k9s / kind installés"

# ==============================================================
# 5. TERRAFORM + TERRAGRUNT + ANSIBLE + PACKER
# ==============================================================
echo "[5/12] Infrastructure as Code (Terraform, Ansible, Packer)..."

# Terraform
TF_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/terraform/$TF_VER/terraform_${TF_VER}_linux_amd64.zip"
unzip -oq "terraform_${TF_VER}_linux_amd64.zip" && install terraform /usr/local/bin/ && rm -f terraform terraform_*.zip

# Terragrunt
TG_VER=$(curl -s "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/$TG_VER/terragrunt_linux_amd64"
chmod +x /usr/local/bin/terragrunt

# Packer
PKR_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/packer" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/packer/$PKR_VER/packer_${PKR_VER}_linux_amd64.zip"
unzip -oq "packer_${PKR_VER}_linux_amd64.zip" && install packer /usr/local/bin/ && rm -f packer packer_*.zip

# Ansible
apt-get install -y python3-pip
pip3 install --quiet ansible ansible-lint molecule

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

echo "[5/12] ✅ Terraform / Terragrunt / Ansible / Packer installés"

# ==============================================================
# 6. CI/CD — Azure CLI, GitHub CLI, GitLab CLI, ArgoCD
# ==============================================================
echo "[6/12] CI/CD Tools..."

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update -qq && apt-get install -y gh

# ArgoCD CLI
ARGOCD_VER=$(curl -s "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VER/argocd-linux-amd64"
chmod +x /usr/local/bin/argocd

# act (GitHub Actions local runner)
curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash

echo "[6/12] ✅ Azure CLI / GitHub CLI / ArgoCD / act installés"

# ==============================================================
# 7. MONITORING — Prometheus + Grafana + Node Exporter
# ==============================================================
echo "[7/12] Stack Monitoring (Prometheus / Grafana / Node Exporter)..."

# Node Exporter
NE_VER=$(curl -s "https://api.github.com/repos/prometheus/node_exporter/releases/latest" | jq -r .tag_name | tr -d v)
curl -sLO "https://github.com/prometheus/node_exporter/releases/download/v$NE_VER/node_exporter-$NE_VER.linux-amd64.tar.gz"
tar xzf "node_exporter-$NE_VER.linux-amd64.tar.gz"
install "node_exporter-$NE_VER.linux-amd64/node_exporter" /usr/local/bin/
rm -rf node_exporter*

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now node_exporter

# Prometheus (via Docker)
mkdir -p /etc/prometheus
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

docker run -d \
  --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus || true

# Grafana (via Docker)
docker run -d \
  --name grafana \
  --restart always \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana-oss:latest || true

echo "[7/12] ✅ Prometheus (9090) + Grafana (3000) + Node Exporter démarrés"

# ==============================================================
# 8. PYTHON DATA SCIENCE / DATAOPS
# ==============================================================
echo "[8/12] Stack DataOps / Data Science Python..."

pip3 install --quiet \
  jupyter jupyterlab notebook \
  numpy pandas polars \
  matplotlib seaborn plotly \
  scikit-learn xgboost \
  sqlalchemy psycopg2-binary pymysql \
  great-expectations dbt-core \
  apache-airflow \
  pyspark \
  boto3 azure-storage-blob azure-identity \
  dask[complete] \
  mlflow \
  black flake8 mypy isort pylint \
  pytest pytest-cov httpx \
  pre-commit \
  rich click typer \
  fastapi uvicorn[standard] \
  requests httpx aiohttp

# Jupyter en service
sudo -u "$ADMIN_USER" mkdir -p "$HOME_DIR/.jupyter"
cat > "$HOME_DIR/.jupyter/jupyter_lab_config.py" << EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = False
c.ServerApp.token = ''
c.ServerApp.password = ''
EOF
chown -R "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.jupyter"

cat > /etc/systemd/system/jupyter.service << EOF
[Unit]
Description=JupyterLab Server
After=network.target
[Service]
Type=simple
User=$ADMIN_USER
WorkingDirectory=$DATA_MOUNT/projects
ExecStart=/usr/bin/python3 -m jupyter lab --config=$HOME_DIR/.jupyter/jupyter_lab_config.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable jupyter

echo "[8/12] ✅ Python DataOps stack installé (Jupyter port 8888)"

# ==============================================================
# 9. BASES DE DONNÉES — Clients + Docker images
# ==============================================================
echo "[9/12] Outils base de données..."

# Clients CLI
apt-get install -y postgresql-client mysql-client redis-tools sqlite3

# DBeaver CLI + Docker images prêtes
docker pull postgres:16-alpine || true
docker pull mysql:8 || true
docker pull redis:7-alpine || true
docker pull mongo:7 || true

# usql (universal SQL CLI)
USQL_VER=$(curl -s "https://api.github.com/repos/xo/usql/releases/latest" | jq -r .tag_name | tr -d v)
curl -sLO "https://github.com/xo/usql/releases/download/v$USQL_VER/usql-$USQL_VER-linux-amd64.tar.bz2" || true
tar xjf usql-*.tar.bz2 && install usql /usr/local/bin/ && rm -f usql* || true

echo "[9/12] ✅ Clients DB + images Docker DB installés"

# ==============================================================
# 10. RÉSEAU / SÉCURITÉ
# ==============================================================
echo "[10/12] Outils réseau & sécurité..."

apt-get install -y \
  nmap masscan \
  tcpdump tshark \
  netcat-openbsd socat \
  iperf3 \
  mtr-tiny traceroute \
  dnsutils whois \
  curl wget httpie \
  sshpass autossh \
  vpnc openvpn \
  wireguard

# Trivy (scanner de vulnérabilités containers)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Hadolint (linter Dockerfile)
HADO_VER=$(curl -s "https://api.github.com/repos/hadolint/hadolint/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/hadolint \
  "https://github.com/hadolint/hadolint/releases/download/$HADO_VER/hadolint-Linux-x86_64"
chmod +x /usr/local/bin/hadolint

# Firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8888/tcp
ufw allow 3000/tcp
ufw allow 9090/tcp
ufw allow 9443/tcp

# Fail2ban
systemctl enable --now fail2ban

echo "[10/12] ✅ Outils réseau + sécurité installés"

# ==============================================================
# 11. LANGUAGES — Go, Node.js, Rust, Java
# ==============================================================
echo "[11/12] Langages de programmation..."

# Go
GO_VER=$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
curl -sLO "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "${GO_VER}.linux-amd64.tar.gz"
rm "${GO_VER}.linux-amd64.tar.gz"
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /etc/profile.d/go.sh
export PATH=$PATH:/usr/local/go/bin

# Go tools
/usr/local/go/bin/go install github.com/go-task/task/v3/cmd/task@latest || true

# Node.js (via NodeSource LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
npm install -g \
  yarn pnpm \
  typescript ts-node \
  eslint prettier \
  pm2 \
  @azure/static-web-apps-cli \
  netlify-cli

# Rust
sudo -u "$ADMIN_USER" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
  sudo -u "$ADMIN_USER" sh -s -- -y || true

# Java (OpenJDK 21 LTS)
apt-get install -y openjdk-21-jdk maven gradle

# SDKMAN (gestionnaire JVM)
sudo -u "$ADMIN_USER" bash -c \
  'curl -s "https://get.sdkman.io" | bash' || true

echo "[11/12] ✅ Go / Node.js / Rust / Java installés"

# ==============================================================
# 12. DIVERS — MOTD, Vim, Git, finalisation
# ==============================================================
echo "[12/12] Configuration finale..."

# Git configuration globale
sudo -u "$ADMIN_USER" git config --global init.defaultBranch main
sudo -u "$ADMIN_USER" git config --global pull.rebase false
sudo -u "$ADMIN_USER" git config --global core.editor vim

# Vim amélioré
cat > /etc/vim/vimrc.local << 'VIMRC'
syntax on
set number relativenumber
set tabstop=2 shiftwidth=2 expandtab
set autoindent smartindent
set hlsearch incsearch
set clipboard=unnamedplus
set mouse=a
set background=dark
colorscheme desert
VIMRC

# MOTD personnalisé
cat > /etc/motd << 'MOTD'

  ╔══════════════════════════════════════════════════════════╗
  ║         🚀  DevOps Pro VM — Azure Students              ║
  ║              Ubuntu 22.04 LTS                           ║
  ╠══════════════════════════════════════════════════════════╣
  ║  🐳 Docker        : docker ps                           ║
  ║  ☸  Kubernetes    : kubectl get nodes                   ║
  ║  🏗  Terraform     : terraform --version                 ║
  ║  📊 Jupyter       : http://<IP>:8888                    ║
  ║  📈 Grafana       : http://<IP>:3000  (admin/admin)     ║
  ║  📉 Prometheus    : http://<IP>:9090                    ║
  ║  🐋 Portainer     : https://<IP>:9443                   ║
  ║  💾 Data Disk     : /data/                              ║
  ║  📋 Install Log   : /var/log/devops-install.log         ║
  ╚══════════════════════════════════════════════════════════╝

MOTD

# Raccourcis pratiques dans /usr/local/bin
cat > /usr/local/bin/devops-status << 'STATUS'
#!/bin/bash
echo "=== 🚀 DevOps VM Status ==="
echo "Docker:      $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
echo "kubectl:     $(kubectl version --client --short 2>/dev/null)"
echo "Terraform:   $(terraform version -json 2>/dev/null | jq -r .terraform_version)"
echo "Ansible:     $(ansible --version 2>/dev/null | head -1)"
echo "Python:      $(python3 --version)"
echo "Node.js:     $(node --version)"
echo "Go:          $(go version 2>/dev/null | awk '{print $3}')"
echo ""
echo "=== 🐳 Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
STATUS
chmod +x /usr/local/bin/devops-status

systemctl daemon-reload
systemctl restart jupyter || true

echo ""
echo "=============================================="
echo " ✅ Installation complète terminée !"
echo " $(date)"
echo " Log : $LOG"
echo " Lancez : devops-status"
echo "=============================================="
