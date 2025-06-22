##### moved from 23- root main.tf

resource "aws_vpc" "Terraform_VPC" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Satyam-Pipeline-VPC"
  }
}

resource "aws_subnet" "prj-public_subnet" {
  cidr_block              = var.public_cidr
  vpc_id                  = aws_vpc.Terraform_VPC.id
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone
  tags = {
    Name = "Satyam-Pipeline-Subnet"
  }
}

resource "aws_internet_gateway" "prj-internet-gateway" {
  vpc_id = aws_vpc.Terraform_VPC.id
  tags = {
    Name = "Satyam-Pipeline-Internet-Gateway"
  }
}

resource "aws_route_table" "prj-route_table" {
  vpc_id = aws_vpc.Terraform_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prj-internet-gateway.id
  }

  tags = {
    Name = "Satyam-Pipeline-Route-table"
  }
}

resource "aws_route_table_association" "prj-route-table-association" {
  subnet_id      = aws_subnet.prj-public_subnet.id
  route_table_id = aws_route_table.prj-route_table.id
}

resource "aws_security_group" "prj-security-group" {
  name   = "web"
  vpc_id = aws_vpc.Terraform_VPC.id

  ingress {
    description = "HTTP inbound allow port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS inbound allow port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH inbound allow port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "inbound allow port"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outgoing request for everything"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Satyam-Pipeline-Security-Group"
  }
}

########### Creating Module ec2 in main.tf root

module "ec2" {
  source = "./modules/ec2"

  ami_id                    = var.ami_id
  ec2_instance_name         = var.ec2_instance_name       # ✅ Add this
  instance_type             = var.instance_type

  vpc_id                    = aws_vpc.Terraform_VPC.id
  subnet_id                 = aws_subnet.prj-public_subnet.id
  security_group_value      = aws_security_group.prj-security-group.id

  key_name                  = var.key_name
  private_key_file          = var.private_key_file

  ansible_user              = var.ansible_user
}

########## Creating MOdule eventbridhe in main.tf

module "eventbridge" {
  source = "./modules/eventbridge"

  github_repo_url            = "https://github.com/gargworld/24-eventbridge-lambda-codebuild.git"
  github_branch                = "main"

  lambda_payload_file        = "${path.module}/lambda_payload.zip"
  codebuild_project_name     = "asg-eventbridge"

  use_existing_secret    = true
  aws_access_key_id      = "" # not used when use_existing_secret = true
  aws_secret_access_key  = "" # not used when use_existing_secret = true

}
