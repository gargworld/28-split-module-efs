#!/bin/bash

terraform init

terraform import module.ec2.aws_key_pair.key_pair pemkey
terraform import module.ec2.aws_iam_role.ec2_cloudwatch_role ec2-cloudwatch-role
terraform import module.ec2.aws_iam_instance_profile.ec2_profile ec2-cloudwatch-instance-profile
terraform import module.ec2.aws_efs_file_system.system_efs fs-023b3e6ecfd9b587a
terraform import module.eventbridge.aws_codebuild_project.terraform_apply terraform-apply-github-project-logs
terraform import module.eventbridge.aws_iam_role.lambda_exec lambda-execution-role
terraform import module.eventbridge.aws_iam_role.codebuild_role codebuild-service-role
terraform import module.eventbridge.aws_iam_policy.codebuild_admin_policy arn:aws:iam::704630444454:policy/codebuild-admin-access

