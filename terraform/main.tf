module "network" {
  source = "./modules/network"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "bastion" {
  source            = "./modules/bastion"
  vpc_id            = module.network.vpc_id   # Pass the VPC ID to the module
  subnet_id         = module.network.public_subnet_id
  ami_id            = var.ami_id
  instance_type     = var.bastion_instance_type
  key_name          = var.key_name
  my_ip             = var.my_ip
}


module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.network.vpc_id
  # my_ip  = var.my_ip
  bastion_private_ip = module.bastion.bastion_private_ip
}

module "iam" {
  source = "./modules/iam"  
}

module "ec2_instances" {
  source             = "./modules/ec2_instances"
  private_subnet_id  = module.network.private_subnet_id
  ami_id             = var.ami_id
  instance_type      = var.ec2_instance_type
  key_name           = var.key_name
  control_plane_sg_id = module.security_groups.control_plane_sg_id
  worker_sg_id        = module.security_groups.worker_sg_id
  instance_profile    = module.iam.k8s_iam_instance_profile
}

