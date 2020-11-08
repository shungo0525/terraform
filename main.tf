provider "aws" {
  profile = "shungo"
  region  = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "aws-tf-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"

  tags = {
    Name = "aws-tf-vpc"
  }
}

# サブネット２つ作成(publicとprivate)
resource "aws_subnet" "aws-tf-public-subnet-1a" {
  vpc_id            = aws_vpc.aws-tf-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "aws-tf-public-subnet-1a"
  }
}

resource "aws_subnet" "aws-tf-private-subnet-1a" {
  vpc_id            = aws_vpc.aws-tf-vpc.id
  cidr_block        = "10.1.20.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "aws-tf-private-subnet-1a"
  }
}

resource "aws_internet_gateway" "aws-tf-igw" {
  vpc_id = aws_vpc.aws-tf-vpc.id
  tags = {
    Name = "aws-tf-igw"
  }
}

resource "aws_route_table" "aws-tf-public-route" {
  vpc_id = aws_vpc.aws-tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws-tf-igw.id
  }
  tags = {
    Name = "aws-tf-public-route"
  }
}

resource "aws_route_table_association" "aws-tf-public-subnet-association" {
  subnet_id      = aws_subnet.aws-tf-public-subnet-1a.id
  route_table_id = aws_route_table.aws-tf-public-route.id
}

resource "aws_instance" "aws-tf-web" {
  ami                     = "ami-0ce107ae7af2e92b5"
  instance_type           = "t2.micro"
  disable_api_termination = false
  key_name = aws_key_pair.auth.key_name
  vpc_security_group_ids  = [aws_security_group.aws-tf-web.id]
  subnet_id               = aws_subnet.aws-tf-public-subnet-1a.id

  tags = {
    Name = "aws-tf-web"
  }
}

# amiとはAmazon Linux 2 AMIです。今回は実際のamiの値を直接入れてますが、いつも最新版にできます。

variable "public_key_path" {}

resource "aws_key_pair" "auth" {
    key_name = "terraform-aws"
    public_key = file(var.public_key_path)
}

resource "aws_security_group" "aws-tf-web" {
  name        = "aws-tf-web"
  description = "aws-tf-web_sg"
  vpc_id      = aws_vpc.aws-tf-vpc.id
  tags = {
    Name = "aws-tf-web"
  }
}

# 80番ポート許可のインバウンドルール
resource "aws_security_group_rule" "inbound_http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

# 22番ポート許可のインバウンドルール
resource "aws_security_group_rule" "inbound_ssh" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

# アウトバウンドルール
resource "aws_security_group_rule" "outbound_all" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = -1
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

resource "aws_eip" "aws-tf-eip" {
  instance = aws_instance.aws-tf-web.id
  vpc      = true
}
output "example-public-ip" {
    value = "${aws_eip.aws-tf-eip.public_ip}"
}

# RDS用のサブネットを作成
resource "aws_subnet" "aws-tf-private-subnet-1c" {
  vpc_id = aws_vpc.aws-tf-vpc.id
  cidr_block = "10.1.3.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "aws-tf-private-subnet-1c"
  }
}
# 使用する２つを指定します。
resource "aws_db_subnet_group" "rdb-tf-db" {
    name        = "rdb-tf-db-subnet"
    description = "It is a DB subnet group on tf_vpc."
    subnet_ids  = [aws_subnet.aws-tf-private-subnet-1a.id,aws_subnet.aws-tf-private-subnet-1c.id]
    tags = {
        Name = "rdb-tf-db"
    }
}

# Security Group
resource "aws_security_group" "aws-tf-db" {
    name        = "aws-tf-db"
    description = "aws-tf-db-sg"
    vpc_id      = aws_vpc.aws-tf-vpc.id
    tags = {
      Name = "aws-tf-db"
    }
}

resource "aws_security_group_rule" "db" {
    type                     = "ingress"
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.aws-tf-web.id
    security_group_id        = aws_security_group.aws-tf-db.id
}

# source_security_group_idとはアクセスを許可するセキュリティグループIDつまりWeb側のセキュリティグループを指します。

resource "aws_db_instance" "aws-td-db" {
  identifier              = "aws-td-db"
  allocated_storage       = 20
  name                    = "db11"
  engine                  = "postgres"
  engine_version          = "11.5"
  instance_class          = "db.t2.micro"
  storage_type            = "gp2"
  username                = "test"
  password                = "password"
  vpc_security_group_ids  = [aws_security_group.aws-tf-db.id]
  db_subnet_group_name    = aws_db_subnet_group.rdb-tf-db.name
}
