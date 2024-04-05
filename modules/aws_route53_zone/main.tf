resource "aws_route53_zone" "private" {
  name = var.route53_zone

  vpc {
    vpc_id = var.vpc_id
  }
}