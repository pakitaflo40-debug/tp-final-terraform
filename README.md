# TP Final Terraform : Mini-projet complet

Mini-projet Terraform sur AWS qui met en pratique quatre notions : un **backend distant S3 avec verrouillage DynamoDB**, un **module EC2 réutilisable**, le déploiement de **deux environnements (dev / prod) avec `for_each`** et la protection de la ressource critique avec **`prevent_destroy`**.

## Objectifs du TP

| # | Exigence | Mise en œuvre |
|---|----------|---------------|
| 1 | Configurer un backend S3 avec verrouillage DynamoDB | `bootstrap/` crée le bucket et la table, `envs/backend.tf` les utilise |
| 2 | Réutiliser le module EC2 | `modules/ec2` et `modules/ec2_protected` |
| 3 | Déployer deux environnements avec `for_each` (dev / prod) | `envs/main.tf` |
| 4 | Protéger la ressource critique avec `prevent_destroy` | `modules/ec2_protected/main.tf` (instance de prod) |

## Architecture

```
tp-final/
├── bootstrap/                 # Crée le backend (bucket S3 + table DynamoDB)
│   └── main.tf
├── modules/
│   ├── ec2/                   # Module EC2 simple (utilisé pour dev)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2_protected/         # Module EC2 avec prevent_destroy (utilisé pour prod)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── envs/                      # Déploiement des environnements dev et prod
│   ├── backend.tf             # Configuration du backend S3 + DynamoDB
│   ├── main.tf                # Provider, for_each, appels de modules
│   ├── variables.tf
│   └── outputs.tf
└── .gitignore
```

## Prérequis

- Un compte AWS (région utilisée : `eu-north-1`)
- [Terraform](https://developer.hashicorp.com/terraform/install) installé
- AWS CLI configuré (`aws configure`) avec des identifiants autorisés à créer des ressources EC2, S3 et DynamoDB
- Git

Vérification rapide :

```bash
terraform version
aws sts get-caller-identity
```

## Explication de chaque exigence

### 1. Backend S3 avec verrouillage DynamoDB

Terraform garde la trace de l'infrastructure dans un fichier **state**. Stocké localement, il peut être perdu et ne peut pas être partagé. Le backend distant règle ces deux problèmes :

- **S3** stocke le state de façon centralisée, avec le **versioning** activé pour pouvoir revenir en arrière ;
- **DynamoDB** gère le **verrouillage** : une table avec la clé `LockID` empêche deux `apply` simultanés de corrompre le state.

Le backend ne peut pas être créé par le code qui l'utilise (le bucket doit exister avant que Terraform y écrive son state). Le projet procède donc en deux temps :

1. `bootstrap/` crée le bucket et la table avec un **state local** ;
2. `envs/` déclare ensuite le backend dans `backend.tf`.

### 2. Module EC2 réutilisable

Un module est un dossier de code Terraform appelé comme une fonction. Il évite de dupliquer le bloc `aws_instance` pour chaque environnement.

- `variables.tf` : entrées (`name`, `instance_type`, `ami_id`)
- `main.tf` : la ressource `aws_instance`
- `outputs.tf` : sorties (`instance_id`, `public_ip`)

Deux variantes existent :

| Module | Protection | Usage |
|--------|-----------|-------|
| `modules/ec2` | aucune | environnement **dev** |
| `modules/ec2_protected` | `prevent_destroy = true` | environnement **prod** |

### 3. Deux environnements avec `for_each`

Une seule map décrit les environnements dans `envs/main.tf` :

```hcl
locals {
  environments = {
    dev  = { instance_type = "t3.micro", protected = false }
    prod = { instance_type = "t3.micro", protected = true }
  }
}
```

Chaque module reçoit uniquement les environnements qui le concernent grâce à un filtre :

```hcl
module "ec2_dev" {
  source   = "../modules/ec2"
  for_each = { for k, v in local.environments : k => v if !v.protected }
  ...
}

module "ec2_prod" {
  source   = "../modules/ec2_protected"
  for_each = { for k, v in local.environments : k => v if v.protected }
  ...
}
```

**Pourquoi `for_each` plutôt que `count` ?** Les éléments sont repérés par leur nom (`["dev"]`, `["prod"]`) et non par un numéro. Supprimer un environnement n'affecte donc pas les autres. Ajouter un environnement se résume à une ligne dans la map.

**Pourquoi deux modules ?** `prevent_destroy` ne peut pas dépendre d'une variable. Pour ne protéger que la prod, il faut une version protégée et une version non protégée du module.

Des blocs `moved` conservent les instances déjà créées lors du passage à `for_each`, sans destruction ni recréation :

```hcl
moved {
  from = module.ec2_dev
  to   = module.ec2_dev["dev"]
}
```

### 4. Protection avec `prevent_destroy`

Dans `modules/ec2_protected/main.tf` :

```hcl
lifecycle {
  prevent_destroy = true
}
```

Toute tentative de suppression de l'instance de prod (`terraform destroy`, ou un changement qui forcerait son remplacement) est **refusée avant toute modification**.

## Utilisation

### Étape 1 : créer le backend

```bash
cd bootstrap
terraform init
terraform apply
```

Le nom du bucket S3 doit être **unique dans le monde entier** et identique dans `bootstrap/main.tf` et `envs/backend.tf`.

### Étape 2 : déployer les environnements

```bash
cd ../envs
terraform init      # configure le backend S3
terraform validate
terraform plan
terraform apply
```

### Étape 3 : vérifier

```bash
terraform state list
```

Résultat attendu :

```
module.ec2_dev["dev"].aws_instance.this
module.ec2_prod["prod"].aws_instance.this
```

Les indices entre crochets prouvent l'utilisation de `for_each`.

### Étape 4 : tester `prevent_destroy`

```bash
terraform destroy
```

Résultat attendu :

```
Error: Instance cannot be destroyed
Resource module.ec2_prod["prod"].aws_instance.this has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed.
```

Rien n'est supprimé : Terraform refuse le plan entier.

## Résultats

- Le state est stocké dans le bucket S3 (clé `tpfinal/terraform.tfstate`) et verrouillé par la table DynamoDB `tfstate-lock`.
- Deux instances EC2 `t3.micro` sont déployées : `app-dev` et `app-prod`.
- L'instance de prod ne peut pas être détruite accidentellement.

## Nettoyage des ressources

À faire dans cet ordre, pour éviter les frais AWS et un dépassement du Free Tier.

**1. Détruire dev (non protégé)**

```bash
cd envs
terraform destroy -target='module.ec2_dev["dev"]'
```

**2. Détruire prod**

Désactivez temporairement la protection (`prevent_destroy = false` dans `modules/ec2_protected/main.tf`), puis :

```bash
terraform destroy
```

Ne commitez pas cette modification.

**3. Détruire le backend, en dernier**

Videz d'abord le bucket S3 (anciennes versions comprises) depuis la console AWS, puis :

```bash
cd ../bootstrap
terraform destroy
```

Le backend se détruit en dernier car il contient le state utilisé par `envs/`.

## Bonnes pratiques appliquées

- Le **state** et le dossier `.terraform/` ne sont **jamais versionnés** (voir `.gitignore`).
- Le fichier `.terraform.lock.hcl` **est versionné** pour fixer les versions des providers.
- Le state distant est **chiffré** (`encrypt = true`) et le bucket a le **versioning** activé.
- Le code est **factorisé** en modules (principe DRY).
- Les ressources critiques sont **protégées** contre la suppression accidentelle.

## Environnement de travail

- Windows avec WSL (Ubuntu) et VS Code
- Terraform, AWS CLI, Git
- Région AWS : `eu-north-1`
- Type d'instance : `t3.micro` (éligible au Free Tier dans cette région)

## Auteur

TP réalisé dans le cadre d'une formation DevOps par Floréal TCHOUMBOU
