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

# Save private key locally on EC2 or your VM from where you can login to EC2 to check (optional)
resource "local_file" "private_key" {
  content              = tls_private_key.rsa_4096.private_key_pem
  filename             = var.private_key_file
  file_permission      = "0600"
  directory_permission = "0700"
}

################## iam cloudwatch role ##################################

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

####################### Auto Scaling Group   #############################

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


#################### creating aws_autoscaling_lifecycle_hook  ############

resource "aws_autoscaling_lifecycle_hook" "terminate_hook" {
  name                   = "terraform-instance-terminate-hook"
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
}


############################ EFS mount ##################################

resource "aws_efs_mount_target" "system_efs_mount" {
  file_system_id  = aws_efs_file_system.system_efs.id
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.efs_sg.id]
}

############################ Wait for SSH null_resource ##################### NO1

resource "null_resource" "wait_for_ssh" {
  depends_on = [aws_autoscaling_group.ec2_asg]

  # Add a trigger to re-run when ASG is replaced
  triggers = {
    asg_version = aws_launch_template.ec2_template.latest_version
    time_now    = timestamp()  # <- NEW: ensures it always changes due to EC2 termination
  }

  provisioner "local-exec" {
    command = <<EOT
ASG_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances \
  --query "AutoScalingInstances[?AutoScalingGroupName=='${var.ec2_instance_name}-asg'].InstanceId" \
  --output text)

IP=$(aws ec2 describe-instances \
  --region ${var.aws_region} \
  --instance-ids $ASG_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "[INFO] Sleeping 10 seconds to allow SSH service to start..."
sleep 10

ATTEMPT=1
MAX_ATTEMPTS=5
echo "trying SSSSSSSSSSSSSSSH"
while ! ssh -vv -i ${var.private_key_file} -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${var.ansible_user}@$IP 'exit'; do
  echo "[$ATTEMPT/$MAX_ATTEMPTS] Waiting for SSSSSSSSSSSSSSSSSSSSH on $IP..."
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

############################ Generate Inventory null_resource ##################### NO2

resource "null_resource" "generate_inventory" {
  depends_on = [null_resource.wait_for_ssh]

  triggers = {
    asg_version = aws_launch_template.ec2_template.latest_version
    time_now    = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
set -e

echo "[INFO] Finding instance in ASG: ${var.ec2_instance_name}-asg"

ATTEMPT=1
MAX_ATTEMPTS=10
ASG_INSTANCE_ID=""

while [ -z "$ASG_INSTANCE_ID" ] && [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
  ASG_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances \
    --region ${var.aws_region} \
    --query "AutoScalingInstances[?AutoScalingGroupName=='${var.ec2_instance_name}-asg'].InstanceId" \
    --output text)

  if [ -z "$ASG_INSTANCE_ID" ]; then
    echo "[$ATTEMPT/$MAX_ATTEMPTS] Waiting for ASG instance to be available..."
    ATTEMPT=$((ATTEMPT+1))
    sleep 5
  fi
done

if [ -z "$ASG_INSTANCE_ID" ]; then
  echo "ERROR: Instance not found in ASG"
  exit 1
fi

echo "[INFO] ASG Instance ID: $ASG_INSTANCE_ID"

IP=$(aws ec2 describe-instances \
  --instance-ids $ASG_INSTANCE_ID \
  --region ${var.aws_region} \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "[INFO] Public IP: $IP"

echo  "Create Ansible inventory"
mkdir -p /tmp/inventory

sleep 10

HOST_ENTRY="$IP ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.private_key_file}"
echo "$HOST_ENTRY" > /tmp/inventory/hosts

echo "[INFO] Inventory written to /tmp/inventory/hosts"
echo `hostname`
cat /tmp/inventory/hosts

sleep 10

EOT
  }
}


############################ "run_system_setup_playbook" null_resource ##################### NO3

resource "null_resource" "run_system_setup_playbook" {
  depends_on = [null_resource.generate_inventory]

  triggers = {
    # Add a trigger to re-run when ASG is replaced
    asg_version = aws_launch_template.ec2_template.latest_version
    time_now    = timestamp()  # <- NEW: ensures it always changes due to EC2 termination

  }

provisioner "local-exec" {
command = <<EOT

set -ex

echo "[INFO] Cleaning previous clone"
rm -rf /tmp/ansible-infra-roles

echo "[INFO] Cloning Ansible repo"
git clone ${var.ansible_repo_url} /tmp/ansible-infra-roles
cd /tmp/ansible-infra-roles

# Copy private key to /tmp
#cp ${var.private_key_source} ${var.private_key_file}

#echo "[INFO] Setting permissions for private key"
#chmod 600 ${var.private_key_file}


echo "Running Ansible playbook..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook site.yml \
  -i /tmp/inventory/hosts \
  --extra-vars "efs_dns_name=${aws_efs_file_system.system_efs.dns_name}" \
  --ssh-extra-args='-o StrictHostKeyChecking=no -o ConnectTimeout=5'
EOT
  }
}
