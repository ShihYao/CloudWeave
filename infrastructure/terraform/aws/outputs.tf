output "vpc_id" {
  description = "CloudWeave VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by logical zone."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id if local.subnets[key].public }
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by logical zone."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id if !local.subnets[key].public }
}

output "security_group_ids" {
  description = "Security group IDs exposed to the M5 workload layer."
  value = {
    ingress     = aws_security_group.ingress.id
    application = aws_security_group.application.id
    database    = aws_security_group.database.id
  }
}

output "route_table_ids" {
  description = "Foundation route table IDs."
  value = {
    public  = aws_route_table.public.id
    private = { for zone, route_table in aws_route_table.private : zone => route_table.id }
  }
}

output "ecr_repository_url" { value = aws_ecr_repository.order_service.repository_url }
output "alb_dns_name" { value = aws_lb.order.dns_name }
output "rds_endpoint" { value = aws_db_instance.order.endpoint }
output "database_secret_arn" { value = aws_db_instance.order.master_user_secret[0].secret_arn }
output "github_actions_deploy_role_arn" { value = aws_iam_role.github_deploy.arn }
