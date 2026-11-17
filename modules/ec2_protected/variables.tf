variable "name" {
  type        = string
  description = "Nom de l'instance (tag Name)"
}

variable "instance_type" {
  type        = string
  description = "Type d'instance EC2"
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI utilisée"
}
