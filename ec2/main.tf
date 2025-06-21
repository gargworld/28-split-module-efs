# ---------------------------------------------
# LAUNCH TEMPLATE & AUTOSCALING WITH KEY PAIR
# ---------------------------------------------

# Generate RSA key pair
resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using generated public key
resource "aws_key_pair" "key_pair" {
  key_name   = "pemkey"
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

# Save private key locally (optional)
resource "local_file" "private_key" {
  content              = tls_private_key.rsa_4096.private_key_pem
  filename             = "pemkey.pem"
  file_permission      = "0600"
  directory_permission = "0700"
}

################## iam cloudwatch role

resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-cloudwatch-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

######################### Launch Template ##################################

resource "aws_launch_template" "ec2_template" {
  #name_prefix   = "prj-template-"
  name_prefix   = "${var.ec2_instance_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.key_pair.key_name

#  iam_instance_profile {
#    name = var.ec2_instance_profile_name
#  }


   iam_instance_profile {
     name = aws_iam_instance_profile.ec2_profile.name
   }


  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.subnet_id
    security_groups             = [var.security_group_value]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum clean metadata
    yum install -y epel-release
    yum install -y ansible python3
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.ec2_instance_name
    }
  }
}

########### Auto Scaling Group   #############################

resource "aws_autoscaling_group" "ec2_asg" {
  name                      = "${var.ec2_instance_name}-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [var.subnet_id]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.ec2_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.ec2_instance_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_efs_file_system" "system_efs" {
  creation_token = "system-efs"
  tags = {
    Name = "ArtifactoryEFS"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

resource "aws_efs_mount_target" "system_efs_mount" {
  file_system_id  = aws_efs_file_system.system_efs.id
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "null_resource" "wait_for_ssh" {
  depends_on = [aws_autoscaling_group.ec2_asg]

  provisioner "local-exec" {
    command = <<EOT
ASG_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances \
  --query "AutoScalingInstances[?AutoScalingGroupName=='${var.ec2_instance_name}-asg'].InstanceId" \
  --output text)

IP=$(aws ec2 describe-instances \
  --instance-ids $ASG_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

ATTEMPT=1
MAX_ATTEMPTS=10

while ! ssh -i ./${var.private_key_file} -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${var.ansible_user}@$IP 'exit' 2>/dev/null; do
  echo "[$ATTEMPT/$MAX_ATTEMPTS] Waiting for SSH on $IP..."
  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: Timed out waiting for SSH."
    exit 1
  fi
  ATTEMPT=$((ATTEMPT+1))
  sleep 5
done

echo "[INFO] SSH is now available on $IP"
EOT
  }
}

resource "null_resource" "generate_inventory" {
  depends_on = [null_resource.wait_for_ssh]

  provisioner "local-exec" {
    command = <<EOT
ASG_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances \
  --query "AutoScalingInstances[?AutoScalingGroupName=='${var.ec2_instance_name}-asg'].InstanceId" \
  --output text)

IP=$(aws ec2 describe-instances \
  --instance-ids $ASG_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

mkdir -p ansible/inventory
HOST_ENTRY="$IP ansible_user=${var.ansible_user} ansible_ssh_private_key_file=./${var.private_key_file}"
echo "[system]" > ansible/inventory/hosts
echo "$HOST_ENTRY" >> ansible/inventory/hosts
EOT
  }
}

resource "null_resource" "run_system_setup_playbook" {
  depends_on = [null_resource.generate_inventory]

  triggers = {
    site_hash                  = filemd5("${path.root}/ansible/site.yml")
    system-setup_roles_hash    = filemd5("${path.root}/ansible/roles/system-setup/tasks/main.yml")
    docker-setup_roles_hash    = filemd5("${path.root}/ansible/roles/docker-setup/tasks/main.yml")
    artifactory_roles_hash     = filemd5("${path.root}/ansible/roles/artifactory/tasks/main.yml")
    efs_roles_hash             = filemd5("${path.root}/ansible/roles/efs/tasks/main.yml")
    cloudwatch_roles_hash      = filemd5("${path.root}/ansible/roles/cloudwatch_agent/tasks/main.yml")
  }

  provisioner "local-exec" {
    command = <<EOT
cd ${path.root}
chmod 600 ${path.root}/${var.private_key_file}

echo "Running Ansible playbook..."
ansible-playbook ${path.root}/ansible/site.yml \
  -i ${path.root}/ansible/inventory/hosts \
  --extra-vars "efs_dns_name=${aws_efs_file_system.system_efs.dns_name}" \
  --ssh-extra-args='-o StrictHostKeyChecking=no -o ConnectTimeout=5'
EOT
  }
}

