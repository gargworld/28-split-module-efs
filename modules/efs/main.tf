############################ EFS module ##################################
# modules/efs/main.tf

resource "aws_efs_file_system" "system_efs" {
  creation_token = "system-efs"

  tags = {
    Name = "appEFS"
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

