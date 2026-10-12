resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = merge(local.workload_tags, { Milestone = "M6" })
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${local.name_prefix}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = merge(local.workload_tags, { Milestone = "M6" })
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "PushOrderImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.order_service.arn]
  }
  statement {
    sid       = "ReadEcsDeploymentState"
    actions   = ["ecs:DescribeServices", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }
  statement {
    sid       = "RegisterOrderTaskDefinition"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }
  statement {
    sid       = "DeployOrderService"
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.order.id]
  }
  statement {
    sid       = "PassOnlyOrderExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ecs_task_execution.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${local.name_prefix}-github-actions-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
