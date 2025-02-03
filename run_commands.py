import argparse
import subprocess
import json
import os
import logging
import os
import sys

from dotenv import load_dotenv

load_dotenv()


class ConfigLoader:
    """Class to load configuration from a JSON file."""
    @staticmethod
    def load_config(config_file):
        with open(config_file, 'r') as file:
            return json.load(file)

class CloudInstanceManager:
    """Class to manage cloud instances based on the cloud provider."""
    def __init__(self, cloud_provider):
        self.cloud_provider = cloud_provider

    def fetch_instance_details(self, filter, instance_type):
        """Fetch instance details using the appropriate cloud provider CLI."""
        if self.cloud_provider == 'aws':
            command = [
                'aws', 'ec2', 'describe-instances',
                '--filters', f"Name=tag:Name,Values={filter}", "Name=instance-state-name,Values=running",
                '--query', f"Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], {instance_type}]",
                '--output', 'text'
            ]
        elif self.cloud_provider == 'azure':
            command = [
                'az', 'vm', 'list',
                '--query', f"[?tags.Name=='{filter}' && powerState=='VM running'].[name, {instance_type}]",
                '--output', 'tsv'
            ]
        elif self.cloud_provider == 'gcp':
            command = [
                'gcloud', 'compute', 'instances', 'list',
                '--filter', f"name ~ '{filter}' AND status=RUNNING",
                '--format', f"value(name,{instance_type})"
            ]
        else:
            raise ValueError(f"Unsupported cloud provider: {self.cloud_provider}")

        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout.strip()

class SSHManager:
    """Class to manage SSH operations."""
    def __init__(self, pem_key_location, bastion_ip):
        self.pem_key_location = pem_key_location
        self.bastion_ip = bastion_ip

    def get_ssh_user(self, os_check):
        """Determine the SSH user based on the OS type."""
        if "Ubuntu" in os_check:
            return "ubuntu"
        elif any(x in os_check for x in ["Amazon", "CentOS", "Red Hat"]):
            return "ec2-user"
        else:
            return "Unknown"

    def detect_package_manager(self):
        """Detect the package manager available on the system."""
        if subprocess.run(['command', '-v', 'dnf'], capture_output=True).returncode == 0:
            return "dnf"
        elif subprocess.run(['command', '-v', 'yum'], capture_output=True).returncode == 0:
            return "yum"
        elif subprocess.run(['command', '-v', 'apt'], capture_output=True).returncode == 0:
            return "apt"
        else:
            return "Unknown"

    def execute_ssh_command(self, command):
        """Execute a command on the remote server via SSH."""
        return subprocess.run(
            ['ssh', '-i', self.pem_key_location, '-o', 'StrictHostKeyChecking=no', f"ec2-user@{self.bastion_ip}", command],
            capture_output=True, text=True
        ).stdout

class AnsibleManager:
    """Class to manage Ansible operations."""
    def __init__(self, ssh_user, pem_key_path, cloud_provider):
        self.ssh_user = ssh_user
        self.pem_key_path = pem_key_path
        self.cloud_provider = cloud_provider

    def generate_inventory(self, k8s_vars):
        """Generate an Ansible inventory file based on Kubernetes node details."""
        hosts_file = f"./ansible/inventories/{self.cloud_provider}/hosts"
        with open(hosts_file, 'w') as file:
            file.write("[master]\n")
            for name, ip in k8s_vars.items():
                if "master" in name:
                    file.write(f"{ip} ansible_user={self.ssh_user} ansible_ssh_private_key_file={self.pem_key_path} node_name={name} control_plane=yes\n")

            file.write("[worker]\n")
            for name, ip in k8s_vars.items():
                if "worker" in name:
                    file.write(f"{ip} ansible_user={self.ssh_user} ansible_ssh_private_key_file={self.pem_key_path} node_name={name} control_plane=no\n")

        print(f"Ansible hosts file has been generated at {hosts_file}")

def main():
    """Main function to orchestrate the script execution."""
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('k8s_filter', type=str, help='Kubernetes filter')
    parser.add_argument('bastion_filter', type=str, help='Bastion filter')
    parser.add_argument('pem_key_location', type=str, help='PEM key location')
    parser.add_argument('dst_location', type=str, help='Destination location')
    parser.add_argument('cloud_provider', type=str, nargs='?', default='aws', help='Cloud provider (default: aws)')

    args = parser.parse_args()

    # Check if the PEM key file exists
    if not os.path.isfile(args.pem_key_location):
        print(f"PEM key file not found: {args.pem_key_location}")
        return

    # Fetch Bastion instance public IP
    print("Fetching Bastion instance public IP...")
    cloud_manager = CloudInstanceManager(args.cloud_provider)
    bastion_info = cloud_manager.fetch_instance_details(args.bastion_filter, "PublicIpAddress")

    if not bastion_info:
        print("Failed to fetch Bastion instance information. Exiting.")
        return

    bastion_ip = bastion_info.split()[1]
    print(f"Bastion Public IP: {bastion_ip}")

    # Detect OS type on Bastion and determine SSH user
    ssh_manager = SSHManager(args.pem_key_location, bastion_ip)
    print("Checking the OS type of Bastion...")
    os_check = ssh_manager.execute_ssh_command('cat /etc/os-release')

    ssh_user = ssh_manager.get_ssh_user(os_check)
    package_manager = ssh_manager.detect_package_manager()

    print(f"Detected OS type: {os_check}")
    print(f"SSH user: {ssh_user}")
    print(f"Package manager: {package_manager}")

    # Install Ansible and dependencies
    print("Installing Ansible on Bastion...")
    install_ansible_command = f"""
    sudo hostnamectl set-hostname "bastion-node"
    if [[ "{package_manager}" == "apt" ]]; then
        sudo apt update -y
        sudo apt install -y software-properties-common
        sudo apt-add-repository --yes --update ppa:ansible/ansible
        sudo apt install -y ansible
    elif [[ "{package_manager}" == "dnf" || "{package_manager}" == "yum" ]]; then
        sudo {package_manager} update -y
        sudo {package_manager} install -y epel-release ansible
    else
        echo "Unsupported package manager: {package_manager}"
        exit 1
    fi
    """
    ssh_manager.execute_ssh_command(install_ansible_command)

    # Copy the PEM key to Bastion using SCP
    print("Copying PEM key to Bastion...")
    subprocess.run(['scp', '-i', args.pem_key_location, args.pem_key_location, f"{ssh_user}@{bastion_ip}:{args.dst_location}"])

    # Construct the path to the PEM key for the Ansible hosts file
    pem_key_name = os.path.basename(args.pem_key_location)
    pem_key_path = f"/home/{ssh_user}/{pem_key_name}"

    # Generate Ansible inventory
    print("Generating Ansible hosts file...")
    k8s_info = cloud_manager.fetch_instance_details(args.k8s_filter, "PrivateIpAddress")

    if not k8s_info:
        print("Failed to fetch Kubernetes node information. Exiting.")
        return

    k8s_vars = {}
    for line in k8s_info.splitlines():
        name, ip = line.split()
        k8s_vars[name] = ip

    ansible_manager = AnsibleManager(ssh_user, pem_key_path, args.cloud_provider)
    ansible_manager.generate_inventory(k8s_vars)

    # Transfer Ansible playbook to Bastion
    subprocess.run(['scp', '-i', args.pem_key_location, '-r', 'ansible', f"{ssh_user}@{bastion_ip}:{args.dst_location}"])

    # Run the Ansible playbook
    print("Running Ansible playbook on Bastion...")
    run_playbook_command = f"""
    cd ansible/
    ansible-playbook -i inventories/{args.cloud_provider}/hosts site.yml
    cd ~/
    sudo mkdir -p /home/{ssh_user}/.kube
    sudo cp /tmp/admin.conf /home/{ssh_user}/.kube/config

    sudo chown -R {ssh_user}:{ssh_user} /home/{ssh_user}/.kube
    sudo chmod 600 /home/{ssh_user}/.kube/config

    echo "export KUBECONFIG=/home/{ssh_user}/.kube/config" >> /home/{ssh_user}/.bashrc
    source /home/{ssh_user}/.bashrc

    echo "Testing kubectl..."
    kubectl get nodes
    """
    ssh_manager.execute_ssh_command(run_playbook_command)

    print("Ansible playbook execution completed.")

if __name__ == "__main__":
    main()