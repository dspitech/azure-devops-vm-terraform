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

output "admin_username" {
  description = "Nom d'utilisateur SSH / système sur la VM"
  value       = var.admin_username
}

output "ssh_key_path" {
  description = "Chemin vers la clé SSH privée"
  value       = "${path.module}/keys/${var.vm_name}_id_rsa"
  sensitive   = true
}

output "grafana_url" {
  description = "URL Grafana"
  value       = "http://${azurerm_public_ip.pip.ip_address}:3000"
}

output "grafana_admin_password" {
  description = "Mot de passe admin Grafana (généré automatiquement)"
  value       = random_password.grafana.result
  sensitive   = true
}

output "jupyter_url" {
  description = "URL Jupyter Lab, avec le token d'accès déjà inclus"
  value       = "http://${azurerm_public_ip.pip.ip_address}:8888/lab?token=${random_password.jupyter_token.result}"
  sensitive   = true
}

output "jupyter_token" {
  description = "Token d'accès JupyterLab (généré automatiquement)"
  value       = random_password.jupyter_token.result
  sensitive   = true
}

output "portainer_url" {
  description = "URL Portainer (Docker UI)"
  value       = "https://${azurerm_public_ip.pip.ip_address}:9443"
}

output "portainer_admin_password" {
  description = "Mot de passe admin Portainer, initialisé automatiquement (utilisateur: admin)"
  value       = random_password.portainer.result
  sensitive   = true
}

output "allowed_ssh_cidr_effective" {
  description = "CIDR effectivement autorisé pour SSH/outils (IP auto-détectée ou fournie)"
  value       = local.effective_ssh_cidr
}

output "dashboard_url" {
  description = "Landing page de statut : profil actif + liens vers les services installés"
  value       = "http://${azurerm_public_ip.pip.ip_address}/"
}

output "resource_group_name" {
  description = "Nom du Resource Group"
  value       = azurerm_resource_group.rg.name
}
