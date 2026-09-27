#!/bin/bash
# =============================================================
#  CLOUD-INIT - Installation automatique complete
#  DevOps / DataOps / Network Admin / SRE / Pentest
#  Ubuntu 22.04 LTS
# =============================================================

# NOTE: pas de "set -e" ici, volontairement. Ce script installe ~40 outils
# independants ; si l'un d'eux echoue (rate-limit GitHub, mirroir Ubuntu
# temporairement indisponible, etc.) le script DOIT continuer pour que les
# 39 autres soient installes et que l'installation se termine a 100%.
# Chaque etape gere deja explicitement son echec via `|| err "..."`.
set -uo pipefail
LOG="/var/log/devops-install.log"
exec > >(tee -a "$LOG") 2>&1

# Si une commande non protegee par || plante quand meme, on log et on
# continue au lieu de laisser un "set -e" implicite tuer tout le script.
trap 'err "Commande inattendue en echec (ligne $LINENO) - poursuite"' ERR

echo "=============================================="
echo "  DevOps Pro VM - Installation demarree"
echo "  $(date)"
echo "=============================================="

# -- Valeurs injectees par Terraform (voir main.tf: cloud_init_header) --
# Les valeurs par defaut ci-dessous ne servent que si ce script est
# relance/teste manuellement en dehors de Terraform.
ADMIN_USER="${ADMIN_USER:-devopsadmin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
PORTAINER_ADMIN_PASSWORD="${PORTAINER_ADMIN_PASSWORD:-ChangeMe123456}"
DATA_DISK_LUN="${DATA_DISK_LUN:-10}"
VM_PROFILE="${VM_PROFILE:-fullstack}"

# -- Profils --------------------------------------------------
# "base"     : socle toujours installe, quel que soit le profil.
# "devops"   : Kubernetes, IaC, CI/CD, scan securite conteneurs.
# "dataops"  : Python / Jupyter / data science, bases de donnees.
# "cybersecurity" : outils reseau + pentest offensif.
# "fullstack" (defaut) : tout ce qui precede - comportement historique.
should_run() {
  local tag="$1"
  [ "$tag" = "base" ] && return 0
  [ "$VM_PROFILE" = "fullstack" ] && return 0
  [ "$VM_PROFILE" = "$tag" ] && return 0
  return 1
}
skip_msg() { echo "  [SKIP]  Phase ignoree (profil \"$VM_PROFILE\" ne necessite pas : $1)"; }

HOME_DIR="/home/$ADMIN_USER"
DATA_MOUNT="/data"

ok()  { echo "   $1"; }
err() { echo "    $1 (non bloquant)"; }

# pip silencieux - jamais bloquant
pip_install() {
  if pip3 install --help 2>/dev/null | grep -q -- '--root-user-action'; then
    pip3 install --quiet --root-user-action=ignore "$@" 2>/dev/null || err "pip_install echoue: $*"
  else
    pip3 install --quiet "$@" 2>/dev/null || err "pip_install echoue: $*"
  fi
}

# Recupere le tag de la derniere release GitHub d'un depot, avec retries
# et repli propre si l'API est rate-limitee (au lieu de lancer un
# telechargement vers une URL contenant ".../download/null/...").
# Usage: VER=$(gh_latest owner/repo) ; [ -n "$VER" ] || { err "..."; continue-ish }
gh_latest() {
  local repo="$1" tag="" attempt
  for attempt in 1 2 3; do
    tag=$(curl -fsSL --max-time 15 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
      | jq -r '.tag_name // empty' 2>/dev/null || true)
    [ -n "$tag" ] && [ "$tag" != "null" ] && break
    sleep $((attempt * 3))
  done
  echo "$tag"
}

# ==============================================================
# 0. MISE A JOUR SYSTEME
# ==============================================================
echo "[0/12] Mise a jour systeme..."
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
  zsh fzf bat fd-find ripgrep || err "Certains paquets apt ont echoue"

# Upgrade pip + typing_extensions immediatement apres installation systeme
python3 -m pip install --upgrade pip --quiet 2>/dev/null || err "Upgrade pip echoue"
pip3 install --quiet --root-user-action=ignore "typing_extensions>=4.13.2" 2>/dev/null \
  || err "Upgrade typing_extensions echoue"
ok "pip mis a jour : $(python3 -m pip --version 2>/dev/null || echo inconnue)"
ok "typing_extensions : $(python3 -c 'import typing_extensions; print(typing_extensions.__version__)' 2>/dev/null || echo inconnue)"

# eza
wget -qO /tmp/eza.tar.gz \
  "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
  && tar xzf /tmp/eza.tar.gz -C /usr/local/bin eza \
  && rm /tmp/eza.tar.gz \
  && ok "eza installe" || err "eza non installe"

# yq
wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq \
  && ok "yq installe" || err "yq non installe"

ok "[0/12] Systeme mis a jour"

# ==============================================================
# 1. DISQUE DE DONNEES
# ==============================================================
echo "[1/12] Configuration du disque de donnees..."

# Le disque de donnees est identifie par son LUN Azure (lien udev stable
# /dev/disk/azure/scsi1/lunN), plutot que par une lettre "/dev/sdX" qui
# peut varier selon la generation de VM / le nombre de disques attaches.
AZURE_LUN_LINK="/dev/disk/azure/scsi1/lun${DATA_DISK_LUN}"
DATA_DISK=""

for i in $(seq 1 12); do
  if [ -e "$AZURE_LUN_LINK" ]; then
    DATA_DISK="$(readlink -f "$AZURE_LUN_LINK")"
    break
  fi
  echo "  Attente du disque de donnees (LUN $DATA_DISK_LUN)... ($i/12)"
  sleep 5
done

# Repli : si le lien udev par LUN n'existe pas (image/generation plus
# ancienne), on cherche le premier disque non partitionne et sans
# systeme de fichiers, en excluant le disque OS (celui qui contient /).
if [ -z "$DATA_DISK" ]; then
  err "Lien $AZURE_LUN_LINK introuvable, recherche du disque de donnees par heuristique"
  os_disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null || true)"
  for dev in $(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}'); do
    devname="$(basename "$dev")"
    [ "$devname" = "$os_disk" ] && continue
    fstype="$(lsblk -no FSTYPE "$dev" 2>/dev/null | head -1)"
    children="$(lsblk -no NAME "$dev" 2>/dev/null | wc -l)"
    if [ -z "$fstype" ] && [ "$children" -le 1 ]; then
      DATA_DISK="$dev"
      break
    fi
  done
fi

if [ -n "$DATA_DISK" ] && [ -b "$DATA_DISK" ]; then
  if ! blkid "$DATA_DISK" | grep -q ext4; then
    mkfs.ext4 -L datadisk "$DATA_DISK"
  fi
  mkdir -p "$DATA_MOUNT"
  if ! grep -q "$DATA_DISK" /etc/fstab; then
    echo "$DATA_DISK  $DATA_MOUNT  ext4  defaults,nofail  0  2" >> /etc/fstab
  fi
  mount -a || true
  ok "Disque $DATA_DISK monte sur $DATA_MOUNT"
else
  err "Aucun disque de donnees trouve, on continue sans (les donnees iront sur le disque OS)"
  mkdir -p "$DATA_MOUNT"
fi

mkdir -p "$DATA_MOUNT"/{projects,datasets,backups,docker-volumes}
mkdir -p "$DATA_MOUNT/docker-volumes"/{postgres,redis}
mkdir -p "$DATA_MOUNT/pentest"/{recon,exploits,reports,loot}
chown -R "$ADMIN_USER:$ADMIN_USER" "$DATA_MOUNT"

ok "[1/12] Disque donnees configure -> $DATA_MOUNT"

# ==============================================================
# 2. ZSH + OH MY ZSH
# ==============================================================
echo "[2/12] Installation ZSH + Oh My Zsh..."
chsh -s "$(which zsh)" "$ADMIN_USER" || true

sudo -u "$ADMIN_USER" env RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  || err "Oh My Zsh non installe"

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

echo "  DevOps Pro VM - Bienvenue $USER"
ZSHRC

chown "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.zshrc"
ok "[2/12] ZSH configure"

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

# -- FIX DOCKER PERMISSIONS ----------------------------------
if id "$ADMIN_USER" &>/dev/null; then
  usermod -aG docker "$ADMIN_USER"
  ok "Utilisateur $ADMIN_USER ajoute au groupe docker"
else
  err "Utilisateur $ADMIN_USER non trouve - usermod ignore"
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
# Attendre que le socket Docker soit pret
timeout 30 bash -c 'until docker info &>/dev/null; do sleep 2; done'

# -- Seul Portainer est demarre comme conteneur au boot ------
docker volume create portainer_data || true
docker run -d \
  --name portainer \
  --restart always \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest && ok "Portainer demarre sur :9443" || err "Portainer non demarre"

# -- Initialisation automatique du compte admin Portainer ----
# Sans cela, le premier visiteur de https://<IP>:9443 dans les 5
# minutes suivant le demarrage devient admin - on le fait nous-memes
# via l'API pour que le mot de passe genere par Terraform soit le seul
# valide des le depart (0 etape manuelle).
PORTAINER_READY=false
for i in $(seq 1 15); do
  if curl -sk --max-time 5 "https://127.0.0.1:9443/api/status" >/dev/null 2>&1; then
    PORTAINER_READY=true
    break
  fi
  sleep 4
done

if [ "$PORTAINER_READY" = true ]; then
  curl -sk --max-time 10 -X POST "https://127.0.0.1:9443/api/users/admin/init" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_ADMIN_PASSWORD}\"}" \
    >/dev/null 2>&1 \
    && ok "Compte admin Portainer initialise (admin / mot de passe genere par Terraform)" \
    || err "Initialisation admin Portainer echouee (deja initialise ou API indisponible)"
else
  err "Portainer non pret apres 60s - initialisez le compte admin manuellement"
fi

ok "[3/12] Docker + Portainer installes"

# ==============================================================
# 4. KUBERNETES TOOLS
# ==============================================================
if should_run "devops"; then
echo "[4/12] Outils Kubernetes..."

KUBECTL_VER=$(curl -sL --max-time 15 https://dl.k8s.io/release/stable.txt || true)
if [ -n "$KUBECTL_VER" ]; then
  curl -sLO "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && ok "kubectl $KUBECTL_VER installe" || err "kubectl non installe"
  rm -f kubectl
else
  err "kubectl non installe (dl.k8s.io injoignable)"
fi

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
  && ok "helm installe" || err "helm non installe"

K9S_VER=$(gh_latest derailed/k9s)
if [ -n "$K9S_VER" ]; then
  curl -sLO "https://github.com/derailed/k9s/releases/download/$K9S_VER/k9s_Linux_amd64.tar.gz" \
    && tar xzf k9s_Linux_amd64.tar.gz k9s \
    && install k9s /usr/local/bin/ \
    && ok "k9s $K9S_VER installe" || err "k9s telechargement/installation echoue"
  rm -f k9s k9s_Linux_amd64.tar.gz
else
  err "k9s non installe (version introuvable, API GitHub indisponible ?)"
fi

git clone --depth=1 https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || true
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -sf /opt/kubectx/kubens  /usr/local/bin/kubens
ok "kubectx/kubens installes"

KIND_VER=$(gh_latest kubernetes-sigs/kind)
if [ -n "$KIND_VER" ]; then
  curl -sLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/$KIND_VER/kind-linux-amd64" \
    && chmod +x /usr/local/bin/kind \
    && ok "kind $KIND_VER installe" || err "kind non installe"
else
  err "kind non installe (version introuvable)"
fi

ok "[4/12] kubectl / Helm / k9s / kind installes"
else
  skip_msg "Kubernetes (profil devops uniquement)"
fi

# ==============================================================
# 5. INFRASTRUCTURE AS CODE
# ==============================================================
if should_run "devops"; then
echo "[5/12] Infrastructure as Code..."

TF_VER=$(curl -s --max-time 15 "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r '.current_version // empty' 2>/dev/null || true)
if [ -n "$TF_VER" ]; then
  curl -sLO "https://releases.hashicorp.com/terraform/$TF_VER/terraform_${TF_VER}_linux_amd64.zip" \
    && unzip -oq "terraform_${TF_VER}_linux_amd64.zip" \
    && install terraform /usr/local/bin/ \
    && ok "Terraform $TF_VER installe" || err "Terraform non installe"
  rm -f terraform terraform_*.zip
else
  err "Terraform non installe (checkpoint-api indisponible)"
fi

TG_VER=$(gh_latest gruntwork-io/terragrunt)
if [ -n "$TG_VER" ]; then
  curl -sLo /usr/local/bin/terragrunt \
    "https://github.com/gruntwork-io/terragrunt/releases/download/$TG_VER/terragrunt_linux_amd64" \
    && chmod +x /usr/local/bin/terragrunt \
    && ok "Terragrunt $TG_VER installe" || err "Terragrunt non installe"
else
  err "Terragrunt non installe (version introuvable)"
fi

PKR_VER=$(curl -s --max-time 15 "https://checkpoint-api.hashicorp.com/v1/check/packer" | jq -r '.current_version // empty' 2>/dev/null || true)
if [ -n "$PKR_VER" ]; then
  curl -sLO "https://releases.hashicorp.com/packer/$PKR_VER/packer_${PKR_VER}_linux_amd64.zip" \
    && unzip -oq "packer_${PKR_VER}_linux_amd64.zip" \
    && install packer /usr/local/bin/ \
    && ok "Packer $PKR_VER installe" || err "Packer non installe"
  rm -f packer packer_*.zip
else
  err "Packer non installe (checkpoint-api indisponible)"
fi

pip_install ansible ansible-lint molecule && ok "Ansible installe" || err "Ansible non installe"

TFLINT_VER=$(gh_latest terraform-linters/tflint)
if [ -n "$TFLINT_VER" ]; then
  curl -sLO "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VER}/tflint_linux_amd64.zip" \
    && unzip -oq tflint_linux_amd64.zip tflint \
    && install tflint /usr/local/bin/ \
    && ok "tflint $TFLINT_VER installe" || err "tflint non installe"
  rm -f tflint tflint_linux_amd64.zip
else
  err "tflint non installe (version introuvable)"
fi

ok "[5/12] Terraform / Terragrunt / Ansible / Packer installes"
else
  skip_msg "Infrastructure as Code (profil devops uniquement)"
fi

# ==============================================================
# 6. CI/CD - Azure CLI, GitHub CLI, ArgoCD, act, Vault, Skaffold, Stern, cosign
# ==============================================================
if should_run "devops"; then
echo "[6/12] CI/CD Tools..."

curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
  && ok "Azure CLI installe" || err "Azure CLI non installe"

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update -qq
apt-get install -y gh && ok "GitHub CLI installe" || err "GitHub CLI non installe"

ARGOCD_VER=$(gh_latest argoproj/argo-cd)
if [ -n "$ARGOCD_VER" ]; then
  curl -sLo /usr/local/bin/argocd \
    "https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VER/argocd-linux-amd64" \
    && chmod +x /usr/local/bin/argocd \
    && ok "ArgoCD CLI $ARGOCD_VER installe" || err "ArgoCD CLI non installe"
else
  err "ArgoCD CLI non installe (version introuvable)"
fi

curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash \
  && ok "act installe" || err "act non installe"

# -- Vault - service systemd persiste ------------------------
VAULT_VER=$(curl -s --max-time 15 "https://checkpoint-api.hashicorp.com/v1/check/vault" | jq -r '.current_version // empty' 2>/dev/null || true)
if [ -z "$VAULT_VER" ]; then
  err "Vault non installe (checkpoint-api indisponible) - le reste de la phase 6 est ignore"
else
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
  ok "Vault $VAULT_VER initialise - root token dans /root/.vault-init"
fi
fi # fin du bloc VAULT_VER

# Skaffold
curl -sLo /usr/local/bin/skaffold \
  "https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64" \
  && chmod +x /usr/local/bin/skaffold \
  && ok "Skaffold installe" || err "Skaffold non installe"

# Stern
STERN_VER=$(gh_latest stern/stern | tr -d v)
if [ -n "$STERN_VER" ]; then
  curl -sLO "https://github.com/stern/stern/releases/download/v${STERN_VER}/stern_${STERN_VER}_linux_amd64.tar.gz" \
    && tar xzf "stern_${STERN_VER}_linux_amd64.tar.gz" stern \
    && install stern /usr/local/bin/ \
    && ok "Stern $STERN_VER installe" || err "Stern non installe"
  rm -f stern stern_*.tar.gz
else
  err "Stern non installe (version introuvable)"
fi

# cosign
COSIGN_VER=$(gh_latest sigstore/cosign)
if [ -n "$COSIGN_VER" ]; then
  curl -sLo /usr/local/bin/cosign \
    "https://github.com/sigstore/cosign/releases/download/$COSIGN_VER/cosign-linux-amd64" \
    && chmod +x /usr/local/bin/cosign \
    && ok "cosign $COSIGN_VER installe" || err "cosign non installe"
else
  err "cosign non installe (version introuvable)"
fi

ok "[6/12] Azure CLI / GitHub CLI / ArgoCD / act / Vault / Skaffold / Stern / cosign installes"
else
  skip_msg "CI/CD Tools (profil devops uniquement)"
fi

# ==============================================================
# 7. MONITORING - Prometheus + Grafana + Node Exporter
# ==============================================================
echo "[7/12] Stack Monitoring..."

NE_VER=$(gh_latest prometheus/node_exporter | tr -d v)
if [ -n "$NE_VER" ]; then
  curl -sLO "https://github.com/prometheus/node_exporter/releases/download/v${NE_VER}/node_exporter-${NE_VER}.linux-amd64.tar.gz" \
    && tar xzf "node_exporter-${NE_VER}.linux-amd64.tar.gz" \
    && install "node_exporter-${NE_VER}.linux-amd64/node_exporter" /usr/local/bin/ \
    || err "node_exporter telechargement/installation echoue"
  rm -rf node_exporter*
else
  err "node_exporter non installe (version introuvable)"
fi

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
systemctl enable --now node_exporter \
  && ok "Node Exporter $NE_VER demarre sur :9100" \
  || err "Node Exporter non demarre"

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
  && ok "Prometheus demarre sur :9090" || err "Prometheus non demarre"

docker volume create grafana_data || true
docker run -d \
  --name grafana \
  --restart always \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}" \
  -e GF_USERS_ALLOW_SIGN_UP=false \
  -v grafana_data:/var/lib/grafana \
  grafana/grafana-oss:latest \
  && ok "Grafana demarre sur :3000 (admin / mot de passe genere par Terraform)" || err "Grafana non demarre"

ok "[7/12] Prometheus (9090) + Grafana (3000) + Node Exporter (9100) installes"

# ==============================================================
# 8. PYTHON / DATAOPS
# ==============================================================
if should_run "dataops"; then
echo "[8/12] Stack DataOps / Data Science Python..."

python3 -m pip install --quiet --upgrade pip setuptools wheel 2>/dev/null || true

# -- FIX TYPING_EXTENSIONS -----------------------------------
pip3 install --quiet --root-user-action=ignore "typing_extensions>=4.13.2" 2>/dev/null \
  || err "Upgrade typing_extensions echoue"

# -- FIX BLINKER ---------------------------------------------
pip_install --ignore-installed blinker

# Jupyter
pip_install jupyter jupyterlab notebook ipywidgets \
  && ok "Jupyter installe" || err "Jupyter non installe"

# Data Science
pip_install \
  numpy pandas polars \
  matplotlib seaborn plotly \
  scikit-learn xgboost \
  && ok "Data science libs installees" || err "Data science libs non installees"

# Bases de donnees Python
pip_install sqlalchemy psycopg2-binary redis \
  && ok "DB libs installees" || err "DB libs non installees"

# dbt + mlflow
pip_install dbt-core mlflow \
  && ok "dbt + mlflow installes" || err "dbt/mlflow non installes"

# Cloud SDKs
pip_install boto3 azure-storage-blob azure-identity \
  && ok "Cloud SDKs installes" || err "Cloud SDKs non installes"

# Dev tools
pip_install \
  black flake8 mypy isort pylint \
  pytest pytest-cov \
  pre-commit rich click typer \
  && ok "Dev tools Python installes" || err "Dev tools non installes"

# API
pip_install fastapi "uvicorn[standard]" requests httpx aiohttp \
  && ok "API libs installees" || err "API libs non installees"

# PySpark + Dask
pip_install pyspark  && ok "PySpark installe" || err "PySpark non installe"
pip_install "dask[complete]" && ok "Dask installe"  || err "Dask non installe"

# JupyterLab config
sudo -u "$ADMIN_USER" mkdir -p "$HOME_DIR/.jupyter"
cat > "$HOME_DIR/.jupyter/jupyter_lab_config.py" << EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = False
c.ServerApp.token = '${JUPYTER_TOKEN}'
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

ok "[8/12] Python DataOps stack installe"
else
  skip_msg "Data Science / Jupyter (profil dataops uniquement)"
fi

# ==============================================================
# 9. BASES DE DONNEES - Clients + conteneurs Docker
# ==============================================================
echo "[9/12] Outils base de donnees..."

# Clients DB (MySQL, MongoDB et Airflow supprimes)
apt-get install -y postgresql-client redis-tools sqlite3 \
  && ok "Clients DB installes (pg, redis, sqlite)" || err "Certains clients DB non installes"

# Conteneurs DB : postgres, redis uniquement (MongoDB supprime)
docker run -d \
  --name postgres \
  --restart always \
  -p 127.0.0.1:5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -v "$DATA_MOUNT/docker-volumes/postgres":/var/lib/postgresql/data \
  postgres:16-alpine

docker run -d \
  --name redis \
  --restart always \
  -p 127.0.0.1:6379:6379 \
  -v "$DATA_MOUNT/docker-volumes/redis":/data \
  redis:7-alpine --appendonly yes

ok "Conteneurs DB demarres sur loopback (postgres:5432, redis:6379)"

USQL_VER=$(gh_latest xo/usql | tr -d v)
if [ -n "$USQL_VER" ]; then
  curl -sLO "https://github.com/xo/usql/releases/download/v${USQL_VER}/usql_static-${USQL_VER}-linux-amd64.tar.bz2" \
    && tar xjf usql_static-*.tar.bz2 \
    && install usql_static /usr/local/bin/usql \
    && rm -f usql_static* \
    && ok "usql $USQL_VER installe" || err "usql non installe"
else
  err "usql non installe (version introuvable)"
fi

ok "[9/12] Clients DB + conteneurs Docker demarres"

# ==============================================================
# 10. RESEAU / SECURITE
# ==============================================================
echo "[10/12] Outils reseau & securite..."

if should_run "cybersecurity"; then
  apt-get install -y masscan tshark autossh vpnc openvpn wireguard \
    && ok "Outils reseau installes" || err "Certains outils reseau non installes"
else
  skip_msg "Outils reseau avances (profil cybersecurity uniquement)"
fi

if should_run "devops"; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin \
    && ok "Trivy installe" || err "Trivy non installe"

  HADO_VER=$(gh_latest hadolint/hadolint)
  if [ -n "$HADO_VER" ]; then
    curl -sLo /usr/local/bin/hadolint \
      "https://github.com/hadolint/hadolint/releases/download/$HADO_VER/hadolint-Linux-x86_64" \
      && chmod +x /usr/local/bin/hadolint \
      && ok "Hadolint $HADO_VER installe" || err "Hadolint non installe"
  else
    err "Hadolint non installe (version introuvable)"
  fi
else
  skip_msg "Trivy / Hadolint - scan securite conteneurs (profil devops uniquement)"
fi

# -- UFW - toujours configure, quel que soit le profil ---------
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP public'
ufw allow 443/tcp  comment 'HTTPS public'
should_run "dataops" && ufw allow 8888/tcp comment 'JupyterLab'
ufw allow 3000/tcp comment 'Grafana'
ufw allow 9090/tcp comment 'Prometheus'
ufw allow 9443/tcp comment 'Portainer'
should_run "devops" && ufw allow 8200/tcp comment 'Vault'
ufw --force enable
ok "UFW configure"

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
ok "fail2ban configure et demarre"

ok "[10/12] Reseau & securite OK"

# ==============================================================
# 10b. PENTEST & SECURITE OFFENSIVE
# ==============================================================
if should_run "cybersecurity"; then
echo "[10b/12] Outils Pentest & Securite offensive..."

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
  && ok "Outils pentest apt installes" || err "Certains outils pentest apt non installes"

NUCLEI_VER=$(gh_latest projectdiscovery/nuclei)
if [ -n "$NUCLEI_VER" ]; then
  curl -sLO "https://github.com/projectdiscovery/nuclei/releases/download/$NUCLEI_VER/nuclei_${NUCLEI_VER#v}_linux_amd64.zip" \
    && unzip -oq nuclei_*.zip nuclei \
    && install nuclei /usr/local/bin/ \
    && ok "Nuclei $NUCLEI_VER installe" || err "Nuclei non installe"
  rm -f nuclei nuclei_*.zip
  sudo -u "$ADMIN_USER" /usr/local/bin/nuclei -update-templates 2>/dev/null || true
else
  err "Nuclei non installe (version introuvable)"
fi

FFUF_VER=$(gh_latest ffuf/ffuf)
if [ -n "$FFUF_VER" ]; then
  curl -sLO "https://github.com/ffuf/ffuf/releases/download/$FFUF_VER/ffuf_${FFUF_VER#v}_linux_amd64.tar.gz" \
    && tar xzf ffuf_*.tar.gz ffuf \
    && install ffuf /usr/local/bin/ \
    && ok "ffuf $FFUF_VER installe" || err "ffuf non installe"
  rm -f ffuf ffuf_*.tar.gz
else
  err "ffuf non installe (version introuvable)"
fi

GOBB_VER=$(gh_latest OJ/gobuster)
if [ -n "$GOBB_VER" ]; then
  curl -sLO "https://github.com/OJ/gobuster/releases/download/$GOBB_VER/gobuster_Linux_x86_64.tar.gz" \
    && tar xzf gobuster_Linux_x86_64.tar.gz gobuster \
    && install gobuster /usr/local/bin/ \
    && ok "gobuster $GOBB_VER installe" || err "gobuster non installe"
  rm -f gobuster gobuster_*.tar.gz
else
  err "gobuster non installe (version introuvable)"
fi

AMASS_VER=$(gh_latest owasp-amass/amass)
if [ -n "$AMASS_VER" ]; then
  curl -sLO "https://github.com/owasp-amass/amass/releases/download/$AMASS_VER/amass_Linux_amd64.zip" \
    && unzip -oq amass_Linux_amd64.zip \
    && install amass_Linux_amd64/amass /usr/local/bin/ \
    && ok "Amass $AMASS_VER installe" || err "Amass non installe"
  rm -rf amass_Linux_amd64*
else
  err "Amass non installe (version introuvable)"
fi

pip_install theHarvester && ok "theHarvester installe" || err "theHarvester non installe"

git clone --depth=1 https://github.com/drwetter/testssl.sh /opt/testssl 2>/dev/null \
  || git -C /opt/testssl pull 2>/dev/null || true
ln -sf /opt/testssl/testssl.sh /usr/local/bin/testssl
ok "testssl.sh installe"

curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
  -o /tmp/msfinstall \
  && chmod 755 /tmp/msfinstall \
  && /tmp/msfinstall \
  && ok "Metasploit installe (installeur officiel Rapid7)" \
  || err "Metasploit non installe (installeur Rapid7 injoignable)"
rm -f /tmp/msfinstall

git clone --depth=1 https://github.com/danielmiessler/SecLists /opt/SecLists 2>/dev/null \
  && ok "SecLists installe dans /opt/SecLists" || err "SecLists non installe"

apt-get install -y wordlists 2>/dev/null || true
gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
ok "Wordlists configurees (/usr/share/wordlists/rockyou.txt)"

ok "[10b/12] Outils Pentest installes"
else
  skip_msg "Pentest offensif (profil cybersecurity uniquement)"
fi

# ==============================================================
# 11. LANGAGES - Go, Node.js, Rust, Java
# ==============================================================
if should_run "devops" || should_run "dataops"; then
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
ok "Go $GO_VER installe"

if curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - ; then
  ok "Depot NodeSource configure"
else
  err "Configuration du depot NodeSource echouee (reseau ?) - nouvelle tentative apres un court delai"
  sleep 5
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - || err "NodeSource toujours indisponible - nodejs viendra des depots Ubuntu (version ancienne)"
fi
apt-get install -y nodejs

# Verifie que la version installee est bien une LTS recente (>=18) et pas
# le paquet nodejs 12.x fourni par Ubuntu (installe si NodeSource a echoue
# silencieusement plus haut).
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 18 ]; then
  err "Node.js trop ancien ou absent ($(node --version 2>/dev/null || echo 'aucun')) - purge et nouvelle tentative via NodeSource"
  apt-get remove -y nodejs libnode-dev libnode72 2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    || err "Echec definitif de l'installation de Node.js via NodeSource"
fi

npm install -g yarn pnpm typescript ts-node eslint prettier pm2 \
  && ok "Node.js $(node --version) + npm globals installes" || err "npm globals non installes"

sudo -u "$ADMIN_USER" bash -c \
  'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path 2>/dev/null' \
  && ok "Rust installe" || err "Rust non installe"

apt-get install -y openjdk-21-jdk maven \
  && ok "Java 21 + Maven installes" || err "Java non installe"

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
ok "Gradle $GRADLE_VER installe"

sudo -u "$ADMIN_USER" bash -c 'curl -s "https://get.sdkman.io" | bash' \
  && ok "SDKMAN installe" || err "SDKMAN non installe"

ok "[11/12] Go / Node.js / Rust / Java installes"
else
  skip_msg "Langages Go/Node/Rust/Java (profils devops et dataops)"
fi

# ==============================================================
# 12. FINALISATION - MOTD, Vim, Git, devops-status
# ==============================================================
echo "[12/12] Configuration finale..."

sudo -u "$ADMIN_USER" git config --global init.defaultBranch main
sudo -u "$ADMIN_USER" git config --global pull.rebase false
sudo -u "$ADMIN_USER" git config --global core.editor vim
ok "Git configure"

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
ok "Vim configure"

{
cat << 'MOTD_HEAD'

  +==========================================================+
  |          DevOps Pro VM - Azure Students                 |
  |              Ubuntu 22.04 LTS                           |
  +==========================================================+
  |   Docker        : docker ps                           |
  |   Grafana       : http://<IP>:3000  (admin / cf. `terraform output grafana_admin_password`) |
  |   Prometheus    : http://<IP>:9090                    |
  |   Portainer     : https://<IP>:9443 (admin / cf. `terraform output portainer_admin_password`) |
  |   PostgreSQL    : localhost:5432    (postgres/postgres)|
  |   Redis         : localhost:6379                       |
MOTD_HEAD

if should_run "devops"; then
cat << 'MOTD_DEVOPS'
  +==========================================================+
  |    Kubernetes    : kubectl get nodes                   |
  |    Terraform     : terraform --version                 |
  |   Vault         : http://<IP>:8200 (init /root)       |
  |   Skaffold      : skaffold version                    |
MOTD_DEVOPS
fi

if should_run "dataops"; then
cat << 'MOTD_DATAOPS'
  +==========================================================+
  |   Jupyter       : http://<IP>:8888  (token: cf. `terraform output jupyter_token`) |
MOTD_DATAOPS
fi

if should_run "cybersecurity"; then
cat << 'MOTD_CYBER'
  +==========================================================+
  |   Pentest       : nuclei / ffuf / gobuster / sqlmap   |
  |   OSINT         : theHarvester / amass                |
  |   Exploit       : msfconsole (Metasploit)             |
  |   Wordlists     : /opt/SecLists / rockyou.txt         |
  |   Pentest dir   : /data/pentest/                      |
MOTD_CYBER
fi

cat << MOTD_TAIL
  +==========================================================+
  |    Profil VM     : $VM_PROFILE
  |   Data Disk     : /data/                              |
  |   Install Log   : /var/log/devops-install.log         |
  |   Statut        : devops-status                       |
  +==========================================================+

MOTD_TAIL
} > /etc/motd
ok "MOTD genere pour le profil \"$VM_PROFILE\""

cat > /usr/local/bin/devops-status << STATUSHEAD
#!/bin/bash
echo "Profil VM        : $VM_PROFILE"
STATUSHEAD

cat >> /usr/local/bin/devops-status << 'STATUS'
echo ""
echo "+==================================================+"
echo "|            DevOps VM - Status                  |"
echo "+==================================================+"
echo ""
echo "-- Outils ------------------------------------------"
printf "%-18s %s\n" "Docker:"     "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo N/A)"
printf "%-18s %s\n" "kubectl:"    "$(kubectl version --client 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo N/A)"
printf "%-18s %s\n" "Helm:"       "$(helm version --short 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Terraform:"  "$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo N/A)"
printf "%-18s %s\n" "Ansible:"    "$(ansible --version 2>/dev/null | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo N/A)"
printf "%-18s %s\n" "Vault:"      "$(vault version 2>/dev/null | awk '{print $2}' || echo N/A)"
printf "%-18s %s\n" "Python:"     "$(python3 --version 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Node.js:"    "$(node --version 2>/dev/null || echo N/A)"
printf "%-18s %s\n" "Go:"         "$(/usr/local/go/bin/go version 2>/dev/null | awk '{print $3}' || echo N/A)"
printf "%-18s %s\n" "Java:"       "$(java -version 2>&1 | head -1 || echo N/A)"
printf "%-18s %s\n" "Azure CLI:"  "$(az version 2>/dev/null | jq -r '."azure-cli"' || echo N/A)"
printf "%-18s %s\n" "Nuclei:"     "$(command -v nuclei >/dev/null 2>&1 && nuclei -version 2>&1 | grep -oP 'v[0-9][0-9.]*' | head -1 || echo N/A)"
printf "%-18s %s\n" "Metasploit:" "$(command -v msfconsole >/dev/null 2>&1 && echo installe || echo N/A)"
echo ""
echo "-- Containers Docker -------------------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
echo ""
echo "-- Services systemd --------------------------------"
for svc in docker jupyter vault node_exporter fail2ban; do
  STATUS_VAL=$(systemctl is-active "$svc" 2>/dev/null)
  [ "$STATUS_VAL" = "active" ] && ICON="[OK]" || ICON="[ ]"
  printf "  %s %-24s %s\n" "$ICON" "$svc:" "$STATUS_VAL"
done
echo ""
echo "-- Espace disque -----------------------------------"
df -h / /data 2>/dev/null || df -h /
echo ""
echo "-- Ports en ecoute ---------------------------------"
ss -tulnp | grep -E ':(22|80|443|3000|8080|8200|8888|9090|9100|9443)\s' 2>/dev/null || true
echo ""
STATUS
chmod +x /usr/local/bin/devops-status

# -- Landing page de statut (nginx, port 80) ------------------
apt-get install -y nginx >/dev/null 2>&1 && ok "nginx installe" || err "nginx non installe"

DEVOPS_ON=$(should_run "devops" && echo true || echo false)
DATAOPS_ON=$(should_run "dataops" && echo true || echo false)
CYBER_ON=$(should_run "cybersecurity" && echo true || echo false)

# -- Inventaire des logiciels installes (pour le dashboard) ----
# Chaque valeur est vide si l'outil n'est pas installe / injoignable :
# le dashboard affiche alors "-" plutot qu'une fausse information.
V_DOCKER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
V_GIT=$(git --version 2>/dev/null | awk '{print $3}')
V_PYTHON=$(python3 --version 2>/dev/null | awk '{print $2}')

V_KUBECTL=$(kubectl version --client 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
V_HELM=$(helm version --short 2>/dev/null | cut -d'+' -f1)
V_K9S=$(k9s version 2>/dev/null | grep -i version | head -1 | awk '{print $NF}')
V_KIND=$(kind version 2>/dev/null | awk '{print $2}')
V_TERRAFORM=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null)
V_TERRAGRUNT=$(terragrunt --version 2>/dev/null | awk '{print $3}')
V_PACKER=$(packer version 2>/dev/null | head -1 | awk '{print $2}')
V_ANSIBLE=$(ansible --version 2>/dev/null | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
V_TFLINT=$(tflint --version 2>/dev/null | head -1 | awk '{print $NF}')
V_VAULT=$(vault version 2>/dev/null | awk '{print $2}')
V_AZCLI=$(az version 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null)
V_GHCLI=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
V_ARGOCD=$(argocd version --client 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
V_TRIVY=$(trivy --version 2>/dev/null | head -1 | awk '{print $2}')

V_JUPYTER=$(jupyter --version 2>/dev/null | head -1)

V_NUCLEI=$(command -v nuclei >/dev/null 2>&1 && nuclei -version 2>&1 | grep -oP 'v[0-9][0-9.]*' | head -1)
V_METASPLOIT=$(command -v msfconsole >/dev/null 2>&1 && echo "installe")
V_FFUF=$(ffuf -V 2>/dev/null | awk '{print $2}')
V_GOBUSTER=$(command -v gobuster >/dev/null 2>&1 && echo "installe")
V_AMASS=$(command -v amass >/dev/null 2>&1 && echo "installe")
V_SQLMAP=$(command -v sqlmap >/dev/null 2>&1 && echo "installe")

V_GO=$(go version 2>/dev/null | awk '{print $3}')
V_NODE=$(node --version 2>/dev/null)
V_JAVA=$(java -version 2>&1 | grep -oP '(?<=version ")[0-9][^"]*' | head -1)

mkdir -p /var/www/html
cat > /var/www/html/index.html << 'DASHBOARD_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DevOps VM - Tableau de bord</title>
<style>
  :root{
    --bg:#0a0b10; --panel:rgba(22,25,38,.6); --panel-solid:#161926;
    --border:rgba(255,255,255,.08); --border-hover:rgba(255,255,255,.18);
    --text:#eef0f6; --muted:#8b8fa8; --muted-2:#5c6079;
    --accent:#7c5cff; --accent-2:#22d3ee;
    --up:#34d399; --down:#fb7185; --checking:#f5b942;
    --radius:18px;
  }
  body[data-profile="devops"]      { --accent:#60a5fa; --accent-2:#22d3ee; }
  body[data-profile="dataops"]     { --accent:#34d399; --accent-2:#a3e635; }
  body[data-profile="cybersecurity"]{ --accent:#fb7185; --accent-2:#f59e0b; }
  body[data-profile="fullstack"]   { --accent:#a78bfa; --accent-2:#22d3ee; }

  *{box-sizing:border-box;}
  html{scroll-behavior:smooth;}
  body{
    margin:0; min-height:100vh; color:var(--text); background:var(--bg);
    font-family:"Segoe UI",system-ui,-apple-system,Roboto,sans-serif;
    overflow-x:hidden;
    -webkit-font-smoothing:antialiased;
  }

  /* -- Fond anime (mesh gradient) --------------------------- */
  .bg-mesh{ position:fixed; inset:0; z-index:0; overflow:hidden; }
  .bg-mesh span{
    position:absolute; width:46vw; height:46vw; border-radius:50%;
    filter:blur(90px); opacity:.35; will-change:transform;
  }
  .bg-mesh span:nth-child(1){ background:var(--accent); top:-15%; left:-10%; animation:float1 22s ease-in-out infinite; }
  .bg-mesh span:nth-child(2){ background:var(--accent-2); bottom:-20%; right:-10%; animation:float2 26s ease-in-out infinite; }
  .bg-mesh span:nth-child(3){ background:#ec4899; top:40%; left:60%; width:32vw; height:32vw; opacity:.18; animation:float3 30s ease-in-out infinite; }
  @keyframes float1{ 0%,100%{transform:translate(0,0)} 50%{transform:translate(6vw,8vh)} }
  @keyframes float2{ 0%,100%{transform:translate(0,0)} 50%{transform:translate(-5vw,-6vh)} }
  @keyframes float3{ 0%,100%{transform:translate(0,0) scale(1)} 50%{transform:translate(-4vw,5vh) scale(1.1)} }

  .wrap{ position:relative; z-index:1; max-width:1040px; margin:0 auto; padding:48px 24px 72px; }

  /* -- Header ----------------------------------------------- */
  header{ margin-bottom:32px; animation:fadeInUp .6s ease both; }
  .title-row{ display:flex; align-items:center; gap:14px; }
  .logo{
    width:46px; height:46px; border-radius:13px; display:flex; align-items:center; justify-content:center;
    background:linear-gradient(135deg,var(--accent),var(--accent-2)); flex-shrink:0;
    box-shadow:0 8px 24px -8px color-mix(in srgb, var(--accent) 60%, transparent);
  }
  h1{
    font-size:28px; margin:0; letter-spacing:-.02em; font-weight:700;
    background:linear-gradient(120deg,#fff, var(--muted) 140%);
    -webkit-background-clip:text; background-clip:text; color:transparent;
  }
  .sub{ color:var(--muted); font-size:14.5px; margin:6px 0 0 60px; }

  .badges{ display:flex; gap:10px; flex-wrap:wrap; margin:20px 0 0 60px; }
  .badge{
    display:inline-flex; align-items:center; gap:8px; font-size:12.5px; font-weight:500;
    padding:7px 14px; border-radius:999px; border:1px solid var(--border);
    background:var(--panel); backdrop-filter:blur(16px);
  }
  .badge b{ color:var(--text); text-transform:capitalize; font-weight:600; }
  .badge.profile{ color:var(--accent-2); }
  .badge .pulse-dot{
    width:7px; height:7px; border-radius:50%; background:var(--up);
    box-shadow:0 0 0 0 rgba(52,211,153,.6); animation:pulse-ring 2s infinite;
  }

  /* -- Grid ------------------------------------------------- */
  .grid{ display:grid; grid-template-columns:repeat(auto-fill,minmax(255px,1fr)); gap:16px; margin-top:28px; }

  .card{
    position:relative; background:var(--panel); border:1px solid var(--border); border-radius:var(--radius);
    padding:20px; backdrop-filter:blur(18px); overflow:hidden;
    opacity:0; transform:translateY(16px);
    animation:fadeInUp .55s cubic-bezier(.2,.8,.2,1) forwards;
    transition:border-color .25s ease, transform .25s ease, box-shadow .25s ease;
  }
  .card:hover{
    border-color:var(--border-hover); transform:translateY(-3px);
    box-shadow:0 18px 40px -20px rgba(0,0,0,.55);
  }
  .card::before{
    content:""; position:absolute; inset:0; border-radius:var(--radius); padding:1px;
    background:linear-gradient(135deg, color-mix(in srgb, var(--accent) 45%, transparent), transparent 55%);
    -webkit-mask:linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
    -webkit-mask-composite:xor; mask-composite:exclude; pointer-events:none; opacity:.7;
  }

  .card-top{ display:flex; align-items:center; justify-content:space-between; margin-bottom:12px; }
  .card-id{ display:flex; align-items:center; gap:11px; }
  .icon-box{
    width:36px; height:36px; border-radius:10px; display:flex; align-items:center; justify-content:center;
    background:rgba(255,255,255,.06); border:1px solid var(--border); flex-shrink:0;
  }
  .icon-box svg{ width:18px; height:18px; stroke:var(--text); }
  .card-title{ font-weight:600; font-size:15px; }

  .status{ display:flex; align-items:center; gap:7px; font-size:11.5px; color:var(--muted); }
  .dot{
    width:9px; height:9px; border-radius:50%; background:var(--muted-2); flex-shrink:0;
    transition:background .3s ease;
  }
  .dot.checking{ background:var(--checking); animation:blink 1s infinite; }
  .dot.up{ background:var(--up); box-shadow:0 0 0 0 rgba(52,211,153,.55); animation:pulse-ring 1.8s infinite; }
  .dot.down{ background:var(--down); box-shadow:0 0 10px 0 rgba(251,113,133,.5); }

  .desc{ color:var(--muted); font-size:13px; line-height:1.55; min-height:40px; }

  .row{ display:flex; gap:8px; margin-top:14px; }
  .btn{
    flex:1; text-align:center; text-decoration:none; font-size:13px; font-weight:600;
    padding:9px 10px; border-radius:10px; border:1px solid var(--border);
    background:rgba(255,255,255,.03); color:var(--text); cursor:pointer;
    transition:all .2s ease; display:inline-flex; align-items:center; justify-content:center; gap:6px;
  }
  .btn.primary{
    background:linear-gradient(135deg, var(--accent), var(--accent-2)); border:none; color:#0a0b10;
  }
  .btn:hover{ transform:translateY(-1px); filter:brightness(1.08); }
  .btn:active{ transform:translateY(0); }
  .btn svg{ width:13px; height:13px; }

  .url-line{
    margin-top:10px; font-size:11px; color:var(--muted-2); font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
    white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
  }

  .empty{
    grid-column:1/-1; text-align:center; padding:48px 20px; color:var(--muted);
    border:1px dashed var(--border); border-radius:var(--radius); font-size:14px;
  }

  .section-title{
    font-size:15px; font-weight:600; color:var(--muted); text-transform:uppercase;
    letter-spacing:.08em; margin:44px 0 16px; padding-top:8px; border-top:1px solid var(--border);
  }

  .tool-category{
    background:var(--panel); border:1px solid var(--border); border-radius:var(--radius);
    padding:16px 18px; margin-bottom:14px; backdrop-filter:blur(18px);
    opacity:0; transform:translateY(12px); animation:fadeInUp .5s ease forwards;
  }
  .tool-category h3{
    margin:0 0 12px; font-size:13.5px; font-weight:600; color:var(--accent-2);
    display:flex; align-items:center; gap:8px;
  }
  .tool-category h3 .cat-dot{ width:7px; height:7px; border-radius:50%; background:var(--accent); }
  .tool-list{ display:flex; flex-wrap:wrap; gap:8px; }
  .tool-chip{
    display:inline-flex; align-items:baseline; gap:6px; font-size:12.5px;
    padding:6px 12px; border-radius:9px; background:rgba(255,255,255,.03); border:1px solid var(--border);
    transition:border-color .2s ease, transform .2s ease;
  }
  .tool-chip:hover{ border-color:var(--border-hover); transform:translateY(-1px); }
  .tool-chip .t-name{ font-weight:600; color:var(--text); }
  .tool-chip .t-version{ color:var(--muted); font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:11.5px; }
  .tool-chip.na{ opacity:.45; }

  @keyframes fadeInUp{ from{opacity:0; transform:translateY(16px);} to{opacity:1; transform:translateY(0);} }
  @keyframes blink{ 0%,100%{opacity:1;} 50%{opacity:.35;} }
  @keyframes pulse-ring{
    0%{ box-shadow:0 0 0 0 color-mix(in srgb, var(--up) 55%, transparent); }
    70%{ box-shadow:0 0 0 8px transparent; }
    100%{ box-shadow:0 0 0 0 transparent; }
  }

  footer{
    margin-top:44px; color:var(--muted-2); font-size:12px; text-align:center; line-height:1.8;
    animation:fadeInUp .6s ease .3s both;
  }
  code{ background:rgba(255,255,255,.06); padding:2px 7px; border-radius:6px; font-size:11.5px; color:var(--accent-2); }

  ::selection{ background:color-mix(in srgb, var(--accent) 40%, transparent); }

  @media (max-width:480px){
    .sub, .badges{ margin-left:0; }
    .title-row{ flex-direction:column; align-items:flex-start; }
  }
</style>
</head>
<body>

<div class="bg-mesh"><span></span><span></span><span></span></div>

<div class="wrap">
  <header>
    <div class="title-row">
      <div class="logo">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#0a0b10" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="4" width="18" height="13" rx="2"></rect>
          <path d="M8 21h8M12 17v4"></path>
        </svg>
      </div>
      <h1>DevOps VM</h1>
    </div>
    <div class="sub">Tableau de bord des services installes sur cette machine</div>
    <div class="badges">
      <span class="badge profile"><span class="pulse-dot"></span>Profil actif : <b id="profile-name">-</b></span>
      <span class="badge" id="count-badge">- services</span>
      <span class="badge" id="clock-badge">--:--:--</span>
    </div>
  </header>

  <div class="grid" id="grid"></div>

  <h2 class="section-title">Logiciels installes</h2>
  <div id="tools-wrap"></div>

  <footer>
    Verification d'etat effectuee depuis votre navigateur, sans donnee envoyee a un tiers .
    Identifiants generes par Terraform : <code>terraform output</code> .
    Details complets : <code>devops-status</code> en SSH
  </footer>
</div>

<script>
const PROFILE = PLACEHOLDER_PROFILE;
const HOST = window.location.hostname;
document.body.setAttribute("data-profile", PROFILE);

const ICONS = {
  grafana: '<path d="M3 3v18h18"/><path d="M7 15l4-6 3 3 5-8"/>',
  prometheus: '<path d="M12 2a7 7 0 0 0-7 7c0 3 2 5 3 7l1 3h6l1-3c1-2 3-4 3-7a7 7 0 0 0-7-7z"/><path d="M9 15h6"/>',
  portainer: '<path d="M21 8l-9-5-9 5 9 5 9-5z"/><path d="M3 8v8l9 5 9-5V8"/><path d="M12 13v8"/>',
  jupyter: '<circle cx="12" cy="6" r="2.2"/><circle cx="6" cy="16" r="2.2"/><circle cx="18" cy="16" r="2.2"/><path d="M8 15c1.5-2 6.5-2 8 0"/>',
  vault: '<rect x="4" y="10" width="16" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>'
};

const SERVICES = [
  { key:"grafana", name:"Grafana", port:3000, https:false, enabled:true,
    desc:"Dashboards de monitoring. Identifiant admin, mot de passe genere par Terraform." },
  { key:"prometheus", name:"Prometheus", port:9090, https:false, enabled:true,
    desc:"Moteur de metriques, source de donnees de Grafana." },
  { key:"portainer", name:"Portainer", port:9443, https:true, enabled:true,
    desc:"Interface de gestion Docker. Certificat auto-signe : acceptez l'avertissement au premier acces." },
  { key:"jupyter", name:"JupyterLab", port:8888, https:false, enabled:PLACEHOLDER_DATAOPS,
    desc:"Notebooks Python / data science. Lien avec token deja inclus." },
  { key:"vault", name:"Vault", port:8200, https:false, enabled:PLACEHOLDER_DEVOPS,
    desc:"Secrets management HashiCorp. Root token dans /root/.vault-init sur la VM." }
];

// Chaque outil : la version est celle reellement detectee sur CETTE VM au
// moment de l'installation (chaine vide si non installe / injoignable).
// "enabled" reprend les memes conditions que cloud-init/install.sh
// (should_run) : la liste affichee correspond exactement a ce qui a ete
// reellement installe pour le profil actif.
const TOOLS = [
  // Socle commun - toujours installe
  { category:"Socle commun", name:"Docker", version:PLACEHOLDER_V_DOCKER, enabled:true },
  { category:"Socle commun", name:"Git", version:PLACEHOLDER_V_GIT, enabled:true },
  { category:"Socle commun", name:"Python 3", version:PLACEHOLDER_V_PYTHON, enabled:true },

  // DevOps & Cloud - profil devops / fullstack
  { category:"DevOps & Cloud", name:"kubectl", version:PLACEHOLDER_V_KUBECTL, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Helm", version:PLACEHOLDER_V_HELM, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"k9s", version:PLACEHOLDER_V_K9S, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"kind", version:PLACEHOLDER_V_KIND, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Terraform", version:PLACEHOLDER_V_TERRAFORM, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Terragrunt", version:PLACEHOLDER_V_TERRAGRUNT, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Packer", version:PLACEHOLDER_V_PACKER, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Ansible", version:PLACEHOLDER_V_ANSIBLE, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"tflint", version:PLACEHOLDER_V_TFLINT, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Vault CLI", version:PLACEHOLDER_V_VAULT, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Azure CLI", version:PLACEHOLDER_V_AZCLI, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"GitHub CLI", version:PLACEHOLDER_V_GHCLI, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"ArgoCD CLI", version:PLACEHOLDER_V_ARGOCD, enabled:PLACEHOLDER_DEVOPS },
  { category:"DevOps & Cloud", name:"Trivy", version:PLACEHOLDER_V_TRIVY, enabled:PLACEHOLDER_DEVOPS },

  // Data & IA - profil dataops / fullstack
  { category:"Data & IA", name:"JupyterLab", version:PLACEHOLDER_V_JUPYTER, enabled:PLACEHOLDER_DATAOPS },

  // Cybersecurite - profil cybersecurity / fullstack
  { category:"Cybersecurite", name:"Nuclei", version:PLACEHOLDER_V_NUCLEI, enabled:PLACEHOLDER_CYBER },
  { category:"Cybersecurite", name:"Metasploit", version:PLACEHOLDER_V_METASPLOIT, enabled:PLACEHOLDER_CYBER },
  { category:"Cybersecurite", name:"ffuf", version:PLACEHOLDER_V_FFUF, enabled:PLACEHOLDER_CYBER },
  { category:"Cybersecurite", name:"gobuster", version:PLACEHOLDER_V_GOBUSTER, enabled:PLACEHOLDER_CYBER },
  { category:"Cybersecurite", name:"Amass", version:PLACEHOLDER_V_AMASS, enabled:PLACEHOLDER_CYBER },
  { category:"Cybersecurite", name:"sqlmap", version:PLACEHOLDER_V_SQLMAP, enabled:PLACEHOLDER_CYBER },

  // Langages - profils devops et dataops
  { category:"Langages", name:"Go", version:PLACEHOLDER_V_GO, enabled: (PLACEHOLDER_DEVOPS || PLACEHOLDER_DATAOPS) },
  { category:"Langages", name:"Node.js", version:PLACEHOLDER_V_NODE, enabled: (PLACEHOLDER_DEVOPS || PLACEHOLDER_DATAOPS) },
  { category:"Langages", name:"Java", version:PLACEHOLDER_V_JAVA, enabled: (PLACEHOLDER_DEVOPS || PLACEHOLDER_DATAOPS) }
];

function buildUrl(s){
  return (s.https ? "https://" : "http://") + HOST + ":" + s.port;
}

function svgIcon(paths, cls){
  return `<svg class="${cls||''}" viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;
}

function makeCard(s, index){
  const url = buildUrl(s);
  const card = document.createElement("div");
  card.className = "card";
  card.style.animationDelay = (index * 90) + "ms";

  card.innerHTML = `
    <div class="card-top">
      <div class="card-id">
        <div class="icon-box">${svgIcon(ICONS[s.key])}</div>
        <div class="card-title">${s.name}</div>
      </div>
      <div class="status"><span class="dot checking" id="dot-${s.key}"></span><span id="label-${s.key}">verif.</span></div>
    </div>
    <div class="desc">${s.desc}</div>
    <div class="row">
      <a class="btn primary" href="${url}" target="_blank" rel="noopener">
        ${svgIcon('<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><path d="M15 3h6v6"/><path d="M10 14L21 3"/>')}
        Ouvrir
      </a>
      <button class="btn" data-copy="${url}">
        ${svgIcon('<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>')}
        Copier
      </button>
    </div>
    <div class="url-line">${url}</div>
  `;

  card.querySelector("[data-copy]").addEventListener("click", function(){
    navigator.clipboard.writeText(url).then(() => {
      const btn = this;
      const original = btn.innerHTML;
      btn.innerHTML = svgIcon('<path d="M20 6L9 17l-5-5"/>') + "Copie !";
      setTimeout(() => { btn.innerHTML = original; }, 1600);
    });
  });

  return card;
}

function checkStatus(s){
  const dot = document.getElementById("dot-" + s.key);
  const label = document.getElementById("label-" + s.key);
  if(!dot) return Promise.resolve(false);
  const url = buildUrl(s);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  return fetch(url, { mode:"no-cors", signal:controller.signal })
    .then(() => { clearTimeout(timer); dot.className = "dot up"; label.textContent = "en ligne"; return true; })
    .catch(() => { clearTimeout(timer); dot.className = "dot down"; label.textContent = "injoignable"; return false; });
}

function updateCount(active){
  Promise.all(active.map(checkStatus)).then(results => {
    const up = results.filter(Boolean).length;
    document.getElementById("count-badge").textContent = up + " / " + active.length + " services en ligne";
  });
}

function tickClock(){
  const el = document.getElementById("clock-badge");
  if(el) el.textContent = new Date().toLocaleTimeString("fr-FR");
}

function escapeHtml(str){
  const d = document.createElement("div");
  d.textContent = str;
  return d.innerHTML;
}

function renderTools(){
  const wrap = document.getElementById("tools-wrap");
  wrap.innerHTML = "";
  const active = TOOLS.filter(t => t.enabled);

  if(active.length === 0){
    wrap.innerHTML = '<div class="empty">Aucun outil supplementaire pour ce profil.</div>';
    return;
  }

  const categories = [];
  active.forEach(t => { if(!categories.includes(t.category)) categories.push(t.category); });

  categories.forEach((cat, i) => {
    const box = document.createElement("div");
    box.className = "tool-category";
    box.style.animationDelay = (i * 90) + "ms";

    const list = active.filter(t => t.category === cat);
    const chips = list.map(t => {
      const v = (t.version || "").trim();
      const cls = v ? "tool-chip" : "tool-chip na";
      const versionHtml = v ? escapeHtml(v) : "-";
      return `<span class="${cls}"><span class="t-name">${escapeHtml(t.name)}</span><span class="t-version">${versionHtml}</span></span>`;
    }).join("");

    box.innerHTML = `<h3><span class="cat-dot"></span>${escapeHtml(cat)}</h3><div class="tool-list">${chips}</div>`;
    wrap.appendChild(box);
  });
}

function render(){
  document.getElementById("profile-name").textContent = PROFILE;
  const grid = document.getElementById("grid");
  grid.innerHTML = "";
  const active = SERVICES.filter(s => s.enabled);

  if(active.length === 0){
    grid.innerHTML = '<div class="empty">Aucun service web pour ce profil.</div>';
    document.getElementById("count-badge").textContent = "0 service";
  } else {
    active.forEach((s, i) => grid.appendChild(makeCard(s, i)));
    updateCount(active);
    setInterval(() => updateCount(active), 15000);
  }

  renderTools();

  tickClock();
  setInterval(tickClock, 1000);
}

render();
</script>
</body>
</html>
DASHBOARD_EOF

# Substitution sure des valeurs (profil, booleens, versions detectees) dans
# le HTML genere. Utilise Python plutot que sed : une version d'outil peut
# contenir des guillemets ou des caracteres speciaux (ex. Java : la chaine
# brute contient des guillemets) qui casseraient une substitution sed/JS.
# json.dumps() produit une chaine JS toujours valide, quel que soit le
# contenu - y compris une chaine vide si l'outil n'est pas installe.
PROFILE="$VM_PROFILE" \
DATAOPS_ON="$DATAOPS_ON" DEVOPS_ON="$DEVOPS_ON" CYBER_ON="$CYBER_ON" \
V_DOCKER="$V_DOCKER" V_GIT="$V_GIT" V_PYTHON="$V_PYTHON" \
V_KUBECTL="$V_KUBECTL" V_HELM="$V_HELM" V_K9S="$V_K9S" V_KIND="$V_KIND" \
V_TERRAFORM="$V_TERRAFORM" V_TERRAGRUNT="$V_TERRAGRUNT" V_PACKER="$V_PACKER" \
V_ANSIBLE="$V_ANSIBLE" V_TFLINT="$V_TFLINT" V_VAULT="$V_VAULT" \
V_AZCLI="$V_AZCLI" V_GHCLI="$V_GHCLI" V_ARGOCD="$V_ARGOCD" V_TRIVY="$V_TRIVY" \
V_JUPYTER="$V_JUPYTER" \
V_NUCLEI="$V_NUCLEI" V_METASPLOIT="$V_METASPLOIT" V_FFUF="$V_FFUF" \
V_GOBUSTER="$V_GOBUSTER" V_AMASS="$V_AMASS" V_SQLMAP="$V_SQLMAP" \
V_GO="$V_GO" V_NODE="$V_NODE" V_JAVA="$V_JAVA" \
python3 - << 'PYEOF'
import json, os

path = "/var/www/html/index.html"
with open(path) as f:
    content = f.read()

# Booleens : substitues tels quels (true/false), pas de guillemets JS.
bool_map = {
    "PLACEHOLDER_DATAOPS": os.environ.get("DATAOPS_ON", "false"),
    "PLACEHOLDER_DEVOPS":  os.environ.get("DEVOPS_ON", "false"),
    "PLACEHOLDER_CYBER":   os.environ.get("CYBER_ON", "false"),
}
for token, value in bool_map.items():
    content = content.replace(token, value)

# Chaines : converties en litteral JS sur via json.dumps (gere guillemets,
# antislashs, chaine vide, etc. sans jamais casser la syntaxe JS).
string_vars = [
    "PROFILE",
    "V_DOCKER", "V_GIT", "V_PYTHON",
    "V_KUBECTL", "V_HELM", "V_K9S", "V_KIND",
    "V_TERRAFORM", "V_TERRAGRUNT", "V_PACKER", "V_ANSIBLE", "V_TFLINT",
    "V_VAULT", "V_AZCLI", "V_GHCLI", "V_ARGOCD", "V_TRIVY",
    "V_JUPYTER",
    "V_NUCLEI", "V_METASPLOIT", "V_FFUF", "V_GOBUSTER", "V_AMASS", "V_SQLMAP",
    "V_GO", "V_NODE", "V_JAVA",
]
for name in string_vars:
    token = "PLACEHOLDER_" + name
    value = os.environ.get(name, "") or ""
    content = content.replace(token, json.dumps(value))

with open(path, "w") as f:
    f.write(content)

remaining = content.count("PLACEHOLDER_")
print(f"Dashboard genere ({remaining} placeholder(s) non substitue(s))")
PYEOF

systemctl enable --now nginx \
  && ok "Landing page de statut disponible sur http://<IP>/" \
  || err "nginx non demarre"

systemctl daemon-reload
if should_run "dataops"; then
  systemctl start jupyter 2>/dev/null && ok "JupyterLab demarre sur :8888" || err "JupyterLab non demarre (verifier : journalctl -u jupyter)"
fi

chown -R "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR"
chown -R "$ADMIN_USER:$ADMIN_USER" "$DATA_MOUNT" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  [OK] Installation complete terminee !"
echo "  $(date)"
echo "  Log complet : $LOG"
echo "  Lance : devops-status"
echo "=============================================="
