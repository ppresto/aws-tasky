# Create usw2 VPCs defined in local.usw2
module "vpc-usw2" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  providers = {
    aws = aws.usw2
  }
  source                   = "terraform-aws-modules/vpc/aws"
  version                  = "~> 3.0"
  for_each                 = local.usw2
  name                     = try(local.usw2[each.key].vpc.name, "${var.prefix}-${each.key}-vpc")
  cidr                     = local.usw2[each.key].vpc.cidr
  azs                      = [data.aws_availability_zones.usw2.names[0], data.aws_availability_zones.usw2.names[1]]
  private_subnets          = local.usw2[each.key].vpc.private_subnets
  public_subnets           = local.usw2[each.key].vpc.public_subnets
  enable_nat_gateway       = true
  single_nat_gateway       = true
  enable_dns_hostnames     = true
  enable_ipv6              = false
  default_route_table_name = "${var.prefix}-${each.key}-vpc1"

  # Cloudwatch log group and IAM role will be created
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  flow_log_max_aggregation_interval         = 60
  flow_log_cloudwatch_log_group_name_prefix = "/aws/${local.usw2[each.key].vpc.name}"
  flow_log_cloudwatch_log_group_name_suffix = "flow"

  tags = {
    Terraform  = "true"
    Owner      = "${var.prefix}"
    transit_gw = "true"
  }
  private_subnet_tags = {
    Tier                                                                                       = "Private"
    "kubernetes.io/role/internal-elb"                                                          = 1
    "kubernetes.io/cluster/${try(local.usw2.usw2-shared.eks.shared.cluster_name, var.prefix)}" = "shared"
    "kubernetes.io/cluster/${try(local.usw2.usw2-shared.eks.new.cluster_name, var.prefix)}"    = "shared"
  }
  public_subnet_tags = {
    Tier                                                                                     = "Public"
    "kubernetes.io/role/elb"                                                                 = 1
    "kubernetes.io/cluster/${try(local.usw2[each.key].eks.shared.cluster_name, var.prefix)}" = "shared"
    "kubernetes.io/cluster/${try(local.usw2.usw2-shared.eks.new.cluster_name, var.prefix)}"  = "shared"
  }
  default_route_table_tags = {
    Name = "${var.prefix}-vpc1-default"
  }
  private_route_table_tags = {
    Name = "${var.prefix}-vpc1-private"
  }
  public_route_table_tags = {
    Name = "${var.prefix}-vpc1-public"
  }
}

# Create EKS cluster per VPC defined in local.usw2
module "eks-usw2" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  providers = {
    aws = aws.usw2
  }
  source                          = "../../modules/aws_eks_cluster"
  for_each                        = local.eks_map_usw2
  cluster_name                    = try(local.eks_map_usw2[each.key].cluster_name, local.name)
  cluster_version                 = try(local.eks_map_usw2[each.key].eks_cluster_version, var.eks_cluster_version)
  cluster_endpoint_private_access = try(local.eks_map_usw2[each.key].cluster_endpoint_private_access, true)
  cluster_endpoint_public_access  = try(local.eks_map_usw2[each.key].cluster_endpoint_public_access, true)
  cluster_service_ipv4_cidr       = try(local.eks_map_usw2[each.key].service_ipv4_cidr, "172.20.0.0/16")
  min_size                        = try(local.eks_map_usw2[each.key].eks_min_size, var.eks_min_size)
  max_size                        = try(local.eks_map_usw2[each.key].eks_max_size, var.eks_max_size)
  desired_size                    = try(local.eks_map_usw2[each.key].eks_desired_size, var.eks_desired_size)
  instance_type                   = try(local.eks_map_usw2[each.key].eks_instance_type, null)
  vpc_id                          = module.vpc-usw2[each.value.vpc_env].vpc_id
  subnet_ids                      = module.vpc-usw2[each.value.vpc_env].private_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_usw2
  #hcp_cidr                        = local.all_routable_cidr_blocks_usw2
}

module "ec2_profile_mongo" {
  providers = {
    aws = aws.usw2
  }
  for_each = local.ec2_map_usw2
  source    = "../../modules/aws_ec2_iam_profile"
  role_name = "${each.value.hostname}-ec2-role"
  s3_bucket_arn = module.mongod-s3-backup[each.key].bucket_arn
}
module "aws-ec2-usw2" {
  providers = {
    aws = aws.usw2
  }
  source   = "../../modules/aws_ec2"
  for_each = local.ec2_map_usw2

  hostname                        = local.ec2_map_usw2[each.key].hostname
  ec2_key_pair_name               = local.ec2_map_usw2[each.key].ec2_ssh_key
  vpc_id                          = module.vpc-usw2[each.value.vpc_env].vpc_id
  prefix                          = var.prefix
  associate_public_ip_address     = each.value.associate_public_ip_address
  subnet_id                       = each.value.target_subnets == "public_subnets" ? module.vpc-usw2[each.value.vpc_env].public_subnets[0] : module.vpc-usw2[each.value.vpc_env].private_subnets[0]
  security_group_ids              = [module.sg-mongod-usw2[each.value.vpc_env].securitygroup_id]
  instance_profile_name           = module.ec2_profile_mongo[each.key].instance_profile_name
  allowed_bastion_cidr_blocks     = var.allowed_bastion_cidr_blocks
  bucket_name                     = module.mongod-s3-backup[each.key].bucket_name
}

module "sg-mongod-usw2" {
  providers = {
    aws = aws.usw2
  }
  source = "../../modules/aws_ec2_sg_mongod"
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "ec2") }
  security_group_create = true
  name_prefix           = "${each.key}-ec2-sg"
  vpc_id                = module.vpc-usw2[each.key].vpc_id
  vpc_cidr_blocks     = local.all_routable_cidr_blocks_usw2
  private_cidr_blocks = local.all_routable_cidr_blocks_usw2
}

module "mongod-s3-backup" {
  providers = {
    aws = aws.usw2
  }
  source = "../../modules/aws_s3_bucket_public"
  for_each = local.ec2_map_usw2
  bucket_name           = "${each.value.hostname}-s3-backup"
  bucket_ownership_controls = "BucketOwnerPreferred"
}