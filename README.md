# DevOps VM - Students

VM Ubuntu 22.04 LTS sur Azure, déployée par Terraform.
Prête à l'emploi pour **DevOps / CI-CD / Pentest / DataOps / SRE**.

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
│   └── install.sh       # Script d'installation automatique
└── keys/                # Clés SSH (générées par Terraform)
```

---

## Prérequis

| Outil | Version minimum | Lien |
|---|---|---|
| Terraform | 1.5 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | dernière | https://docs.microsoft.com/cli/azure/install |

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
nano terraform.tfvars   # Éditez selon vos besoins
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

---

## Logiciels installés automatiquement

### Containers et Orchestration

| Outil | Description |
|---|---|
| Docker CE + Docker Compose | Moteur de conteneurs |
| kubectl | CLI Kubernetes |
| Helm | Gestionnaire de paquets Kubernetes |
| k9s | Interface terminal Kubernetes |
| kubectx / kubens | Changement de contexte et namespace |
| kind | Cluster Kubernetes local |
| Portainer | Interface web Docker — https://\<IP\>:9443 |
| Skaffold | Dev loop Kubernetes local |
| Stern | Tail de logs multi-pods |
| cosign | Signature et vérification d'images OCI |

### Infrastructure as Code

| Outil | Description |
|---|---|
| Terraform + tflint | IaC HashiCorp + linter |
| Terragrunt | Wrapper Terraform DRY |
| Packer | Construction d'images machine |
| Ansible + ansible-lint + molecule | Automatisation de configuration |
| Vault | Gestion des secrets HashiCorp |

### Cloud et CI/CD

| Outil | Description |
|---|---|
| Azure CLI | Gestion des ressources Azure |
| GitHub CLI | Gestion des dépôts et PR GitHub |
| ArgoCD CLI | GitOps sur Kubernetes |
| act | Exécution GitHub Actions en local |

### Monitoring

| Outil | Accès |
|---|---|
| Prometheus | http://\<IP\>:9090 |
| Grafana | http://\<IP\>:3000 (admin/admin) |
| Node Exporter | Métriques système (port 9100, interne) |

### Bases de données

Clients en ligne de commande :

- postgresql-client, mysql-client, redis-tools, sqlite3, usql

Conteneurs Docker démarrés automatiquement :

| Service | Port | Credentials |
|---|---|---|
| PostgreSQL 16 | 5432 | postgres / postgres |
| MySQL 8 | 3306 | root / root |
| Redis 7 | 6379 | - |
| MongoDB 7 | 27017 | admin / admin |

> Les données sont persistées dans `/data/docker-volumes/`.

### Python et DataOps

| Catégorie | Librairies |
|---|---|
| Data Science | pandas, polars, numpy, matplotlib, seaborn, plotly |
| Machine Learning | scikit-learn, xgboost, mlflow |
| Pipelines | dbt-core, Apache Airflow, PySpark, Dask |
| API | FastAPI, uvicorn, requests, httpx |
| Bases de données | SQLAlchemy, psycopg2, pymysql |
| Cloud | azure-storage-blob, azure-identity, boto3 |
| Qualité | black, flake8, mypy, isort, pylint, pytest |
| Notebooks | JupyterLab - http://\<IP\>:8888 |

### Securite - DevSecOps

| Outil | Description |
|---|---|
| Trivy | Scanner de vulnérabilités pour conteneurs |
| Hadolint | Linter Dockerfile |
| fail2ban | Protection contre le brute-force SSH |
| ufw | Pare-feu applicatif |

### Securite - Pentest et Securite Offensive

| Outil | Description |
|---|---|
| Nuclei | Scanner de vulnérabilités par templates |
| ffuf | Fuzzing web rapide |
| gobuster | Brute-force répertoires et DNS |
| Amass | Énumération de sous-domaines (OSINT) |
| theHarvester | Collecte d'informations OSINT |
| testssl.sh | Audit TLS/SSL |
| Metasploit Framework | Framework d'exploitation |
| Nikto | Scanner de vulnérabilités web |
| Hydra | Brute-force de services réseau |
| sqlmap | Détection et exploitation d'injections SQL |
| John the Ripper | Cracking de mots de passe |
| sslscan | Analyse des configurations SSL/TLS |
| dirb | Discovery de répertoires web |
| enum4linux | Énumération Windows/Samba |
| SecLists | Wordlists de référence — /opt/SecLists |
| rockyou.txt | Wordlist — /usr/share/wordlists/rockyou.txt |

Répertoire de travail dédié : `/data/pentest/{recon,exploits,reports,loot}`

### Reseau

| Outil | Description |
|---|---|
| nmap / masscan | Scan de ports et de réseaux |
| tcpdump / tshark | Capture et analyse de trafic |
| iperf3 | Test de bande passante |
| mtr / traceroute | Diagnostic réseau |
| OpenVPN / WireGuard | VPN |
| netdiscover / arp-scan | Découverte réseau ARP |
| httpie / socat / netcat | Outils réseau divers |

### Langages

| Langage | Détails |
|---|---|
| Go | Dernière version stable |
| Node.js LTS | yarn, pnpm, TypeScript, ts-node, eslint, prettier, pm2 |
| Rust | Via rustup |
| Java 21 | OpenJDK + Maven + Gradle + SDKMAN |

### Shell et Productivite

- ZSH + Oh My Zsh (thème Agnoster) avec autosuggestions et syntax highlighting
- fzf, bat, exa, fd, ripgrep
- tmux, vim (configuré), htop, tree, jq, yq

---

## Securite et NSG

> Recommandation : restreignez l'accès SSH à votre IP uniquement.

Dans `terraform.tfvars` :

```hcl
# Trouvez votre IP : curl ifconfig.me
allowed_ssh_cidr = "90.12.34.56/32"
```

Ports ouverts par le NSG :

| Port | Service | Source autorisée |
|---|---|---|
| 22 | SSH | allowed_ssh_cidr uniquement |
| 80 / 443 | HTTP / HTTPS | Tout |
| 8888 | JupyterLab | allowed_ssh_cidr uniquement |
| 3000 | Grafana | allowed_ssh_cidr uniquement |
| 9090 | Prometheus | allowed_ssh_cidr uniquement |
| 9443 | Portainer | allowed_ssh_cidr uniquement |
| 8200 | Vault | allowed_ssh_cidr uniquement |
| 9100 | Node Exporter | CIDR VNet interne uniquement |
| 5432 / 3306 / 6379 / 27017 | Bases de données | CIDR VNet interne uniquement |

---

## Cout estimé (Azure Students - 100$/an de crédit)

| Ressource | Taille | Cout/mois* |
|---|---|---|
| VM Standard_B2ms | 2 vCPU / 8 GB RAM | ~30$ |
| Disque OS Premium 64 GB | - | ~7$ |
| Disque Données Premium 64 GB | - | ~7$ |
| IP Publique Standard | - | ~3$ |
| **Total** | | **~47$/mois** |

> Prix indicatifs West Europe. Eteignez la VM lorsqu'elle n'est pas utilisée pour économiser votre crédit.

---

## Commandes utiles post-déploiement

```bash
# Statut de tous les services et outils
devops-status

# Suivre les logs d'installation
tail -f /var/log/devops-install.log

# Démarrer JupyterLab manuellement
sudo systemctl start jupyter

# Lister les conteneurs Docker actifs
docker ps

# Éteindre la VM depuis Azure (économise le crédit)
az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm

# Redémarrer la VM
az vm start -g rg-devops-pro-vm -n devops-pro-vm
```

---

## Destruction de l'infrastructure

```bash
terraform destroy -auto-approve
```

> Toutes les ressources Azure créées par Terraform seront supprimées définitivement.
