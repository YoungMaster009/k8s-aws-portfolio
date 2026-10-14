# Phase 2 bootstrap: ECR repository + GitHub Actions push role (run from laptop)

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tf-state-590183753633"
    key          = "k8s-aws-portfolio/bootstrap/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Project   = "k8s-aws-portfolio"
      ManagedBy = "terraform"
    }
  }
}

variable "repo_id" {
  description = "Immutable GitHub repository ID for k8s-aws-portfolio"
  type        = string
}

variable "owner_id" {
  description = "Immutable GitHub owner ID for YoungMaster009"
  type        = string
  default     = "145816778"
}

# ---------- ECR repository ----------

resource "aws_ecr_repository" "app" {
  name                 = "k8s-aws-portfolio"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten
  force_delete         = true        # lets terraform destroy remove it even with images

  image_scanning_configuration {
    scan_on_push = true # free basic vulnerability scan on every push
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------- GitHub OIDC role ----------

# Reuse the OIDC provider Project 1 already created (one per account)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Accept both sub formats for now, then trim after checking CloudTrail
    # (same approach as Project 1). Only the main branch can push.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:YoungMaster009/k8s-aws-portfolio:ref:refs/heads/main",
        "repo:YoungMaster009@${var.owner_id}/k8s-aws-portfolio@${var.repo_id}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "github-actions-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "push" {
  # Login token is account-wide by design, so it can't be scoped to one repo
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Everything else is limited to this one repository
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "push" {
  name   = "ecr-push-k8s-aws-portfolio"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.push.json
}

# ---------- Outputs ----------

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "role_arn" {
  value = aws_iam_role.ecr_push.arn
}
