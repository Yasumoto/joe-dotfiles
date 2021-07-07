resource "aws_vpc" "main" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.31.0.0/20"
  availability_zone = "us-west-2c"

  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_subnet" "second" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.31.48.0/20"
  availability_zone = "us-west-2d"

  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_subnet" "third" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.31.16.0/20"
  availability_zone = "us-west-2a"

  tags = {
    terraform = true
    Name      = "main"
  }
}

resource "aws_subnet" "fourth" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.31.32.0/20"
  availability_zone = "us-west-2b"

  map_public_ip_on_launch = true

  tags = {
    terraform = true
    Name      = "main"
  }
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
