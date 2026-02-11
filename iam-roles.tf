locals {
    # Define the aws_auth role mapping for EKS
    aws_k8s_role_mapping = [
      {
        rolearn  = module.eks.eks_managed_node_groups["dev"].iam_role_arn 
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      {
        rolearn  = data.aws_iam_role.github_actions_role.arn # the ARN of the IAM (CI/CD role identity)
        username = "amir-github-actions-deploy-role" # the username for the role in Kubernetes
        groups   = ["system:masters"] # This role will have admin access to the cluster
      },
      {
        rolearn  = aws_iam_role.external-admin.arn # the ARN of the IAM role
        username = "admin" # the username for the role in Kubernetes
        groups   = ["none"] # the group in Kubernetes that this role belongs to
      },
      {
        rolearn  = aws_iam_role.external-developer.arn
        username = "developer"
        groups   = ["none"]
      }
    ]
}
# This role is for amir-github-actions-deploy-role who need admin access to the EKS cluster
data "aws_iam_role" "github_actions_role" {
  name = "amir-github-actions-deploy-role"
}
data "aws_iam_user" "amir-user" {
  user_name = "amir"
}
# This role is for external admin who need cluster viewer access to the EKS cluster
resource "aws_iam_role" "external-admin" {
  name = "external-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.user_for_admin_role
        }
      }
    ]
  })
}

# Separate policy attachment
resource "aws_iam_role_policy" "external-admin-policy" {
  name = "external-admin-policy"
  role = aws_iam_role.external-admin.id

  # This policy allows the admin to describe the EKS cluster
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["eks:DescribeCluster"]
        Effect   = "Allow"
        Resource = module.eks.cluster_arn  # Use the cluster ARN from the EKS module
      }
    ]
  })
}


# This role is for external developer who need a namespace viewer access to the EKS cluster
resource "aws_iam_role" "external-developer" {
  name = "external-developer"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.user_for_dev_role
        }
      }
    ]
  })
}

# Separate policy attachment
resource "aws_iam_role_policy" "external-developer-policy" {
  name = "external-developer-policy"
  role = aws_iam_role.external-developer.id

  # This policy allows the admin to describe the EKS cluster
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["eks:DescribeCluster"]
        Effect   = "Allow"
        Resource = module.eks.cluster_arn  # Use the cluster ARN from the EKS module "*"
      }
    ]
  })
}


# This resource creates an EKS access entry for the GitLab CI role
# It allows the GitLab CI role to access the EKS cluster with full admin permissions
resource "aws_eks_access_entry" "Full_role_admin_Access" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_role.github_actions_role.arn
  type              = "STANDARD"

  depends_on = [module.eks]
  tags = {
    App = "amir-wordpress-eks-cluster"
  }
}
resource "aws_eks_access_policy_association" "role_admin_cluster_policy" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_role.github_actions_role.arn
  policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [module.eks]
  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "Full_user_admin_Access" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_user.amir-user.arn
  type              = "STANDARD"

  depends_on = [module.eks]
  tags = {
    App = "amir-wordpress-eks-cluster"
  }
}
resource "aws_eks_access_policy_association" "user_admin_cluster_policy" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_user.amir-user.arn
  policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [module.eks]
  access_scope {
    type = "cluster"
  }
}