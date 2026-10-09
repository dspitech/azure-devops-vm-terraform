# =============================================================
#  NETWORK — VNet / Subnet / NSG
#  Ports ouverts (restreints à l'IP auto-détectée du déployeur) :
#    22 (SSH), 8888 (Jupyter), 3000 (Grafana), 9443 (Portainer),
#    9090 (Prometheus), 8200 (Vault)
#  Ports des outils (même restriction d'IP) : voir local.tool_ports_* dans
#    main.tf — code-server 8443, cAdvisor 8085, MinIO 9000/9001, Metabase 3001,
#    pgAdmin 5050, Streamlit 8501, MLflow 5000, Prefect 4200, Dask 8787,
#    CyberChef 8001, DVWA 8081, Juice Shop 8082, WebGoat 8083, WebWolf 9091
#  Ports ouverts à tout Internet : 80, 443
#  Ports internes VNet uniquement : 9100 (Node Exporter), 5432 (Postgres), 6379 (Redis)
# =============================================================

# ─── Virtual Network ─────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vm_name}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.vnet_address_space]
  dns_servers         = var.dns_servers
  tags                = var.tags
}

# ─── Subnet ──────────────────────────────────────────────────
resource "azurerm_subnet" "subnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

# ─── Network Security Group ───────────────────────────────────
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags

  # ── SSH ──────────────────────────────────────────────────
  # Restreint à local.effective_ssh_cidr : IP publique détectée
  # automatiquement (var.allowed_ssh_cidr = "auto", défaut), ou la
  # valeur explicite fournie par l'utilisateur.
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.effective_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── HTTP ─────────────────────────────────────────────────
  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── HTTPS ────────────────────────────────────────────────
  security_rule {
    name                       = "allow-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── JupyterLab ───────────────────────────────────────────
  # Jamais exposé publiquement — restreint à allowed_ssh_cidr
  # Créée uniquement si le profil installe JupyterLab (dataops/fullstack)
  dynamic "security_rule" {
    for_each = local.profile_dataops ? [1] : []
    content {
      name                       = "allow-jupyter"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8888"
      source_address_prefix      = local.effective_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # ── Grafana ──────────────────────────────────────────────
  security_rule {
    name                       = "allow-grafana"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = local.effective_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Portainer (Docker UI — HTTPS) ────────────────────────
  security_rule {
    name                       = "allow-portainer"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9443"
    source_address_prefix      = local.effective_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Prometheus ───────────────────────────────────────────
  security_rule {
    name                       = "allow-prometheus"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = local.effective_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Vault (HashiCorp) — API + UI sur le même port ────────
  # Créée uniquement si le profil installe Vault (devops/fullstack)
  dynamic "security_rule" {
    for_each = local.profile_devops ? [1] : []
    content {
      name                       = "allow-vault"
      priority                   = 170
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8200"
      source_address_prefix      = local.effective_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # ── Outils web : socle commun (code-server, cAdvisor) ─────
  # Restreint à allowed_ssh_cidr. Les ports sont ouverts même pour les outils
  # non démarrés par défaut : il suffit de les lancer sur la VM.
  security_rule {
    name                       = "allow-tools-common"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = local.tool_ports_common
    source_address_prefix      = local.effective_ssh_cidr
    destination_address_prefix = "*"
  }

  # ── Outils data (profils dataops / fullstack) ─────────────
  # MinIO (API 9000 + console 9001), Metabase, pgAdmin, et les outils à
  # lancer manuellement : Streamlit, MLflow, Prefect, Dask.
  dynamic "security_rule" {
    for_each = local.profile_dataops ? [1] : []
    content {
      name                       = "allow-tools-dataops"
      priority                   = 220
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = local.tool_ports_dataops
      source_address_prefix      = local.effective_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # ── Outils cybersécurité (profils cybersecurity / fullstack) ──
  # CyberChef + cibles d'entraînement volontairement vulnérables (DVWA,
  # Juice Shop, WebGoat/WebWolf). ⚠ Ne JAMAIS mettre allowed_ssh_cidr = "*"
  # avec ce profil : ces applications seraient exposées à tout Internet.
  dynamic "security_rule" {
    for_each = local.profile_cybersecurity ? [1] : []
    content {
      name                       = "allow-tools-cyber"
      priority                   = 230
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = local.tool_ports_cyber
      source_address_prefix      = local.effective_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # ── Ports supplémentaires choisis par l'utilisateur ───────
  # var.extra_open_ports : pour tout autre outil que vous lancez sur la VM.
  # Pensez aussi à `sudo ufw allow <port>/tcp` côté VM.
  dynamic "security_rule" {
    for_each = length(var.extra_open_ports) > 0 ? [1] : []
    content {
      name                       = "allow-tools-extra"
      priority                   = 240
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = var.extra_open_ports
      source_address_prefix      = local.effective_ssh_cidr
      destination_address_prefix = "*"
    }
  }

  # ── Node Exporter — interne VNet uniquement ───────────────
  # Prometheus scrape depuis la même VM (localhost) ou VNet
  # Ne jamais exposer les métriques système publiquement
  security_rule {
    name                       = "allow-node-exporter"
    priority                   = 180
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = var.vnet_address_space
    destination_address_prefix = "*"
  }

  # ── Bases de données — VNet interne uniquement ────────────
  # PostgreSQL (5432), Redis (6379) — seuls conteneurs réellement
  # déployés par cloud-init/install.sh (MySQL/MongoDB ont été retirés).
  # Les conteneurs écoutent déjà sur 127.0.0.1 : cette règle NSG
  # n'ajoute qu'une couche de défense en profondeur supplémentaire.
  # Ajoutez ici 3306/27017 si vous réactivez MySQL/MongoDB dans install.sh.
  security_rule {
    name                       = "allow-db-internal"
    priority                   = 190
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5432", "6379"]
    source_address_prefix      = var.vnet_address_space
    destination_address_prefix = "*"
  }

  # ── Airflow Webserver — optionnel, restreint ──────────────
  # Décommenter pour exposer l'UI Airflow (port 8080)
  # security_rule {
  #   name                       = "allow-airflow"
  #   priority                   = 200
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "8080"
  #   source_address_prefix      = local.effective_ssh_cidr
  #   destination_address_prefix = "*"
  # }

  # ── Deny all other inbound ───────────────────────────────
  # Règle de refus explicite — bonne pratique même si Azure
  # refuse par défaut, pour la lisibilité et l'audit
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ─── Association NSG → Subnet ────────────────────────────────
# Toutes les VM du subnet héritent des règles NSG
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
