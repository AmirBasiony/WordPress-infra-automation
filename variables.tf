variable aws_region {
  default = "us-east-1"
}

variable k8s_version {
    default = "1.32"
}
variable "name" {
  default = "amir-wordpress-eks"
}

variable "tags" {
  default = {
    App = "amir-wordpress-eks-cluster"
  }
}

variable vpc_cidr_block {
    default = "10.0.0.0/16"
}
variable private_subnet_cidr_blocks {
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable public_subnet_cidr_blocks {
    default = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}


# variable user_for_admin_role {}
# variable user_for_dev_role {}
# variable user_for_FullAdminAccess {}