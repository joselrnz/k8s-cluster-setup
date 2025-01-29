# cli/commands/status.py

import click
import subprocess
import os

@click.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True, help='Cloud provider to check status for.')
def status(provider):
    """Check the status of the infrastructure on the specified cloud provider."""
    click.echo(f"Checking status on {provider}...")

    # Change directory to the provider's Terraform configuration
    os.chdir(f"terraform/{provider}")

    # Show the current state
    subprocess.run(["terraform", "show"], check=True)