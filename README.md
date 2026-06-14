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

[Objectif](#objectif) • [Architecture](#architecture-terraform) • [Déploiement](#déploiement-en-5-étapes) • [Services](#accéder-aux-services) • [Logiciels](#logiciels-installés) • [Sécurité](#sécurité-et-nsg) • [Coût](#coût-estimé-azure-students--100an-de-crédit)

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

## Architecture Terraform

Cette section explique chaque fichier Terraform et son rôle dans l'infrastructure.

###  provider.tf - Configuration des providers

**Rôle** : Configure les providers (AzureRM, Random, TLS) et leurs versions minimales.

```hcl
# =============================================================
#  PROVIDER — AzureRM
#  Authentification via Azure CLI (az login)
#  ou variables d'environnement ARM_*
# =============================================================

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # ── Optionnel : renseigner ici ou via variables d'env ──────
  # subscription_id = var.subscription_id
  # tenant_id       = var.tenant_id
  # client_id       = var.client_id
  # client_secret   = var.client_secret
}

provider "random" {}
provider "tls" {}
```

**Explications clés** :
- `azurerm` : provider officiel HashiCorp pour Azure
- `features` : configure les comportements de suppression (utile pour les environnements dev)
- `random` : génère des suffixes uniques pour éviter les conflits de noms globaux
- `tls` : génère les clés SSH RSA 4096 bits pour l'accès à la VM

---

###  variables.tf - Définition des paramètres

**Rôle** : Déclare toutes les variables Terraform utilisées dans le projet.

```hcl
# =============================================================
#  VARIABLES
# =============================================================

# ─── General ─────────────────────────────────────────────────
variable "resource_group_name" {
  description = "Nom du Resource Group Azure"
  type        = string
  default     = "rg-devops-vm"
}

variable "location" {
  description = "Région Azure (students → westeurope recommandé)"
  type        = string
  default     = "norwayeast"
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources"
  type        = map(string)
  default = {
    Environment = "Dev"
    Project     = "DevOps-Pro-VM"
    Owner       = "Student"
    ManagedBy   = "Terraform"
  }
}

# ─── VM ──────────────────────────────────────────────────────
variable "vm_name" {
  description = "Nom de la VM"
  type        = string
  default     = "devops-pro-vm"
}

variable "vm_size" {
  description = <<EOT
Taille de la VM Azure.
Recommandé pour Azure Students :
  - Standard_B2s   → 2 vCPU / 4 GB  (économique)
  - Standard_B2ms  → 2 vCPU / 8 GB  (confortable)
  - Standard_B4ms  → 4 vCPU / 16 GB (pro)
EOT
  type    = string
  default = "Standard_B2ms"
}

variable "admin_username" {
  description = "Nom d'utilisateur administrateur"
  type        = string
  default     = "devopsadmin"
}

variable "os_disk_size_gb" {
  description = "Taille du disque OS en GB"
  type        = number
  default     = 64
}

variable "data_disk_size_gb" {
  description = "Taille du disque de données en GB (projets, datasets)"
  type        = number
  default     = 64
}

variable "vm_private_ip" {
  description = "IP privée statique de la VM"
  type        = string
  default     = "10.0.1.10"
}

# ─── Network ─────────────────────────────────────────────────
variable "vnet_address_space" {
  description = "Espace d'adressage du VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Préfixe du sous-réseau"
  type        = string
  default     = "10.0.1.0/24"
}

variable "dns_servers" {
  description = "Serveurs DNS du VNet"
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

variable "allowed_ssh_cidr" {
  description = <<EOT
CIDR autorisé pour SSH et outils (Jupyter, Grafana…).
Par défaut ouvert - RESTREINDRE à votre IP en production :
  ex: "90.12.34.56/32"
EOT
  type    = string
  default = "*"
}
```

**Explications clés** :
- Toutes les variables ont des valeurs par défaut sensées
- `tags` appliqués à TOUTES les ressources (traçabilité Azure)
- `vm_size` : B2ms = 2 vCPU / 8 GB RAM (bon compromis coût/performance)
- `allowed_ssh_cidr` : **TRÈS IMPORTANT** — restreignez votre IP en production

---

###  main.tf - Ressources centrales (VM, stockage, clés SSH)

**Rôle** : Crée la machine virtuelle, les disques, les clés SSH, les IPs publiques et le groupe de ressources.

```hcl
# =============================================================
#  AZURE DEVOPS / DATAOPS / NETWORK ADMIN PRO VM
#  Ubuntu 22.04 LTS - Azure Students Subscription
# =============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ─── Resource Group ──────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ─── Random suffix (unique names) ────────────────────────────
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ─── SSH Key pair (generated by Terraform) ───────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/keys/${var.vm_name}_id_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh.public_key_openssh
  filename = "${path.module}/keys/${var.vm_name}_id_rsa.pub"
}

# ─── Storage Account (boot diagnostics) ──────────────────────
resource "azurerm_storage_account" "diag" {
  name                     = "diag${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# ─── Public IP ───────────────────────────────────────────────
resource "azurerm_public_ip" "pip" {
  name                = "${var.vm_name}-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.vm_name}-${random_string.suffix.result}"
  tags                = var.tags
}

# ─── Network Interface ────────────────────────────────────────
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_private_ip
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
  tags = var.tags
}

# ─── Associate NIC → NSG ─────────────────────────────────────
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ─── Virtual Machine ─────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size

  admin_username = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.nic.id]

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diag.primary_blob_endpoint
  }

  custom_data = base64encode(file("${path.module}/cloud-init/install.sh"))

  tags = var.tags
}

# ─── Data Disk ───────────────────────────────────────────────
resource "azurerm_managed_disk" "data_disk" {
  name                = "${var.vm_name}-data-disk"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_data" {
  virtual_machine_id    = azurerm_linux_virtual_machine.vm.id
  managed_disk_id       = azurerm_managed_disk.data_disk.id
  lun                   = 0
  caching               = "ReadWrite"
}
```

**Explications clés** :
- `azurerm_resource_group` : conteneur logique pour tous les services
- `tls_private_key` : génère une clé SSH RSA 4096 bits (idéal pour production)
- `azurerm_public_ip` : IP statique (ne change pas au reboot, importante pour les DNS)
- `azurerm_linux_virtual_machine` : Ubuntu 22.04 avec clé SSH uniquement (pas de mot de passe)
- `custom_data` : exécute automatiquement `install.sh` (cloud-init)
- `azurerm_managed_disk` : disque de données Premium SSD (montable sur `/data`)

---

###  network.tf - Réseau virtuel, sous-réseau, NSG (pare-feu)

**Rôle** : Configure le réseau Azure (VNet, Subnet, NSG avec règles pare-feu).

```hcl
# =============================================================
#  NETWORK — VNet / Subnet / NSG
#  Ports ouverts : 22, 80, 443, 8888, 3000, 9090, 9443, 8200
#  Ports internes VNet uniquement : 9100, 5432, 3306, 6379, 27017
# =============================================================

# ─── Virtual Network ─────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vm_name}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.vnet_address_space]
  dns_servers         = var.dns_servers
  tags                = var.tags
}

# ─── Subnet ──────────────────────────────────────────────────
resource "azurerm_subnet" "subnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

# ─── Network Security Group ───────────────────────────────────
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags

  # ── SSH ──────────────────────────────────────────────────
  # Restreint à votre IP uniquement (var.allowed_ssh_cidr)
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── HTTP ─────────────────────────────────────────────────
  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── HTTPS ────────────────────────────────────────────────
  security_rule {
    name                       = "allow-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── JupyterLab ───────────────────────────────────────────
  security_rule {
    name                       = "allow-jupyter"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8888"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Grafana ──────────────────────────────────────────────
  security_rule {
    name                       = "allow-grafana"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Portainer (Docker UI) ───────────────────────────────
  security_rule {
    name                       = "allow-portainer"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9443"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Prometheus ───────────────────────────────────────────
  security_rule {
    name                       = "allow-prometheus"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Vault ────────────────────────────────────────────────
  security_rule {
    name                       = "allow-vault"
    priority                   = 170
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Deny ALL (dernière priorité) ─────────────────────────
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```

**Explications clés** :
- `azurerm_virtual_network` : crée l'espace d'adressage Azure (10.0.0.0/16)
- `azurerm_subnet` : sous-réseau pour les VMs (10.0.1.0/24)
- `azurerm_network_security_group` : pare-feu virtuel avec règles stateless
- Priorités : 100 = SSH, 110 = HTTP, 120 = HTTPS, 130 = JupyterLab, etc.
- **Clé** : SSH restreint à `allowed_ssh_cidr`, tous les outils sensibles aussi restreints
- Priorité 4096 (Deny All) : défense en profondeur (explicite deny)

---

###  outputs.tf - Valeurs de sortie (IPs, URLs, commandes SSH)

**Rôle** : Affiche les informations essentielles après `terraform apply` (IPs, URLs des services, commandes de connexion).

```hcl
# =============================================================
#  OUTPUTS
# =============================================================

output "vm_public_ip" {
  description = "Adresse IP publique de la VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_fqdn" {
  description = "FQDN (DNS) de la VM"
  value       = azurerm_public_ip.pip.fqdn
}

output "vm_private_ip" {
  description = "Adresse IP privée de la VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "ssh_command" {
  description = "Commande SSH prête à l'emploi"
  value       = "ssh -i keys/${var.vm_name}_id_rsa ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "ssh_key_path" {
  description = "Chemin vers la clé SSH privée"
  value       = "${path.module}/keys/${var.vm_name}_id_rsa"
  sensitive   = true
}

output "jupyter_url" {
  description = "URL Jupyter Lab (après démarrage)"
  value       = "http://${azurerm_public_ip.pip.ip_address}:8888"
}

output "grafana_url" {
  description = "URL Grafana (admin/admin)"
  value       = "http://${azurerm_public_ip.pip.ip_address}:3000"
}

output "portainer_url" {
  description = "URL Portainer (Docker UI)"
  value       = "https://${azurerm_public_ip.pip.ip_address}:9443"
}

output "resource_group_name" {
  description = "Nom du Resource Group"
  value       = azurerm_resource_group.rg.name
}
```

**Explications clés** :
- `terraform output` récupère ces valeurs après `terraform apply`
- `ssh_command` : commande SSH complète à copier-coller
- `sensitive = true` sur la clé SSH (masquée dans les logs)
- Tous les URLs incluent l'IP publique (dynamique)

---

## Déploiement en 5 étapes

### 1. Connexion Azure

Lancer le cloud Shell depuis le portal Azure et choisir PowerSehll.

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

## Script Cloud-Init — Installation automatique

**Fichier** : `cloud-init/install.sh`

**Rôle** : Script d'initialisation automatique exécuté au démarrage de la VM via `cloud-init` (user data Terraform). Il installe et configure tous les logiciels en 12 phases logiques.

###  Phases d'installation

| Phase | Durée | Description |
|---|---|---|
| **[0/12]** | ~3 min | Mise à jour système, dépendances base, `eza`, `yq` |
| **[1/12]** | ~2 min | Montage et formatage du disque de données (`/data`) |
| **[2/12]** | ~2 min | ZSH + Oh My Zsh + plugins + configuration `.zshrc` |
| **[3/12]** | ~3 min | Docker CE + daemon config + Portainer UI (9443) |
| **[4/12]** | ~2 min | kubectl, Helm, k9s, kubectx, kind |
| **[5/12]** | ~3 min | Terraform, Terragrunt, Packer, Ansible, tflint |
| **[6/12]** | ~3 min | Azure CLI, GitHub CLI, ArgoCD, act, Vault (8200), Skaffold, Stern, cosign |
| **[7/12]** | ~2 min | Prometheus (9090), Grafana (3000), Node Exporter (9100) |
| **[8/12]** | ~3 min | Python 3, Jupyter Lab (8888), libs data science/ML |
| **[9/12]** | ~2 min | Bases de données Docker : PostgreSQL, MySQL, Redis, MongoDB |
| **[10/12]** | ~2 min | Go, Node.js LTS, Rust, Java 21 |
| **[11/12]** | ~2 min | Pentest tools : Nuclei, ffuf, gobuster, Amass, theHarvester, Metasploit, Hydra, sqlmap, John, etc. |
| **[12/12]** | ~2 min | Nettoyage, permissions finales, messages de statut |

###  Sécurité du script

- **fail2ban** : Protection contre brute-force SSH activée
- **ufw** : Pare-feu applicatif configuré (aligné sur NSG Azure)
- **Vault** : Initialisé automatiquement, root token dans `/root/.vault-init` (750)
- **Docker** : groupe `docker` ajouté à `devopsadmin` (accès sans sudo)
- **Mots de passe par défaut** : Grafana (admin/admin), Vault (root token), tous changeable

###  Exemple de trace d'exécution

```log
==============================================================
  DevOps Pro VM — Installation démarrée
  Fri Dec 13 10:15:23 UTC 2024
==============================================================
   [0/12] Système mis à jour
   eza installé
   yq installé
   [0/12] Système mis à jour
   [1/12] Disque /dev/sdc monté sur /data
   [1/12] Disque données configuré → /data
   [2/12] ZSH configuré
   [3/12] Docker + Portainer installés
   Portainer démarré sur :9443
   ✓ kubectl 1.29.0 installé
   ✓ Helm 3.13.2 installé
   ✓ Terraform 1.7.0 installé
   ... (suite)
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
