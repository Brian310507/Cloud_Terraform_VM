# TP Noté — Déployer 2 VMs avec Load Balancer sur Azure via Terraform

**Étudiant** : Alexandre ROQUES  
**Date** : 23 février 2026  
**Module** : Cloud & Infrastructure as Code  

---

## Sommaire

1. [Prérequis et mise en place](#1-prérequis-et-mise-en-place)
2. [Structure du projet](#2-structure-du-projet)
3. [Difficultés rencontrées](#3-difficultés-rencontrées)
4. [Résultats et preuves de déploiement](#4-résultats-et-preuves-de-déploiement)
5. [Nettoyage de l'infrastructure](#5-nettoyage-de-linfrastructure)
6. [Conclusion](#6-conclusion)

---

## 1. Prérequis et mise en place

### Outils installés

- **Terraform** >= 1.5.0 — installé via `winget install HashiCorp.Terraform`
- **Azure CLI** — utilisé pour l'authentification avec `az login`

### Authentification Azure

Connexion effectuée via la commande suivante, qui ouvre une fenêtre de navigateur pour s'authentifier avec le compte Microsoft étudiant :

```bash
az login
az account show  # Pour récupérer le subscription_id
```

---

## 2. Structure du projet

Le projet a été organisé selon les conventions Terraform, avec une séparation claire des responsabilités :

```
tp-terraform-azure/
├── versions.tf    # Version Terraform >= 1.5.0 et provider azurerm ~> 4.0
├── provider.tf    # Configuration du provider Azure
├── variables.tf   # Variables : location et prefix
├── main.tf        # Toutes les ressources Azure
└── outputs.tf     # IP publique du LB, ID du RG, nom du VNET, ID du Subnet
```

### Ressources déployées (16 au total)

| Ressource | Nom | Rôle |
|---|---|---|
| `azurerm_resource_group` | tp-azure-rg | Conteneur de toutes les ressources |
| `azurerm_virtual_network` | tp-azure-vnet | Réseau virtuel (10.0.0.0/16) |
| `azurerm_subnet` | tp-azure-subnet | Sous-réseau (10.0.1.0/24) |
| `azurerm_network_security_group` | tp-azure-nsg | Firewall (SSH:22, HTTP:80, Deny all) |
| `azurerm_network_interface` x2 | tp-azure-nic-1/2 | Interfaces réseau des VMs |
| `azurerm_linux_virtual_machine` x2 | tp-azure-vm-1/2 | VMs Ubuntu 22.04 avec Nginx |
| `azurerm_public_ip` | tp-azure-lb-pip | IP publique statique du Load Balancer |
| `azurerm_lb` | tp-azure-lb | Load Balancer Standard |
| `azurerm_lb_backend_address_pool` | tp-azure-backend-pool | Pool des VMs backend |
| `azurerm_lb_probe` | tp-azure-http-probe | Sonde de santé HTTP sur port 80 |
| `azurerm_lb_rule` | tp-azure-http-rule | Règle de distribution du trafic port 80 |

---

## 3. Difficultés rencontrées

### 3.1 — Terraform non reconnu dans PowerShell

**Problème** : Après téléchargement, la commande `terraform` n'était pas reconnue dans PowerShell.

```
Le terme «terraform» n'est pas reconnu comme nom d'applet de commande...
```

**Solution** : Installation via winget et redémarrage du terminal pour que le PATH soit mis à jour :

```powershell
winget install HashiCorp.Terraform
# Fermer et réouvrir PowerShell
terraform version
```

---

### 3.2 — Erreur de syntaxe dans main.tf (doublon)

**Problème** : Lors du `terraform init`, une erreur de syntaxe a été détectée à la ligne 115 de `main.tf` :

```
Error: Missing newline after argument
  on main.tf line 115:
  115: public_key = public_key = file("C:/Users/Alexandre ROQUES/.ssh/id_rsa.pub")
```

**Cause** : Le mot-clé `public_key =` avait été écrit deux fois par erreur.

**Solution** : Correction de la ligne en supprimant le doublon :

```hcl
# Avant (incorrect)
public_key = public_key = file("C:/Users/Alexandre ROQUES/.ssh/id_rsa.pub")

# Après (correct)
public_key = file("C:/Users/Alexandre ROQUES/.ssh/id_rsa.pub")
```

---

### 3.3 — Resource Group déjà existant dans Azure

**Problème** : Lors du premier `terraform apply`, le resource group `tp-azure-rg` existait déjà dans Azure suite à un test précédent, et n'était pas dans le state Terraform :

```
Error: a resource with the ID "...resourceGroups/tp-azure-rg" already exists
- to be managed via Terraform this resource needs to be imported into the State.
```

**Solution** : Import de la ressource existante dans le state Terraform :

```bash
terraform import azurerm_resource_group.rg \
  /subscriptions/4ca697b4-c330-47fc-8e23-2286c67e2153/resourceGroups/tp-azure-rg
```

---

### 3.4 — Région France Central non autorisée (Erreur 403)

**Problème** : La région `France Central` configurée par défaut était bloquée par la politique de l'abonnement Azure for Students :

```
Error: creating Virtual Network "tp-azure-vnet": 403 Forbidden
RequestDisallowedByAzure: Resource was disallowed by Azure:
This policy maintains a set of best available regions...
```

**Solution** : Changement de la région dans `variables.tf` pour utiliser `West Europe`, autorisée sur les abonnements étudiants :

```hcl
variable "location" {
  description = "Région Azure"
  default     = "West Europe"   # Remplace "France Central"
}
```

Suivi d'un `terraform destroy` puis d'un nouveau `terraform apply` pour recréer toutes les ressources dans la bonne région.

---

### 3.5 — Le Load Balancer ne distribue pas le trafic en alternance stricte

**Problème** : Lors des tests avec `curl` ou `Invoke-WebRequest`, toutes les requêtes aboutissaient systématiquement sur la même VM (VM-1 ou VM-2), sans alternance visible.

**Explication** : Le Load Balancer Azure utilise par défaut une affinité de session basée sur un hash 5-tuple (IP source, port source, IP destination, port destination, protocole). Depuis le même poste et la même session, les requêtes sont toujours routées vers le même backend.

**Validation** : En relançant la commande depuis une nouvelle session PowerShell, la VM cible a changé (VM-2 au lieu de VM-1), confirmant que les deux VMs sont bien actives et enregistrées dans le backend pool.

---

## 4. Résultats et preuves de déploiement

### 4.1 — Terraform Plan

Exécution de `terraform plan` confirmant les 16 ressources à créer, sans erreur de configuration.

> 📸 *[Capture d'écran : sortie complète du terraform plan]*

---

### 4.2 — Terraform Apply

Déploiement complet réussi des 16 ressources en une seule exécution.

> 📸 *[Capture d'écran : terraform apply — Apply complete! Resources: 16 added, 0 changed, 0 destroyed]*

Outputs affichés après le déploiement :

```
load_balancer_public_ip = "20.203.143.16"
resource_group_id       = "/subscriptions/.../resourceGroups/tp-azure-rg"
subnet_id               = "/subscriptions/.../tp-azure-subnet"
vnet_name               = "tp-azure-vnet"
```

---

### 4.3 — Accès au serveur web via le Load Balancer

Test d'accès HTTP via l'IP publique du Load Balancer `20.203.143.16`.

**VM-1 répond :**

```
curl http://20.203.143.16
→ <h1>Hello from VM-1</h1>  (HTTP 200 OK)
```

**VM-2 répond :**

```
curl http://20.203.143.16
→ <h1>Hello from VM-2</h1>  (HTTP 200 OK)
```

> 📸 *[Capture d'écran : réponse VM-1 via curl]*  
> 📸 *[Capture d'écran : réponse VM-2 via navigateur]*

Les deux VMs sont bien actives et accessibles derrière le Load Balancer.

---

### 4.4 — Erreur d'accès serveur (difficulté documentée)

Lors des premières tentatives de test, l'accès HTTP retournait une erreur de connexion. Cela était dû au délai d'initialisation des VMs : le script `custom_data` (installation de Nginx) s'exécute au premier démarrage et nécessite 2 à 3 minutes avant d'être opérationnel.

> 📸 *[Capture d'écran : erreur d'accès serveur lors du premier test]*

**Solution** : Attendre quelques minutes après le `terraform apply` avant de tester l'accès HTTP.

---

## 5. Nettoyage de l'infrastructure

Suppression de toutes les ressources déployées via :

```bash
terraform destroy
```

> 📸 *[Capture d'écran : terraform destroy — Destroy complete!]*

La destruction a bien supprimé les 16 ressources créées, évitant toute consommation inutile du crédit Azure étudiant.

---

## 6. Conclusion

Ce TP a permis de déployer une infrastructure Azure complète via Terraform, comprenant deux VMs Ubuntu avec Nginx, un réseau sécurisé (VNET, Subnet, NSG) et un Load Balancer public distribant le trafic HTTP.

Les principales compétences mises en pratique :

- Structuration d'un projet Terraform selon les conventions (fichiers séparés)
- Authentification auprès d'Azure via l'Azure CLI
- Déclaration de ressources Azure interdépendantes en HCL
- Débogage d'erreurs Terraform (syntaxe, state, région, permissions)
- Utilisation du cycle de vie complet : `init` → `plan` → `apply` → `destroy`

Les difficultés rencontrées (région bloquée, resource group existant, affinité de session du Load Balancer) ont été l'occasion de comprendre en profondeur le fonctionnement de Terraform et d'Azure.
