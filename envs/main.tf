provider "aws" {
  region = "eu-north-1"
}

module "ec2_dev" {
  source        = "../modules/ec2"
  ami_id        = "ami-0a664360bb4a53714"
  instance_type = "t3.micro"
  name          = "app-dev"
}

module "ec2_prod" {
  source        = "../modules/ec2_protected"
  ami_id        = "ami-0a664360bb4a53714"
  instance_type = "t3.micro"
  name          = "app-prod"
}
