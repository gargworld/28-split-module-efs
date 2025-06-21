resource "aws_instance" "prj-vm" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  count                  = 1
  subnet_id              = var.subnet_id
  key_name               = var.key_name  # Use the existing key pair name here
  vpc_security_group_ids = [var.security_group_value]

  associate_public_ip_address = true

  tags = {
    Name = "${var.ec2_instance_name}-${count.index}"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum clean metadata
              yum install -y epel-release
              yum install -y ansible python3
              EOF
}

# Generate Key Pair

resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

resource "local_file" "private_key" {
  content              = tls_private_key.rsa_4096.private_key_pem
  #filename             = var.key_name
  filename             = var.private_key_file
  file_permission      = "0600" # 👈 Secure permissions
  directory_permission = "0700"
}

###### EFS TF block

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

##### Start of IAM block 
# IAM Role that allows EC2 to assume CloudWatch permissions

resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach CloudWatchAgent policy to the role

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_attach" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create instance profile so EC2 can use this IAM role

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-cloudwatch-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

################## --- WAIT FOR SSH ---

resource "null_resource" "wait_for_ssh" {
  depends_on = [aws_instance.prj-vm]

  provisioner "local-exec" {
    command = <<EOT
IP="${aws_instance.prj-vm[0].public_ip}"
echo " IP isssssssssssssssssssssssssssssssssssss" $IP
ATTEMPT=1
MAX_ATTEMPTS=10

echo "[INFO] Waiting some seconds before attempting SSH..."
sleep 5

echo "pem key name is ------------" ${var.private_key_file}
echo "ec2 user is ................" ${var.ansible_user}
echo "ec2 ip is .................." $IP

while ! ssh -i ./${var.private_key_file} -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${var.ansible_user}@$IP 'exit' 2>/dev/null; do
  echo "[$ATTEMPT/$MAX_ATTEMPTS] Waiting for SSH on $IP...inside EC2 module of main playbook"
  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: Timed out waiting for SSH inside EC2 module of main playbook."
    exit 1
  fi
  ATTEMPT=$((ATTEMPT+1))
  sleep 5
done

echo "[INFO] SSH is now available on" $IP

EOT
  }
}

################## --- GENERATE INVENTORY FILE ---


resource "null_resource" "generate_inventory" {
  depends_on = [aws_instance.prj-vm]

  provisioner "local-exec" {
    command = <<EOT
echo "!!!!!          Generating inventory file              !!!!!"
chmod 600 ./${var.private_key_file}
# Ensure inventory directory exists
mkdir -p ansible/inventory

# Prepare host entry
IP="${aws_instance.prj-vm[0].public_ip}"
HOST_ENTRY="$IP ansible_user=${var.ansible_user} ansible_ssh_private_key_file=./${var.private_key_file}"

# Check if the host is already in the file
if ! grep -q "$IP" ansible/inventory/hosts 2>/dev/null; then
  if ! grep -q "^\[system\]" ansible/inventory/hosts 2>/dev/null; then
    echo "[system]" >> ansible/inventory/hosts
  fi

  echo "$HOST_ENTRY" > ansible/inventory/hosts
  echo "Appended host: $HOST_ENTRY"
else
  echo "Host already exists in inventory."
fi

echo "Current directory: $(pwd)"
echo "!!!!!!DONE Generating inventory file!!!!!"
EOT
  }
}

################## --- RUN ARTIFACTORY SETUP PLAYBOOK ---

resource "null_resource" "run_system_setup_playbook" {
  depends_on = [
    null_resource.wait_for_ssh,
    aws_instance.prj-vm,
    null_resource.generate_inventory
  ]

  triggers = {
    site_hash                  = filemd5("${path.root}/ansible/site.yml")

    system-setup_roles_hash    = filemd5("${path.root}/ansible/roles/system-setup/tasks/main.yml")
    docker-setup_roles_hash    = filemd5("${path.root}/ansible/roles/docker-setup/tasks/main.yml")
    artifactory_roles_hash     = filemd5("${path.root}/ansible/roles/artifactory/tasks/main.yml")
    efs_roles_hash	       = filemd5("${path.root}/ansible/roles/efs/tasks/main.yml")
    cloudwatch_roles_hash      = filemd5("${path.root}/ansible/roles/cloudwatch_agent/tasks/main.yml")
  }

  provisioner "local-exec" {
    command = <<EOT
	cd ${path.root}
	echo "Using key: ${path.root}/${var.private_key_file}"
	echo "Trying to SSH into: ${aws_instance.prj-vm[0].public_ip}"
	chmod 600 ${path.root}/${var.private_key_file}

	echo "#####################Running Ansible playbook..."

	ansible-playbook ${path.root}/ansible/site.yml \
  		-i ${path.root}/ansible/inventory/hosts \
  		--extra-vars "efs_dns_name=${aws_efs_file_system.system_efs.dns_name}" \
  		--ssh-extra-args='-o StrictHostKeyChecking=no -o ConnectTimeout=5'

    EOT
  }
}
