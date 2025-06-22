# modules/eventbridge_pipeline/variables.tf

variable "codebuild_project_name" {}
variable "github_repo_url" {}
variable "github_branch" {
  default = "main"
}
variable "lambda_payload_file" {}

