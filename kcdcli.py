# kcdcli.py

import click
from cli.commands import deploy, destroy, status

@click.group()
def cli():
    """KCD CLI for managing cloud infrastructure deployments."""
    pass

cli.add_command(deploy.deploy)
cli.add_command(destroy.destroy)
cli.add_command(status.status)

if __name__ == '__main__':
    cli()