# iac-lab

**Status: work in progress.**

A small infrastructure-as-code pipeline: Terraform provisions a local Docker network + a load balancer and two application backends, then hands off to Ansible for configuration (nginx round-robin proxy, a minimal Flask app on each backend).

## Architecture

- `terraform/` — provisions the Docker network and 3 containers (`lb`, `app1`, `app2`), writes an Ansible inventory from its outputs
- `ansible/` — configures the containers: `lb` role sets up nginx as a round-robin proxy, `app` role installs/starts the Flask backend
- `.github/workflows/` — CI: `terraform validate`, `ansible-lint` on every push

## Quickstart

_Coming soon — not runnable yet, still building._

## Why

Built to demonstrate a real, working IaC pattern (declarative provisioning → config management handoff) rather than just reading about one. Nodes are Docker containers rather than VMs — a deliberate choice for a fast, dependency-light local dev loop, not a limitation of the approach.
