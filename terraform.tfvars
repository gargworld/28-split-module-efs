region_value         = "us-east-1"
availability_zone    = "us-east-1a"

vpc_cidr             = "10.0.0.0/26"
public_cidr          = "10.0.0.0/28"

ami_id               = "ami-0b8c2bd77c5e270cf" # Red Hat Enterprise Linux

ec2_instance_name    = "rhel96"  # or whatever you want
instance_type        = "t2.large"

key_name             = "pemkey"
private_key_file     = "pemkey.pem"

ansible_user         = "ec2-user"

github_repo_url	     = "https://github.com/gargworld/24-eventbridge-lambda-codebuild.git"
github_branch        = "main"
