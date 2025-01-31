import subprocess
import json
import os

class KubernetesManager:
    def __init__(self, provider):
        self.provider = provider
        self.kubeconfig = f"config/kubeconfig/{provider}-config"

    def is_available(self):
        """Check if the cluster is accessible"""
        try:
            self._run_command(["kubectl", "cluster-info"])
            return True
        except:
            return False

    def get_nodes(self):
        """Get status of all nodes"""
        output = self._run_command(["kubectl", "get", "nodes", "-o", "json"])
        nodes_json = json.loads(output)
        
        nodes = []
        for node in nodes_json['items']:
            status = "Ready"
            for condition in node['status']['conditions']:
                if condition['type'] == 'Ready':
                    status = "Ready" if condition['status'] == 'True' else "NotReady"
                    break
            
            nodes.append({
                'name': node['metadata']['name'],
                'status': status
            })
        return nodes

    def get_pods(self):
        """Get status of system pods"""
        output = self._run_command([
            "kubectl", "get", "pods",
            "-n", "kube-system",
            "-o", "json"
        ])
        pods_json = json.loads(output)
        
        pods = []
        for pod in pods_json['items']:
            pods.append({
                'name': pod['metadata']['name'],
                'status': pod['status']['phase']
            })
        return pods

    def get_component_status(self):
        """Get status of cluster components"""
        output = self._run_command(["kubectl", "get", "componentstatuses", "-o", "json"])
        cs_json = json.loads(output)
        
        components = []
        for cs in cs_json['items']:
            status = "Healthy"
            for condition in cs['conditions']:
                if condition['type'] == 'Healthy':
                    status = "Healthy" if condition['status'] == 'True' else "Unhealthy"
                    break
            
            components.append({
                'name': cs['metadata']['name'],
                'status': status
            })
        return components

    def _run_command(self, command):
        """Run kubectl command"""
        env = os.environ.copy()
        env["KUBECONFIG"] = self.kubeconfig
        
        try:
            result = subprocess.run(
                command,
                env=env,
                check=True,
                capture_output=True,
                text=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise Exception(f"Kubernetes command failed: {e}") 