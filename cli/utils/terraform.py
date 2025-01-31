import os
import subprocess
import click
import json

class TerraformManager:
    def __init__(self, provider):
        self.provider = provider
        self.tf_dir = f"terraform/{provider}"

    def init(self):
        """Initialize Terraform"""
        click.echo("Initializing Terraform...")
        self._run_command(["terraform", "init"])

    def plan(self):
        """Create Terraform plan"""
        click.echo("Creating Terraform plan...")
        self._run_command(["terraform", "plan"])

    def apply(self):
        """Apply Terraform configuration"""
        click.echo("Applying Terraform configuration...")
        self._run_command(["terraform", "apply", "-auto-approve"])

    def destroy(self):
        """Destroy infrastructure"""
        click.echo("Destroying infrastructure...")
        self._run_command(["terraform", "destroy", "-auto-approve"])

    def get_status(self):
        """Get status of infrastructure resources"""
        try:
            output = subprocess.run(
                ["terraform", "show", "-json"],
                cwd=self.tf_dir,
                check=True,
                capture_output=True,
                text=True
            )
            tf_state = json.loads(output.stdout)
            
            status = {}
            for resource in tf_state.get('values', {}).get('root_module', {}).get('resources', []):
                name = resource['address']
                state = resource.get('values', {}).get('status', 'unknown')
                status[name] = state
            
            return status
        except subprocess.CalledProcessError as e:
            raise Exception(f"Failed to get infrastructure status: {e}")

    def _run_command(self, command):
        """Run Terraform command"""
        try:
            subprocess.run(
                command,
                cwd=self.tf_dir,
                check=True
            )
        except subprocess.CalledProcessError as e:
            raise Exception(f"Terraform command failed: {e}") 