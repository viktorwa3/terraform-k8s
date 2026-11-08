#!/usr/bin/env python3
"""Dynamic inventory from `terraform output -json` of azure/ (tf-azure.json)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.environ.get("TF_AZURE_JSON", os.path.join(HERE, "..", "tf-azure.json"))


def out(data):
    # Accept both `terraform output -json` ({k: {value}}) and plain values.
    return {k: (v["value"] if isinstance(v, dict) and "value" in v else v) for k, v in data.items()}


def build(o):
    cp = o["cp"]
    workers = o["workers"]
    hosts = {}
    for node in [cp] + workers:
        hosts[node["name"]] = {
            "ansible_host": node["public_ip"],
            "ansible_user": "ansible",
            "node_private_ip": node["private_ip"],
        }
    return {
        "_meta": {"hostvars": hosts},
        "all": {
            "children": ["control_plane", "workers"],
            "vars": {
                "azure_arc_enabled": True,
                "azure_resource_group": o["resource_group"],
                "azure_location": o["location"],
                "azure_tenant_id": o["tenant_id"],
                "azure_subscription_id": o["subscription_id"],
                "azure_cluster_name": o["cluster_name"],
                "azure_node_identity_client_id": o["node_identity_client_id"],
                "azure_log_analytics_workspace_id": o["log_analytics_workspace_id"],
                "argocd_key_vault_uri": o["key_vault_uri"],
                "argocd_ingress_host": o["ingress_fqdn"],
            },
        },
        "control_plane": {"hosts": [cp["name"]]},
        "workers": {"hosts": [w["name"] for w in workers]},
    }


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        print("{}")
        return
    with open(PATH, encoding="utf-8") as f:
        print(json.dumps(build(out(json.load(f)))))


if __name__ == "__main__":
    main()
