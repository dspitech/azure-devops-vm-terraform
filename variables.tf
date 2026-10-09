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

variable "vm_profile" {
  description = <<EOT
Profil de la VM — détermine quels outils cloud-init installe, adapté au
parcours de l'étudiant. Le socle commun (Docker, monitoring, sécurité de
base, PostgreSQL/Redis) est toujours installé quel que soit le profil.
  - "devops"        : Kubernetes, Terraform/Ansible/Packer, CI/CD (ArgoCD,
                       Vault, Skaffold...), scan sécurité conteneurs (Trivy,
                       Hadolint), langages (Go/Node/Rust/Java)
  - "dataops"        : JupyterLab, stack Python data science/ML, langages
  - "cybersecurity"  : outils réseau, pentest offensif (Nuclei, Metasploit,
                       ffuf, gobuster, Amass, theHarvester, sqlmap...)
  - "fullstack" (défaut) : tout ce qui précède réuni (comportement historique)
EOT
  type    = string
  default = "fullstack"

  validation {
    condition     = contains(["devops", "dataops", "cybersecurity", "fullstack"], var.vm_profile)
    error_message = "vm_profile doit être l'un de : \"devops\", \"dataops\", \"cybersecurity\", \"fullstack\"."
  }
}

variable "auto_shutdown_enabled" {
  description = "Active l'arret automatique quotidien de la VM (recommande sur un abonnement Azure Students pour preserver le credit)."
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Heure d'arret automatique quotidien, format HHmm (ex: \"1900\")."
  type        = string
  default     = "1900"
}

variable "auto_shutdown_timezone" {
  description = "Fuseau horaire de l'heure d'arret automatique."
  type        = string
  default     = "Romance Standard Time" # Europe (Paris/Oslo...) ; voir `az account list-locations` ou la doc Azure pour la liste.
}

variable "allowed_ssh_cidr" {
  description = <<EOT
CIDR autorisé pour SSH et les outils sensibles (Jupyter, Grafana, Portainer,
Prometheus, Vault).
  - "auto" (défaut) : Terraform détecte automatiquement l'IP publique de la
    machine qui exécute `terraform apply` et restreint l'accès à cette IP/32.
    Aucune étape manuelle requise.
  - une IP/CIDR explicite, ex: "90.12.34.56/32"
  - "*" pour ouvrir à tout Internet (déconseillé, uniquement pour du dépannage)
EOT
  type    = string
  default = "auto"

  validation {
    condition     = var.allowed_ssh_cidr == "auto" || var.allowed_ssh_cidr == "*" || can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr doit être \"auto\", \"*\", ou un CIDR valide (ex: \"90.12.34.56/32\")."
  }
}

variable "extra_open_ports" {
  description = <<EOT
Ports TCP supplémentaires à ouvrir dans le NSG (restreints à allowed_ssh_cidr),
pour d'autres outils que vous lancez vous-même sur la VM. Exemple : ["8000", "8080"].
Les ports des outils fournis (Streamlit, MLflow, MinIO, DVWA...) sont déjà ouverts
automatiquement selon le profil. Pensez à `sudo ufw allow <port>/tcp` sur la VM.
EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.extra_open_ports : can(regex("^[0-9]{1,5}$", p)) ? (tonumber(p) >= 1 && tonumber(p) <= 65535) : false])
    error_message = "extra_open_ports doit contenir des numéros de port valides (1-65535), sous forme de chaînes. Exemple : [\"8000\", \"8080\"]."
  }
}
