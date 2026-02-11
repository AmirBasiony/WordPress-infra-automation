// Provider block for Kubernetes
// Configures the Kubernetes provider to connect to the EKS cluster
provider "kubernetes" {
    host    = module.eks.cluster_endpoint // EKS cluster endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) // Base64 encoded CA certificate for the cluster

    exec {
        command = "aws" // Command to execute for authentication
        api_version = "client.authentication.k8s.io/v1beta1" // API version for the authentication
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region ]
    }
}

locals {
  fake_dep = substr(md5(aws_eks_access_entry.Full_role_admin_Access.id), 0, 16)
}

# Manually apply the aws-auth ConfigMap after cluster creation
resource "kubernetes_namespace" "amir_wordpress" {
  metadata {
    name = "amir-wordpress"
    labels = {
      force_dep = local.fake_dep
    }  
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
    module.eks,
    aws_eks_access_entry.Full_role_admin_Access,
    kubernetes_config_map.aws_auth
    ]
  
}

#######################################################
# Kubernetes config_map for aws-auth
# This config_map is used to map IAM roles to Kubernetes users/groups
#######################################################
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
    labels = {
      force_dep = local.fake_dep
    } 
  }

  data = {
    mapRoles = yamlencode(local.aws_k8s_role_mapping) // Maps IAM roles to Kubernetes users/groups
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
      module.eks,
      aws_eks_access_entry.Full_role_admin_Access
      ]
}

#######################################################
# Kubernetes Role and Role Binding for Namespace Viewer
#######################################################
resource "kubernetes_role" "namespace-viewer" {
  metadata {
    name = "namespace-viewer"
    namespace = "amir-wordpress"
    labels = {
      force_dep = local.fake_dep
    } 
  }

  rule {
    api_groups     = [""]
    resources      = ["pods", "services", "configmaps", "secrets", "persistentvolumes", "persistentvolumeclaims"]
    verbs          = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
      module.eks,
      aws_eks_access_entry.Full_role_admin_Access,
      kubernetes_config_map.aws_auth
      ]
}

resource "kubernetes_role_binding" "namespace-viewer" {
  metadata {
    name      = "namespace-viewer"
    namespace = "amir-wordpress"
    labels = {
      force_dep = local.fake_dep
    } 
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.namespace-viewer.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = "developer"
    api_group = "rbac.authorization.k8s.io"
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
      module.eks,
      aws_eks_access_entry.Full_role_admin_Access,
      kubernetes_config_map.aws_auth
      ]
}



# #######################################################################
# # Kubernetes Cluster Role and Cluster Role Binding for Cluster Viewer
# #######################################################################
resource "kubernetes_cluster_role" "cluster-viewer" {
  metadata {
    name = "cluster-viewer"
    labels = {
      force_dep = local.fake_dep
    } 
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
      module.eks,
      aws_eks_access_entry.Full_role_admin_Access,
      kubernetes_config_map.aws_auth
      ]
}

resource "kubernetes_cluster_role_binding" "cluster-viewer" {
  metadata {
    name = "cluster-viewer"
    labels = {
      force_dep = local.fake_dep
    } 
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster-viewer.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = "admin"
    api_group = "rbac.authorization.k8s.io"
  }
  # Wait until the EKS cluster is fully created
  depends_on = [
      module.eks,
      aws_eks_access_entry.Full_role_admin_Access,
      kubernetes_config_map.aws_auth
      ]
}


