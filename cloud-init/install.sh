#!/bin/bash
# =============================================================
#  CLOUD-INIT — Installation automatique complète
#  DevOps / DataOps / Network Admin / SRE / Pentest
#  Ubuntu 22.04 LTS
# =============================================================

set -euo pipefail
LOG="/var/log/devops-install.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "  DevOps Pro VM — Installation démarrée"
echo "  $(date)"
echo "=============================================="

ADMIN_USER="devopsadmin"
HOME_DIR="/home/$ADMIN_USER"
DATA_DISK="/dev/sdc"
DATA_MOUNT="/data"

ok()  { echo "   $1"; }
err() { echo "    $1 (non bloquant)"; }

# pip silencieux — jamais bloquant
pip_install() {
  if pip3 install --help 2>/dev/null | grep -q -- '--root-user-action'; then
    pip3 install --quiet --root-user-action=ignore "$@" 2>/dev/null || err "pip_install échoué: $*"
  else
    pip3 install --quiet "$@" 2>/dev/null || err "pip_install échoué: $*"
  fi
}

# ==============================================================
# 0. MISE À JOUR SYSTÈME
# ==============================================================
echo "[0/12] Mise à jour système..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get upgrade -y -qq \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"

apt-get install -y -qq \
  curl wget git vim nano htop tmux tree \
  unzip zip tar gzip bzip2 \
  build-essential gcc g++ make cmake \
  software-properties-common apt-transport-https \
  ca-certificates gnupg lsb-release \
  jq xmlstarlet \
  net-tools nmap traceroute tcpdump wireshark-common \
  dnsutils whois mtr-tiny iperf3 \
  netdiscover arp-scan \
  sshpass openssh-client \
  rsync netcat-openbsd socat httpie \
  python3 python3-pip python3-venv python3-dev \
  libssl-dev libffi-dev \
  fail2ban ufw \
  zsh fzf bat fd-find ripgrep || err "Certains paquets apt ont échoué"

# Upgrade pip + typing_extensions immédiatement après installation système
# FIX : pydantic-core / Airflow crashent si typing_extensions < 4.13
python3 -m pip install --upgrade pip --quiet 2>/dev/null || err "Upgrade pip échoué"
pip3 install --quiet --root-user-action=ignore "typing_extensions>=4.13.2" 2>/dev/null \
  || err "Upgrade typing_extensions échoué"
ok "pip mis à jour : $(python3 -m pip --version 2>/dev/null || echo inconnue)"
ok "typing_extensions : $(python3 -c 'import typing_extensions; print(typing_extensions.__version__)' 2>/dev/null || echo inconnue)"

# eza
wget -qO /tmp/eza.tar.gz \
  "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
  && tar xzf /tmp/eza.tar.gz -C /usr/local/bin eza \
  && rm /tmp/eza.tar.gz \
  && ok "eza installé" || err "eza non installé"

# yq
wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq \
  && ok "yq installé" || err "yq non installé"

ok "[0/12] Système mis à jour"

# ==============================================================
# 1. DISQUE DE DONNÉES
# ==============================================================
echo "[1/12] Configuration du disque de données..."

for i in $(seq 1 6); do
  [ -b "$DATA_DISK" ] && break
  echo "  Attente du disque $DATA_DISK... ($i/6)"
  sleep 5
done

if [ -b "$DATA_DISK" ]; then
  if ! blkid "$DATA_DISK" | grep -q ext4; then
    mkfs.ext4 -L datadisk "$DATA_DISK"
  fi
  mkdir -p "$DATA_MOUNT"
  if ! grep -q "$DATA_DISK" /etc/fstab; then
    echo "$DATA_DISK  $DATA_MOUNT  ext4  defaults,nofail  0  2" >> /etc/fstab
  fi
  mount -a || true
  ok "Disque $DATA_DISK monté sur $DATA_MOUNT"
else
  err "Disque $DATA_DISK non trouvé, on continue sans"
  mkdir -p "$DATA_MOUNT"
fi

mkdir -p "$DATA_MOUNT"/{projects,datasets,backups,docker-volumes}
mkdir -p "$DATA_MOUNT/docker-volumes"/{postgres,redis,mongo}
mkdir -p "$DATA_MOUNT/pentest"/{recon,exploits,reports,loot}
chown -R "$ADMIN_USER:$ADMIN_USER" "$DATA_MOUNT"

ok "[1/12] Disque données configuré → $DATA_MOUNT"

# ==============================================================
# 2. ZSH + OH MY ZSH
# ==============================================================
echo "[2/12] Installation ZSH + Oh My Zsh..."
chsh -s "$(which zsh)" "$ADMIN_USER" || true

sudo -u "$ADMIN_USER" env RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  || err "Oh My Zsh non installé"

sudo -u "$ADMIN_USER" git clone --depth=1 \
  https://github.com/zsh-users/zsh-autosuggestions \
  "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true

sudo -u "$ADMIN_USER" git clone --depth=1 \
  https://github.com/zsh-users/zsh-syntax-highlighting \
  "$HOME_DIR/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true

cat > "$HOME_DIR/.zshrc" << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git docker docker-compose kubectl terraform ansible python pip zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh 2>/dev/null || true

# Aliases
alias ll='ls -alFh --color=auto'
alias ls='eza --icons 2>/dev/null || ls --color=auto'
alias k='kubectl'
alias d='docker'
alias dc='docker compose'
alias tf='terraform'
alias tg='terragrunt'
alias ans='ansible'
alias py='python3'
alias pip='pip3'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias update='sudo apt update && sudo apt upgrade -y'
alias cls='clear'

# PATH
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"
export EDITOR=vim
export DOCKER_BUILDKIT=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export GOPATH="$HOME/go"

# Completions
[[ -f /usr/local/bin/kubectl ]]   && source <(kubectl completion zsh)   2>/dev/null || true
[[ -f /usr/local/bin/helm ]]      && source <(helm completion zsh)      2>/dev/null || true
[[ -f /usr/local/bin/terraform ]] && complete -o nospace -C /usr/local/bin/terraform terraform 2>/dev/null || true

# SDKMAN
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

echo "  DevOps Pro VM — Bienvenue $USER"
ZSHRC

chown "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.zshrc"
ok "[2/12] ZSH configuré"

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
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# ── FIX DOCKER PERMISSIONS ──────────────────────────────────
# usermod -aG fonctionne uniquement si l'utilisateur existe déjà.
# cloud-init tourne en root ; on vérifie explicitement que $ADMIN_USER
# existe avant d'appeler usermod pour éviter "user '' does not exist".
if id "$ADMIN_USER" &>/dev/null; then
  usermod -aG docker "$ADMIN_USER"
  ok "Utilisateur $ADMIN_USER ajouté au groupe docker"
else
  err "Utilisateur $ADMIN_USER non trouvé — usermod ignoré"
fi

# Activer le groupe docker dans les sessions futures sans reconnexion
cat >> "$HOME_DIR/.profile" << 'PROFILE_DOCKER'

# Activer le groupe docker sans reconnexion (cloud-init fix)
if ! id -Gn 2>/dev/null | grep -qw docker; then
  exec sg docker "$SHELL $@"
fi
PROFILE_DOCKER

# S'assurer que le socket est accessible par le groupe docker
chmod 660 /var/run/docker.sock 2>/dev/null || true
chgrp docker /var/run/docker.sock 2>/dev/null || true

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl start docker
# Attendre que le socket Docker soit prêt
timeout 30 bash -c 'until docker info &>/dev/null; do sleep 2; done'

# ── Seul Portainer est démarré comme conteneur au boot ──────
docker volume create portainer_data || true
docker run -d \
  --name portainer \
  --restart always \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest && ok "Portainer démarré sur :9443" || err "Portainer non démarré"

ok "[3/12] Docker + Portainer installés"

# ==============================================================
# 4. KUBERNETES TOOLS
# ==============================================================
echo "[4/12] Outils Kubernetes..."

KUBECTL_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
ok "kubectl $KUBECTL_VER installé"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
  && ok "helm installé" || err "helm non installé"

K9S_VER=$(curl -s "https://api.github.com/repos/derailed/k9s/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/derailed/k9s/releases/download/$K9S_VER/k9s_Linux_amd64.tar.gz"
tar xzf k9s_Linux_amd64.tar.gz k9s
install k9s /usr/local/bin/
rm -f k9s k9s_Linux_amd64.tar.gz
ok "k9s $K9S_VER installé"

git clone --depth=1 https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || true
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -sf /opt/kubectx/kubens  /usr/local/bin/kubens
ok "kubectx/kubens installés"

KIND_VER=$(curl -s "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/$KIND_VER/kind-linux-amd64"
chmod +x /usr/local/bin/kind
ok "kind $KIND_VER installé"

ok "[4/12] kubectl / Helm / k9s / kind installés"

# ==============================================================
# 5. INFRASTRUCTURE AS CODE
# ==============================================================
echo "[5/12] Infrastructure as Code..."

TF_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/terraform/$TF_VER/terraform_${TF_VER}_linux_amd64.zip"
unzip -oq "terraform_${TF_VER}_linux_amd64.zip"
install terraform /usr/local/bin/
rm -f terraform terraform_*.zip
ok "Terraform $TF_VER installé"

TG_VER=$(curl -s "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/$TG_VER/terragrunt_linux_amd64"
chmod +x /usr/local/bin/terragrunt
ok "Terragrunt $TG_VER installé"

PKR_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/packer" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/packer/$PKR_VER/packer_${PKR_VER}_linux_amd64.zip"
unzip -oq "packer_${PKR_VER}_linux_amd64.zip"
install packer /usr/local/bin/
rm -f packer packer_*.zip
ok "Packer $PKR_VER installé"

pip_install ansible ansible-lint molecule && ok "Ansible installé" || err "Ansible non installé"

curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash \
  && ok "tflint installé" || err "tflint non installé"

ok "[5/12] Terraform / Terragrunt / Ansible / Packer installés"

# ==============================================================
# 6. CI/CD — Azure CLI, GitHub CLI, ArgoCD, act, Vault, Skaffold, Stern, cosign
# ==============================================================
echo "[6/12] CI/CD Tools..."

curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
  && ok "Azure CLI installé" || err "Azure CLI non installé"

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update -qq
apt-get install -y gh && ok "GitHub CLI installé" || err "GitHub CLI non installé"

ARGOCD_VER=$(curl -s "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VER/argocd-linux-amd64"
chmod +x /usr/local/bin/argocd
ok "ArgoCD CLI $ARGOCD_VER installé"

curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash \
  && ok "act installé" || err "act non installé"

# ── Vault — service systemd persisté ────────────────────────
VAULT_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/vault" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/vault/$VAULT_VER/vault_${VAULT_VER}_linux_amd64.zip"
unzip -oq "vault_${VAULT_VER}_linux_amd64.zip"
install vault /usr/local/bin/
rm -f vault vault_*.zip

useradd --system --home /etc/vault.d --shell /bin/false vault 2>/dev/null || true
mkdir -p /etc/vault.d /opt/vault/data
chown -R vault:vault /etc/vault.d /opt/vault

cat > /etc/vault.d/vault.hcl << 'EOF'
ui            = true
disable_mlock = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://0.0.0.0:8200"
EOF

cat > /etc/systemd/system/vault.service << 'EOF'
[Unit]
Description=HashiCorp Vault
Documentation=https://www.vaultproject.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl enable vault
systemctl start vault
sleep 3

if [ ! -f /root/.vault-init ]; then
  export VAULT_ADDR="http://127.0.0.1:8200"
  vault operator init -key-shares=1 -key-threshold=1 -format=json > /root/.vault-init 2>/dev/null || true
  chmod 600 /root/.vault-init
  UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' /root/.vault-init 2>/dev/null || echo "")
  [ -n "$UNSEAL_KEY" ] && vault operator unseal "$UNSEAL_KEY" || true
  ok "Vault $VAULT_VER initialisé — root token dans /root/.vault-init"
fi

# Skaffold
curl -sLo /usr/local/bin/skaffold \
  "https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64"
chmod +x /usr/local/bin/skaffold
ok "Skaffold installé"

# Stern
STERN_VER=$(curl -s "https://api.github.com/repos/stern/stern/releases/latest" | jq -r .tag_name | tr -d v)
curl -sLO "https://github.com/stern/stern/releases/download/v${STERN_VER}/stern_${STERN_VER}_linux_amd64.tar.gz"
tar xzf "stern_${STERN_VER}_linux_amd64.tar.gz" stern
install stern /usr/local/bin/
rm -f stern stern_*.tar.gz
ok "Stern $STERN_VER installé"

# cosign
COSIGN_VER=$(curl -s "https://api.github.com/repos/sigstore/cosign/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/cosign \
  "https://github.com/sigstore/cosign/releases/download/$COSIGN_VER/cosign-linux-amd64"
chmod +x /usr/local/bin/cosign
ok "cosign $COSIGN_VER installé"

ok "[6/12] Azure CLI / GitHub CLI / ArgoCD / act / Vault / Skaffold / Stern / cosign installés"

# ==============================================================
# 7. MONITORING — Prometheus + Grafana + Node Exporter
# ==============================================================
echo "[7/12] Stack Monitoring..."

NE_VER=$(curl -s "https://api.github.com/repos/prometheus/node_exporter/releases/latest" \
  | jq -r .tag_name | tr -d v)
curl -sLO "https://github.com/prometheus/node_exporter/releases/download/v${NE_VER}/node_exporter-${NE_VER}.linux-amd64.tar.gz"
tar xzf "node_exporter-${NE_VER}.linux-amd64.tar.gz"
install "node_exporter-${NE_VER}.linux-amd64/node_exporter" /usr/local/bin/
rm -rf node_exporter*

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes
Restart=always
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now node_exporter
ok "Node Exporter $NE_VER démarré sur :9100"

mkdir -p /etc/prometheus
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'vault'
    metrics_path: '/v1/sys/metrics'
    params:
      format: ['prometheus']
    bearer_token_file: /root/.vault-token
    static_configs:
      - targets: ['localhost:8200']
EOF

docker run -d \
  --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  && ok "Prometheus démarré sur :9090" || err "Prometheus non démarré"

docker volume create grafana_data || true
docker run -d \
  --name grafana \
  --restart always \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -e GF_USERS_ALLOW_SIGN_UP=false \
  -v grafana_data:/var/lib/grafana \
  grafana/grafana-oss:latest \
  && ok "Grafana démarré sur :3000" || err "Grafana non démarré"

ok "[7/12] Prometheus (9090) + Grafana (3000) + Node Exporter (9100) installés"

# ==============================================================
# 8. PYTHON / DATAOPS
# ==============================================================
echo "[8/12] Stack DataOps / Data Science Python..."

python3 -m pip install --quiet --upgrade pip setuptools wheel 2>/dev/null || true

# ── FIX TYPING_EXTENSIONS ───────────────────────────────────
# pydantic-core >= 2.x et Airflow 2.9 nécessitent typing_extensions >= 4.13.2
# qui expose `Sentinel`. On l'installe en premier, avant tout autre paquet.
pip3 install --quiet --root-user-action=ignore "typing_extensions>=4.13.2" 2>/dev/null \
  || err "Upgrade typing_extensions échoué"

# ── FIX BLINKER ─────────────────────────────────────────────
# NE PAS faire `apt-get remove python3-blinker` : cela supprime en cascade
# walinuxagent, cloud-init et d'autres packages critiques Azure.
pip_install --ignore-installed blinker

# Jupyter
pip_install jupyter jupyterlab notebook ipywidgets \
  && ok "Jupyter installé" || err "Jupyter non installé"

# Data Science
pip_install \
  numpy pandas polars \
  matplotlib seaborn plotly \
  scikit-learn xgboost \
  && ok "Data science libs installées" || err "Data science libs non installées"

# Bases de données Python (sans pymysql — MySQL supprimé)
pip_install sqlalchemy psycopg2-binary pymongo redis \
  && ok "DB libs installées" || err "DB libs non installées"

# dbt + mlflow
pip_install dbt-core mlflow \
  && ok "dbt + mlflow installés" || err "dbt/mlflow non installés"

# Cloud SDKs
pip_install boto3 azure-storage-blob azure-identity \
  && ok "Cloud SDKs installés" || err "Cloud SDKs non installés"

# Dev tools
pip_install \
  black flake8 mypy isort pylint \
  pytest pytest-cov \
  pre-commit rich click typer \
  && ok "Dev tools Python installés" || err "Dev tools non installés"

# API
pip_install fastapi "uvicorn[standard]" requests httpx aiohttp \
  && ok "API libs installées" || err "API libs non installées"

# Airflow — les contraintes sont OBLIGATOIRES pour éviter les conflits
PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
AIRFLOW_VER="2.9.1"
if pip3 install --help 2>/dev/null | grep -q -- '--root-user-action'; then
  pip3 install --quiet --root-user-action=ignore \
    "apache-airflow==${AIRFLOW_VER}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VER}/constraints-${PYTHON_VER}.txt" \
    && ok "Airflow ${AIRFLOW_VER} installé" || err "Airflow non installé"
else
  pip3 install --quiet \
    "apache-airflow==${AIRFLOW_VER}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VER}/constraints-${PYTHON_VER}.txt" \
    && ok "Airflow ${AIRFLOW_VER} installé" || err "Airflow non installé"
fi

if command -v airflow &>/dev/null; then
  sudo -u "$ADMIN_USER" bash -c "
    export AIRFLOW_HOME=$HOME_DIR/airflow
    airflow db migrate 2>/dev/null || airflow db init
    airflow users create \
      --username admin --password admin \
      --firstname Admin --lastname User \
      --role Admin --email admin@localhost 2>/dev/null || true
  " || err "Airflow DB init échoué"

  cat > /etc/systemd/system/airflow-webserver.service << EOF
[Unit]
Description=Apache Airflow Webserver
After=network.target

[Service]
User=$ADMIN_USER
Environment=AIRFLOW_HOME=$HOME_DIR/airflow
ExecStart=$(which airflow) webserver --port 8080
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/airflow-scheduler.service << EOF
[Unit]
Description=Apache Airflow Scheduler
After=network.target

[Service]
User=$ADMIN_USER
Environment=AIRFLOW_HOME=$HOME_DIR/airflow
ExecStart=$(which airflow) scheduler
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable airflow-webserver airflow-scheduler
  ok "Airflow services activés (port 8080)"
fi

# PySpark + Dask
pip_install pyspark  && ok "PySpark installé" || err "PySpark non installé"
pip_install "dask[complete]" && ok "Dask installé"  || err "Dask non installé"

# JupyterLab config
sudo -u "$ADMIN_USER" mkdir -p "$HOME_DIR/.jupyter"
cat > "$HOME_DIR/.jupyter/jupyter_lab_config.py" << 'EOF'
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.root_dir = '/data/projects'
c.ServerApp.allow_remote_access = True
EOF
chown -R "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.jupyter"

JUPYTER_BIN=$(su -c "which jupyter" - "$ADMIN_USER" 2>/dev/null \
  || find /usr /home -name jupyter -type f 2>/dev/null | head -1 \
  || echo "/usr/local/bin/jupyter")

cat > /etc/systemd/system/jupyter.service << EOF
[Unit]
Description=JupyterLab Server
After=network.target

[Service]
Type=simple
User=$ADMIN_USER
WorkingDirectory=$DATA_MOUNT/projects
ExecStart=$JUPYTER_BIN lab --config=$HOME_DIR/.jupyter/jupyter_lab_config.py
Restart=always
RestartSec=10
Environment=PATH=/home/$ADMIN_USER/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF
systemctl enable jupyter

ok "[8/12] Python DataOps stack installé"

# ==============================================================
# 9. BASES DE DONNÉES — Clients + conteneurs Docker
# ==============================================================
echo "[9/12] Outils base de données..."

# MySQL supprimé — on n'installe que les clients restants
apt-get install -y postgresql-client redis-tools sqlite3 \
  && ok "Clients DB installés (pg, redis, sqlite)" || err "Certains clients DB non installés"

# Conteneurs DB : postgres, redis, mongo uniquement (MySQL supprimé)
docker run -d \
  --name postgres \
  --restart always \
  -p 127.0.0.1:5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -v "$DATA_MOUNT/docker-volumes/postgres":/var/lib/postgresql/data \
  postgres:16-alpine &

docker run -d \
  --name redis \
  --restart always \
  -p 127.0.0.1:6379:6379 \
  -v "$DATA_MOUNT/docker-volumes/redis":/data \
  redis:7-alpine --appendonly yes &

docker run -d \
  --name mongo \
  --restart always \
  -p 127.0.0.1:27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=admin \
  -v "$DATA_MOUNT/docker-volumes/mongo":/data/db \
  mongo:7 &

wait
ok "Conteneurs DB démarrés sur loopback (postgres:5432, redis:6379, mongo:27017)"

USQL_VER=$(curl -s "https://api.github.com/repos/xo/usql/releases/latest" \
  | jq -r .tag_name | tr -d v)
curl -sLO "https://github.com/xo/usql/releases/download/v${USQL_VER}/usql_static-${USQL_VER}-linux-amd64.tar.bz2" \
  && tar xjf usql_static-*.tar.bz2 \
  && install usql_static /usr/local/bin/usql \
  && rm -f usql_static* \
  && ok "usql $USQL_VER installé" || err "usql non installé"

ok "[9/12] Clients DB + conteneurs Docker démarrés"

# ==============================================================
# 10. RÉSEAU / SÉCURITÉ
# ==============================================================
echo "[10/12] Outils réseau & sécurité..."

apt-get install -y masscan tshark autossh vpnc openvpn wireguard \
  && ok "Outils réseau installés" || err "Certains outils réseau non installés"

curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin \
  && ok "Trivy installé" || err "Trivy non installé"

HADO_VER=$(curl -s "https://api.github.com/repos/hadolint/hadolint/releases/latest" \
  | jq -r .tag_name)
curl -sLo /usr/local/bin/hadolint \
  "https://github.com/hadolint/hadolint/releases/download/$HADO_VER/hadolint-Linux-x86_64"
chmod +x /usr/local/bin/hadolint
ok "Hadolint $HADO_VER installé"

# ── UFW — aligné exactement sur les règles NSG de network.tf ──
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH (allowed_ssh_cidr via NSG)'
ufw allow 80/tcp   comment 'HTTP public'
ufw allow 443/tcp  comment 'HTTPS public'
ufw allow 8888/tcp comment 'JupyterLab (allowed_ssh_cidr via NSG)'
ufw allow 3000/tcp comment 'Grafana (allowed_ssh_cidr via NSG)'
ufw allow 9090/tcp comment 'Prometheus (allowed_ssh_cidr via NSG)'
ufw allow 9443/tcp comment 'Portainer (allowed_ssh_cidr via NSG)'
ufw allow 8200/tcp comment 'Vault (allowed_ssh_cidr via NSG)'
ufw --force enable
ok "UFW configuré (règles alignées sur network.tf NSG)"

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
systemctl enable --now fail2ban
ok "fail2ban configuré et démarré"

ok "[10/12] Réseau & sécurité OK"

# ==============================================================
# 10b. PENTEST & SÉCURITÉ OFFENSIVE
# ==============================================================
echo "[10b/12] Outils Pentest & Sécurité offensive..."

apt-get install -y \
  nikto \
  hydra \
  sqlmap \
  john \
  sslscan \
  dirb \
  netdiscover \
  arp-scan \
  enum4linux \
  nbtscan \
  && ok "Outils pentest apt installés" || err "Certains outils pentest apt non installés"

NUCLEI_VER=$(curl -s "https://api.github.com/repos/projectdiscovery/nuclei/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/projectdiscovery/nuclei/releases/download/$NUCLEI_VER/nuclei_${NUCLEI_VER#v}_linux_amd64.zip"
unzip -oq nuclei_*.zip nuclei
install nuclei /usr/local/bin/
rm -f nuclei nuclei_*.zip
sudo -u "$ADMIN_USER" /usr/local/bin/nuclei -update-templates 2>/dev/null || true
ok "Nuclei $NUCLEI_VER installé (templates mis à jour)"

FFUF_VER=$(curl -s "https://api.github.com/repos/ffuf/ffuf/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/ffuf/ffuf/releases/download/$FFUF_VER/ffuf_${FFUF_VER#v}_linux_amd64.tar.gz"
tar xzf ffuf_*.tar.gz ffuf
install ffuf /usr/local/bin/
rm -f ffuf ffuf_*.tar.gz
ok "ffuf $FFUF_VER installé"

GOBB_VER=$(curl -s "https://api.github.com/repos/OJ/gobuster/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/OJ/gobuster/releases/download/$GOBB_VER/gobuster_Linux_x86_64.tar.gz"
tar xzf gobuster_Linux_x86_64.tar.gz gobuster
install gobuster /usr/local/bin/
rm -f gobuster gobuster_*.tar.gz
ok "gobuster $GOBB_VER installé"

AMASS_VER=$(curl -s "https://api.github.com/repos/owasp-amass/amass/releases/latest" | jq -r .tag_name)
curl -sLO "https://github.com/owasp-amass/amass/releases/download/$AMASS_VER/amass_Linux_amd64.zip"
unzip -oq amass_Linux_amd64.zip
install amass_Linux_amd64/amass /usr/local/bin/
rm -rf amass_Linux_amd64*
ok "Amass $AMASS_VER installé"

pip_install theHarvester && ok "theHarvester installé" || err "theHarvester non installé"

git clone --depth=1 https://github.com/drwetter/testssl.sh /opt/testssl 2>/dev/null \
  || git -C /opt/testssl pull 2>/dev/null || true
ln -sf /opt/testssl/testssl.sh /usr/local/bin/testssl
ok "testssl.sh installé"

curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg \
  | gpg --dearmor -o /usr/share/keyrings/metasploit.gpg 2>/dev/null || true
echo "deb [signed-by=/usr/share/keyrings/metasploit.gpg] https://apt.metasploit.com/ $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/metasploit.list
apt-get update -qq 2>/dev/null || true
apt-get install -y metasploit-framework \
  && ok "Metasploit installé" \
  || err "Metasploit non installé (repo peut ne pas supporter jammy)"

git clone --depth=1 https://github.com/danielmiessler/SecLists /opt/SecLists 2>/dev/null \
  && ok "SecLists installé dans /opt/SecLists" || err "SecLists non installé"

apt-get install -y wordlists 2>/dev/null || true
gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
ok "Wordlists configurées (/usr/share/wordlists/rockyou.txt)"

ok "[10b/12] Outils Pentest installés"

# ==============================================================
# 11. LANGAGES — Go, Node.js, Rust, Java
# ==============================================================
echo "[11/12] Langages de programmation..."

GO_VER=$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
curl -sLO "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "${GO_VER}.linux-amd64.tar.gz"
rm -f "${GO_VER}.linux-amd64.tar.gz"
cat > /etc/profile.d/go.sh << 'EOF'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
export GOPATH=$HOME/go
EOF
chmod +x /etc/profile.d/go.sh
export PATH=$PATH:/usr/local/go/bin
ok "Go $GO_VER installé"

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
npm install -g yarn pnpm typescript ts-node eslint prettier pm2 \
  && ok "Node.js $(node --version) + npm globals installés" || err "npm globals non installés"

sudo -u "$ADMIN_USER" bash -c \
  'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path 2>/dev/null' \
  && ok "Rust installé" || err "Rust non installé"

apt-get install -y openjdk-21-jdk maven \
  && ok "Java 21 + Maven installés" || err "Java non installé"

cat > /etc/profile.d/java.sh << 'EOF'
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"
EOF
chmod +x /etc/profile.d/java.sh

GRADLE_VER="8.7"
curl -sLO "https://services.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip"
unzip -oq "gradle-${GRADLE_VER}-bin.zip" -d /opt/
ln -sf "/opt/gradle-${GRADLE_VER}/bin/gradle" /usr/local/bin/gradle
rm -f "gradle-${GRADLE_VER}-bin.zip"
ok "Gradle $GRADLE_VER installé"

sudo -u "$ADMIN_USER" bash -c 'curl -s "https://get.sdkman.io" | bash' \
  && ok "SDKMAN installé" || err "SDKMAN non installé"

ok "[11/12] Go / Node.js / Rust / Java installés"

# ==============================================================
# 12. FINALISATION — MOTD, Vim, Git, devops-status
# ==============================================================
echo "[12/12] Configuration finale..."

sudo -u "$ADMIN_USER" git config --global init.defaultBranch main
sudo -u "$ADMIN_USER" git config --global pull.rebase false
sudo -u "$ADMIN_USER" git config --global core.editor vim
ok "Git configuré"

cat > /etc/vim/vimrc.local << 'VIMRC'
syntax on
set number relativenumber
set tabstop=2 shiftwidth=2 expandtab
set autoindent smartindent
set hlsearch incsearch
set clipboard=unnamedplus
set mouse=a
set background=dark
set wildmenu
set showcmd
colorscheme desert
VIMRC
ok "Vim configuré"

cat > /etc/motd << 'MOTD'

  ╔══════════════════════════════════════════════════════════╗
  ║          DevOps Pro VM — Azure Students                 ║
  ║              Ubuntu 22.04 LTS                           ║
  ╠══════════════════════════════════════════════════════════╣
  ║  🐳 Docker        : docker ps                           ║
  ║  ☸  Kubernetes    : kubectl get nodes                   ║
  ║  🏗  Terraform     : terraform --version                 ║
  ║  🔐 Vault         : http://<IP>:8200 (init /root)       ║
  ║  📦 Skaffold      : skaffold version                    ║
  ║  📊 Jupyter       : http://<IP>:8888                    ║
  ║  📈 Grafana       : http://<IP>:3000  (admin/admin)     ║
  ║  📉 Prometheus    : http://<IP>:9090                    ║
  ║  🐋 Portainer     : https://<IP>:9443                   ║
  ╠══════════════════════════════════════════════════════════╣
  ║  🐘 PostgreSQL    : localhost:5432    (postgres/postgres)║
  ║  🔴 Redis         : localhost:6379                       ║
  ║  🍃 MongoDB       : localhost:27017   (admin/admin)      ║
  ╠══════════════════════════════════════════════════════════╣
  ║  🔍 Pentest       : nuclei / ffuf / gobuster / sqlmap   ║
  ║  🌐 OSINT         : theHarvester / amass                ║
  ║  💣 Exploit       : msfconsole (Metasploit)             ║
  ║  📚 Wordlists     : /opt/SecLists / rockyou.txt         ║
  ║  📁 Pentest dir   : /data/pentest/                      ║
  ╠══════════════════════════════════════════════════════════╣
  ║  💾 Data Disk     : /data/                              ║
  ║  📋 Install Log   : /var/log/devops-install.log         ║
  ║  🔍 Statut        : devops-status                       ║
  ╚══════════════════════════════════════════════════════════╝

MOTD

cat > /usr/local/bin/devops-status << 'STATUS'
#!/bin/bash
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║            DevOps VM - Status                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "── Outils ──────────────────────────────────────────"
printf "%-18s %s\n" "Docker:"     "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo N/A)"
printf "%-18s %s\n" "kubectl:"    "$(kubectl version --client --short 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Helm:"       "$(helm version --short 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Terraform:"  "$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo N/A)"
printf "%-18s %s\n" "Ansible:"    "$(ansible --version 2>/dev/null | head -1 | awk '{print $3}' || echo N/A)"
printf "%-18s %s\n" "Vault:"      "$(vault version 2>/dev/null | awk '{print $2}' || echo N/A)"
printf "%-18s %s\n" "Python:"     "$(python3 --version 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Node.js:"    "$(node --version 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Go:"         "$(/usr/local/go/bin/go version 2>/dev/null | awk '{print $3}' || echo N/A)"
printf "%-18s %s\n" "Java:"       "$(java -version 2>&1 | head -1 || echo N/A)"
printf "%-18s %s\n" "Azure CLI:"  "$(az version 2>/dev/null | jq -r '."azure-cli"' || echo N/A)"
printf "%-18s %s\n" "Nuclei:"     "$(nuclei -version 2>/dev/null | grep -oP 'v[\d.]+' | head -1 || echo N/A)"
printf "%-18s %s\n" "Metasploit:" "$(msfconsole -v 2>/dev/null | head -1 || echo N/A)"
echo ""
echo "── Containers Docker ───────────────────────────────"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
echo ""
echo "── Services systemd ────────────────────────────────"
for svc in docker jupyter vault node_exporter fail2ban airflow-webserver airflow-scheduler; do
  STATUS_VAL=$(systemctl is-active "$svc" 2>/dev/null)
  [ "$STATUS_VAL" = "active" ] && ICON="✅" || ICON="⚪"
  printf "  %s %-24s %s\n" "$ICON" "$svc:" "$STATUS_VAL"
done
echo ""
echo "── Espace disque ───────────────────────────────────"
df -h / /data 2>/dev/null || df -h /
echo ""
echo "── Ports en écoute ─────────────────────────────────"
ss -tulnp | grep -E ':(22|80|443|3000|8080|8200|8888|9090|9100|9443)\s' 2>/dev/null || true
echo ""
STATUS
chmod +x /usr/local/bin/devops-status

systemctl daemon-reload
systemctl start jupyter 2>/dev/null && ok "JupyterLab démarré sur :8888" || err "JupyterLab non démarré (vérifier : journalctl -u jupyter)"

chown -R "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR"
chown -R "$ADMIN_USER:$ADMIN_USER" "$DATA_MOUNT" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  ✅ Installation complète terminée !"
echo "  $(date)"
echo "  Log complet : $LOG"
echo "  Lance : devops-status"
echo "=============================================="
