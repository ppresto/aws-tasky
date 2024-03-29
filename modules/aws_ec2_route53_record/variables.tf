
# This prefix will be used in your EKS cluster name.
# Update the ./aws_eks/awscli_eks_connect.sh with your EKS cluster name to connect.
variable "name_prefix" {
  description = "Unique name to identify sg"
  type        = string
  default     = "presto"
}

variable "env" { default = "dev" }
# The EKS cluster will be created in this region.
# Update ./aws_eks/awscli_eks_connect.sh with your region value to connect.
variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "route53_zone" {
  description = "My Hosted Zone"
  type        = string
  default     = "my.route53.hosted.zone."
}

variable "route53_zone_id" {
  description = "Zone ID"
  type        = string
  default     = ""
}

variable "route53_record_prefix" {
  description = "Record prefix"
  type        = string
  default     = "ec2"
}

variable "route53_record_ip" {
  description = "Record IP"
  type        = string
  default     = ""
}