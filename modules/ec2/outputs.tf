output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ec2_asg.name
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.system_efs.dns_name
}
