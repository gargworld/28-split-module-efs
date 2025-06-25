output "lambda_function_name" {
  value = aws_lambda_function.terraform_trigger.function_name
}

output "codebuild_project_name" {
  value = aws_codebuild_project.terraform_apply.name
}

output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.asg_termination_rule.name
}
