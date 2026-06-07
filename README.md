# 🚀 DevOps Pro VM — Azure Students

VM Ubuntu 22.04 LTS sur Azure, déployée par Terraform.  
Prête à l'emploi pour **DevOps / DataOps / Network Admin / SRE**.

---

## 📁 Structure des fichiers

```
azure-devops-vm/
├── provider.tf          # Configuration provider AzureRM
├── main.tf              # VM, disques, IPs, clés SSH
├── network.tf           # VNet, Subnet, NSG (pare-feu)
├── variables.tf         # Définition des variables
├── terraform.tfvars     # Vos valeurs personnalisées
├── outputs.tf           # IPs, URL, commandes SSH
├── cloud-init/
│   └── install.sh       # Script d'installation automatique
└── keys/                # Clés SSH (générées par Terraform)
```

---

## ✅ Prérequis

| Outil | Version | Installation |
|-------|---------|-------------|
| Terraform | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | dernière | https://docs.microsoft.com/cli/azure/install |

---

## 🚀 Déploiement en 5 étapes

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
# Éditez terraform.tfvars selon vos besoins
nano terraform.tfvars
```

### 3. Initialiser Terraform
```bash
terraform init
terraform validate
terraform plan
```

### 4. Déployer
```bash
terraform apply -auto-approve
```

⏱ La VM est créée en **~3 minutes**.  
⏱ L'installation des logiciels prend **15-25 minutes** en arrière-plan.

### 5. Connexion SSH
```bash
# La commande exacte est affichée dans les outputs :
terraform output ssh_command

# Exemple :
ssh -i keys/devops-pro-vm_id_rsa devopsadmin@<IP_PUBLIQUE>

# Suivre l'installation en temps réel :
tail -f /var/log/devops-install.log

# Vérifier le statut :
devops-status
```

---

## 🛠 Logiciels installés automatiquement

### 🐳 Containers & Orchestration
- Docker CE + Docker Compose
- kubectl + Helm + k9s + kubectx/kubens
- kind (Kubernetes local)
- Portainer (UI Docker) → https://\<IP\>:9443

### 🏗 Infrastructure as Code
- **Terraform** + tflint
- **Terragrunt**
- **Packer**
- **Ansible** + ansible-lint + molecule

### ☁️ Cloud & CI/CD
- **Azure CLI** (az)
- **GitHub CLI** (gh)
- **ArgoCD CLI**
- act (GitHub Actions local)

### 📊 Monitoring
- **Prometheus** → http://\<IP\>:9090
- **Grafana** → http://\<IP\>:3000 (admin/admin)
- **Node Exporter** (métriques système)

### 🐍 Python / DataOps
- JupyterLab → http://\<IP\>:8888
- pandas, polars, numpy, matplotlib, seaborn, plotly
- scikit-learn, xgboost, mlflow
- dbt-core, great-expectations
- Apache Airflow
- PySpark + Dask
- FastAPI + uvicorn
- SQLAlchemy + clients PostgreSQL/MySQL
- Azure SDK (azure-storage-blob, azure-identity)
- black, flake8, mypy, pytest

### 🗄 Bases de données (clients + images Docker)
- postgresql-client, mysql-client, redis-tools, sqlite3
- usql (client SQL universel)
- Images Docker : PostgreSQL 16, MySQL 8, Redis 7, MongoDB 7

### 🌐 Réseau & Sécurité
- nmap, masscan, tcpdump, tshark
- iperf3, mtr, traceroute, dnsutils
- OpenVPN, WireGuard
- **Trivy** (scanner vulnérabilités containers)
- **Hadolint** (linter Dockerfile)
- fail2ban, ufw (firewall)

### 💻 Langages
- **Go** (dernière version stable)
- **Node.js** LTS + yarn, pnpm, TypeScript, pm2
- **Rust** (via rustup)
- **Java 21** (OpenJDK) + Maven + Gradle + SDKMAN

### 🎨 Shell & Productivité
- **ZSH** + Oh My Zsh (thème Agnoster)
- fzf, bat, exa, fd, ripgrep
- tmux, vim (configuré), htop, tree, jq, yq

---

## 🔒 Sécurité

> ⚠️ **Recommandation** : Restreignez l'accès SSH à votre IP.

Dans `terraform.tfvars` :
```hcl
# Trouvez votre IP : curl ifconfig.me
allowed_ssh_cidr = "90.12.34.56/32"
```

Ports ouverts par le NSG :
| Port | Service |
|------|---------|
| 22 | SSH |
| 80/443 | HTTP/HTTPS |
| 8888 | JupyterLab |
| 3000 | Grafana |
| 9090 | Prometheus |
| 9443 | Portainer |

---

## 💰 Coût estimé (Azure Students — 100$/an de crédit)

| Ressource | Taille | Coût/mois* |
|-----------|--------|-----------|
| VM Standard_B2ms | 2 vCPU / 8 GB | ~30$ |
| Disque OS Premium 64 GB | — | ~7$ |
| Disque Données Premium 64 GB | — | ~7$ |
| IP Publique Standard | — | ~3$ |
| **Total** | | **~47$/mois** |

> *Prix indicatifs West Europe. Éteignez la VM quand non utilisée :  
> `az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm`

---

## 🗑 Destruction

```bash
terraform destroy -auto-approve
```

---

## 🔧 Commandes utiles post-déploiement

```bash
# Statut de tous les services
devops-status

# Logs d'installation
tail -f /var/log/devops-install.log

# Démarrer JupyterLab manuellement
sudo systemctl start jupyter

# Voir les containers Docker
docker ps

# Éteindre la VM depuis Azure (économise du crédit)
az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm

# Redémarrer la VM
az vm start -g rg-devops-pro-vm -n devops-pro-vm
```
