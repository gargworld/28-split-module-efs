# Example Lambda function resource
resource "aws_lambda_function" "terraform_trigger" {
  function_name = "terraform-trigger-lambda"
  filename      = "lambda/lambda_payload.zip"
  handler       = "index.handler"
  runtime       = "python3.8"

  role = aws_iam_role.lambda_exec_role.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
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
  service_role  = aws_iam_role.codebuild_service_role.arn
  build_timeout = 20

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "TF_VERSION"
      value = "1.2.9"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

resource "aws_iam_role" "codebuild_service_role" {
  name = "codebuild_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

############### Add any other necessary permissions and resources as needed
##### moved from 23- root main.tf

resource "aws_vpc" "Terraform_VPC" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Satyam-Pipeline-VPC"
  }
}

resource "aws_subnet" "prj-public_subnet" {
  cidr_block              = var.public_cidr
  vpc_id                  = aws_vpc.Terraform_VPC.id
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone
  tags = {
    Name = "Satyam-Pipeline-Subnet"
  }
}

resource "aws_internet_gateway" "prj-internet-gateway" {
  vpc_id = aws_vpc.Terraform_VPC.id
  tags = {
    Name = "Satyam-Pipeline-Internet-Gateway"
  }
}

resource "aws_route_table" "prj-route_table" {
  vpc_id = aws_vpc.Terraform_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prj-internet-gateway.id
  }

  tags = {
    Name = "Satyam-Pipeline-Route-table"
  }
}

resource "aws_route_table_association" "prj-route-table-association" {
  subnet_id      = aws_subnet.prj-public_subnet.id
  route_table_id = aws_route_table.prj-route_table.id
}

resource "aws_security_group" "prj-security-group" {
  name   = "web"
  vpc_id = aws_vpc.Terraform_VPC.id

  ingress {
    description = "HTTP inbound allow port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS inbound allow port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH inbound allow port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "inbound allow port"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outgoing request for everything"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Satyam-Pipeline-Security-Group"
  }
}


module "ec2" {
  source                = "../ec2"

  ec2_instance_name     = var.ec2_instance_name
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  #ec2_instance_count    = var.ec2_instance_count

  vpc_id                = aws_vpc.Terraform_VPC.id
  subnet_id             = aws_subnet.prj-public_subnet.id
  security_group_value  = aws_security_group.prj-security-group.id

  ansible_user          = var.ansible_user
  ec2_instance_profile_name = var.ec2_instance_profile_name

  # 👇 Make sure this is EXACTLY "(used in your local-exec and playbook)
  key_name              = var.key_name
  private_key_file      = var.private_key_file
}

