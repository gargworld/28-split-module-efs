output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.Terraform_VPC.id
}

output "subnet_id" {
  value = aws_subnet.prj-public_subnet.id
}

output "security_group_id" {
  value = aws_security_group.prj-security-group.id
}

