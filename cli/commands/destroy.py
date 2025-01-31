import click
from cli.utils.terraform import TerraformManager

def destroy_cluster(provider):
    """
    Destroy the Kubernetes cluster
    """
    try:
        tf = TerraformManager(provider)
        tf.destroy()
        click.echo(click.style("✓ Cluster destroyed successfully!", fg="green"))
    except Exception as e:
        click.echo(click.style(f"Error: {str(e)}", fg="red"))
        raise click.Abort() 