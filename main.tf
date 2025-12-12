#tfstate file add to s3
terraform {
  backend "s3" {
    bucket = "terraform-state-file-07"  #s3 bucket name 
    key = "terraform.tfstate"   #state file path
    region = "ap-south-1"      #bucket region 
  }
}

#provider block
provider "aws" {
  region = "ap-south-1"
}
#create a vpc
resource "aws_vpc" "my-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.Project_name}-vpc"
  }
}

#create a private subnet for backend
resource "aws_subnet" "pvt-sub1" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = var.pvt_cidr
  availability_zone = var.az1
  tags = {
    Name = "${var.Project_name}-PVT-Subnet-backend"
  }
  
}

#create a private subnet for database 
resource "aws_subnet" "pvt-sub2" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = var.pvt_cidr2
  availability_zone = var.az2
  tags = {
     Name = "${var.Project_name}-PVT-Subnet-database"
  }
  
}

#create a public subnet for frontend 
resource "aws_subnet" "pub-sub" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = var.pub_cidr
  availability_zone = var.az2
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.Project_name}-PUB-Subnet-frontend"
  }
}

#create a igw 
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
     Name = "${var.Project_name}-IGW"
  }
}

#create a route table
resource "aws_default_route_table" "main-rt" {
  default_route_table_id = aws_vpc.my-vpc.default_route_table_id
  tags = {
     Name = "${var.Project_name}-main-rt"
  }
}

#create an EIP
resource "aws_eip" "nat-eip" {
  domain = "vpc"

  tags = {
    Name = "${var.Project_name}-nat-eip"
      }
  
  
}

#create nat gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id = aws_subnet.pub-sub.id

  tags = {
    Name = "${var.Project_name}-natgw"
  }
    
}

#custome route table
resource "aws_route_table" "pvt-rt" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "${var.Project_name}-pvt-rt"
  }
   
}

resource "aws_route" "private_route" {
  route_table_id = aws_route_table.pvt-rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.natgw.id
  
}

#pvt route table association
resource "aws_route_table_association" "backend_asso" {
  subnet_id = aws_subnet.pvt-sub1.id
  route_table_id = aws_route_table.pvt-rt.id
}

resource "aws_route_table_association" "db_asso" {
  subnet_id = aws_subnet.pvt-sub2.id
  route_table_id = aws_route_table.pvt-rt.id
}


#add route in main route table 
resource "aws_route" "aws-route" {
  route_table_id = aws_default_route_table.main-rt.id
  destination_cidr_block = var.igw_cidr
  gateway_id = aws_internet_gateway.my-igw.id 
  
}

#association 
resource "aws_route_table_association" "pub-association" {
  subnet_id = aws_subnet.pub-sub.id
  route_table_id = aws_default_route_table.main-rt.id
}

#frontend security group
resource "aws_security_group" "frontend-sg" {
  name = "${var.Project_name}-frontend-sg"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    to_port = 80
    from_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    to_port = 22
    from_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#backend security group
resource "aws_security_group" "backend-sg" {
  name = "${var.Project_name}-backend-sg"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    to_port = 8080
    from_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.frontend-sg.id]
  }

  ingress {
    to_port = 22
    from_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [ aws_security_group.frontend-sg ]
}

#db security

resource "aws_security_group" "db-sg" {
  name = "${var.Project_name}-db-sg"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    to_port = 3306
    from_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.backend-sg.id]  
  }

  egress {
    to_port = 0
    from_port = 0
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }  
  depends_on = [ aws_security_group.backend-sg ]
}

#frontend ec2
resource "aws_instance" "frontend" {
  ami = var.my_ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.pub-sub.id
  vpc_security_group_ids = [aws_security_group.frontend-sg.id]
  key_name = var.key_pair
  associate_public_ip_address = true
  tags = {
    Name = "${var.Project_name}-frontend"
  }
  depends_on = [ aws_security_group.frontend-sg]
}

#backend ec2
resource "aws_instance" "backend" {
  ami = var.my_ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.pvt-sub1.id
  vpc_security_group_ids = [aws_security_group.backend-sg.id]
  key_name = var.key_pair
  tags = {
    Name = "${var.Project_name}-backend"
  }
  depends_on = [ aws_security_group.backend-sg ]
}

#subnet group
resource "aws_db_subnet_group" "db-subnet" {
  name = "fct_dbsubnet"
  subnet_ids = [aws_subnet.pvt-sub1.id , aws_subnet.pvt-sub2.id]

  tags = {
    Name = "${var.Project_name}-db-subnet"
  }
}

#database
resource "aws_db_instance" "mydb" {
  identifier = "${var.Project_name}-mydb"
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_type
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db-subnet.name
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  publicly_accessible = false
  skip_final_snapshot  = true

  tags = {
    Name = "${var.Project_name}-rds"
  }
}


