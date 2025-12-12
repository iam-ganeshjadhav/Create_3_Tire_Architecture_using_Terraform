variable "my_ami" {
  default = "ami-00ca570c1b6d79f36"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "pvt_cidr" {
  default = "10.0.0.0/20"
}

variable "az1" {
  default = "ap-south-1a"
}

variable "pub_cidr" {
  default = "10.0.16.0/20"
}


variable "az2" {
  default = "ap-south-1b"
}

variable "Project_name" {
  default = "fct"
}

variable "igw_cidr" {
  default = "0.0.0.0/0"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_pair" {
  default = "jenkinsmumbai"
}

variable "pvt_cidr2" {
  default = "10.0.32.0/20"
}

variable "db_instance_type" {
  type = string
  default = "db.t3.micro"

}

variable "db_username" {
  default = "root"
  
}

variable "db_password" {
  default = "Ganesh9075"
}
