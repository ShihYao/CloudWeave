resource "aws_db_subnet_group" "order" {
  name       = "${local.name_prefix}-order-db"
  subnet_ids = values({ for key, subnet in aws_subnet.this : key => subnet.id if !local.subnets[key].public })
  tags       = merge(local.workload_tags, { Name = "${local.name_prefix}-order-db-subnets" })
}

resource "aws_db_instance" "order" {
  identifier                      = "${local.name_prefix}-order-db"
  engine                          = "postgres"
  engine_version                  = "17"
  instance_class                  = "db.t4g.micro"
  allocated_storage               = 20
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = local.database_name
  username                        = local.database_user
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.order.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  publicly_accessible             = false
  multi_az                        = false
  backup_retention_period         = 1
  deletion_protection             = false
  skip_final_snapshot             = true
  apply_immediately               = true
  auto_minor_version_upgrade      = true
  performance_insights_enabled    = false
  enabled_cloudwatch_logs_exports = ["postgresql"]
  tags                            = merge(local.workload_tags, { Name = "${local.name_prefix}-order-db" })
}
