# DevOps VM - Azure Students

### Nom : Lo | Prénom : Pape | Email : pape.lo@estiam.com
<div align="center">

![Azure](https://img.shields.io/badge/Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Security](https://img.shields.io/badge/Pentest-Ready-brightgreen?style=for-the-badge&logo=kalilinux&logoColor=white)

**VM DevOps tout-en-un déployée sur Azure via Terraform**
*Version 1.0 · DevOps · DataOps · Pentest · SRE*

[Objectif](#objectif) • [Déploiement](#déploiement-en-5-étapes) • [Services](#accéder-aux-services) • [Sécurité](#sécurité-et-nsg) • [Coût](#coût-estimé-azure-students--100an-de-crédit)

</div>

---

## Objectif

Ce projet s'adresse aux étudiants et aux professionnels qui souhaitent disposer rapidement d'un environnement de travail complet, sans passer des heures à configurer leurs outils manuellement.

En quelques minutes, Terraform déploie sur Azure une machine virtuelle Ubuntu 22.04 LTS entièrement préconfigurée, couvrant les besoins suivants :

- **DevOps et CI/CD** : Docker, Kubernetes, Terraform, Ansible, Vault, ArgoCD, GitHub Actions et bien d'autres.
- **Pentest et sécurité offensive** : Metasploit, Nuclei, ffuf, sqlmap, Hydra, Amass et un répertoire de travail dédié.
- **DataOps et Data Science** : JupyterLab, Airflow, Spark, dbt, pandas, scikit-learn et les principaux SDKs cloud.
- **SRE et monitoring** : Prometheus, Grafana, Node Exporter, Trivy et fail2ban préconfigurés.

Que vous soyez en cours de formation, en stage ou en poste, cette VM vous permet de démarrer immédiatement sur un environnement standardisé, reproductible et prêt pour des cas d'usage réels.

---

## Structure des fichiers

```
azure-devops-vm/
├── provider.tf          # Configuration provider AzureRM
├── main.tf              # VM, disques, IPs, clés SSH
├── network.tf           # VNet, Subnet, NSG (pare-feu)
├── variables.tf         # Définition des variables
├── terraform.tfvars     # Vos valeurs personnalisées
├── outputs.tf           # IPs, URL, commandes SSH
├── cloud-init/
│   └── install.sh       # Script d'installation automatique (~20 min)
└── keys/                # Clés SSH (générées par Terraform)
```

---

## Prérequis

| Outil | Version minimum | Lien |
|---|---|---|
| Terraform | 1.5 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | dernière | https://docs.microsoft.com/cli/azure/install |

> **Abonnement requis** : Azure for Students (100$/an de crédit gratuit) ou tout autre abonnement Azure actif.

---

## Variables Terraform

Les variables se définissent dans `terraform.tfvars`. Voici les principales :

| Variable | Défaut | Description |
|---|---|---|
| `vm_name` | `devops-pro-vm` | Nom de la VM et des ressources Azure associées |
| `location` | `westeurope` | Région Azure de déploiement |
| `vm_size` | `Standard_B2ms` | Taille de la VM (2 vCPU / 8 GB RAM) |
| `admin_username` | `devopsadmin` | Nom de l'utilisateur SSH |
| `os_disk_size_gb` | `64` | Taille du disque OS en GB |
| `data_disk_size_gb` | `64` | Taille du disque de données en GB |
| `vnet_address_space` | `10.0.0.0/16` | Plage d'adresses du réseau virtuel |
| `subnet_address_prefix` | `10.0.1.0/24` | Plage d'adresses du sous-réseau |
| `allowed_ssh_cidr` | **À définir** | Votre IP publique au format CIDR (`90.x.x.x/32`) |
| `tags` | `{}` | Tags Azure appliqués à toutes les ressources |

Exemple de `terraform.tfvars` minimal :

```hcl
vm_name          = "devops-pro-vm"
location         = "westeurope"
allowed_ssh_cidr = "90.12.34.56/32"   # curl ifconfig.me

tags = {
  environment = "student"
  project     = "devops-lab"
}
```

---

## Déploiement en 5 étapes

### 1. Connexion Azure

```bash
az login
az account show   # Vérifiez que l'abonnement Students est sélectionné
```

Si plusieurs abonnements :

```bash
az account list --output table
az account set --subscription "Azure for Students"
```

### 2. Cloner et configurer

```bash
cd azure-devops-vm
cp terraform.tfvars.example terraform.tfvars   # si un exemple est fourni
nano terraform.tfvars                          # Éditez selon vos besoins
```

### 3. Déployer

```bash
terraform init && terraform fmt && terraform validate && terraform plan && terraform apply -auto-approve
```

- La VM est créée en **~3 minutes**.
- L'installation des logiciels s'effectue **en arrière-plan** et prend **15-25 minutes**.

### 4. Connexion SSH

Récupérer la commande exacte générée par Terraform :

```bash
terraform output ssh_command
```

**Étape 1 - Télécharger la clé privée** depuis le Cloud Shell Azure :

```
azure-devops-vm-terraform/keys/devops-pro-vm_id_rsa
```

**Étape 2 - Se connecter depuis votre machine locale** (adapter le chemin vers la clé) :

```bash
# Linux / macOS
chmod 600 ~/Downloads/devops-pro-vm_id_rsa
ssh -i ~/Downloads/devops-pro-vm_id_rsa devopsadmin@<IP>

# Windows (PowerShell)
ssh -i "C:\Users\<votre-utilisateur>\Downloads\devops-pro-vm_id_rsa" devopsadmin@<IP>
```

**Étape 3 - Suivre l'installation en temps réel** :

```bash
tail -f /var/log/devops-install.log
```

**Étape 4 - Vérifier que tout est opérationnel** :

```bash
devops-status
```

### 5. Accéder aux services

Une fois l'installation terminée, les services sont accessibles depuis votre IP (remplacer `<IP>` par l'IP publique de la VM) :

| Service | URL | Credentials |
|---|---|---|
| JupyterLab | http://\<IP\>:8888 | Aucun (token désactivé) |
| Grafana | http://\<IP\>:3000 | admin / admin |
| Prometheus | http://\<IP\>:9090 | - |
| Portainer | https://\<IP\>:9443 | Création au 1er accès |
| Vault UI | http://\<IP\>:8200/ui | Root token dans `/root/.vault-init` |
| Airflow | http://\<IP\>:8080 | admin / admin (démarrage manuel) |

> **Sécurité** : tous ces ports sont restreints à votre IP (`allowed_ssh_cidr`) via le NSG Azure. Vérifiez votre IP actuelle avec `curl ifconfig.me` avant de vous connecter depuis un autre réseau.

---

## Logiciels installés automatiquement

### Containers et Orchestration

| Outil | Description |
|---|---|
| Docker CE + Docker Compose | Moteur de conteneurs et orchestration locale |
| kubectl | CLI Kubernetes officielle |
| Helm | Gestionnaire de paquets Kubernetes |
| k9s | Interface terminal Kubernetes interactive |
| kubectx / kubens | Changement de contexte et namespace en une commande |
| kind | Cluster Kubernetes local dans Docker |
| Portainer | Interface web Docker - https://\<IP\>:9443 |
| Skaffold | Dev loop Kubernetes local (build/push/deploy automatisé) |
| Stern | Tail de logs multi-pods Kubernetes |
| cosign | Signature et vérification d'images OCI (supply chain security) |

### Infrastructure as Code

| Outil | Description |
|---|---|
| Terraform + tflint | IaC HashiCorp + linter de bonnes pratiques |
| Terragrunt | Wrapper Terraform pour configurations DRY multi-environnements |
| Packer | Construction d'images machine reproductibles |
| Ansible + ansible-lint + molecule | Automatisation de configuration et tests de rôles |
| Vault | Gestion centralisée des secrets HashiCorp - http://\<IP\>:8200 |

### Cloud et CI/CD

| Outil | Description |
|---|---|
| Azure CLI | Gestion complète des ressources Azure depuis le terminal |
| GitHub CLI | Gestion des dépôts, PR et releases GitHub |
| ArgoCD CLI | GitOps et déploiements continus sur Kubernetes |
| act | Exécution de workflows GitHub Actions en local (Docker) |

### Monitoring

| Outil | Accès | Description |
|---|---|---|
| Prometheus | http://\<IP\>:9090 | Collecte et stockage de métriques time-series |
| Grafana | http://\<IP\>:3000 (admin/admin) | Dashboards de visualisation - préconfigurés avec Node Exporter |
| Node Exporter | Port 9100 (interne VNet) | Métriques système CPU, RAM, disque, réseau |

### Bases de données

Clients en ligne de commande : `postgresql-client`, `mysql-client`, `redis-tools`, `sqlite3`, `usql` (client universel multi-BDD).

Conteneurs Docker démarrés automatiquement avec données persistées dans `/data/docker-volumes/` :

| Service | Port (loopback) | Credentials | Image |
|---|---|---|---|
| PostgreSQL 16 | 127.0.0.1:5432 | postgres / postgres | postgres:16-alpine |
| MySQL 8 | 127.0.0.1:3306 | root / root | mysql:8 |
| Redis 7 | 127.0.0.1:6379 | - | redis:7-alpine |
| MongoDB 7 | 127.0.0.1:27017 | admin / admin | mongo:7 |

> Les conteneurs écoutent sur `127.0.0.1` uniquement pour éviter toute exposition publique, même si le NSG Azure filtre déjà au niveau réseau.

### Python et DataOps

| Catégorie | Librairies |
|---|---|
| Data Science | pandas, polars, numpy, matplotlib, seaborn, plotly |
| Machine Learning | scikit-learn, xgboost, mlflow |
| Pipelines | dbt-core, Apache Airflow 2.9, PySpark, Dask |
| API | FastAPI, uvicorn, requests, httpx, aiohttp |
| Bases de données | SQLAlchemy, psycopg2, pymysql, pymongo, redis |
| Cloud | azure-storage-blob, azure-identity, boto3 |
| Qualité | black, flake8, mypy, isort, pylint, pytest, pre-commit |
| Notebooks | JupyterLab - http://\<IP\>:8888 |

### Sécurité - DevSecOps

| Outil | Description |
|---|---|
| Trivy | Scanner de vulnérabilités pour images Docker, fichiers IaC et dépendances |
| Hadolint | Linter Dockerfile (détecte les mauvaises pratiques) |
| fail2ban | Protection automatique contre le brute-force SSH |
| ufw | Pare-feu applicatif (aligné sur les règles NSG Azure) |

### Sécurité - Pentest et Sécurité Offensive

| Outil | Description |
|---|---|
| Nuclei | Scanner de vulnérabilités par templates (ProjectDiscovery) |
| ffuf | Fuzzing web rapide (répertoires, paramètres, vhosts) |
| gobuster | Brute-force de répertoires et DNS |
| Amass | Énumération de sous-domaines et cartographie d'infrastructure (OSINT) |
| theHarvester | Collecte d'informations emails, noms, domaines (OSINT) |
| testssl.sh | Audit complet de la configuration TLS/SSL |
| Metasploit Framework | Framework d'exploitation de vulnérabilités |
| Nikto | Scanner de vulnérabilités web (serveurs HTTP) |
| Hydra | Brute-force de services réseau (SSH, FTP, HTTP, etc.) |
| sqlmap | Détection et exploitation automatique d'injections SQL |
| John the Ripper | Cracking de mots de passe (hash, fichiers chiffrés) |
| sslscan | Analyse rapide des configurations SSL/TLS |
| dirb | Discovery de répertoires et fichiers web |
| enum4linux | Énumération d'informations Windows/Samba |
| netdiscover / arp-scan | Découverte réseau ARP (hôtes actifs) |
| SecLists | Wordlists de référence - `/opt/SecLists` |
| rockyou.txt | Wordlist - `/usr/share/wordlists/rockyou.txt` |

Répertoire de travail dédié : `/data/pentest/{recon,exploits,reports,loot}`

>  **Avertissement légal** : ces outils sont destinés à des environnements de test et d'apprentissage. Ne les utilisez jamais sur des systèmes sans autorisation explicite.

### Réseau

| Outil | Description |
|---|---|
| nmap / masscan | Scan de ports et de réseaux |
| tcpdump / tshark | Capture et analyse de trafic réseau |
| iperf3 | Test de bande passante |
| mtr / traceroute | Diagnostic de routage réseau |
| OpenVPN / WireGuard | Clients et serveur VPN |
| netdiscover / arp-scan | Découverte réseau ARP |
| httpie / socat / netcat | Outils réseau divers (HTTP, tunnels, transferts) |
| autossh | Maintien automatique des tunnels SSH |

### Langages

| Langage | Détails |
|---|---|
| Go | Dernière version stable (via go.dev), `$GOPATH` configuré |
| Node.js LTS | yarn, pnpm, TypeScript, ts-node, eslint, prettier, pm2 |
| Rust | Via rustup, configuré pour l'utilisateur admin |
| Java 21 | OpenJDK + Maven + Gradle 8.7 + SDKMAN |

### Shell et Productivité

- ZSH + Oh My Zsh (thème Agnoster) avec autosuggestions et syntax highlighting
- `fzf`, `bat`, `eza` (remplaçant de `exa`), `fd`, `ripgrep`
- `tmux`, `vim` (configuré avec numérotation et coloration), `htop`, `tree`, `jq`, `yq`
- Alias prédéfinis : `k` (kubectl), `d` (docker), `dc` (docker compose), `tf` (terraform), `tg` (terragrunt)

---

## Sécurité et NSG

> **Recommandation** : restreignez l'accès SSH à votre IP uniquement.

```bash
# Trouver votre IP publique
curl ifconfig.me
```

Dans `terraform.tfvars` :

```hcl
allowed_ssh_cidr = "90.12.34.56/32"
```

Récapitulatif des règles NSG définies dans `network.tf` :

| Priorité | Port(s) | Service | Source autorisée |
|---|---|---|---|
| 100 | 22 | SSH | `allowed_ssh_cidr` uniquement |
| 110 | 80 | HTTP | Tout (`*`) |
| 120 | 443 | HTTPS | Tout (`*`) |
| 130 | 8888 | JupyterLab | `allowed_ssh_cidr` uniquement |
| 140 | 3000 | Grafana | `allowed_ssh_cidr` uniquement |
| 150 | 9443 | Portainer | `allowed_ssh_cidr` uniquement |
| 160 | 9090 | Prometheus | `allowed_ssh_cidr` uniquement |
| 170 | 8200 | Vault | `allowed_ssh_cidr` uniquement |
| 180 | 9100 | Node Exporter | CIDR VNet interne uniquement |
| 190 | 5432, 3306, 6379, 27017 | Bases de données | CIDR VNet interne uniquement |
| 4096 | `*` | Deny all | - |

> Le pare-feu UFW dans la VM est aligné sur ces mêmes règles (défense en profondeur).

---

## Coût estimé (Azure Students - 100$/an de crédit)

| Ressource | Taille | Coût/mois* |
|---|---|---|
| VM Standard_B2ms | 2 vCPU / 8 GB RAM | ~30$ |
| Disque OS Premium SSD 64 GB | - | ~7$ |
| Disque Données Premium SSD 64 GB | - | ~7$ |
| IP Publique Standard | - | ~3$ |
| **Total** | | **~47$/mois** |

> Prix indicatifs région West Europe. **Éteignez la VM lorsqu'elle n'est pas utilisée** pour économiser votre crédit : `az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm`

**Optimisation** : passer à `Standard_B1ms` (1 vCPU / 2 GB) réduit le coût à ~18$/mois si vous n'utilisez pas les outils gourmands en mémoire (Airflow, PySpark, Metasploit).

---

## Commandes utiles post-déploiement

```bash
# Statut de tous les services et outils
devops-status

# Suivre les logs d'installation
tail -f /var/log/devops-install.log

# Démarrer JupyterLab manuellement (si arrêté)
sudo systemctl start jupyter
sudo systemctl status jupyter

# Démarrer Airflow
sudo systemctl start airflow-webserver airflow-scheduler

# Démarrer / vérifier Vault
sudo systemctl status vault
cat /root/.vault-init   # root token et unseal key (sudo requis)

# Lister les conteneurs Docker actifs
docker ps

# Vérifier les ports en écoute
ss -tulnp

# Éteindre la VM depuis Azure (économise le crédit)
az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm

# Redémarrer la VM
az vm start -g rg-devops-pro-vm -n devops-pro-vm
```

---

## Troubleshooting

### L'installation est toujours en cours après 30 minutes

```bash
# Vérifier où en est le script
tail -50 /var/log/devops-install.log

# Vérifier si le processus tourne encore
ps aux | grep install.sh
```

### Un service ne démarre pas

```bash
# Vérifier les logs systemd
journalctl -u jupyter --no-pager -n 50
journalctl -u vault --no-pager -n 50
journalctl -u node_exporter --no-pager -n 50

# Redémarrer un service
sudo systemctl restart jupyter
```

### JupyterLab inaccessible depuis le navigateur

```bash
# Vérifier que le service tourne
sudo systemctl status jupyter

# Vérifier que le port est ouvert
ss -tulnp | grep 8888

# Vérifier le pare-feu UFW
sudo ufw status

# Vérifier votre IP actuelle (peut avoir changé)
curl ifconfig.me
# Si différente de allowed_ssh_cidr → mettre à jour terraform.tfvars et ré-appliquer
```

### Vault non initialisé après redémarrage

```bash
# Vault doit être unsealed après chaque redémarrage
sudo cat /root/.vault-init
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal <unseal_key>
```

### Les conteneurs Docker ne démarrent pas

```bash
# Vérifier l'état de Docker
sudo systemctl status docker

# Voir les conteneurs (y compris ceux qui ont échoué)
docker ps -a

# Relancer un conteneur
docker start postgres mysql redis mongo

# Voir les logs d'un conteneur
docker logs postgres --tail 50
```

### Erreur Terraform "subscription not found"

```bash
az account list --output table
az account set --subscription "Azure for Students"
terraform init -reconfigure
```

---

## Mise à jour de la VM

### Mettre à jour les paquets système

```bash
sudo apt update && sudo apt upgrade -y
```

### Mettre à jour un outil spécifique (exemple : Terraform)

```bash
TF_VER=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r .current_version)
curl -sLO "https://releases.hashicorp.com/terraform/$TF_VER/terraform_${TF_VER}_linux_amd64.zip"
unzip -oq "terraform_${TF_VER}_linux_amd64.zip"
sudo install terraform /usr/local/bin/
rm -f terraform terraform_*.zip
```

### Mettre à jour les images Docker

```bash
docker pull postgres:16-alpine && docker stop postgres && docker rm postgres
# Puis relancer avec la même commande docker run qu'à l'installation
```

### Recréer la VM avec une config mise à jour

```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

> Les données du disque `/data` sont perdues lors d'un `destroy`. Sauvegardez vos projets importants avant.

---

## Destruction de l'infrastructure

```bash
terraform destroy -auto-approve
```

> Toutes les ressources Azure créées par Terraform seront supprimées définitivement (VM, disques, IP, VNet, NSG). Cette action est **irréversible**.

**Avant de détruire**, sauvegardez :
- Vos projets dans `/data/projects/`
- Vos rapports pentest dans `/data/pentest/`
- Vos clés Vault (`/root/.vault-init`)
- Vos configurations personnalisées

---

## Contribution

Les contributions sont bienvenues. Pour proposer une amélioration :

1. Forkez le dépôt
2. Créez une branche `feature/ma-fonctionnalite`
3. Modifiez `install.sh` ou les fichiers Terraform
4. Testez en déployant une VM réelle
5. Ouvrez une Pull Request avec une description claire des changements

### Ajouter un nouvel outil

Dans `install.sh`, respectez le pattern existant :

```bash
TOOL_VER=$(curl -s "https://api.github.com/repos/<org>/<repo>/releases/latest" | jq -r .tag_name)
curl -sLo /usr/local/bin/tool "https://.../$TOOL_VER/tool-linux-amd64"
chmod +x /usr/local/bin/tool
ok "Tool $TOOL_VER installé"
```

N'oubliez pas de l'ajouter dans `devops-status` et dans les tableaux du README.
