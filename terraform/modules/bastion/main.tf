resource "aws_security_group" "bastion_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.bastion_sg.id]
  key_name        = var.key_name
  tags = {
    Name = "bastion-host"
  }
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}
