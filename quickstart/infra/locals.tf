data "aws_region" "usw2" {}
data "aws_availability_zones" "usw2" {
  state = "available"
}
data "aws_caller_identity" "usw2" {}

data "aws_iam_policy" "ebscsi-usw2" {
  name = "AmazonEBSCSIDriverPolicy"
}

locals {
  # US-WEST-2 DC Configuration
  usw2 = {
    "usw2-shared" = {
      #"name" : "usw2-shared",
      #"region" : "us-west-2",
      "vpc" = {
        "name" : "${var.prefix}-usw2-shared",
        "cidr" : "10.15.0.0/20",
        "private_subnets" : ["10.15.1.0/24", "10.15.2.0/24", "10.15.3.0/24"],
        "public_subnets" : ["10.15.11.0/24", "10.15.12.0/24", "10.15.13.0/24"],
        "routable_cidr_blocks" : ["10.15.0.0/20"]
      },
      "eks" = {
        shared = {
          "cluster_name" : "${var.prefix}-shared-usw2",
          "cluster_version" : var.eks_cluster_version,
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "cluster_endpoint_private_access" : true,
          "cluster_endpoint_public_access" : true,
          "eks_min_size" : 1,
          "eks_max_size" : 3,
          "eks_desired_size" : 1,          # used for pool size
          "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
        },
      },
      "ec2" = {
        "ext-mongodb" = {
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "target_subnets" : "public_subnets",
          "associate_public_ip_address" : true
        }
        "int-mongodb" = {
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "target_subnets" : "private_subnets",
          "associate_public_ip_address" : false
        }
      }
    }
  }
  # HCP Runtime
  # consul_config_file_json_usw2 = jsondecode(base64decode(module.hcp_consul_usw2[local.hvn_list_usw2[0]].consul_config_file))
  # consul_gossip_key_usw2       = local.consul_config_file_json_usw2.encrypt
  # consul_retry_join_usw2       = local.consul_config_file_json_usw2.retry_join

  # Resource location lists used to build other data structures
  tgw_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "tgw")])
  hvn_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "hcp-consul")])
  vpc_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "vpc")])

  # Use HVN cidr block to create routes from VPC to HCP Consul.  Convert to map to support for_each
  hvn_cidrs_list_usw2 = [for env, values in local.usw2 : {
    "hvn" = {
      "cidr" = values.hcp-consul.cidr_block
      "env"  = env
    }
    } if contains(keys(values), "hcp-consul")
  ]
  hvn_cidrs_map_usw2 = { for item in local.hvn_cidrs_list_usw2 : keys(item)[0] => values(item)[0] }

  # create list of objects with routable_cidr_blocks for each vpc and tgw combo. Convert to map.
  vpc_tgw_cidr_usw2 = flatten([for env, values in local.usw2 :
    flatten([for tgw-key, tgw-val in local.tgw_list_usw2 :
      flatten([for cidr in values.vpc.routable_cidr_blocks : {
        "${env}-${tgw-val}-${cidr}" = {
          "tgw_env" = tgw-val
          "vpc_env" = env
          "cidr"    = cidr
        }
        }
      ])
    ])
  ])
  vpc_tgw_cidr_map_usw2 = { for item in local.vpc_tgw_cidr_usw2 : keys(item)[0] => values(item)[0] }

  # create list of routable_cidr_blocks for each internal VPC to add, convert to map
  vpc_routes_usw2 = flatten([for env, values in local.usw2 :
    flatten([for id, routes in local.vpc_tgw_cidr_map_usw2 : {
      "${env}-${routes.tgw_env}-${routes.cidr}" = {
        "tgw_env"    = routes.tgw_env
        "vpc_env"    = routes.vpc_env
        "target_vpc" = env
        "cidr"       = routes.cidr
      }
      } if routes.vpc_env != env
    ])
  ])
  vpc_routes_map_usw2 = { for item in local.vpc_routes_usw2 : keys(item)[0] => values(item)[0] }
  # create list of hvn and tgw to attach them.  Convert to map.
  hvn_tgw_attachments_usw2 = flatten([for hvn in local.hvn_list_usw2 :
    flatten([for tgw in local.tgw_list_usw2 : {
      "hvn-${hvn}-tgw-${tgw}" = {
        "tgw_env" = tgw
        "hvn_env" = hvn
      }
      }
    ])
  ])
  hvn_tgw_attachments_map_usw2 = { for item in local.hvn_tgw_attachments_usw2 : keys(item)[0] => values(item)[0] }

  # Create list of tgw and vpc for attachments.  Convert to map.
  tgw_vpc_attachments_usw2 = flatten([for vpc in local.vpc_list_usw2 :
    flatten([for tgw in local.tgw_list_usw2 :
      {
        "vpc-${vpc}-tgw-${tgw}" = {
          "tgw_env" = tgw
          "vpc_env" = vpc
        }
      }
    ])
  ])
  tgw_vpc_attachments_map_usw2 = { for item in local.tgw_vpc_attachments_usw2 : keys(item)[0] => values(item)[0] }

  # Concat all VPC/Env private_cidr_block lists into one distinct list of routes to add TGW.
  all_routable_cidr_blocks_usw2 = distinct(flatten([for env, values in local.usw2 :
    values.vpc.routable_cidr_blocks
  ]))

  # Create EC2 Resource map per Proj/Env
  ec2_location_usw2 = flatten([for env, values in local.usw2 : {
    "${env}" = values.ec2
    } if contains(keys(values), "ec2")
  ])
  ec2_location_map_usw2 = { for item in local.ec2_location_usw2 : keys(item)[0] => values(item)[0] }
  # Flatten map by EC2 instance and inject Proj/Env.  For_each loop can now build every instance
  ec2_usw2 = flatten([for env, values in local.ec2_location_map_usw2 :
    flatten([for ec2, attr in values : {
      "${env}-${ec2}" = {
        "ec2_ssh_key"                 = attr.ec2_ssh_key
        "target_subnets"              = attr.target_subnets
        "vpc_env"                     = env
        "hostname"                    = ec2
        "associate_public_ip_address" = attr.associate_public_ip_address
        "service"                     = try(attr.service, "default")
        "create_consul_policy"        = try(attr.create_consul_policy, false)
      }
    }])
  ])
  ec2_map_usw2 = { for item in local.ec2_usw2 : keys(item)[0] => values(item)[0] }

  ec2_service_list_usw2 = distinct([for values in local.ec2_map_usw2 : "${values.service}"])

  # Create EKS Resource map per Proj/Env
  eks_location_usw2 = flatten([for env, values in local.usw2 : {
    "${env}" = values.eks
    }
  ])
  eks_location_map_usw2 = { for item in local.eks_location_usw2 : keys(item)[0] => values(item)[0] }
  # Flatten map by eks instance and inject Proj/Env.  For_each loop can now build every instance
  eks_usw2 = flatten([for env, values in local.eks_location_map_usw2 :
    flatten([for eks, attr in values : {
      "${env}-${eks}" = {
        "cluster_name"                    = attr.cluster_name
        "cluster_version"                 = attr.cluster_version
        "ec2_ssh_key"                     = attr.ec2_ssh_key
        "cluster_endpoint_private_access" = attr.cluster_endpoint_private_access
        "cluster_endpoint_public_access"  = attr.cluster_endpoint_public_access
        "eks_min_size"                    = attr.eks_min_size
        "eks_max_size"                    = attr.eks_max_size
        "eks_desired_size"                = attr.eks_desired_size
        "eks_instance_type"               = attr.eks_instance_type
        "vpc_env"                         = env
      }
    }])
  ])
  eks_map_usw2 = { for item in local.eks_usw2 : keys(item)[0] => values(item)[0] }
}