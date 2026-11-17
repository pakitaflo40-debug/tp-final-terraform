output "ips" {
  value = merge(
    { for env, m in module.ec2_dev : env => m.public_ip },
    { for env, m in module.ec2_prod : env => m.public_ip }
  )
}
