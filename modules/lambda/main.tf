# -------------------------------------------------------------------
# Data Sources for Dynamic Region and Account ID
# -------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


# -------------------------------------------------------------------
# Add a full-access IAM policy for CodeBuild (before attachments)
# -------------------------------------------------------------------

resource "aws_iam_policy" "codebuild_admin_policy" {
  name = "codebuild-admin-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "*",
        Resource = "*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# Lambda IAM Role
# -------------------------------------------------------------------

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_codebuild_trigger" {
  name = "lambda-start-codebuild"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "codebuild:StartBuild",
        Resource = "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${aws_codebuild_project.terraform_apply.name}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_logging" {
  name = "codebuild-logging"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# Package Lambda Function (ZIP)
# -------------------------------------------------------------------

resource "null_resource" "lambda_zip" {
  triggers = {
    index_py_hash = filemd5("${path.module}/lambda/index.py")
  }

  provisioner "local-exec" {
    command = <<EOT
cd ${path.module}/lambda
zip -r lambda_payload.zip index.py
EOT
  }
}

# -------------------------------------------------------------------
# Lambda Function triggered by codebuild via eventbridge
# -------------------------------------------------------------------

resource "aws_lambda_function" "terraform_trigger" {
  depends_on    = [null_resource.lambda_zip]
  function_name = "terraform-trigger-lambda-logs"
  filename      = var.lambda_payload_file
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      PROJECT_NAME = aws_codebuild_project.terraform_apply.name
    }
  }
}

# -------------------------------------------------------------------
# EventBridge Rule & Permissions
# -------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "asg_termination_rule" {
  name        = "asg-instance-termination"
  description = "Trigger Lambda on ASG instance termination"
  event_pattern = jsonencode({
    source      = ["aws.autoscaling"],
    "detail-type" = ["EC2 Instance-terminate Lifecycle Action"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.asg_termination_rule.name
  target_id = "lambda-asg-termination"
  arn       = aws_lambda_function.terraform_trigger.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_termination_rule.arn
}

# -------------------------------------------------------------------
# CodeBuild IAM Role
# -------------------------------------------------------------------

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name]
  }
}

resource "aws_iam_role_policy_attachment" "attach_secrets_access_to_cb_role" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_admin_policy.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_admin_policy.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_admin_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_admin_policy.arn

}

# -------------------------------------------------------------------
# Main CodeBuild Project "terraform_apply"
# -------------------------------------------------------------------

resource "aws_codebuild_project" "terraform_apply" {
  name          = "terraform-apply-github-project-logs"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 20

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "modules/lambda/lambda/buildspec.yml"
  }
}
