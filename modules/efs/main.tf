############################ EFS module ##################################
# modules/efs/main.tf

# Only create a new one if the above lookup fails (optional step handled below)
resource "aws_efs_file_system" "system_efs" {
  count = var.enable_create ? 1 : 0
  creation_token = "system-efs"

  tags = {
    Name = "appEFS"
  }
}

resource "aws_security_group" "efs_sg" {
  count       = var.enable_create ? 1 : 0
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
  count           = var.enable_create ? 1 : 0
  file_system_id  = aws_efs_file_system.system_efs[0].id
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.efs_sg[0].id]
}
