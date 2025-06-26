variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ec2_instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID in which resources will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "security_group_value" {
  description = "Security Group ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of the existing AWS key pair"
  type        = string
  }

variable "private_key_file" {
  description = "Local filename for the generated PEM private key"
  type        = string
}

variable "ansible_user" {
  description = "Username for Ansible SSH connections"
  type        = string
}

variable "ansible_repo_url" {
  type    = string
  default = "https://github.com/gargworld/27-ansible-infra-roles.git"
}


variable "ansible_tmp_dir" {
  type    = string
  default = "/tmp/ansible-infra-roles
}
