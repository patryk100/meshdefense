terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Private Hosted Zone for Air-Gapped Internal DNS
# --------------------------------------------------------------------------------------------------
resource "aws_route53_zone" "internal" {
  name = var.internal_domain

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-internal-dns"
  })
}

# --------------------------------------------------------------------------------------------------
# Route 53 DNS Alias Records for Internal Ingress Gateway & Big Bang Services (Story 3.3)
# --------------------------------------------------------------------------------------------------
resource "aws_route53_record" "ingress_wildcard_apps" {
  count   = var.enable_ingress_dns_alias ? 1 : 0
  zone_id = aws_route53_zone.internal.zone_id
  name    = "*.apps.${var.internal_domain}"
  type    = "A"

  alias {
    name                   = var.ingress_nlb_dns_name
    zone_id                = var.ingress_nlb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ingress_wildcard_root" {
  count   = var.enable_ingress_dns_alias ? 1 : 0
  zone_id = aws_route53_zone.internal.zone_id
  name    = "*.${var.internal_domain}"
  type    = "A"

  alias {
    name                   = var.ingress_nlb_dns_name
    zone_id                = var.ingress_nlb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ingress_apex" {
  count   = var.enable_ingress_dns_alias ? 1 : 0
  zone_id = aws_route53_zone.internal.zone_id
  name    = var.internal_domain
  type    = "A"

  alias {
    name                   = var.ingress_nlb_dns_name
    zone_id                = var.ingress_nlb_zone_id
    evaluate_target_health = true
  }
}

# --------------------------------------------------------------------------------------------------
# VPC Endpoints for Completely Disconnected IL6 Operation
# (Allows access to AWS internal APIs without NAT Gateway or Internet Gateway)
# --------------------------------------------------------------------------------------------------
locals {
  services = [
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "kms",
    "s3",
    "ssm",
    "ssmmessages",
    "sts",
    "logs",
    "monitoring",
    "secretsmanager",
    "sqs",
    "eks",
    "eks-auth",
    "elasticloadbalancing"
  ]
}


resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpc-endpoints-sg"
  description = "Security group for internal VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

data "aws_vpc_endpoint_service" "interface" {
  for_each     = toset([for s in local.services : s if s != "s3"])
  service      = each.key
  service_type = "Interface"
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset([for s in local.services : s if s != "s3"])

  vpc_id              = var.vpc_id
  service_name        = data.aws_vpc_endpoint_service.interface[each.key].service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.environment}-vpce-${each.key}"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, {
    Name = "${var.environment}-vpce-s3"
  })
}
