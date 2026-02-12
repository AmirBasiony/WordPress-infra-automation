#############################################
# kube-resources.tf (FINAL)
# - aws-auth used ONLY for node role
# - EKS Access Entries control human/role access
# - RBAC binds to GROUPS: eks-admins, eks-readonly
# - Developer is namespace-only read access
#############################################

# Provider block for Kubernetes (uses aws eks get-token)
# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

#   exec {
#     command     = "aws"
#     api_version = "client.authentication.k8s.io/v1beta1"
#     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
#   }
# }
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    command     = "aws"
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
  }
}


#######################################################
# Namespace
#######################################################
resource "kubernetes_namespace_v1" "amir_wordpress" {
  metadata {
    name = "amir-wordpress"
  }

  depends_on = [module.eks]
}

#######################################################
# aws-auth ConfigMap (NODES ONLY)
#######################################################
locals {
  aws_auth_node_roles = [
    {
      rolearn  = module.eks.eks_managed_node_groups["dev"].iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.aws_auth_node_roles)
  }

  # IMPORTANT: this tells Terraform “update/overwrite data in the existing configmap”
  force = true

  depends_on = [module.eks]
}


#######################################################
# RBAC
# 1) eks-admins => cluster-admin (cluster-wide full access)
#######################################################
resource "kubernetes_cluster_role_binding_v1" "eks_admins_cluster_admin" {
  metadata {
    name = "eks-admins-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "eks-admins"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [module.eks]
}

#######################################################
# 2) eks-readonly => view (namespace-only read access)
#    (developer read access ONLY in amir-wordpress namespace)
#######################################################
resource "kubernetes_role_binding_v1" "eks_readonly_ns" {
  metadata {
    name      = "eks-readonly-view"
    namespace = kubernetes_namespace_v1.amir_wordpress.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "Group"
    name      = "eks-readonly"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_namespace_v1.amir_wordpress]
}
