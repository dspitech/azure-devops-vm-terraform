# =============================================================
#  Profil DATAOPS — JupyterLab, Python data science / ML
#  Usage : terraform apply -var-file="examples/dataops.tfvars"
# =============================================================

resource_group_name = "rg-dataops-student"
location             = "westeurope"

vm_name        = "vm-dataops"
vm_size        = "Standard_B2ms"   # 2 vCPU / 8 GB RAM — augmentez si gros datasets
admin_username = "devopsadmin"

vm_profile = "dataops"

os_disk_size_gb   = 64
data_disk_size_gb = 128   # plus d'espace pour les datasets

vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"
vm_private_ip         = "10.0.1.10"
dns_servers           = ["8.8.8.8", "1.1.1.1"]

# allowed_ssh_cidr n'est PAS fixé ici volontairement : la valeur de
# terraform.tfvars (ou "auto" par defaut si absente) s'applique. Ne
# décommentez la ligne suivante que pour figer explicitement une IP
# différente rien que pour ce profil :
# allowed_ssh_cidr = "auto"

tags = {
  Environment = "Student"
  Project     = "DevOps-Pro-VM"
  Profile     = "dataops"
  ManagedBy   = "Terraform"
}
