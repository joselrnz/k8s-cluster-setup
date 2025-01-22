resource "aws_instance" "master" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.private_subnet_id
  security_groups = [var.control_plane_sg_id]
  key_name        = var.key_name
  tags = {
    Name = "k8s-master"
  }
}

resource "aws_instance" "worker" {
  count           = 2
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.private_subnet_id
  security_groups = [var.worker_sg_id]
  key_name        = var.key_name
  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }
}
