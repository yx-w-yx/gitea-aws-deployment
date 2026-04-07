# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gitea-vpc"
  }
}

# 公有子网
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "gitea-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gitea-igw"
  }
}

# 路由表
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gitea-public-rt"
  }
}

# 路由表关联
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2 (Gitea)
resource "aws_security_group" "gitea" {
  name        = "gitea-sg"
  description = "Security group for Gitea server"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Gitea web interface
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 所有出站流量允许
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitea-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "gitea-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  # 只允许EC2的Security Group访问
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.gitea.id]
  }

  tags = {
    Name = "gitea-rds-sg"
  }
}

# RDS需要至少两个子网，创建第二个
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "gitea-public-subnet-2"
  }
}

# RDS子网组
resource "aws_db_subnet_group" "main" {
  name       = "gitea-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.public2.id]

  tags = {
    Name = "gitea-db-subnet-group"
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "gitea" {
  identifier             = "gitea-db"
  engine                 = "postgres"
  engine_version         = "16.6"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "gitea"
  username               = "gitea"
  password               = "Gitea1234!"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = {
    Name = "gitea-db"
  }
}
# EC2实例
resource "aws_instance" "gitea" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.gitea.id]
  key_name               = "vockey"

  tags = {
    Name = "gitea-server"
  }
}

# 输出EC2公网IP
output "gitea_public_ip" {
  value = aws_instance.gitea.public_ip
}

# 输出RDS地址
output "rds_endpoint" {
  value = aws_db_instance.gitea.address
}
# CloudWatch CPU告警
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "gitea-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "EC2 CPU usage exceeds 80%"

  dimensions = {
    InstanceId = aws_instance.gitea.id
  }

  tags = {
    Name = "gitea-ec2-cpu-alarm"
  }
}

# CloudWatch RDS CPU告警
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "gitea-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU usage exceeds 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.gitea.id
  }

  tags = {
    Name = "gitea-rds-cpu-alarm"
  }
}

# CloudWatch RDS存储空间告警
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "gitea-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "5000000000"
  alarm_description   = "RDS free storage below 5GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.gitea.id
  }

  tags = {
    Name = "gitea-rds-storage-alarm"
  }
}