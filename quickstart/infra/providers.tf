provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}
terraform {
  required_version = ">= 1.3.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.17.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks-usw2.cluster_name
}

provider "kubectl" {
  host                   = module.eks-usw2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks-usw2.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
  load_config_file       = false
}