# CLuster Info
output "cluster_name" {
  description = "The name of the EKS cluster"
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value = module.eks.cluster_endpoint
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value = module.eks.cluster_status
}

# Kubectl Configuration
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --alias ${module.eks.cluster_name}"
}

output "aws_region" {
  description = "AWS region where the EKS cluster is deployed"
  value = var.aws_region
}

output "github_actions_role" {
  description = "GitHub actions role for accessing the EKS cluster"
  value = data.aws_iam_role.github_actions_role.arn
}

output "external_admin_role" {
  description = "ARN of the external admin IAM role"
  value = data.aws_iam_user.k8s-admin.arn
}
output "external_developer_role" {
  description = "ARN of the external developer IAM role"
  value = data.aws_iam_user.k8s-developer.arn
}

output "node_group_iam_role_arn" {
  value = module.eks.eks_managed_node_groups["dev"].iam_role_arn
}

output "eso_wp_role_arn" {
  value = data.aws_iam_role.eso_wp_role.arn
}
