# CloudWeave M4 AWS Foundation

This root module implements the frozen M3 network and security foundation. It intentionally creates no NAT Gateway, workload, database, public listener rule, or speculative IAM role.

## Prerequisites

- Terraform >= 1.8 and < 2.0
- AWS credentials supplied by the standard AWS credential chain or an optional named profile
- A selected AWS Region and two distinct Availability Zone IDs

Never put access keys or secrets in Terraform files or tfvars.

## Workflow

1. Copy terraform.tfvars.example to terraform.tfvars and confirm Region/AZ IDs.
2. Run aws sts get-caller-identity with the selected profile.
3. Run terraform init, terraform fmt -check -recursive, and terraform validate.
4. Run terraform plan -out m4.tfplan and review terraform show m4.tfplan.
5. Apply the reviewed file with terraform apply m4.tfplan.

Review the plan for exactly one VPC, four subnets, one internet gateway, three route tables, one public default route, four route-table associations, three security groups, and four least-privilege SG rules. There must be no NAT Gateway, Elastic IP, workload, or database.

Before teardown, create and review a destroy plan. Local state is the M4 learning baseline and is gitignored. It is unsuitable for shared or production operation; a remote backend with locking is a future environment-management decision.
