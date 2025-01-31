import click
from cli.utils.terraform import TerraformManager
from cli.utils.ansible import AnsibleManager

def deploy_cluster(provider, skip_terraform=False, skip_ansible=False):
    """
    Deploy the Kubernetes cluster
    """
    try:
        if not skip_terraform:
            tf = TerraformManager(provider)
            tf.init()
            tf.plan()
            tf.apply()
            click.echo(click.style("✓ Terraform deployment completed", fg="green"))

        if not skip_ansible:
            ansible = AnsibleManager(provider)
            ansible.run_playbook()
            click.echo(click.style("✓ Ansible configuration completed", fg="green"))

        click.echo(click.style("✓ Cluster deployment completed successfully!", fg="green"))

    except Exception as e:
        click.echo(click.style(f"Error: {str(e)}", fg="red"))
        raise click.Abort() 