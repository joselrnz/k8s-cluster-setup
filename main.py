#!/usr/bin/python3
import click
import os
from cli.utils.terraform import TerraformManager

@click.group()
def cli():
    """Kubernetes Cluster Deployment CLI"""
    pass

@cli.group()
@click.option('--provider', '-p', type=click.Choice(['aws', 'azure', 'gcp']), required=True, help='Cloud provider')
@click.pass_context
def cluster(ctx, provider):
    """Manage Kubernetes cluster"""
    ctx.ensure_object(dict)
    ctx.obj['provider'] = provider

@cluster.command(name='init')
@click.pass_context
def terraform_init(ctx):
    """Initialize Terraform"""
    provider = ctx.obj['provider']
    tf = TerraformManager(provider)
    tf.init()

@cluster.command(name='plan')
@click.pass_context
def terraform_plan(ctx):
    """Show Terraform plan"""
    provider = ctx.obj['provider']
    tf = TerraformManager(provider)
    tf.plan()

@cluster.command(name='apply')
@click.pass_context
def terraform_apply(ctx):
    """Apply Terraform configuration"""
    provider = ctx.obj['provider']
    tf = TerraformManager(provider)
    tf.apply()

@cluster.command(name='destroy')
@click.pass_context
@click.option('--auto-approve', is_flag=True, help='Skip interactive approval')
def terraform_destroy(ctx, auto_approve):
    """Destroy Terraform infrastructure"""
    provider = ctx.obj['provider']
    tf = TerraformManager(provider)
    
    if auto_approve or click.confirm(f'Are you sure you want to destroy the {provider} infrastructure?'):
        tf.destroy()

if __name__ == '__main__':
    cli(obj={}) 