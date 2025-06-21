# modules/eventbridge_pipeline/variables.tf

variable "codebuild_project_name" {}
variable "codebuild_service_role_arn" {}
variable "github_repo_url" {}
variable "github_branch" {
  default = "main"
}
variable "lambda_execution_role_arn" {}
variable "lambda_payload_file" {}
