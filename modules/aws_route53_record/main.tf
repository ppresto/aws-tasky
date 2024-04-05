resource "aws_route53_record" "ec2-record" {
  zone_id = var.route53_zone_id
  name    = "${var.route53_record_prefix}.${var.route53_zone}"
  type    = "A"
  ttl     = "300"
  records = [var.route53_record_ip]
  #[module.aws-ec2-usw2["usw2-shared-ext-mongodb"].ec2_ip_private]
}