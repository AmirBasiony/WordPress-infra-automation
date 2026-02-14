#############################################
# helm provider (UPDATED)
#############################################
# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

#     exec {
#       command     = "aws"
#       api_version = "client.authentication.k8s.io/v1beta1"
#       args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
#     }
#   }
# }
provider "helm" {
  kubernetes {
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
}


#############################################
# VPC
#############################################
data "aws_availability_zones" "azs" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = var.name
  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.azs.names
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

#############################################
# EKS Cluster (UPDATED)
#############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name                   = var.name
  cluster_version                = var.k8s_version
  cluster_endpoint_public_access = true

  # keep this ON so your current identity can reach the cluster initially
  enable_cluster_creator_admin_permissions = false
  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # RECOMMENDED: let the module manage SGs unless you are explicitly managing them
  create_cluster_security_group = true
  create_node_security_group    = true

  eks_managed_node_groups = {
    dev = {
      min_size       = 2
      desired_size   = 2
      max_size       = 2
      instance_types = ["t3.medium"]
    }
    iam_role_additional_policies = {
      ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    }
  }

  tags = var.tags
}

#############################################
# EKS Blueprints Addons (UPDATED depends_on)
#############################################
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "${var.name}-ebs-csi-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}


module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

      timeouts = {
        create = "40m"
        update = "40m"
        delete = "40m"
      }
    }

    coredns    = { most_recent = true }
    vpc-cni    = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true

  # CRITICAL: ensure the cluster is reachable first
  # - aws-auth must exist so nodes can join
  # - access entries ensure your runner identity can authenticate
  depends_on = [
    module.eks,
    kubernetes_config_map_v1_data.aws_auth,

    aws_eks_access_entry.github_actions,
    aws_eks_access_policy_association.github_actions_admin,

    aws_eks_access_entry.amir,
    aws_eks_access_policy_association.amir_admin,
  ]
  
}
