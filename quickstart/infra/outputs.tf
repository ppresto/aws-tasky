output "usw2_regions" {
  value = { for k, v in local.usw2 : k => data.aws_region.usw2.name }
}
output "usw2_projects" { # Used by ./scripts/kubectl_connect_eks.sh to loop through Proj/Env and Auth to EKS clusters
  value = [for proj in sort(keys(local.usw2)) : proj]
}
# VPC
output "usw2_vpc_ids" {
  value = { for env in sort(keys(local.usw2)) : env => module.myvpc[env].vpc_id }
}

output "usw2_eks_cluster_endpoints" {
  description = "Endpoint for your Kubernetes API server"
  value       = { for k, v in local.usw2 : k => module.eks-usw2.cluster_endpoint if contains(keys(v), "eks") }
}
output "usw2_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.usw2 : k => local.usw2[k].eks.shared.cluster_name if contains(keys(v), "eks") }
}

output "usw2_ec2_ip" {
  value = { for k, v in local.ec2_map_usw2 : k => module.ec2[k].ec2_ip }
}

output "usw2_ec2_route53_records" {
  value = { for k, v in local.ec2_map_usw2 : k => module.route53_record[k].record }
}

output "bucket_url" {
  value = { for k, v in local.ec2_map_usw2 : k => "http://${module.s3-mongo[k].bucket_name}.s3.us-west-2.amazonaws.com" }
}