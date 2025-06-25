# modules/eventbridge_pipeline/variables.tf

variable "codebuild_project_name" {
  description = "CodeBuild project name"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

#variable "lambda_payload_file" {
#  description = "Path to Lambda zip file"
#  type        = string
#}

variable "github_repo_url" {
  description = "GitHub repository for CodeBuild"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch"
  type        = string
}

variable "buildspec_path" {
  type    = string
  default = "lambda/buildspec.yml"
}

