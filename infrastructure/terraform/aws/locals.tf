locals {
  project_name = "cloudweave"
  common_tags = {
    Project     = "CloudWeave"
    Environment = var.environment
    Milestone   = "M4"
    ManagedBy   = "Terraform"
  }
  subnets = {
    public-a  = { cidr = "10.20.0.0/24", availability_zone = var.availability_zone_ids[0], public = true }
    public-b  = { cidr = "10.20.1.0/24", availability_zone = var.availability_zone_ids[1], public = true }
    private-a = { cidr = "10.20.10.0/24", availability_zone = var.availability_zone_ids[0], public = false }
    private-b = { cidr = "10.20.11.0/24", availability_zone = var.availability_zone_ids[1], public = false }
  }
}
