/*
整份檔案形成的 dependency graph：

aws_vpc.main
├── aws_subnet.this["public-a"]
├── aws_subnet.this["public-b"]
├── aws_subnet.this["private-a"]
├── aws_subnet.this["private-b"]
├── aws_internet_gateway.main
├── aws_route_table.public
└── aws_route_table.private["a" / "b"]

aws_route_table.public + aws_internet_gateway.main
└── aws_route.public_ipv4_default

public subnets + public route table
└── public route-table associations

*Internet Gateway 是 VPC-level resource，不是 AZ-specific resource。
因此可以讓兩個 public subnet 共用一張 public route table

private subnets + matching private route tables
└── private route-table associations

(private subnet A 10.20.10.0/24 → private route table A)
(private subnet B 10.20.11.0/24 → private route table B)

*保留未來彈性，每個 AZ 可以有獨立的路由策略

*/

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags                 = { Name = "${local.project_name}-${var.environment}-vpc" }
}

resource "aws_subnet" "this" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone_id    = each.value.availability_zone
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.project_name}-${var.environment}-${each.key}-subnet"
    Tier = each.value.public ? "public" : "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.project_name}-${var.environment}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.project_name}-${var.environment}-public-rt", Tier = "public" }
}

resource "aws_route" "public_ipv4_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "private" {
  for_each = toset(["a", "b"])
  vpc_id   = aws_vpc.main.id
  tags     = { Name = "${local.project_name}-${var.environment}-private-${each.key}-rt", Tier = "private" }
}

resource "aws_route_table_association" "public" {
  for_each       = { for key, subnet in local.subnets : key => subnet if subnet.public }
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = { for key, subnet in local.subnets : key => subnet if !subnet.public }
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[trimprefix(each.key, "private-")].id
}
