variable "environments" {
  type = map(object({
    instance_type   = string
    ami             = string
    prevent_destroy = bool
  }))

  default = {
    dev = {
      instance_type   = "t2.micro"
      ami             = "ami-0c55b159cbfafe1f0"
      prevent_destroy = false
    }
    prod = {
      instance_type   = "t2.micro"
      ami             = "ami-0c55b159cbfafe1f0"
      prevent_destroy = true
    }
  }
}
