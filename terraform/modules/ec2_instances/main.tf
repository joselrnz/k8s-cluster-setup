resource "aws_instance" "master" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.private_subnet_id
  security_groups = [var.control_plane_sg_id]
  key_name        = var.key_name
  iam_instance_profile = var.instance_profile
  tags = {
    Name = "k8s-master"
  }
}

resource "aws_instance" "worker" {
  count           = 2
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.private_subnet_id
  iam_instance_profile = var.instance_profile
  security_groups = [var.worker_sg_id]
  key_name        = var.key_name
  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }
}

output "master_ip" {
  value = aws_instance.master.private_ip
}

output "worker_ips" {
  value = [for instance in aws_instance.worker : instance.private_ip]
}