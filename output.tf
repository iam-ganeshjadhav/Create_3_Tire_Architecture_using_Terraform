#public ip  frontend
output "public_ip" {
  value = aws_instance.frontend.public_ip
  
}

#public ip backend
output "pvt_ip" {
  value = aws_instance.backend.private_ip
}

#rds end point
output "endpoint" {
  value = aws_db_instance.mydb.endpoint
}

