locals {
  aws_auth_node_roles = [
    {
      rolearn  = module.eks.eks_managed_node_groups["dev"].iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
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
data "aws_iam_user" "k8s-admin" {
  user_name= "k8s-admin"
}
data "aws_iam_user" "k8s-developer" {
  user_name= "k8s-developer"
}
# This role is for external admin who need cluster viewer access to the EKS cluster
resource "aws_eks_access_entry" "k8s_admin" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_user.k8s-admin.arn
  kubernetes_groups = ["eks-admins"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "k8s_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_user.k8s-admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}



# This role is for external developer who need a namespace viewer access to the EKS cluster
resource "aws_eks_access_entry" "k8s_developer" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_user.k8s-developer.arn
  kubernetes_groups = ["eks-readonly"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "k8s_developer_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_user.k8s-developer.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  access_scope { type = "cluster" }
}


# This resource creates an EKS access entry for the GitLab CI role
# It allows the GitLab CI role to access the EKS cluster with full admin permissions
resource "aws_eks_access_entry" "github_actions" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_role.github_actions_role.arn
  kubernetes_groups = ["eks-admins"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.github_actions_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}


resource "aws_eks_access_entry" "amir" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_user.amir-user.arn
  kubernetes_groups = ["eks-admins"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "amir_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_user.amir-user.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
