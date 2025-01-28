output "Master_Node_IP" {
  value = module.ec2_instances.master_ip
  description = "Private IP address of the master node"
}
output "Worker_Node_IPs" {
  value = module.ec2_instances.worker_ips
  description = "Private IP addresses of the worker nodes"
}

output "Bastian_Private_IP" {
  value = module.bastion.bastion_private_ip
  description = "Private IP address of the master node"
}
