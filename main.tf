provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "terravpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terravpc"
  }
}

resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.terravpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "publicsubnet"
  }
}

resource "aws_subnet" "privatesubnet" {
  vpc_id     = aws_vpc.terravpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privatesubnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terravpc.id

  tags = {
    Name = "terra vpc igw"
  }
}

resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.terravpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public route table"
  }
}

resource "aws_route_table_association" "public-rta" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.publicrt.id
}

resource "aws_eip" "terraeip" {
  vpc = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.terraeip.id
  subnet_id     = aws_subnet.publicsubnet.id

  tags = {
    Name = "gw NAT"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "privatert" {
  vpc_id = aws_vpc.terravpc.id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "private route table"
  }
}

resource "aws_route_table_association" "private-rta" {
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.privatert.id
}

resource "aws_security_group" "terra_pubsec" {
  name        = "allow_terra_sec"
  description = "Allow all inbound traffic from VPC"
  vpc_id      = aws_vpc.terravpc.id

  ingress {
    description = "Allow all TCP traffic from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "terra_prisec" {
  name        = "limited_terra_sec"
  description = "Allow limited inbound traffic"
  vpc_id      = aws_vpc.terravpc.id

  ingress {
    description = "Allow SSH from public subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Allow HTTP from public subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Allow HTTPS from public subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow public to private"
  }
}

resource "aws_instance" "pubinstance" {
  ami                     = "ami-0e86e20dae9224db8"
  instance_type           = "t2.micro"
  availability_zone       = "us-east-1a"
  associate_public_ip_address = true
  vpc_security_group_ids  = [aws_security_group.terra_pubsec.id]
  subnet_id               = aws_subnet.publicsubnet.id
  key_name                = "key"  # Changed to the key file name "key"

  tags = {
    Name = "TERRA WEBSERVER"
  }
}

resource "aws_instance" "priinstance" {
  ami                     = "ami-0e86e20dae9224db8"
  instance_type           = "t2.micro"
  availability_zone       = "us-east-1f"
  associate_public_ip_address = false
  vpc_security_group_ids  = [aws_security_group.terra_prisec.id]
  subnet_id               = aws_subnet.privatesubnet.id
  key_name                = "key"  # Changed to the key file name "key"

  tags = {
    Name = "TERRA APPSERVER"}
}
