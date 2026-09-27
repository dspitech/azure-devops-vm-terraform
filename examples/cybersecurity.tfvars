# =============================================================
#  Profil CYBERSECURITY — Réseau, pentest offensif
#  Usage : terraform apply -var-file="examples/cybersecurity.tfvars"
#
#  ⚠️  N'utilisez les outils de pentest installés que sur des cibles que
#      vous êtes autorisé(e) à tester (labs dédiés, environnements de TP).
# =============================================================

resource_group_name = "rg-cybersecurity-student"
location             = "westeurope"

vm_name        = "vm-cybersecurity"
vm_size        = "Standard_B2ms"   # 2 vCPU / 8 GB RAM
admin_username = "devopsadmin"

vm_profile = "cybersecurity"

os_disk_size_gb   = 64
data_disk_size_gb = 64

vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"
vm_private_ip         = "10.0.1.10"
dns_servers           = ["8.8.8.8", "1.1.1.1"]

allowed_ssh_cidr = "auto"

tags = {
  Environment = "Student"
  Project     = "DevOps-Pro-VM"
  Profile     = "cybersecurity"
  ManagedBy   = "Terraform"
}
