provider "helm" {
  kubernetes{
    host    = module.eks.cluster_endpoint // EKS cluster endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) // Base64 encoded CA certificate for the cluster

    exec {
        command = "aws" // Command to execute for authentication
        api_version = "client.authentication.k8s.io/v1beta1" // API version for the authentication
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region ]
    } 
  }
}
# VPC for Cluster
data "aws_availability_zones" "azs" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = var.name
  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.azs.names
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks

  # Enable NAT Gateway for private subnets and DNS hostnames for the VPC.
  enable_nat_gateway = true
  single_nat_gateway = true
  
  # Tags are used to reference components from other AWS resources.
  # These tags help the Cloud Controller Manager (CCM) from AWS
  # identify the correct VPCs and subnets for the cluster.
  public_subnet_tags = {
    # This tag is used to indicate that the public subnets can be used for external load balancers.
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    # This tag indicates that the private subnets can be used for internal load balancers.
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name                   = var.name
  cluster_version                = var.k8s_version
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  create_node_security_group    = false
  
  eks_managed_node_groups = {
    dev = {
      min_size     = 1
      desired_size = 1
      max_size     = 2
      instance_types = ["t3.medium"]
    }
  }

  tags = var.tags
}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller    = true
  enable_cluster_autoscaler              = true
  enable_metrics_server                  = true
  # enable_kube_prometheus_stack           = true
}

