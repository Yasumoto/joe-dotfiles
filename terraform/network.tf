module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.47"

  name                 = local.cluster_name
  cidr                 = "172.31.0.0/16"
  azs                  = ["us-west-1a", "us-west-1b", "us-west-1c", "us-west-1d"]
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.31.0.0/20", "172.31.16.0/20", "172.31.32.0/20", "172.31.48.0/20"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  })

  private_subnet_tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  })

  tags = local.tags
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_route_table_association" "main-subnet-association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "second-subnet-association" {
  subnet_id      = aws_subnet.second.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "public-main-subnet-association" {
  subnet_id      = aws_subnet.third.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "public-second-subnet-association" {
  subnet_id      = aws_subnet.fourth.id
  route_table_id = aws_route_table.main.id
}
