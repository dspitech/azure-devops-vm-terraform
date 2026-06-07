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
Par défaut ouvert — RESTREINDRE à votre IP en production :
  ex: "90.12.34.56/32"
EOT
  type    = string
  default = "*"
}
