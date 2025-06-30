output "efs_id" {
  description = "EFS File System ID"
  value       = var.enable_create ? aws_efs_file_system.system_efs[0].id : ""
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = var.enable_create ? aws_efs_file_system.system_efs[0].dns_name : ""
}
