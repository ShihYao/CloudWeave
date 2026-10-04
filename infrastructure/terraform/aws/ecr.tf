# ECR 存放 Order Service container images
# IMMUTABLE:　如果application有新版本，應使用新tag
resource "aws_ecr_repository" "order_service" {
  name                 = "${local.name_prefix}-order-service"
  image_tag_mutability = "IMMUTABLE"
  encryption_configuration { encryption_type = "AES256" }
  tags = local.workload_tags
}
# Lifecycle Policy 只保留最新十個 images
resource "aws_ecr_lifecycle_policy" "order_service" {
  repository = aws_ecr_repository.order_service.name
  policy = jsonencode({ rules = [{
    rulePriority = 1
    description  = "Keep the ten newest release images"
    selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
    action       = { type = "expire" }
  }] })
}
