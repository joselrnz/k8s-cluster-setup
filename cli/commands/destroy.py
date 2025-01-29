# cli/commands/destroy.py

import click
import subprocess
import os

@click.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True, help='Cloud provider to destroy infrastructure from.')
def destroy(provider):
    """Destroy infrastructure on the specified cloud provider."""
    click.echo(f"Destroying infrastructure on {provider}...")

    # Change directory to the provider's Terraform configuration
    os.chdir(f"terraform/{provider}")

    # Destroy the infrastructure
    subprocess.run(["terraform", "destroy", "-auto-approve"], check=True)

    click.echo(f"Infrastructure on {provider} destroyed.")