# =============================================================
#  get-credentials.ps1 — Récapitulatif des identifiants de connexion
#  À lancer depuis le dossier du projet, APRES un `terraform apply` réussi.
#  Usage : .\get-credentials.ps1
# =============================================================

terraform output ssh_command *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur : aucun state Terraform trouvé ici (ou déploiement pas encore terminé)."
    Write-Host "Lance ce script depuis le dossier du projet, après 'terraform apply'."
    exit 1
}

function Get-Out($name) {
    terraform output -raw $name 2>$null
}

Write-Host "======================================================="
Write-Host "  Identifiants de connexion - DevOps VM"
Write-Host "======================================================="

Write-Host ""
Write-Host "--- SSH ---------------------------------------------"
Write-Host "Commande    : $(Get-Out ssh_command)"
Write-Host "Utilisateur : $(Get-Out admin_username)"

Write-Host ""
Write-Host "--- Tableau de bord de statut ------------------------"
Write-Host "Lien        : $(Get-Out dashboard_url)"
Write-Host "(public, aucune authentification requise)"

Write-Host ""
Write-Host "--- Grafana -------------------------------------------"
Write-Host "Lien        : $(Get-Out grafana_url)"
Write-Host "Utilisateur : admin"
Write-Host "Mot de passe: $(Get-Out grafana_admin_password)"

Write-Host ""
Write-Host "--- JupyterLab ----------------------------------------"
Write-Host "Lien        : $(Get-Out jupyter_url)"
Write-Host "(token deja inclus dans le lien ci-dessus)"
Write-Host "Token       : $(Get-Out jupyter_token)"

Write-Host ""
Write-Host "--- Portainer -----------------------------------------"
Write-Host "Lien        : $(Get-Out portainer_url)"
Write-Host "Utilisateur : admin"
Write-Host "Mot de passe: $(Get-Out portainer_admin_password)"

Write-Host ""
Write-Host "--- Securite --------------------------------------------"
Write-Host "IP autorisee (SSH / outils) : $(Get-Out allowed_ssh_cidr_effective)"

Write-Host ""
Write-Host "======================================================="
Write-Host "Attention : ce recapitulatif contient des secrets : ne le partagez pas,"
Write-Host "            ne le committez pas dans git."
