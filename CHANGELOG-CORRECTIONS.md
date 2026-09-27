# Changelog des corrections — Automatisation à 100%

Ce fichier résume l'audit complet du projet et toutes les corrections
apportées. Vous pouvez le supprimer une fois pris connaissance de son contenu.

## 🔴 Bug critique — cause probable de l'échec d'automatisation

**Tous les fichiers du projet, y compris `cloud-init/install.sh`, étaient
encodés en fins de ligne Windows (CRLF).**

Cloud-init exécute `install.sh` en se basant sur son shebang. Avec des CRLF,
la première ligne du fichier est en réalité `#!/bin/bash\r` (un `\r` invisible
en fin de ligne). Le noyau Linux interprète ce `\r` comme faisant partie du
chemin de l'interpréteur et échoue avec une erreur du type :

```
/bin/bash^M: bad interpreter: No such file or directory
```

**Conséquence : le script d'installation ne s'exécutait jamais sur la VM.**
Aucun des ~40 outils n'était installé, quel que soit le contenu du script.

→ **Corrigé** : tous les fichiers ont été reconvertis en LF (Unix).

---

## Corrections Terraform

| # | Fichier | Problème | Correction |
|---|---|---|---|
| 1 | `terraform.tfvars` | `allowed_ssh_cidr = "*"` figé en dur → SSH, Jupyter, Grafana, Vault, Portainer ouverts à tout Internet | `allowed_ssh_cidr = "auto"` : détection automatique de l'IP publique du déployeur au moment du `terraform apply`, sans étape manuelle |
| 2 | `main.tf` / `variables.tf` | Idem — le défaut de la variable était aussi `"*"` | Nouveau défaut `"auto"` + `data "http" "my_ip"` + `local.effective_ssh_cidr`, avec validation de format |
| 3 | `main.tf` | Grafana en `admin/admin`, Jupyter sans token, Portainer à initialiser manuellement au 1er accès (fenêtre de 5 min) | `random_password` générés pour les 3 services, injectés dans la VM, initialisation automatique de Portainer via son API, exposés via `terraform output` (sensibles) |
| 4 | `main.tf` | `ADMIN_USER="devopsadmin"` codé en dur dans `install.sh`, complètement déconnecté de `var.admin_username` : changer la variable ne changeait rien sur la VM | Injection via un en-tête cloud-init généré par Terraform (`export ADMIN_USER="${var.admin_username}"`, etc.) |
| 5 | `main.tf` | Disque de données détecté via `/dev/sdc` supposé — fragile si la génération de VM ou le nombre de disques change | Détection par LUN Azure (lien udev stable `/dev/disk/azure/scsi1/lunN`), avec repli heuristique (recherche du disque non partitionné, hors disque OS) |
| 6 | `main.tf` | Provider `local` (utilisé par `local_file`/`local_sensitive_file`) non déclaré dans `required_providers` | Ajouté, avec version pinnée |
| 7 | `main.tf` | `disable_password_authentication` non explicite | Ajouté explicitement (`true`) |
| 8 | `outputs.tf` | `output "jupyter_url"` défini **deux fois** (Terraform aurait refusé d'appliquer) | Doublon supprimé, nouveaux outputs ajoutés : `grafana_admin_password`, `jupyter_token`, `portainer_admin_password`, `allowed_ssh_cidr_effective` |
| 9 | `network.tf` | Règle NSG ouvrant MySQL (3306) et MongoDB (27017) alors que ces conteneurs ont été retirés du script d'installation | Règle réduite à 5432 (Postgres) et 6379 (Redis) uniquement |
| 10 | *(racine)* | Pas de `.gitignore` : le dossier `keys/` contenant la **clé privée SSH générée** pouvait être commité par erreur dans git | `.gitignore` ajouté (exclut `keys/*`, `.terraform/`, `*.tfstate*`, etc.) |

---

## Corrections dans `cloud-init/install.sh`

| # | Problème | Correction |
|---|---|---|
| 11 | `set -euo pipefail` strict, alors que les propres messages du script disaient "(non bloquant)" : une seule commande en échec (ex. rate-limit de l'API GitHub, très probable avec ~15 appels non authentifiés par déploiement) tuait tout le script à mi-chemin | Remplacé par `set -uo pipefail` + `trap` de log, cohérent avec l'intention initiale : le script va désormais **jusqu'au bout** même si un outil individuel échoue |
| 12 | Appels bruts à `https://api.github.com/.../releases/latest` sans retry ni garde : en cas de rate-limit, `jq` renvoie `null` et le script tentait de télécharger une URL invalide | Nouvelle fonction `gh_latest()` avec 3 tentatives + backoff, et chaque site d'appel (k9s, kind, terragrunt, argocd, stern, cosign, node_exporter, hadolint, nuclei, ffuf, gobuster, amass, usql) gardé par `if [ -n "$VER" ]; then ... else err "..."; fi` |
| 13 | Portainer nécessitait une configuration manuelle du compte admin à la première connexion (fenêtre de 5 minutes) | Initialisation automatique via `POST /api/users/admin/init` avec le mot de passe généré par Terraform |
| 14 | Grafana démarré avec `admin/admin` | Mot de passe injecté via `GF_SECURITY_ADMIN_PASSWORD` (généré par Terraform) |
| 15 | JupyterLab démarré sans authentification (`token = ''`, `password = ''`), accessible par quiconque atteint le port 8888 | Token généré par Terraform injecté dans `jupyter_lab_config.py` |
| 16 | Détection du disque de données limitée à `/dev/sdc`, avec seulement 6 tentatives de 5s | Détection par LUN (voir plus haut), 12 tentatives, repli heuristique |
| 17 | MOTD annonçait `admin/admin` pour Grafana et ne mentionnait aucune protection Jupyter | Mis à jour pour pointer vers les commandes `terraform output` correspondantes |

---

## Corrections dans `README.md`

Le README documentait plusieurs éléments qui ne correspondaient plus (ou
jamais) au contenu réel de `install.sh` :

- Références à **Apache Airflow** (port 8080, commandes `systemctl start
  airflow-webserver`) : Airflow n'est **jamais installé** par le script.
  Toutes les mentions ont été retirées.
- Références à **MySQL** et **MongoDB** dans le tableau des bases de données,
  les librairies Python (`pymysql`, `pymongo`) et les commandes de dépannage
  (`docker start ... mysql ... mongo`) : ces conteneurs ont été retirés du
  script (commentaire explicite dans `install.sh` : *"MongoDB, MySQL et
  Airflow supprimés"*) mais le README ne le reflétait pas. Corrigé.
- Table des 12 phases d'installation qui ne correspondait plus à l'ordre
  réel des phases dans le script (ordre corrigé : disque → zsh → Docker →
  Kubernetes → IaC → CI/CD → monitoring → DataOps → bases de données → réseau
  → pentest → langages → finalisation).
- Toutes les mentions d'identifiants statiques (`admin/admin`, "aucun token")
  remplacées par des renvois vers les commandes `terraform output`
  correspondantes.
- Extrait de code `variables.tf` reproduit dans le README (à but illustratif)
  mis à jour pour refléter le nouveau `allowed_ssh_cidr = "auto"`.

---

## Ce qui n'a *pas* été changé (et pourquoi)

- **Version du provider `azurerm` (`~> 3.90`)** : une montée vers la branche
  4.x introduirait des changements de comportement non triviaux (bloc
  `features`, enregistrement des resource providers, etc.) qu'il n'était pas
  possible de tester ici faute d'accès à l'API Azure et au registre
  Terraform depuis cet environnement. Rester en 3.x fonctionne, mais c'est un
  point à réévaluer si vous voulez rester aligné avec les dernières
  fonctionnalités du provider.
- **Automatisation complète d'Airflow/MySQL/MongoDB** : plutôt que de
  réinstaller ces services (risque d'introduire de nouveaux bugs non
  testés), j'ai choisi d'aligner la documentation sur le comportement réel et
  volontaire du script (ces services ont été retirés par un commit
  précédent). Si vous voulez les réintégrer, dites-le moi et je les ajoute
  proprement (conteneurs Docker + règles NSG + entrées README).
- **Aucun accès à un environnement Azure ou à `terraform validate`/`plan`**
  dans ce sandbox (réseau restreint aux registres de paquets). La validation
  a été faite par :
  - analyse manuelle ligne à ligne,
  - parsing HCL de chaque fichier `.tf` (`python-hcl2`),
  - `bash -n` (vérification syntaxique) et `shellcheck -S error` sur
    `install.sh` (aucune erreur).
  Un `terraform validate` et un test réel sur une VM Azure restent
  recommandés avant mise en production.

---

## Ajout ultérieur — Profils étudiants (`vm_profile`)

Suite à la demande de fournir des VMs préconfigurées selon le profil de
l'étudiant, une nouvelle variable `vm_profile` a été ajoutée
(`"devops"` | `"dataops"` | `"cybersecurity"` | `"fullstack"`, défaut
`"fullstack"` pour rester rétro-compatible avec le comportement d'origine).

- **`cloud-init/install.sh`** : chaque phase non essentielle est encapsulée
  dans `if should_run "<profil>"; then ... fi`. Le socle commun (mise à jour
  système, disque de données, ZSH, Docker + Portainer, monitoring
  Prometheus/Grafana, PostgreSQL/Redis, UFW + fail2ban, finalisation)
  s'exécute toujours ; le reste dépend du profil. Le MOTD et `devops-status`
  affichent désormais le profil actif et n'annoncent que les services
  réellement démarrés.
- **`network.tf`** : les règles NSG pour Jupyter (8888) et Vault (8200)
  utilisent désormais un `dynamic "security_rule"` conditionné par le profil
  — ces ports ne sont ouverts que si le service correspondant est installé.
- **`variables.tf` / `main.tf`** : nouvelle variable `vm_profile` (avec
  validation), propagée à la VM via l'en-tête cloud-init, comme
  `admin_username` et les mots de passe générés.
- **`examples/*.tfvars`** : un fichier `.tfvars` prêt à l'emploi par profil,
  pour déployer directement avec `terraform apply -var-file="examples/dataops.tfvars"`
  sans avoir à éditer `terraform.tfvars`.

Validation effectuée : `bash -n` + `shellcheck -S error` sur le script
(aucune erreur), parsing HCL de tous les `.tf` et `.tfvars` (aucune erreur).
Comme précédemment, aucun déploiement réel sur Azure n'a pu être testé dans
cet environnement — un premier `terraform apply` par profil reste la
meilleure validation finale.

---

## Ajout ultérieur — Tableau de bord de statut par VM

Une landing page de statut est maintenant générée automatiquement à la fin
de l'installation (phase 12), servie par **nginx** sur le port 80 (déjà
ouvert publiquement par le NSG existant — aucun changement réseau requis).

- Affiche le **profil actif** de la VM (`vm_profile`).
- N'affiche que les services **réellement installés** pour ce profil (mêmes
  conditions `should_run()` que le reste du script).
- Pour chaque service : un bouton "Ouvrir" (nouvel onglet), un bouton
  "Copier le lien", et un **indicateur d'état en direct** (vert/rouge),
  vérifié depuis le navigateur du visiteur via `fetch(..., {mode:"no-cors"})`
  — aucune donnée n'est envoyée à un serveur tiers, tout se passe côté client.
- Page 100% autonome (HTML/CSS/JS inline, sans dépendance externe), donc
  fonctionne même sans accès Internet depuis le poste du visiteur.
- Nouvel output Terraform : `terraform output dashboard_url`.

**Limitation connue** : Portainer utilise un certificat TLS auto-signé sur
le port 9443. Tant que le navigateur n'a pas accepté ce certificat une
première fois (en ouvrant le lien directement), l'indicateur d'état de
Portainer sur le tableau de bord peut apparaître rouge même si le service
tourne correctement — c'est un comportement standard des navigateurs face à
un certificat auto-signé, pas un bug du tableau de bord.

Validation effectuée : le bloc HTML/CSS/JS généré a été extrait du script et
testé isolément (`node --check` sur le JavaScript, parsing HTML) après
simulation de la substitution des variables de profil — aucune erreur.
Comme pour le reste du projet, un test visuel dans un vrai navigateur après
déploiement Azure reste la meilleure validation finale.

---

## Ajout ultérieur — Retours d'un premier déploiement réel

Un premier déploiement réel (profil `fullstack`) a permis d'identifier trois
problèmes que la validation statique ne pouvait pas détecter :

1. **Aucun lien du dashboard ne fonctionnait.** Cause : `terraform apply` avait
   été lancé depuis Azure Cloud Shell, dont l'IP de sortie diffère de celle du
   navigateur de l'utilisateur. `allowed_ssh_cidr = "auto"` avait donc
   autorisé l'IP de Cloud Shell (ce qui explique que le SSH depuis Cloud Shell
   fonctionnait), mais bloqué le navigateur de l'utilisateur sur tous les
   ports sauf le 80 (dashboard, volontairement public) — d'où tous les points
   rouges. **Ce n'est pas un bug du code, mais une limite inhérente à la
   détection automatique d'IP** : elle capture l'IP de la machine qui exécute
   `terraform apply`, pas celle du poste qui naviguera ensuite vers la VM.
   Remède : `terraform apply -var="allowed_ssh_cidr=<IP réelle>/32"` depuis
   n'importe quel terminal pour corriger le NSG sans tout redéployer. Un
   avertissement plus visible sur ce point serait une amélioration future
   possible (ex: détecter si l'environnement est Cloud Shell et prévenir).

2. **Metasploit ne s'installait pas (`403 Forbidden` sur `apt.metasploit.com`).**
   Le dépôt apt officiel de Rapid7 pour Metasploit est devenu indisponible.
   → Remplacé par l'installeur "omnibus" officiel de Rapid7
   (`msfupdate.erb`), qui ne dépend pas de ce dépôt.

3. **Node.js installé en version 12 (Ubuntu) au lieu de la LTS actuelle.**
   Le script exécutait le script d'installation NodeSource sans vérifier
   s'il avait réussi ; en cas d'échec silencieux, `apt-get install -y
   nodejs` retombait sur le paquet `nodejs` obsolète des dépôts Ubuntu
   (12.22.9) sans qu'aucune erreur ne soit visible. → Le script vérifie
   désormais la version installée après coup et refait une tentative
   NodeSource si elle est inférieure à 18.

4. **`devops-status` affichait `kubectl: N/A` alors que kubectl était bien
   installé**, à cause du flag `--short` de `kubectl version`, supprimé dans
   kubectl ≥ 1.28. De même, `Ansible: 2.17.14]` affichait un crochet
   parasite car `ansible --version | awk '{print $3}'` capturait le `]` de
   sortie `ansible [core 2.17.14]`. Les deux lignes ont été corrigées pour
   extraire proprement le numéro de version avec une regex, quel que soit le
   format de sortie de l'outil.

Un script `fix-existing-vm.sh` a été fourni séparément pour corriger une VM
déjà déployée sans avoir à la recréer.
