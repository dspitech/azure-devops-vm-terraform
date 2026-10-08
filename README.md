# DevOps VM - Azure Students 

<div align="center">

![Azure](https://img.shields.io/badge/Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Security](https://img.shields.io/badge/Pentest-Ready-brightgreen?style=for-the-badge&logo=kalilinux&logoColor=white)

**VM DevOps préconfigurée, déployée sur Azure en une commande via Terraform**
*Profils DevOps · DataOps · Cybersécurité · Fullstack*

</div>

---

## Sommaire

- [Objectif](#objectif)
- [Profils étudiants (`vm_profile`)](#profils-étudiants-vm_profile)
- [Structure des fichiers](#structure-des-fichiers)
- [Prérequis](#prérequis)
- [Variables Terraform](#variables-terraform)
- [Architecture](#architecture)
- [Démarrage rapide](#démarrage-rapide)
- [Accéder aux services](#5-accéder-aux-services)
- [Services en tunnel SSH uniquement](#services-en-tunnel-ssh-uniquement-non-exposés-dans-le-nsg)
- [Logiciels installés automatiquement](#logiciels-installés-automatiquement)
- [Sécurité et réseau](#sécurité-et-réseau)
- [Coût estimé](#coût-estimé-azure-students--100an-de-crédit)
- [Script cloud-init](#script-cloud-init--installation-automatique)
- [Commandes utiles post-déploiement](#commandes-utiles-post-déploiement)
- [Dépannage](#dépannage)
- [Maintenance](#maintenance-de-la-vm)
- [Destruction de l'infrastructure](#destruction-de-linfrastructure)
- [Contribution](#contribution)
- [Auteur](#auteur)

---

## Objectif

Ce projet s'adresse aux étudiants et aux professionnels qui souhaitent disposer rapidement d'un environnement de travail complet, sans passer des heures à configurer leurs outils manuellement.

En quelques minutes, Terraform déploie sur Azure une machine virtuelle Ubuntu 22.04 LTS entièrement préconfigurée, couvrant les besoins suivants :

- **DevOps et CI/CD** : Docker, Kubernetes (kubectl/Helm/k9s/kind/k3s), Terraform, Ansible, Vault, ArgoCD, GitHub Actions, sécurité IaC (Checkov/tfsec/gitleaks/semgrep) et bien d'autres.
- **Pentest et sécurité offensive** : Metasploit, Nuclei, ffuf, sqlmap, Hydra, Amass, suite ProjectDiscovery, et des cibles d'entraînement (DVWA, Juice Shop, WebGoat) isolées en tunnel SSH.
- **DataOps et Data Science** : JupyterLab, Spark, dbt, pandas, scikit-learn, DuckDB, Streamlit, MinIO, Metabase et les principaux SDKs cloud.
- **SRE et monitoring** : Prometheus, Grafana, Loki/Promtail, cAdvisor, Node Exporter, Trivy et fail2ban préconfigurés.
- **Productivité** : code-server (VS Code web), lazygit/lazydocker, et un tableau de bord web qui s'adapte automatiquement au profil choisi.

Que vous soyez en cours de formation, en stage ou en poste, cette VM vous permet de démarrer immédiatement sur un environnement standardisé, reproductible et prêt pour des cas d'usage réels. L'installation est **résiliente** : si un outil isolé échoue à s'installer (indisponibilité ponctuelle d'une API tierce, par exemple), le reste de l'installation continue et va jusqu'au bout.

---

## Profils étudiants (`vm_profile`)

Plutôt que d'installer systématiquement tous les outils (installation plus
longue, VM plus chargée), le projet propose 4 profils. Le socle commun
(Docker + Portainer, Prometheus + Grafana, PostgreSQL + Redis, sécurité de
base UFW/fail2ban) est **toujours installé**, quel que soit le profil.

| Profil | Pour qui | Outils ajoutés au socle commun |
|---|---|---|
| `devops` | Étudiants DevOps / Cloud / SRE | Kubernetes (kubectl, Helm, k9s, kind, k3s, kustomize, kubeconform, popeye), Terraform/Terragrunt/Packer/Ansible + sécurité IaC (Checkov, tfsec, gitleaks, semgrep, conftest, terraform-docs, infracost), CI/CD (Azure CLI, AWS CLI, gcloud, GitHub CLI, ArgoCD, act, Vault, Skaffold, Stern, cosign), Trivy/Hadolint, dive/ctop, Go/Node.js/Rust/Java |
| `dataops` | Étudiants Data / IA / ML | JupyterLab, pandas/polars/numpy/scikit-learn/xgboost/mlflow, DuckDB, Streamlit, DVC, Great Expectations, Prefect, dbt-core, PySpark, Dask, FastAPI, MinIO, Metabase, pgAdmin, Redpanda, Go/Node.js/Rust/Java |
| `cybersecurity` | Étudiants Cybersécurité / Pentest | Recon (subfinder, httpx, naabu, dnsx, katana, feroxbuster, whatweb), Nuclei, ffuf, gobuster, Amass, theHarvester, wpscan, OWASP ZAP, Metasploit, Hydra, sqlmap, John the Ripper, impacket, NetExec, binwalk, radare2, volatility3, CyberChef, cibles d'entraînement (DVWA, Juice Shop, WebGoat), outils de défense (Lynis, ClamAV, auditd, osquery, CrowdSec), wordlists |
| `fullstack` (défaut) | Formation généraliste, labo tout-en-un | Tout ce qui précède, réuni |

> Le socle commun inclut aussi, depuis la dernière mise à jour : code-server
> (VS Code dans le navigateur), lazygit, lazydocker, btop, ncdu, direnv,
> pre-commit, tldr, restic, unattended-upgrades, et une stack de logs
> Loki/Promtail + cAdvisor en complément de Prometheus/Grafana.
>
> ⚠️ Le profil `fullstack` installe les 4 familles d'outils **simultanément** :
> prévoyez au moins 8 Go de RAM (`Standard_B2ms` ou plus). Une
> `precondition` Terraform bloque le déploiement si vous choisissez
> `fullstack` avec une VM plus petite (`Standard_B2s`/`B1s`).

**Déployer un profil précis** - un fichier d'exemple prêt à l'emploi existe pour chacun dans `examples/` :

```bash
terraform apply -var-file="examples/devops.tfvars"
# ou : dataops.tfvars / cybersecurity.tfvars / fullstack.tfvars
```

> Ces fichiers ne fixent volontairement **pas** `allowed_ssh_cidr` : si vous
> l'avez déjà défini dans votre propre `terraform.tfvars` (ex. votre IP
> réelle), cette valeur s'applique automatiquement - Terraform charge
> `terraform.tfvars` en premier, puis complète avec le fichier `-var-file`
> pour tout ce qu'il ne définit pas. Sans `terraform.tfvars` personnalisé,
> la détection automatique (`"auto"`) s'applique par défaut.

Vous pouvez aussi simplement fixer `vm_profile` dans votre propre
`terraform.tfvars` :

```hcl
vm_profile = "dataops"   # "devops" | "dataops" | "cybersecurity" | "fullstack"
```

Le NSG Azure n'ouvre que les ports des services réellement installés pour le
profil choisi (par exemple, le port 8888/Jupyter n'est ouvert que pour
`dataops`/`fullstack`), et `cloud-init/install.sh` saute proprement les
phases non concernées (visible dans `/var/log/devops-install.log` et via
`devops-status`, qui affiche le profil actif).

Un **tableau de bord de statut** est généré automatiquement (voir
[Accéder aux services](#5-accéder-aux-services)) : accessible sur
`http://<IP>/`, il affiche le profil actif, un lien direct + un indicateur
d'état en temps réel pour chaque service web installé, ainsi que
l'inventaire complet des logiciels installés (avec leur version réelle),
regroupé par catégorie et filtré selon le profil actif.

---

## Structure des fichiers

```
azure-devops-vm/
├── provider.tf          # Configuration provider AzureRM
├── main.tf              # VM, disques, IPs, clés SSH, mots de passe générés
├── network.tf           # VNet, Subnet, NSG (pare-feu, adapté au profil)
├── variables.tf         # Définition des variables (dont vm_profile)
├── terraform.tfvars     # Vos valeurs personnalisées (profil "fullstack" par défaut)
├── examples/            # Fichiers .tfvars prêts à l'emploi par profil
│   ├── devops.tfvars
│   ├── dataops.tfvars
│   ├── cybersecurity.tfvars
│   └── fullstack.tfvars
├── outputs.tf           # IPs, URLs, mots de passe générés, commandes SSH
├── cloud-init/
│   └── install.sh       # Script d'installation automatique, adapté au profil
└── keys/                # Clés SSH (générées par Terraform, ignorées par git)
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
| `vm_profile` | `"fullstack"` | `"devops"` \| `"dataops"` \| `"cybersecurity"` \| `"fullstack"` - voir la section [Profils étudiants](#profils-étudiants-vm_profile) |
| `os_disk_size_gb` | `64` | Taille du disque OS en GB |
| `data_disk_size_gb` | `64` | Taille du disque de données en GB |
| `vnet_address_space` | `10.0.0.0/16` | Plage d'adresses du réseau virtuel |
| `subnet_address_prefix` | `10.0.1.0/24` | Plage d'adresses du sous-réseau |
| `allowed_ssh_cidr` | `"auto"` | IP publique du déployeur, détectée **automatiquement** (aucune saisie requise). Une valeur explicite (`"90.x.x.x/32"`) ou `"*"` restent possibles. |
| `auto_shutdown_enabled` | `true` | Arrêt automatique quotidien de la VM (protège le crédit Azure Students) |
| `auto_shutdown_time` | `"1900"` | Heure d'arrêt quotidien, format `HHmm` |
| `auto_shutdown_timezone` | `"Romance Standard Time"` | Fuseau horaire de l'arrêt automatique |
| `tags` | `{}` | Tags Azure appliqués à toutes les ressources |

Exemple de `terraform.tfvars` minimal (fonctionne tel quel, `allowed_ssh_cidr` s'auto-détecte) :

```hcl
vm_name  = "devops-pro-vm"
location = "westeurope"

tags = {
  environment = "student"
  project     = "devops-lab"
}
```

---

## Architecture

```
                         Internet
                            │
                 ┌──────────┴──────────┐
                  IP Publique (Standard)
                 └──────────┬──────────┘
                            │
                  ╔═════════▼═════════╗
                  ║   NSG (pare-feu)   ║  ← ports ouverts selon vm_profile
                  ╚═════════┬═════════╝
                            │
                 VNet 10.0.0.0/16
                 └─ Subnet 10.0.1.0/24
                            │
                  ┌─────────▼─────────┐
                  │   VM Ubuntu 22.04  │
                  │  (cloud-init boot) │
                  ├────────────────────┤
                  │ Disque OS (64 GB)  │
                  │ Disque data (64+)  │──▶ /data
                  └────────────────────┘
```

Le déploiement repose sur 5 fichiers Terraform et un script cloud-init, chacun avec une responsabilité unique :

| Fichier | Rôle |
|---|---|
| `provider.tf` | Déclare les providers utilisés (AzureRM, random, tls, local, http) et leurs versions minimales. |
| `variables.tf` | Déclare toutes les variables d'entrée (taille de VM, réseau, `vm_profile`, `allowed_ssh_cidr`...) avec valeurs par défaut et validations. |
| `main.tf` | Crée la VM, les disques, la clé SSH (générée), les mots de passe (Grafana/Jupyter/Portainer, générés), détecte l'IP publique du déployeur, et injecte tout ça dans le script cloud-init. |
| `network.tf` | VNet, Subnet, IP publique, NSG - les règles de pare-feu s'adaptent automatiquement au profil choisi (`vm_profile`). |
| `outputs.tf` | Toutes les valeurs utiles après déploiement : IP, commande SSH, URLs des services, mots de passe générés (marqués `sensitive`). |
| `cloud-init/install.sh` | Exécuté au premier démarrage de la VM. Installe et configure les outils en 13 phases, en sautant celles qui ne concernent pas le profil actif. |

**Décisions de conception clés :**

- **Rien à saisir à la main** : l'IP publique du déployeur est détectée automatiquement (`allowed_ssh_cidr = "auto"`), et les mots de passe de Grafana/Jupyter/Portainer sont générés par Terraform plutôt que codés en dur.
- **Résilience** : `install.sh` continue même si un outil isolé échoue à s'installer (ex : rate-limit temporaire d'une API tierce) - chaque étape est indépendante et journalisée dans `/var/log/devops-install.log`.
- **Profils** : un seul jeu de fichiers Terraform, un seul script cloud-init - le comportement s'adapte via la variable `vm_profile` plutôt que via des branches de code séparées.
- **Visibilité** : un tableau de bord web (`http://<IP>/`) et une commande `devops-status` en SSH donnent à tout moment une vue claire de ce qui est installé et de son état.

> L'historique détaillé des choix techniques et des corrections apportées au projet est disponible dans [`CHANGELOG-CORRECTIONS.md`](./CHANGELOG-CORRECTIONS.md).

---

## Démarrage rapide

### 1. Connexion Azure

Lancer le cloud Shell depuis le portal Azure et choisir PowerShell.

> ⚠️ **Piège fréquent avec Cloud Shell** : `allowed_ssh_cidr = "auto"`
> détecte l'IP de la machine qui exécute `terraform apply` - donc celle de
> **Cloud Shell**, pas celle de votre PC. Si vous déployez depuis Cloud
> Shell, SSH fonctionnera depuis Cloud Shell, mais votre navigateur (sur un
> réseau différent) sera bloqué par le NSG sur tous les services (dashboard
> excepté, volontairement public sur le port 80). Corrigez après coup avec :
> ```bash
> terraform apply -auto-approve -var="allowed_ssh_cidr=<VOTRE_IP_RÉELLE>/32"
> ```
> Trouvez votre IP réelle en ouvrant `https://ifconfig.me` **depuis votre
> propre navigateur** (pas depuis Cloud Shell). Comparez avec `terraform
> output allowed_ssh_cidr_effective` pour confirmer le décalage.

### 2. Cloner et configurer

```bash
git clone https://github.com/dspitech/azure-devops-vm-terraform.git
cd azure-devops-vm
nano terraform.tfvars                          # Éditez selon vos besoins (optionnel)
```

> **Choisir un profil** : `terraform.tfvars` déploie par défaut le profil
> `"fullstack"` (tous les outils). Pour un profil ciblé, utilisez directement
> un des fichiers de `examples/` - voir [Profils étudiants](#profils-étudiants-vm_profile) :
> `terraform apply -var-file="examples/dataops.tfvars"` (étape 3 ci-dessous).

### 3. Déployer

```bash
terraform init && terraform fmt && terraform validate && terraform plan && terraform apply -auto-approve
# Ou, pour un profil ciblé :
# terraform apply -auto-approve -var-file="examples/devops.tfvars"
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
download ./keys/devops-pro-vm_id_rsa  
```

**Étape 2 - Se connecter depuis votre machine locale** (adapter le chemin vers la clé) :

```bash
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

**Le plus simple : ouvrez le tableau de bord** - `terraform output dashboard_url`
(ou directement `http://<IP>/`). Il affiche le profil actif de la VM, un lien
« Ouvrir » + « Copier le lien » pour chaque service réellement installé, et
un indicateur d'état en direct (vert = joignable, rouge = injoignable),
vérifié depuis votre navigateur sans rien envoyer à un tiers.

Sinon, les services sont accessibles directement (remplacer `<IP>` par l'IP publique de la VM) :

| Service | URL | Credentials | Profil requis |
|---|---|---|---|
| JupyterLab | http://\<IP\>:8888 | Token généré par Terraform → `terraform output jupyter_token` (ou `jupyter_url` qui inclut déjà le token) | `dataops` / `fullstack` |
| Grafana | http://\<IP\>:3000 | `admin` / mot de passe généré → `terraform output grafana_admin_password` | tous |
| Prometheus | http://\<IP\>:9090 | - | tous |
| Portainer | https://\<IP\>:9443 | `admin` / mot de passe généré → `terraform output portainer_admin_password` (compte déjà initialisé, aucune action requise) | tous |
| Vault UI | http://\<IP\>:8200/ui | Root token dans `/root/.vault-init` sur la VM | `devops` / `fullstack` |

> **Sécurité** : tous ces ports sont restreints par défaut à l'IP publique détectée automatiquement au moment du `terraform apply` (`allowed_ssh_cidr = "auto"`), à l'exception du tableau de bord (port 80) qui est volontairement public - il n'affiche que des liens et un inventaire des logiciels installés (versions), aucun secret ni information sensible. Si votre IP change ensuite, mettez à jour `terraform.tfvars` avec la nouvelle IP (ou ré-appliquez pour redétecter) puis relancez `terraform apply`.

### Services en tunnel SSH uniquement (non exposés dans le NSG)

Certains services sont volontairement liés à `127.0.0.1` sur la VM et ne
sont **jamais** ouverts dans le NSG, le plus souvent parce qu'ils n'ont pas
d'authentification forte native (code-server) ou parce que ce sont des
cibles volontairement vulnérables (DVWA, Juice Shop, WebGoat). Le tableau
de bord web les liste avec une pastille « tunnel SSH » et une commande
prête à copier. Accès via un tunnel SSH local :

```bash
ssh -L 8443:localhost:8443 -i keys/devops-pro-vm_id_rsa devopsadmin@<IP>
# puis ouvrez http://127.0.0.1:8443 dans votre navigateur
```

| Service | Port (loopback) | Profil requis | Notes |
|---|---|---|---|
| code-server | 8443 | tous | VS Code web, mot de passe = `terraform output portainer_admin_password` |
| MinIO Console | 9001 | `dataops` / `fullstack` | `minioadmin` / mot de passe Portainer |
| Metabase | 3001 | `dataops` / `fullstack` | BI, configuration au premier accès |
| pgAdmin | 5050 | `dataops` / `fullstack` | `admin@devops-vm.local` / mot de passe Portainer |
| cAdvisor | 8085 | tous | Métriques conteneurs en temps réel |
| CyberChef | 8001 | `cybersecurity` / `fullstack` | Décodage/encodage/analyse de données |
| DVWA | 8081 | `cybersecurity` / `fullstack` | Cible d'entraînement - usage légal uniquement |
| OWASP Juice Shop | 8082 | `cybersecurity` / `fullstack` | Cible d'entraînement - usage légal uniquement |
| WebGoat | 8083 | `cybersecurity` / `fullstack` | Cible d'entraînement - usage légal uniquement |

Voir aussi `terraform output tunnel_only_services` pour la liste complète.

---

## Logiciels installés automatiquement

> La liste ci-dessous correspond au profil `fullstack` (tout installé). Avec
> un profil ciblé (`devops`/`dataops`/`cybersecurity`), seuls le socle commun
> et les outils de ce profil sont installés - voir le tableau de la section
> [Profils étudiants](#profils-étudiants-vm_profile).

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
| kustomize | Personnalisation de manifests Kubernetes sans templating |
| kubeconform | Validation de manifests Kubernetes contre les schémas officiels |
| popeye | Scanner de bonnes pratiques / ressources inutilisées sur un cluster |
| k3s | Cluster Kubernetes mono-nœud réel, **installé mais désactivé par défaut** (`sudo systemctl start k3s`) |
| dive | Inspection des layers d'une image Docker |
| ctop | `top` pour conteneurs Docker |

### Infrastructure as Code

| Outil | Description |
|---|---|
| Terraform + tflint | IaC HashiCorp + linter de bonnes pratiques |
| Terragrunt | Wrapper Terraform pour configurations DRY multi-environnements |
| Packer | Construction d'images machine reproductibles |
| Ansible + ansible-lint + molecule | Automatisation de configuration et tests de rôles |
| Vault | Gestion centralisée des secrets HashiCorp - http://\<IP\>:8200 |

### Sécurité IaC et code (DevSecOps)

| Outil | Description |
|---|---|
| Checkov | Analyse statique de sécurité pour Terraform/CloudFormation/K8s |
| tfsec | Scanner de sécurité spécifique Terraform |
| gitleaks | Détection de secrets commités dans un dépôt Git |
| semgrep | Analyse statique de code multi-langages (règles de sécurité) |
| conftest | Tests de policies (Open Policy Agent) sur fichiers de config |
| terraform-docs | Génération automatique de documentation Terraform |
| infracost | Estimation du coût cloud d'un plan Terraform |

### Cloud et CI/CD

| Outil | Description |
|---|---|
| Azure CLI | Gestion complète des ressources Azure depuis le terminal |
| AWS CLI | Gestion des ressources AWS (usage multi-cloud) |
| gcloud CLI | Gestion des ressources Google Cloud (usage multi-cloud) |
| GitHub CLI | Gestion des dépôts, PR et releases GitHub |
| ArgoCD CLI | GitOps et déploiements continus sur Kubernetes |
| act | Exécution de workflows GitHub Actions en local (Docker) |

### Monitoring et logs

| Outil | Accès | Description |
|---|---|---|
| Prometheus | http://\<IP\>:9090 | Collecte et stockage de métriques time-series |
| Grafana | http://\<IP\>:3000 (admin / mot de passe généré, cf. `terraform output grafana_admin_password`) | Dashboards de visualisation - préconfigurés avec Node Exporter |
| Node Exporter | Port 9100 (interne VNet) | Métriques système CPU, RAM, disque, réseau |
| cAdvisor | 127.0.0.1:8085 (tunnel SSH) | Métriques d'utilisation des conteneurs Docker |
| Loki + Promtail | 127.0.0.1:3100 (tunnel SSH, backend uniquement) | Agrégation des logs système (`/var/log/*log`), consultable depuis Grafana |

### Bases de données

Clients en ligne de commande : `postgresql-client`, `redis-tools`, `sqlite3`, `usql` (client universel multi-BDD).

Conteneurs Docker démarrés automatiquement avec données persistées dans `/data/docker-volumes/` :

| Service | Port (loopback) | Credentials | Image | Profil requis |
|---|---|---|---|---|
| PostgreSQL 16 | 127.0.0.1:5432 | postgres / postgres | postgres:16-alpine | tous |
| Redis 7 | 127.0.0.1:6379 | - | redis:7-alpine | tous |
| MinIO | 127.0.0.1:9000 (API) / :9001 (console, tunnel SSH) | minioadmin / mot de passe Portainer | minio/minio | `dataops` / `fullstack` |
| pgAdmin | 127.0.0.1:5050 (tunnel SSH) | admin@devops-vm.local / mot de passe Portainer | dpage/pgadmin4 | `dataops` / `fullstack` |
| Metabase | 127.0.0.1:3001 (tunnel SSH) | config au 1er accès | metabase/metabase | `dataops` / `fullstack` |
| Redpanda | 127.0.0.1:9092 | - | redpandadata/redpanda | `dataops` / `fullstack` |

> Les conteneurs écoutent sur `127.0.0.1` uniquement pour éviter toute exposition publique, même si le NSG Azure filtre déjà au niveau réseau. MySQL et MongoDB ne sont volontairement pas déployés dans cette version (retirés du script d'installation) ; ajoutez-les vous-même dans `cloud-init/install.sh` si vous en avez besoin.

### Python et DataOps

| Catégorie | Librairies |
|---|---|
| Data Science | pandas, polars, numpy, matplotlib, seaborn, plotly, DuckDB |
| Machine Learning | scikit-learn, xgboost, mlflow |
| Pipelines | dbt-core, PySpark, Dask, Prefect, Great Expectations |
| Versioning de données | DVC |
| Visualisation / apps | Streamlit |
| API | FastAPI, uvicorn, requests, httpx, aiohttp |
| Bases de données | SQLAlchemy, psycopg2, redis |
| Cloud | azure-storage-blob, azure-identity, boto3 |
| Qualité | black, flake8, mypy, isort, pylint, pytest, pre-commit |
| Notebooks | JupyterLab - http://\<IP\>:8888 (token requis, cf. `terraform output jupyter_token`) |

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
| subfinder / dnsx | Énumération de sous-domaines et résolution DNS (ProjectDiscovery) |
| httpx | Sondage HTTP/HTTPS en masse (ProjectDiscovery) |
| naabu | Scanner de ports rapide (ProjectDiscovery) |
| katana | Crawler web nouvelle génération (ProjectDiscovery) |
| feroxbuster | Brute-force de répertoires web, rapide et récursif |
| whatweb | Fingerprinting de technologies web |
| wpscan | Scanner de vulnérabilités WordPress |
| wfuzz | Fuzzing web générique |
| impacket / NetExec | Exploitation et énumération Active Directory / SMB |
| OWASP ZAP | Scanner de vulnérabilités applicatives web (image Docker) |
| CyberChef | Décodage/encodage/analyse de données - 127.0.0.1:8001 (tunnel SSH) |
| binwalk | Analyse et extraction de firmwares/images binaires |
| radare2 | Framework de reverse engineering |
| volatility3 | Analyse forensique de mémoire (RAM dumps) |

Répertoire de travail dédié : `/data/pentest/{recon,exploits,reports,loot}`

>  **Avertissement légal** : ces outils sont destinés à des environnements de test et d'apprentissage. Ne les utilisez jamais sur des systèmes sans autorisation explicite.

### Cibles d'entraînement (volontairement vulnérables)

Isolées sur `127.0.0.1`, jamais exposées via le NSG - accès uniquement par
tunnel SSH (voir [Services en tunnel SSH uniquement](#services-en-tunnel-ssh-uniquement-non-exposés-dans-le-nsg)).
Usage pédagogique/légal uniquement.

| Outil | Port (loopback) | Description |
|---|---|---|
| DVWA | 8081 | Application web volontairement vulnérable (classique, par niveau de difficulté) |
| OWASP Juice Shop | 8082 | Application e-commerce moderne volontairement vulnérable |
| WebGoat | 8083 | Plateforme d'entraînement OWASP, leçons guidées |

### Sécurité défensive (Blue Team)

| Outil | Description |
|---|---|
| Lynis | Audit de durcissement système (hardening) |
| ClamAV | Antivirus / scan de malwares |
| auditd | Journalisation des appels système sensibles |
| osquery | Interrogation de l'état du système via SQL |
| CrowdSec | Détection et bannissement collaboratif d'IP malveillantes |

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
- `fzf`, `bat`, `eza` (remplaçant de `exa`), `fd`, `ripgrep`, `btop`, `ncdu`, `direnv`, `tldr`
- `tmux`, `vim` (configuré avec numérotation et coloration), `htop`, `tree`, `jq`, `yq`
- Alias prédéfinis : `k` (kubectl), `d` (docker), `dc` (docker compose), `tf` (terraform), `tg` (terragrunt)
- **code-server** : VS Code dans le navigateur - 127.0.0.1:8443 (tunnel SSH)
- **lazygit** / **lazydocker** : interfaces terminal pour Git et Docker
- **restic** : sauvegarde de `/data` (installé, planification à configurer selon vos besoins)
- **unattended-upgrades** : mises à jour de sécurité système automatiques

---

## Sécurité et réseau

> L'accès SSH et les outils sensibles sont restreints **automatiquement** à
> l'IP publique du déployeur (`allowed_ssh_cidr = "auto"`, valeur par
> défaut) - aucune manipulation requise. Voir `terraform output
> allowed_ssh_cidr_effective` pour vérifier la valeur retenue.

Récapitulatif des règles NSG définies dans `network.tf` (le port ouvert
dépend parfois du profil `vm_profile` choisi) :

| Priorité | Port(s) | Service | Source autorisée | Profil requis |
|---|---|---|---|---|
| 100 | 22 | SSH | `allowed_ssh_cidr` (auto-détecté) | tous |
| 110 | 80 | HTTP - tableau de bord de statut | Tout (`*`) - volontairement public, ne montre que des liens | tous |
| 120 | 443 | HTTPS (réservé) | Tout (`*`) | tous |
| 130 | 8888 | JupyterLab | `allowed_ssh_cidr` | `dataops` / `fullstack` |
| 140 | 3000 | Grafana | `allowed_ssh_cidr` | tous |
| 150 | 9443 | Portainer | `allowed_ssh_cidr` | tous |
| 160 | 9090 | Prometheus | `allowed_ssh_cidr` | tous |
| 170 | 8200 | Vault | `allowed_ssh_cidr` | `devops` / `fullstack` |
| 180 | 9100 | Node Exporter | CIDR VNet interne uniquement | tous |
| 190 | 5432, 6379 | PostgreSQL, Redis | CIDR VNet interne uniquement | tous |
| 4096 | `*` | Deny all | - | - |

> Le pare-feu UFW dans la VM est aligné sur ces mêmes règles (défense en profondeur) et s'adapte lui aussi au profil actif.

> **Services ajoutés depuis la dernière mise à jour** (code-server, MinIO, Metabase, pgAdmin, cAdvisor, Loki, CyberChef, DVWA, Juice Shop, WebGoat...) : **aucun n'est ajouté au NSG**. Ils écoutent uniquement sur `127.0.0.1` à l'intérieur de la VM et ne sont accessibles que via un tunnel SSH - voir [Services en tunnel SSH uniquement](#services-en-tunnel-ssh-uniquement-non-exposés-dans-le-nsg). C'est volontaire, en particulier pour les cibles d'entraînement volontairement vulnérables.

**Autres protections en place** :

- **fail2ban** : bannissement automatique après 5 tentatives SSH infructueuses.
- **Identifiants générés** : Grafana, Jupyter et Portainer n'utilisent jamais de mot de passe par défaut - tous générés aléatoirement par Terraform (`random_password`), récupérables via `terraform output` (marqués `sensitive`). Ce même mot de passe (Portainer) est réutilisé pour code-server, MinIO et pgAdmin.
- **Clé SSH** : générée par Terraform (`tls_private_key`), jamais transmise en clair ; le dossier `keys/` est exclu de git par `.gitignore`.
- **Vault** : initialisé et scellé (unseal) automatiquement au premier démarrage ; root token dans `/root/.vault-init` (permissions 750).
- **Arrêt automatique quotidien** : la VM s'éteint automatiquement chaque jour (`auto_shutdown_time`, 19h par défaut) pour préserver le crédit Azure Students - désactivable via `auto_shutdown_enabled = false`. Voir `terraform output auto_shutdown_info`.
- **Mises à jour automatiques** : `unattended-upgrades` applique les correctifs de sécurité système sans intervention.

---

## Coût estimé (Azure Students - 100$/an de crédit)

| Ressource | Taille | Coût/mois* |
|---|---|---|
| VM Standard_B2ms | 2 vCPU / 8 GB RAM | ~30$ |
| Disque OS Premium SSD 64 GB | - | ~7$ |
| Disque Données Premium SSD 64 GB | - | ~7$ |
| IP Publique Standard | - | ~3$ |
| **Total** | | **~47$/mois** |

> Prix indicatifs région West Europe. **L'arrêt automatique quotidien est activé par défaut** (`auto_shutdown_enabled = true`, 19h) et réduit déjà fortement la facture ; vous pouvez aussi éteindre manuellement à tout moment : `az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm`

**Optimisation** : passer à `Standard_B1ms` (1 vCPU / 2 GB) réduit le coût à ~18$/mois si vous n'utilisez pas les outils gourmands en mémoire (PySpark, Metasploit). ⚠️ Le profil `fullstack` nécessite au moins `Standard_B2ms` (8 Go) - voir l'avertissement dans [Profils étudiants](#profils-étudiants-vm_profile).

---

## Script Cloud-Init - Installation automatique

**Fichier** : `cloud-init/install.sh`

**Rôle** : Script d'initialisation automatique exécuté au démarrage de la VM via `cloud-init` (user data Terraform). Il installe et configure tous les logiciels en 13 phases logiques (0 à 12, plus une phase 10b dédiée au pentest). Chaque outil est installé de façon indépendante : si l'un d'eux échoue (ex : indisponibilité temporaire d'une API tierce), les autres phases s'exécutent quand même et l'installation va jusqu'au bout.

###  Phases d'installation

| Phase | Durée | Description |
|---|---|---|
| **[0/12]** | ~3 min | Mise à jour système, dépendances de base |
| **[1/12]** | ~1 min | Détection et montage du disque de données (`/data`) |
| **[2/12]** | ~2 min | ZSH + Oh My Zsh + plugins + configuration `.zshrc` |
| **[3/12]** | ~3 min | Docker CE + daemon config + Portainer UI (9443, admin initialisé automatiquement) |
| **[3b/12]** | ~3 min | Socle commun étendu : code-server, lazygit, lazydocker, btop/ncdu/direnv, restic, unattended-upgrades |
| **[4/12]** | ~3 min | kubectl, Helm, k9s, kubectx, kind, kustomize, kubeconform, popeye, k3s (désactivé par défaut) |
| **[5/12]** | ~4 min | Terraform, Terragrunt, Packer, Ansible, tflint, Checkov, tfsec, gitleaks, semgrep, conftest, terraform-docs, infracost |
| **[6/12]** | ~4 min | Azure CLI, AWS CLI, gcloud, GitHub CLI, ArgoCD, act, Vault (8200), Skaffold, Stern, cosign, dive, ctop |
| **[7/12]** | ~3 min | Prometheus (9090), Grafana (3000, mot de passe généré), Node Exporter (9100), cAdvisor, Loki/Promtail |
| **[8/12]** | ~4 min | Python 3, Jupyter Lab (8888, token généré), libs data science/ML, DuckDB, Streamlit, DVC, Prefect, MinIO, Metabase, pgAdmin, Redpanda |
| **[9/12]** | ~2 min | Clients DB (`usql`) + conteneurs Docker : PostgreSQL, Redis |
| **[10/12]** | ~2 min | Outils réseau (masscan, tshark…), Trivy, Hadolint, UFW, fail2ban |
| **[10b/12]** | ~5 min | Pentest : Nuclei, ffuf, gobuster, Amass, theHarvester, suite ProjectDiscovery, feroxbuster, Metasploit, Hydra, sqlmap, John, impacket, NetExec, cibles d'entraînement (DVWA/Juice Shop/WebGoat), outils de défense (Lynis, ClamAV, osquery, CrowdSec) |
| **[11/12]** | ~2 min | Go, Node.js LTS, Rust, Java 21 |
| **[12/12]** | ~2 min | Nettoyage, permissions finales, tableau de bord de statut (nginx, port 80), messages de statut |

###  Sécurité du script

- **fail2ban** : Protection contre brute-force SSH activée
- **ufw** : Pare-feu applicatif configuré (aligné sur NSG Azure)
- **Vault** : Initialisé automatiquement, root token dans `/root/.vault-init` (750)
- **Docker** : groupe `docker` ajouté à `devopsadmin` (accès sans sudo)
- **Identifiants** : Grafana, Jupyter et Portainer utilisent tous des identifiants **générés aléatoirement par Terraform** (plus de mot de passe par défaut) - récupérables via `terraform output`. Vault utilise son root token généré à l'initialisation.

###  Exemple de trace d'exécution (profil `dataops`)

```log
==============================================================
  DevOps Pro VM - Installation démarrée
  Fri Sep 26 22:10:03 UTC 2026
==============================================================
   [0/12] Système mis à jour
   [1/12] Disque données configuré → /data
   [2/12] ZSH configuré
   [3/12] Docker + Portainer installés
   Compte admin Portainer initialisé (admin / mot de passe généré par Terraform)
  ⏭  Phase ignorée (profil "dataops" ne nécessite pas : Kubernetes (profil devops uniquement))
  ⏭  Phase ignorée (profil "dataops" ne nécessite pas : Infrastructure as Code (profil devops uniquement))
  ⏭  Phase ignorée (profil "dataops" ne nécessite pas : CI/CD Tools (profil devops uniquement))
   [7/12] Prometheus (9090) + Grafana (3000) + Node Exporter (9100) installés
   [8/12] Python DataOps stack installé
   [9/12] Clients DB + conteneurs Docker démarrés
   UFW configuré
   fail2ban configuré et démarré
  ⏭  Phase ignorée (profil "dataops" ne nécessite pas : Pentest offensif (profil cybersecurity uniquement))
   [11/12] Go / Node.js / Rust / Java installés
   Landing page de statut disponible sur http://<IP>/
  ✅ Installation complète terminée !
```

###  Personnalisation du script

Pour ajouter des outils supplémentaires, éditez `cloud-init/install.sh` :

```bash
# Exemple : installer un nouvel outil (jq, curl, etc.)
apt-get install -y -qq my-package

# Exemple : installer depuis pip
pip_install my-python-package

# Exemple : créer un répertoire de travail
mkdir -p /data/my-workspace
chown -R "$ADMIN_USER:$ADMIN_USER" /data/my-workspace
```

>  **Important** : testez le script localement avant de l'utiliser sur une VM de production :
> ```bash
> bash -x cloud-init/install.sh  # -x = debug mode
> ```

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

# Démarrer / vérifier Vault
sudo systemctl status vault
cat /root/.vault-init   # root token et unseal key (sudo requis)

# Lister les conteneurs Docker actifs
docker ps
lazydocker   # interface terminal interactive

# Vérifier les ports en écoute
ss -tulnp

# Activer k3s (désactivé par défaut pour ne pas doubler la RAM avec kind)
sudo systemctl start k3s
sudo k3s kubectl get nodes

# Accéder à un service en tunnel SSH (ex: code-server)
ssh -L 8443:localhost:8443 -i keys/devops-pro-vm_id_rsa devopsadmin@<IP>
# puis ouvrir http://127.0.0.1:8443

# Éteindre la VM depuis Azure (économise le crédit)
az vm deallocate -g rg-devops-pro-vm -n devops-pro-vm

# Redémarrer la VM
az vm start -g rg-devops-pro-vm -n devops-pro-vm
```

---

## Dépannage

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

# Vérifier votre IP actuelle (peut avoir changé depuis le déploiement)
curl ifconfig.me
# Comparer avec : terraform output allowed_ssh_cidr_effective
# Si différente → terraform apply à nouveau (allowed_ssh_cidr="auto" redétecte
# automatiquement), ou fixez une valeur explicite dans terraform.tfvars.
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
docker start postgres redis

# Voir les logs d'un conteneur
docker logs postgres --tail 50
```

### Un service tunnel SSH (code-server, MinIO, DVWA...) reste injoignable

```bash
# Ces services écoutent sur 127.0.0.1 à l'intérieur de la VM, pas sur l'IP
# publique : un tunnel SSH est obligatoire, le NSG ne les ouvre jamais.
ssh -L <port>:localhost:<port> -i keys/devops-pro-vm_id_rsa devopsadmin@<IP>
# puis ouvrir http://127.0.0.1:<port> dans VOTRE navigateur local

# Vérifier que le conteneur/service tourne bien côté VM
docker ps | grep <nom-service>
sudo systemctl status code-server
```

### `terraform apply` refuse le déploiement avec une erreur de précondition

```
Error: Resource precondition failed
Le profil "fullstack" installe simultanement tous les outils...
```

Le profil `fullstack` installe les 4 familles d'outils en même temps : une
VM `Standard_B2s`/`B1s` (moins de 8 Go de RAM) swappe ou tue des services
via l'OOM killer. Choisissez `Standard_B2ms` ou plus, ou déployez un profil
unique (`devops`/`dataops`/`cybersecurity`) qui installe moins d'outils.

### Erreur Terraform "subscription not found"

```bash
az account list --output table
az account set --subscription "Azure for Students"
terraform init -reconfigure
```

---

## Maintenance de la VM

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
TOOL_VER=$(gh_latest <org>/<repo>)
if [ -n "$TOOL_VER" ]; then
  curl -sLo /usr/local/bin/tool "https://.../$TOOL_VER/tool-linux-amd64" \
    && chmod +x /usr/local/bin/tool \
    && ok "Tool $TOOL_VER installé" || err "Tool non installé"
else
  err "Tool non installé (version introuvable)"
fi
```

Si l'outil ne concerne qu'un profil précis, encadrez le bloc avec `if
should_run "devops"; then ... else skip_msg "..."; fi` (voir les phases 4, 5,
6, 8, 10b et 11 du script pour des exemples). `gh_latest` gère déjà les
retries en cas de rate-limit de l'API GitHub - préférez-le à un appel `curl`
direct vers `api.github.com`.

N'oubliez pas de l'ajouter dans `devops-status`, dans le tableau de bord
(`SERVICES` dans la phase 12), et dans les tableaux du README.

---

## Auteur

**Pape Lo** - [pape.lo@estiam.com](mailto:pape.lo@estiam.com)

