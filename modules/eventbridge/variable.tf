# modules/eventbridge_pipeline/variables.tf

variable "codebuild_project_name" {}
variable "github_repo_url" {}
variable "github_branch" {
  default = "main"
}
variable "lambda_payload_file" {}


# -------------------------------------------------------------------
# Secret Manager Variables
# -------------------------------------------------------------------

variable "use_existing_secret" {
  type    = bool
  default = true
  description = "Whether to use an existing Secrets Manager secret instead of creating a new one"
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS Access Key for CodeBuild"
  sensitive   = true
  default     = null
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS Secret Access Key for CodeBuild"
  sensitive   = true
  default     = null
}
