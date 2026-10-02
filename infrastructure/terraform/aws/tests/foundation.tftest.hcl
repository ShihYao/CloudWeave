# 使用模擬的 AWS provider，不呼叫真實 AWS API
mock_provider "aws" {}

# 產生一份測試用 plan，然後檢查裡面的值
run "m3_foundation_contract" {
  command = plan

  variables {
    aws_region            = "ap-southeast-2"
    availability_zone_ids = ["apse2-az1", "apse2-az3"]
  }

  # 驗證 VPC CIDR 是 10.20.0.0/16
  assert {
    condition     = aws_vpc.main.cidr_block == "10.20.0.0/16"
    error_message = "The VPC CIDR must match the M3 design freeze."
  }

  # 驗證 DNS support 已啟用、DNS hostnames 已啟用
  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "Both VPC DNS settings must be enabled."
  }

  # 驗證必須建立四個 subnet
  assert {
    condition     = length(aws_subnet.this) == 4
    error_message = "The foundation must have four subnets."
  }

  # 驗證四個 subnet CIDR 符合 M3 設計
  assert {
    condition = toset([for subnet in aws_subnet.this : subnet.cidr_block]) == toset([
      "10.20.0.0/24",
      "10.20.1.0/24",
      "10.20.10.0/24",
      "10.20.11.0/24"
    ])
    error_message = "Subnet CIDRs must match the M3 design freeze."
  }

  # 驗證 Public default route 是 0.0.0.0/0
  assert {
    condition     = aws_route.public_ipv4_default.destination_cidr_block == "0.0.0.0/0"
    error_message = "The public route table must route IPv4 default traffic to the IGW."
  }

  # 驗證有兩張 private route table
  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Each private subnet must have a private route table."
  }

  # 驗證 Database ingress port 是 5432
  assert {
    condition     = aws_vpc_security_group_ingress_rule.database_from_application.from_port == 5432
    error_message = "PostgreSQL ingress must be limited to TCP 5432 from the application SG."
  }
}
