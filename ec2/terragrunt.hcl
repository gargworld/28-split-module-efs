include {
  path = find_in_parent_folders()
}

locals {
  private_key_file = "pemkey.pem"
}



dependency "network" {
  config_path = "../network"
}

terraform {
  source = "../modules/ec2"
}

inputs = {
  ami_id               = "ami-0b8c2bd77c5e270cf" # Red Hat Enterprise Linux
  ec2_instance_name    = "rhel96"  # or whatever you want
  instance_type        = "t2.large"

  key_name             = "pemkey"
  private_key_file     = "${get_path_to_repo_root()}/secrets/${local.private_key_file}" # This is how you define in terragrunt

  ansible_user         = "ec2-user"

  vpc_id               = dependency.network.outputs.vpc_id
  subnet_id            = dependency.network.outputs.subnet_id
  security_group_value = dependency.network.outputs.security_group_id
}
