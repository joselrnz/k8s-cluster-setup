#!/bin/bash

# Function to display usage of the script
usage() {
  echo "Usage: $0 <k8s_filter> <bastion_filter> <pem_key_location> <dst_location> [cloud_provider]"
  echo "  cloud_provider is optional and defaults to 'aws' if not specified."
  exit 1
}

# Function to determine the package manager
detect_package_manager() {
  if command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v apt &>/dev/null; then
    echo "apt"
  else
    echo "Unknown"
  fi
}

# Function to determine the SSH user based on the OS type
get_ssh_user() {
  local os_check=$1
  if [[ $os_check == *"Ubuntu"* ]]; then
    echo "ubuntu"
  elif [[ $os_check == *"Amazon"* || $os_check == *"CentOS"* || $os_check == *"Red Hat"* ]]; then
    echo "ec2-user"
  else
    echo "Unknown"
  fi
}

# Function to fetch instance details dynamically based on cloud provider
fetch_instance_details() {
  local filter=$1
  local instance_type=$2

  case "$cloud_provider" in
    aws)
      aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$filter" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], $instance_type]" \
        --output text
      ;;
    azure)
      az vm list --query "[?tags.Name=='$filter' && powerState=='VM running'].[name, $instance_type]" --output tsv
      ;;
    gcp)
      gcloud compute instances list --filter="name ~ '$filter' AND status=RUNNING" --format="value(name,$instance_type)"
      ;;
    *)
      echo "Unsupported cloud provider: $cloud_provider"
      exit 1
      ;;
  esac
}

# Ensure correct number of arguments are provided
if [ "$#" -lt 4 ]; then
  usage
fi

# Read input arguments
k8s_filter="$1"
bastion_filter="$2"
pem_key_location="$3"
dst_location="$4"
cloud_provider="${5:-aws}"  # Defaults to AWS if not provided

# Check if the PEM key file exists
if [ ! -f "$pem_key_location" ]; then
  echo "PEM key file not found: $pem_key_location"
  exit 1
fi

# Fetch Bastion instance public IP
echo "Fetching Bastion instance public IP..."
bastion_info=$(fetch_instance_details "$bastion_filter" "PublicIpAddress")

if [ -z "$bastion_info" ]; then
  echo "Failed to fetch Bastion instance information. Exiting."
  exit 1
fi

bastion_ip=$(echo "$bastion_info" | awk '{print $2}')
echo "Bastion Public IP: $bastion_ip"

# Detect OS type on Bastion and determine SSH user
echo "Checking the OS type of Bastion..."
os_check=$(ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ec2-user@$bastion_ip" 'cat /etc/os-release' 2>/dev/null || \
           ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "ubuntu@$bastion_ip" 'cat /etc/os-release')

ssh_user=$(get_ssh_user "$os_check")
package_manager=$(detect_package_manager)

echo "Detected OS type: $os_check"
echo "SSH user: $ssh_user"
echo "Package manager: $package_manager"

# Install Ansible and dependencies
echo "Installing Ansible on Bastion..."
ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "$ssh_user@$bastion_ip" <<EOF
  sudo hostnamectl set-hostname "bastion-node"
  if [[ "$package_manager" == "apt" ]]; then
    sudo apt update -y
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
  elif [[ "$package_manager" == "dnf" || "$package_manager" == "yum" ]]; then
    sudo $package_manager update -y
    sudo $package_manager install -y epel-release ansible
  else
    echo "Unsupported package manager: $package_manager"
    exit 1
  fi
EOF

# Copy the PEM key to Bastion using SCP
echo "Copying PEM key to Bastion..."
scp -i "$pem_key_location" "$pem_key_location" "$ssh_user@$bastion_ip:$dst_location"

# Construct the path to the PEM key for the Ansible hosts file
pem_key_name=$(basename "$pem_key_location")
pem_key_path="/home/$ssh_user/$pem_key_name"

# Generate Ansible inventory
echo "Generating Ansible hosts file..."
hosts_file="./ansible/inventories/${cloud_provider}/hosts"
echo "[master]" > "$hosts_file"

# Fetch Kubernetes nodes' private IPs
echo "Fetching Kubernetes nodes' private IPs..."
k8s_info=$(fetch_instance_details "$k8s_filter" "PrivateIpAddress")

if [ -z "$k8s_info" ]; then
  echo "Failed to fetch Kubernetes node information. Exiting."
  exit 1
fi

declare -A k8s_vars
while IFS=$'\t' read -r name ip; do
  k8s_vars["$name"]="$ip"
done <<< "$k8s_info"

for name in "${!k8s_vars[@]}"; do
  if [[ "$name" == *master* ]]; then
    echo "${k8s_vars[$name]} ansible_user=$ssh_user ansible_ssh_private_key_file=$pem_key_path node_name=$name control_plane=yes" >> "$hosts_file"
  fi
done

echo "[worker]" >> "$hosts_file"
for name in "${!k8s_vars[@]}"; do
  if [[ "$name" == *worker* ]]; then
    echo "${k8s_vars[$name]} ansible_user=$ssh_user ansible_ssh_private_key_file=$pem_key_path node_name=$name control_plane=no" >> "$hosts_file"
  fi
done

echo "Ansible hosts file has been generated at $hosts_file"

# Transfer Ansible playbook to Bastion
scp -i "$pem_key_location" -r "ansible" "$ssh_user@$bastion_ip:$dst_location"

# Run the Ansible playbook
echo "Running Ansible playbook on Bastion..."
ssh -i "$pem_key_location" -o StrictHostKeyChecking=no "$ssh_user@$bastion_ip" <<EOF
  cd ansible/
  ansible-playbook -i inventories/$cloud_provider/hosts site.yml
  cd ~/
  sudo mkdir -p /home/$ssh_user/.kube
  sudo cp /tmp/admin.conf /home/$ssh_user/.kube/config

  sudo chown -R $ssh_user:$ssh_user /home/$ssh_user/.kube
  sudo chmod 600 /home/$ssh_user/.kube/config

  echo "export KUBECONFIG=/home/$ssh_user/.kube/config" >> /home/$ssh_user/.bashrc
  source /home/$ssh_user/.bashrc

  echo "Testing kubectl..."
  kubectl get nodes
EOF

echo "Ansible playbook execution completed."
