include {
  path = find_in_parent_folders()
}

locals {
  private_key_file = "pemkey.pem"
  private_key_source_path = "${get_path_to_repo_root()}/secrets/pemkey.pem"
  private_key_dest_path   = "/tmp/pemkey.pem"
}


dependency "network" {
  config_path = "../network"
}

dependency "efs" {
  config_path = "../efs"
}

terraform {
  source = "../modules/ec2"
}

inputs = {
  ami_id               = "ami-0b8c2bd77c5e270cf" # Red Hat Enterprise Linux
  ec2_instance_name    = "rhel96"  # or whatever you want
  instance_type        = "t2.large"

  key_name             = "pemkey"
  private_key_file     = local.private_key_dest_path
  private_key_source   = local.private_key_source_path

  aws_region           = dependency.network.outputs.aws_region
  vpc_id               = dependency.network.outputs.vpc_id
  subnet_id            = dependency.network.outputs.subnet_id
  security_group_value = dependency.network.outputs.security_group_id
  
  ansible_user         = "ec2-user"
  ansible_repo_url     = "https://github.com/gargworld/27-ansible-infra-roles.git" 
  ansible_tmp_dir      = "/tmp/ansible-infra-roles"
 
  efs_dns_name = dependency.efs.outputs.efs_dns_name
}
