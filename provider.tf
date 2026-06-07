# =============================================================
#  PROVIDER — AzureRM
#  Authentification via Azure CLI (az login)
#  ou variables d'environnement ARM_*
# =============================================================

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # ── Optionnel : renseigner ici ou via variables d'env ──────
  # subscription_id = var.subscription_id
  # tenant_id       = var.tenant_id
  # client_id       = var.client_id
  # client_secret   = var.client_secret
}

provider "random" {}
provider "tls" {}
