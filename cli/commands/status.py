import click
import subprocess
import json
from cli.utils.terraform import TerraformManager
from cli.utils.kubernetes import KubernetesManager

def get_cluster_status(provider):
    """
    Get the status of the Kubernetes cluster
    """
    try:
        # Get infrastructure status
        tf = TerraformManager(provider)
        tf_status = tf.get_status()
        
        # Get Kubernetes cluster status
        k8s = KubernetesManager(provider)
        
        click.echo("\n=== Cluster Status ===")
        click.echo(f"\nProvider: {click.style(provider.upper(), fg='blue')}")
        
        # Infrastructure Status
        click.echo("\n🏗️  Infrastructure:")
        for resource, state in tf_status.items():
            color = "green" if state == "running" else "yellow" if state == "pending" else "red"
            click.echo(f"  • {resource}: {click.style(state, fg=color)}")
        
        # Kubernetes Status
        if k8s.is_available():
            click.echo("\n🚀 Kubernetes:")
            
            # Node Status
            nodes = k8s.get_nodes()
            click.echo("\n  Nodes:")
            for node in nodes:
                status = node['status']
                color = "green" if status == "Ready" else "red"
                click.echo(f"  • {node['name']}: {click.style(status, fg=color)}")
            
            # Pod Status
            pods = k8s.get_pods()
            click.echo("\n  System Pods:")
            for pod in pods:
                status = pod['status']
                color = "green" if status == "Running" else "yellow" if status == "Pending" else "red"
                click.echo(f"  • {pod['name']}: {click.style(status, fg=color)}")
            
            # Component Status
            components = k8s.get_component_status()
            click.echo("\n  Components:")
            for component in components:
                status = component['status']
                color = "green" if status == "Healthy" else "red"
                click.echo(f"  • {component['name']}: {click.style(status, fg=color)}")
        else:
            click.echo("\n❌ Kubernetes cluster is not accessible")
            
    except Exception as e:
        click.echo(click.style(f"\nError getting cluster status: {str(e)}", fg="red"))
        raise click.Abort() 