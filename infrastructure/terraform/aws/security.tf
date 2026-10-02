/*
目前只建立安全邊界與內部規則，不建立 ALB、ECS 或 RDS；那些屬於 M5。
Ingress tier (ALB): egress
    │ TCP 8080
    ▼
Application tier (ECS): ingress + egress
    │ TCP 5432
    ▼
Database tier (RDS): ingress

一般情況下 AWS 預設 allow-all egress
*/

resource "aws_security_group" "ingress" {
  name        = "${local.project_name}-${var.environment}-ingress-sg"
  description = "Ingress-tier boundary; listener rules are added with the M5 load balancer."
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.project_name}-${var.environment}-ingress-sg" }
}

resource "aws_security_group" "application" {
  name        = "${local.project_name}-${var.environment}-app-sg"
  description = "Application-tier boundary for the future ECS service."
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.project_name}-${var.environment}-app-sg" }
}

resource "aws_security_group" "database" {
  name        = "${local.project_name}-${var.environment}-db-sg"
  description = "Database-tier boundary for the future PostgreSQL database."
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.project_name}-${var.environment}-db-sg" }
}

# Application Security Group 的入站規則
# 只接受來自 Ingress SG 的 TCP 8080 (Ingress SG ──TCP 8080──> Application SG)
# 不允許 Internet 直接連入 (Internet ──X──> Application)

resource "aws_vpc_security_group_ingress_rule" "application_from_ingress" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.ingress.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  description                  = "Order API traffic from the ingress tier"
}

# Ingress Security Group 的出站規則
# 允許送出 TCP 8080 到 Application SG
resource "aws_vpc_security_group_egress_rule" "ingress_to_application" {
  security_group_id            = aws_security_group.ingress.id
  referenced_security_group_id = aws_security_group.application.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  description                  = "Forward traffic to the Order application"
}

# Database Security Group 的入站規則
# 只接受來自 Application SG 的 TCP 5432 (Application SG ──TCP 5432──> Database SG)
# 其餘皆不允許

resource "aws_vpc_security_group_ingress_rule" "database_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL traffic from the application tier"
}

# Application Security Group 的出站規則
# 允許送出 TCP 5432 到 Database SG
resource "aws_vpc_security_group_egress_rule" "application_to_database" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Application traffic to PostgreSQL"
}
