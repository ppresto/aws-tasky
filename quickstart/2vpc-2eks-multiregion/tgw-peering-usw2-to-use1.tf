# Create the intra-region Peering Attachment from Gateway 1 to Gateway 2.
# Actually, this will create two peerings: one for Gateway 1 (Creator)
# and one for Gateway 2 (Acceptor).
resource "aws_ec2_transit_gateway_peering_attachment" "example_source_peering" {
  #count = var.peer_transit_gateways == false ? 0 : 1
  provider                = aws.usw2
  transit_gateway_id      = module.tgw-usw2[local.tgw_list_usw2[0]].ec2_transit_gateway_id
  peer_region             = data.aws_region.use1.name
  peer_transit_gateway_id = module.tgw-use1[local.tgw_list_use1[0]].ec2_transit_gateway_id
  tags = {
    Name          = "${local.tgw_list_usw2[0]}-tgw_to_${local.tgw_list_use1[0]}-tgw"
    SourceGateway = "${local.tgw_list_usw2[0]}"
    PeerGateway   = "${local.tgw_list_use1[0]}"
  }
}

# Transit Gateway 2's peering request needs to be accepted.
# So, we fetch the Peering Attachment that is created for the Gateway 2.
data "aws_ec2_transit_gateway_peering_attachment" "example_accepter_peering_data" {
  filter {
    name   = "transit-gateway-id"
    values = [module.tgw-use1[local.tgw_list_use1[0]].ec2_transit_gateway_id]
  }
  depends_on = [aws_ec2_transit_gateway_peering_attachment.example_source_peering]
}

# Accept the Attachment Peering request.
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "example_accepter" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_peering_attachment.example_accepter_peering_data.id
  #transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.example_source_peering.id
  tags = {
    Name = "terraform-example-tgw-peering-accepter"
    Side = "Acceptor"
  }
  #depends_on = [data.aws_ec2_transit_gateway_peering_attachment.example_accepter_peering_data]
}

# Create usw2 routes in the use1 transit gateway route table
resource "aws_ec2_transit_gateway_route" "use1" {
  provider                       = aws.use1
  for_each                       = local.tgw_vpc_attachments_map_usw2
  destination_cidr_block         = local.usw2[each.value.vpc_env].vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.example_source_peering.id
  transit_gateway_route_table_id = module.tgw-use1[local.tgw_list_use1[0]].ec2_transit_gateway_association_default_route_table_id
  depends_on                     = [module.tgw_vpc_attach_use1, aws_ec2_transit_gateway_peering_attachment.example_source_peering]
}
# Create use1 routes in the usw2 transit gateway route table
resource "aws_ec2_transit_gateway_route" "usw2" {
  provider                       = aws.usw2
  for_each                       = local.tgw_vpc_attachments_map_use1
  destination_cidr_block         = local.use1[each.value.vpc_env].vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.example_source_peering.id
  transit_gateway_route_table_id = module.tgw-usw2[local.tgw_list_usw2[0]].ec2_transit_gateway_association_default_route_table_id
  depends_on                     = [module.tgw_vpc_attach_usw2, aws_ec2_transit_gateway_peering_attachment.example_source_peering]
}

# Create private use1 subnet route to reach remote usw2 VPC through tgw.
module "route_add_usw2_to_use1_private_subnet" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.use1
  }
  route_table_id         = module.vpc-use1["use1-shared"].private_route_table_ids[0]
  destination_cidr_block = local.usw2["usw2-shared"].vpc.cidr
  transit_gateway_id     = module.tgw-use1["use1-shared"].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_use1]
}

# Create private usw2 subnet route to reach remote use1 VPC through tgw.
module "route_add_use1_to_usw2_private_subnet" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.usw2
  }
  route_table_id         = module.vpc-usw2["usw2-shared"].private_route_table_ids[0]
  destination_cidr_block = local.use1["use1-shared"].vpc.cidr
  transit_gateway_id     = module.tgw-usw2["usw2-shared"].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_usw2]
}

output "tgw_peering_attachment_tags" {
  value = aws_ec2_transit_gateway_peering_attachment.example_source_peering.tags_all
  #depends_on = [data.aws_ec2_transit_gateway_peering_attachment.example_accepter_peering_data]
}