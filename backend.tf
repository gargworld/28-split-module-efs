terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-704630444454"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
  }
}
