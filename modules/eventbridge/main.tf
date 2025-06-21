# Example Lambda function resource
resource "aws_lambda_function" "terraform_trigger" {
  function_name = "terraform-trigger-lambda"
  filename      = "modules/eventbridge/lambda/lambda_payload.zip"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  #role = var.lambda_exec_role_arn
  role = var.lambda_execution_role_arn

}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role = split("/", var.lambda_execution_role_arn)[1]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_event_rule" "asg_termination_rule" {
  name        = "asg-instance-termination"
  description = "Trigger Lambda on ASG instance termination"
  event_pattern = jsonencode({
    "source": ["aws.autoscaling"],
    "detail-type": ["EC2 Instance-terminate Lifecycle Action"],
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

# CodeBuild project definition (simplified)

resource "aws_codebuild_project" "terraform_apply" {
  name          = "terraform-apply-project"
  service_role  = var.codebuild_service_role_arn
  build_timeout = 20

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }
}

############### Add any other necessary permissions and resources as needed
