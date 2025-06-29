include {
  path = find_in_parent_folders()
}

locals {
}

dependency "network" {
  config_path = "../network"
}

terraform {
  source = "../modules/efs"
}

inputs = {

  vpc_id    = dependency.network.outputs.vpc_id
  subnet_id = dependency.network.outputs.subnet_id

}
