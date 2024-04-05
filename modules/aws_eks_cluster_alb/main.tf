# EBS Policy to enable ebs csi driver for persistant volume claims
data "aws_iam_policy" "ebscsi" {
  name = "AmazonEBSCSIDriverPolicy"
}

# Create EKS cluster
module "eks" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"
  #version = "19.10.0"

  cluster_name                             = var.cluster_name
  cluster_version                          = var.cluster_version
  cluster_endpoint_private_access          = var.cluster_endpoint_private_access
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_service_ipv4_cidr                = var.cluster_service_ipv4_cidr
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.subnet_ids
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  access_entries = {
    # One access entry with a policy associated
    test-admin = {
      kubernetes_groups = [""]
      principal_arn     = "arn:aws:iam::729755634065:role/aws_ppresto_test-admin"

      policy_associations = {
        first = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  cluster_addons = {
    #coredns = {
    #  resolve_conflicts = "OVERWRITE"
    #}
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      #addon_version = "v1.13.3-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      most_recent = true
      #service_account_role_arn = data.aws_iam_policy.ebscsi.arn
      #addon_version = "v1.21.0-eksbuild.1"
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }
  create_kms_key = true

  cluster_security_group_additional_rules = {
    # Allow other Internally routable CIDRs ingress access to cluster
    "${var.cluster_name}_ingress_routable_cidrs" = {
      description = "Ingress from cluster routable networks"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = concat(var.all_routable_cidrs)
    }
  }

  node_security_group_additional_rules = {
    "${var.cluster_name}_ingress_self_all" = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    "${var.cluster_name}_ingress_cluster_all" = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 50
    instance_types = [var.instance_type]

    iam_role_additional_policies = {
      additional = data.aws_iam_policy.ebscsi.arn
    }
  }
  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default_node_group = {
      # Remote access cannot be specified with a launch template
      # remote_access = {
      #   ec2_ssh_key               = var.ec2_key_pair_name
      #   source_security_group_ids = [module.sg-consul-dataplane-usw2[each.key].securitygroup_id]
      # }
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size
    }
  }
}