output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.system_efs.dns_name
}

output "efs_id" {
  value       = var.enable_create ? aws_efs_file_system.system_efs[0].id : ""
  description = "EFS File System ID"
}
