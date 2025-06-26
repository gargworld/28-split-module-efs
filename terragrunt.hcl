# terragrunt.hcl in root
locals {
  region = "us-east-1"
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-bucket-704630444454"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region

    dynamodb_table = "terragrunt-locks"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
}
EOF
}

