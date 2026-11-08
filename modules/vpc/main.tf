locals {
  # Subnets are addressed by availability zone name, not list position. Adding or
  # removing a zone then never reshuffles the other subnets (for_each, not count).
  zone_index = { for index, zone in var.availability_zones : zone => index }

  # Zones that get a NAT gateway: none, the first zone only, or every zone.
  nat_gateway_zones = var.enable_nat_gateway ? (
    var.single_nat_gateway ? slice(var.availability_zones, 0, 1) : var.availability_zones
  ) : []
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = var.name })
}

# Adopt the default security group and strip every rule so nothing can use it by accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default-unused" })
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.zone_index

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr_block, var.subnet_newbits, each.value)
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.zone_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr_block, var.subnet_newbits, each.value + var.private_subnet_offset)

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# Public routing: one shared route table, default route to the internet gateway
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# NAT gateways (optional)
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_zones)

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "egress" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Private routing: one route table per zone so each can use its own NAT gateway
# ---------------------------------------------------------------------------

resource "aws_route_table" "private" {
  for_each = local.zone_index

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.zone_index : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.egress[var.single_nat_gateway ? var.availability_zones[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
