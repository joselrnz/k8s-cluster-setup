#!/bin/bash

# Function to display usage of the script
usage() {
  echo "Usage: $0 <k8s_filter> <bastion_filter> <pem_key_location> <dst_location> [cloud_provider]"
  echo "  cloud_provider is optional and defaults to 'aws' if not specified."
  exit 1
}

# Function to fetch EC2 instance details using AWS CLI
fetch_instance_details() {
  local filter=$1
  local instance_type=$2
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$filter" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], $instance_type]" \
    --output text
}

# Function to determine the SSH user based on the OS type
get_ssh_user() {
  local os_check=$1
  if [[ $os_check == *"Ubuntu"* ]]; then
    echo "ubuntu"
  elif [[ $os_check == *"Amazon"* ]]; then
    echo "ec2-user"
  else
    echo "Unknown"
  fi
}

# Function to check if AWS CLI is available
check_aws_cli() {
  if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
  fi
}

# Main script execution starts here

# Ensure correct number of arguments are provided
if [ "$#" -lt 4 ]; then
  usage
fi

# Read input arguments
k8s_filter="$1"       # Kubernetes filter, e.g., *k8s*
bastion_filter="$2"   # Bastion filter, e.g., *bastion*
pem_key_location="$3" # Path to the PEM key file
dst_location="$4"     # Destination location for file transfer

# Check if the PEM key file exists
if [ ! -f "$pem_key_location" ]; then
  echo "PEM key file not found: $pem_key_location"
  exit 1
fi

# Optional cloud provider (defaults to 'aws' if not provided)
cloud_provider="${5:-aws}"  # If cloud_provider is not provided, default to 'aws'

# Set the home directory based on the SSH user (defaulting to ubuntu)
home_dir="/home/$(get_ssh_user "Ubuntu")/"

# Fetch Bastion instance public IP
echo "Fetching Bastion instance public IP..."
bastion_info=$(fetch_instance_details "$bastion_filter" "PublicIpAddress")

# Ensure Bastion IP was fetched successfully
if [ -z "$bastion_info" ]; then
  echo "Failed to fetch Bastion instance information. Exiting."
  exit 1
fi

# Extract Bastion IP
bastion_var=$(echo "$bastion_info" | awk '{print $2}')
echo "Bastion Public IP: $bastion_var"

# Fetch Kubernetes nodes' private IPs
echo "Fetching Kubernetes nodes' private IPs..."
k8s_info=$(fetch_instance_details "$k8s_filter" "PrivateIpAddress")

# Ensure Kubernetes IPs were fetched successfully
if [ -z "$k8s_info" ]; then
  echo "Failed to fetch Kubernetes node information. Exiting."
  exit 1
fi

# Process Kubernetes node information into an associative array
declare -A k8s_vars
while IFS=$'\t' read -r name ip; do
  k8s_vars["$name"]="$ip"
done <<< "$k8s_info"

# Display Kubernetes nodes
echo "Kubernetes Nodes:"
for name in "${!k8s_vars[@]}"; do
  dynamic_var_name="${name//-/_}"
  echo "$dynamic_var_name=${k8s_vars[$name]}"
done

# Determine OS type and set the SSH user
echo "Checking the OS type of Bastion..."
ec2_ip_bastion=$(echo "$bastion_var" | tr '.' '-')
os_check=$(ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ec2-user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" 'uname -a' 2>/dev/null || \
           ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ubuntu@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" 'uname -a')

ssh_user=$(get_ssh_user "$os_check")

if [[ "$os_check" == *"Ubuntu"* ]]; then
    echo "Detected Ubuntu. Installing Ansible using apt..."
    ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ubuntu@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" <<EOF
        sudo apt update -y
        sudo hostnamectl set-hostname "bastion-node"
        sudo apt install -y software-properties-common
        sudo apt-add-repository --yes --update ppa:ansible/ansible
        sudo apt install -y ansible
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
EOF
elif [[ "$os_check" == *"Amazon Linux"* || "$os_check" == *"CentOS"* || "$os_check" == *"Red Hat"* ]]; then
    echo "Detected Amazon Linux/CentOS/Red Hat. Installing Ansible using yum..."
    ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ec2-user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" <<EOF
        sudo yum update -y
        sudo hostnamectl set-hostname "bastion-node"
        sudo yum install -y epel-release
        sudo yum install -y ansible
EOF
else
    echo "Unknown OS or not Linux. Cannot install Ansible."
fi
echo   "$pem_key_location" -o StrictHostKeyChecking=no "ubuntu@ec2-$ec2_ip_bastion.compute-1.amazonaws.com"
echo "Detected OS type: $os_check"
echo "SSH user: $ssh_user"

# Copy the PEM key to Bastion using SCP
echo "Copying PEM key to Bastion..."
scp -i "$pem_key_location" "$pem_key_location" "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com:$dst_location"

# Construct the path to the PEM key for the Ansible hosts file
pem_key_name=$(basename "$pem_key_location")
pem_key_path="${home_dir}${pem_key_name}"

# Create the hosts file with cloud provider path
hosts_file="./ansible/inventories/${cloud_provider}/hosts"
echo "[master]" > "$hosts_file"
for name in "${!k8s_vars[@]}"; do
  if [[ "$name" == *master* ]]; then
    node_name="${name}"
    control_plane="yes"
    echo "${k8s_vars[$name]} ansible_user=$ssh_user ansible_ssh_private_key_file=$pem_key_path ansible_ssh_common_args='-o StrictHostKeyChecking=no' node_name=$node_name control_plane=$control_plane" >> "$hosts_file"
  fi
done

echo "[worker]" >> "$hosts_file"
for name in "${!k8s_vars[@]}"; do
  if [[ "$name" == *worker* ]]; then
    node_name="${name}"
    control_plane="no"
    echo "${k8s_vars[$name]} ansible_user=$ssh_user ansible_ssh_private_key_file=$pem_key_path ansible_ssh_common_args='-o StrictHostKeyChecking=no' node_name=$node_name control_plane=$control_plane" >> "$hosts_file"
  fi
done

# For debugging: Print all dynamic variables
for name in "${!k8s_vars[@]}"; do
  dynamic_var_name="${name//-/_}"
  echo "$dynamic_var_name=${k8s_vars[$name]}"
done

echo "Ansible hosts file has been generated at $hosts_file"

# Transfer Ansible playbook to Bastion
scp -i "$pem_key_location" -r "ansible" "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com:$dst_location"

# Run the Ansible playbook
echo "Running Ansible playbook on Bastion..."
ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" <<EOF
  cd ansible/
  ansible-playbook -i inventories/$cloud_provider/hosts site.yml
  cd ~/
  sudo mkdir -p /home/$ssh_user/.kube
  sudo cp /tmp/admin.conf /home/$ssh_user/.kube/config

  # Set proper ownership and permissions
  sudo chown -R $ssh_user:$ssh_user /home/$ssh_user/.kube
  sudo chmod 600 /home/$ssh_user/.kube/config

  # Set the KUBECONFIG environment variable (persistent)
  echo "export KUBECONFIG=/home/$ssh_user/.kube/config" >> /home/$ssh_user/.bashrc
  source /home/$ssh_user/.bashrc

  # Verify kubectl works without sudo
  echo "Testing kubectl..."
  kubectl get nodes
EOF

echo "Ansible playbook execution completed."
ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com"

# Command to run 
##./run_bash.sh "*k8s*" "*bastion*" "<Key pair location>.pem" "/home/ubuntu/" "aws"
#./run_bash.sh "*k8s*" "*bastion*" "/home/joselrnz/aws/key_pairs/kube.pem" "/home/ubuntu/" "aws"