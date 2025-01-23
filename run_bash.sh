#!/bin/bash

# Read arguments for dynamic filter values
k8s_filter="$1"       # First argument for Kubernetes filter, e.g., *k8s*
bastion_filter="$2"   # Second argument for bastion filter, e.g., *bastion*
pem_key_location="$3" # Third argument for PEM key file location
dst_location="$4"     # Fourth argument for destination location
# Fetch bastion public IP dynamically based on argument
bastion_info=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$bastion_filter" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], PublicIpAddress]" \
    --output text)

# Process bastion information into a variable
bastion_var=""
while IFS=$'\t' read -r name ip; do
  bastion_var="$ip"  # Store the bastion public IP
  export bastion_var
done <<< "$bastion_info"

# Fetch Kubernetes node private IPs dynamically based on argument
k8s_info=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$k8s_filter" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], PrivateIpAddress]" \
    --output text)

# Process Kubernetes node information into separate variables
declare -A k8s_vars
while IFS=$'\t' read -r name ip; do
  k8s_vars["$name"]="$ip"
done <<< "$k8s_info"

# Output Bastion variable
echo "Bastion Public IP: $bastion_var"

# Dynamically create and export Kubernetes node variables
echo "Kubernetes Nodes:"
for name in "${!k8s_vars[@]}"; do
  # Replace dashes in the name with underscores to create valid variable names
  dynamic_var_name="${name//-/_}"

  # Export the variable with the private IP
  declare "$dynamic_var_name=${k8s_vars[$name]}"
  export "$dynamic_var_name"

  # Print the dynamically created variable
  echo "$dynamic_var_name=${k8s_vars[$name]}"
done



# Determine the OS and SSH into the bastion

ec2_ip_bastion=$(echo "$bastion_var" | tr '.' '-')
os_check=$(ssh -i "$pem_key_location" "ec2-user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" 'uname -a' 2>/dev/null || ssh -i "$pem_key_location" "ubuntu@ec2-$ec2_ip_bastion.compute-1.amazonaws.com" 'uname -a')

if [[ $os_check == *"Ubuntu"* ]]; then
  ssh_user="ubuntu"
elif [[ $os_check == *"Amazon"* ]]; then
  ssh_user="ec2-user"
else
  echo "Unable to determine the OS type. Exiting."
  exit 1
fi


echo "Detected OS type: $os_check"
echo "SSH user: $ssh_user"

# SSH into the bastion
echo "SSH into the bastion host..."

# Copy PEM key to bastion using SCP
echo "Copying PEM key to bastion..."
echo "$pem_key_location" "$pem_key_location" $dst_location

echo "$pem_key_location" "$pem_key_location" "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com:$dst_location"
scp -i "$pem_key_location" "$pem_key_location" "$ssh_user@ec2-$ec2_ip_bastion.compute-1.amazonaws.com:$dst_location"


# ./run_bash.sh "*k8s*" "*bastion*"   "/home/user/key_pairs/kube.pem" "/home/ubuntu/"
: '
1. writ script to copy perm to bastion
2. pull gitlab ansiuble to cluster

3. login to the bastion
'