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
