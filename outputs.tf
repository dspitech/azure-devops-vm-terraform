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
  description = "Mot de passe admin Portainer, initialisé automatiquement (utilisateur: admin). Réutilisé comme mot de passe pour code-server, MinIO (minioadmin) et pgAdmin (admin@devops-vm.local)."
  value       = random_password.portainer.result
  sensitive   = true
}

output "auto_shutdown_info" {
  description = "Rappel de l'heure d'arrêt automatique quotidien de la VM (protège le crédit Azure Students)"
  value       = var.auto_shutdown_enabled ? "VM arrêtée automatiquement chaque jour à ${var.auto_shutdown_time} (${var.auto_shutdown_timezone})" : "Arrêt automatique désactivé (auto_shutdown_enabled = false)"
}

output "tunnel_only_services" {
  description = "Services volontairement liés à 127.0.0.1 (non exposés par le NSG) : accès via tunnel SSH, ex. `ssh -L 8443:localhost:8443 -i keys/<vm>_id_rsa <user>@<ip>`"
  value = join(", ", [
    "code-server:8443", "MinIO console:9001", "Metabase:3001", "pgAdmin:5050",
    "Redpanda:9092", "cAdvisor:8085", "Loki:3100", "CyberChef:8001",
    "DVWA:8081 (cybersecurity/fullstack)", "Juice Shop:8082 (cybersecurity/fullstack)", "WebGoat:8083 (cybersecurity/fullstack)"
  ])
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
