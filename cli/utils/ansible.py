import os
import subprocess
import click

class AnsibleManager:
    def __init__(self, provider):
        self.provider = provider
        self.ansible_dir = "ansible"
        self.inventory_file = f"inventory/{provider}/hosts.yml"
        self.extra_vars = {}

    def run_playbook(self, extra_vars=None, tags=None):
        """Run Ansible playbook"""
        click.echo("Running Ansible playbook...")
        try:
            cmd = ["ansible-playbook", "-i", self.inventory_file, "site.yml"]
            
            # Add provider-specific vars
            provider_vars = f"vars/{self.provider}.yml"
            if os.path.exists(os.path.join(self.ansible_dir, provider_vars)):
                cmd.extend(["-e", f"@{provider_vars}"])
            
            # Add extra vars if provided
            if extra_vars:
                cmd.extend(["-e", f"@{extra_vars}"])
            
            # Add tags if provided
            if tags:
                cmd.extend(["-t", tags])

            # Add verbose output if needed
            if os.getenv("ANSIBLE_VERBOSE"):
                cmd.append("-v")

            subprocess.run(
                cmd,
                cwd=self.ansible_dir,
                check=True
            )
        except subprocess.CalledProcessError as e:
            raise Exception(f"Ansible playbook execution failed: {e}")

    def validate_playbook(self):
        """Validate playbook syntax"""
        try:
            subprocess.run(
                ["ansible-playbook", "--syntax-check", "-i", self.inventory_file, "site.yml"],
                cwd=self.ansible_dir,
                check=True
            )
        except subprocess.CalledProcessError as e:
            raise Exception(f"Playbook validation failed: {e}") 