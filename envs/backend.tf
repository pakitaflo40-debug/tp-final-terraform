terraform {
  backend "s3" {
    bucket         = "tfstate-tpfinal-floreal-2026"
    key            = "tpfinal/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "tfstate-lock"
    encrypt        = true
  }
}
