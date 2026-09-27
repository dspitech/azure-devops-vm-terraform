# =============================================================
#  terraform.tfvars  — Personnalisez ces valeurs
# =============================================================

resource_group_name = "rg-devops-pro-vm"
location            = "norwayeast"

vm_name        = "devops-pro-vm"
vm_size        = "Standard_B2ms"   # 2 vCPU / 8 GB RAM
admin_username = "devopsadmin"

# Profil de la VM — adapte les outils installés au parcours de l'étudiant.
# Valeurs possibles : "devops" | "dataops" | "cybersecurity" | "fullstack"
# Le socle commun (Docker, monitoring, sécurité de base, Postgres/Redis)
# est toujours installé, quel que soit le profil choisi.
vm_profile = "fullstack"

os_disk_size_gb   = 64
data_disk_size_gb = 64

vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"
vm_private_ip         = "10.0.1.10"
dns_servers           = ["8.8.8.8", "1.1.1.1"]

# CIDR autorisé pour SSH et les outils sensibles (Jupyter, Grafana, Portainer, Vault).
# "auto" = détection automatique de l'IP publique du déployeur au moment du
# `terraform apply` (recommandé, aucune action requise).
# Remplacez par une IP/CIDR explicite (ex: "90.12.34.56/32") si vous préférez
# la figer, ou par "*" pour ouvrir à tout Internet (déconseillé).
allowed_ssh_cidr = "203.0.113.45/32"

tags = {
  Environment = "Dev"
  Project     = "DevOps-Pro-VM"
  Owner       = "Student"
  ManagedBy   = "Terraform"
}
