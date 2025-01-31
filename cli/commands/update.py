import click
from cli.utils.terraform import TerraformManager
from cli.utils.ansible import AnsibleManager

def update_cluster(provider):
    """
    Update the Kubernetes cluster
    """
    try:
        tf = TerraformManager(provider)
        tf.plan()
        
        if click.confirm("Do you want to apply the changes?"):
            tf.apply()
            click.echo(click.style("✓ Infrastructure updated", fg="green"))
            
            ansible = AnsibleManager(provider)
            ansible.run_playbook()
            click.echo(click.style("✓ Configuration updated", fg="green"))
            
        click.echo(click.style("✓ Cluster update completed!", fg="green"))
    except Exception as e:
        click.echo(click.style(f"Error: {str(e)}", fg="red"))
        raise click.Abort() 