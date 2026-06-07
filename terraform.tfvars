# =============================================================
#  terraform.tfvars  — Personnalisez ces valeurs
# =============================================================

resource_group_name = "rg-devops-pro-vm"
location            = "norwayeast"

vm_name        = "devops-pro-vm"
vm_size        = "Standard_B2ms"   # 2 vCPU / 8 GB RAM
admin_username = "devopsadmin"

os_disk_size_gb   = 64
data_disk_size_gb = 64

vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"
vm_private_ip         = "10.0.1.10"
dns_servers           = ["8.8.8.8", "1.1.1.1"]

# ⚠️  IMPORTANT : remplacez "*" par votre IP publique pour sécuriser SSH
# Trouvez votre IP : https://ifconfig.me
allowed_ssh_cidr = "*"

tags = {
  Environment = "Dev"
  Project     = "DevOps-Pro-VM"
  Owner       = "Student"
  ManagedBy   = "Terraform"
}
