# cli/commands/deploy.py

import click
import subprocess
import os

@click.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True, help='Cloud provider to deploy to.')
def deploy(provider):
    """Deploy infrastructure to the specified cloud provider."""
    click.echo(f"Deploying to {provider}...")

    # Change directory to the provider's Terraform configuration
    os.chdir(f"terraform/{provider}")

    # Initialize Terraform
    subprocess.run(["terraform", "init"], check=True)

    # Plan the deployment
    subprocess.run(["terraform", "plan"], check=True)

    # Apply the deployment
    subprocess.run(["terraform", "apply", "-auto-approve"], check=True)

    click.echo(f"Deployment to {provider} completed.")