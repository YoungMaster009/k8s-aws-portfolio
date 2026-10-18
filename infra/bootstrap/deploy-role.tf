data "aws_iam_openid_connect_provider" "github_deploy" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account = "590183753633"
  region  = "us-west-1"
  allowed_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ]
}

resource "aws_iam_role" "eks_deploy" {
  name = "github-actions-eks-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github_deploy.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:YoungMaster009@145816778/k8s-aws-portfolio@${var.repo_id}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eks_deploy" {
  name = "eks-deploy-k8s-portfolio"
  role = aws_iam_role.eks_deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "NetworkInThisRegionOnly"
        Effect   = "Allow"
        Action   = [
          "ec2:Describe*", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DisassociateAddress",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "elasticloadbalancing:DescribeLoadBalancers",
        ]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = local.region } }
      },
      {
        Sid    = "ThisClusterOnly"
        Effect = "Allow"
        Action = "eks:*"
        Resource = [
          "arn:aws:eks:${local.region}:${local.account}:cluster/k8s-portfolio",
          "arn:aws:eks:${local.region}:${local.account}:*/k8s-portfolio/*",
        ]
      },
      {
        Sid    = "ManageOnlyProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::${local.account}:role/k8s-portfolio-*"
      },
      {
        Sid       = "AttachOnlyEksPolicies"
        Effect    = "Allow"
        Action    = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource  = "arn:aws:iam::${local.account}:role/k8s-portfolio-*"
        Condition = { ArnEquals = { "iam:PolicyARN" = local.allowed_policies } }
      },
      {
        Sid       = "PassProjectRolesToEksOnly"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = "arn:aws:iam::${local.account}:role/k8s-portfolio-*"
        Condition = { StringEquals = { "iam:PassedToService" = "eks.amazonaws.com" } }
      },
      {
        Sid      = "StateFilesForThisStackOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::tf-state-${local.account}/k8s-aws-portfolio/eks/*"
      },
      {
        Sid       = "ListStateBucketPrefix"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = "arn:aws:s3:::tf-state-${local.account}"
        Condition = { StringLike = { "s3:prefix" = "k8s-aws-portfolio/eks/*" } }
      },
      {
        Sid      = "FindNewestImage"
        Effect   = "Allow"
        Action   = "ecr:DescribeImages"
        Resource = "arn:aws:ecr:${local.region}:${local.account}:repository/k8s-aws-portfolio"
      },
    ]
  })
}

output "eks_deploy_role_arn" {
  value = aws_iam_role.eks_deploy.arn
}