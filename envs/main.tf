provider "aws" {
  region = "eu-north-1"
}

locals {
  environments = {
    dev = {
      instance_type = "t3.micro"
      protected     = false
    }
    prod = {
      instance_type = "t3.micro"
      protected     = true
    }
  }

  ami_id = "ami-0a664360bb4a53714"
}

# Environnements non protégés (dev)
module "ec2_dev" {
  source   = "../modules/ec2"
  for_each = { for k, v in local.environments : k => v if !v.protected }

  name          = "app-${each.key}"
  instance_type = each.value.instance_type
  ami_id        = local.ami_id
}

# Environnements protégés (prod)
module "ec2_prod" {
  source   = "../modules/ec2_protected"
  for_each = { for k, v in local.environments : k => v if v.protected }

  name          = "app-${each.key}"
  instance_type = each.value.instance_type
  ami_id        = local.ami_id
}

# Conserve les instances déjà créées (évite de les détruire/recréer)
moved {
  from = module.ec2_dev
  to   = module.ec2_dev["dev"]
}

moved {
  from = module.ec2_prod
  to   = module.ec2_prod["prod"]
}
