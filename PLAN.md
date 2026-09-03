# iac-lab — Project Plan

**Status:** Phase 0 complete (2026-08-24). Starting Phase 1 next. Work through phases in order; check items off as you go.

## How we'll actually work through this

You write every project file and run every command yourself (that's the
point). For each step I'll give you the exact file content or command to
type, you run it and paste back the result (output, or the error if it
fails), and I confirm before we move to the next step. `PLAN.md` tracks
phase-level progress, not every micro-step — check a phase's boxes off
once it's done.

**Commits:** at each phase boundary, commit directly to `main` with a
message naming the phase (e.g. "Phase 1: Terraform network + containers +
inventory handoff"). No branches needed for a solo lab. I will never
`git push` without asking you first, regardless of what we're committing.

**Session hygiene:** before ending a work session, run `terraform destroy`
(or at minimum `docker stop` the containers) — otherwise orphaned
containers/networks accumulate on this machine across sessions.

## Why this project (and what "done" actually means)

The working demo is a byproduct, not the point. The real goal is to
internalize a split that shows up in almost every real infrastructure job:
**provisioning vs. configuration.** Terraform declares what infrastructure
*exists*; Ansible configures the *software* on top of it. Nearly nobody
builds one god-tool that does both — once you understand why the industry
keeps them separate and *how they hand off to each other*, that mental
model transfers to any cloud, any scale, any employer. Building this small
and local (destroy/rebuild in seconds) exists to give you many reps of the
full cycle, so the failure modes that only show up when you actually run
something — state drift, a non-idempotent task, a plan silently depending
on something imperative — become familiar instead of theoretical.

### Hard skills you should have by the end
- Terraform: providers, resources, state, outputs/variables, the
  plan → apply → destroy lifecycle, the implicit dependency graph, and why
  provisioners are a smell to avoid.
- Ansible: inventories, roles, tasks vs. handlers, idempotency, Jinja2
  templating, "ran once" vs. "converges every run."
- Docker as infrastructure: bridge networks, container-to-container DNS
  by name, why a container needs a foreground process to stay alive.
- The handoff itself: two tools with zero code-level coupling, integrated
  through a plain generated file — you'll be able to point at one line in
  the inventory and say "that's where Terraform's world becomes Ansible's."
- Debugging infra: reading a Terraform plan diff, reading Ansible verbose
  task output, tracing one HTTP request through a proxy to a backend.
- CI for infrastructure: lint/validate as a merge gate.

### Soft skills you should have by the end
- Forming a hypothesis from an error message before searching for it.
- Trusting the plan → apply → observe → adjust loop enough to treat
  infrastructure as safe to experiment on and destroy, not something to
  tiptoe around.
- Writing down *why* a decision was made at the moment you make it (the
  "Key design decisions" section below is modeling exactly this).
- Breaking a complex build into independently-verifiable phases instead
  of wiring everything up at once and debugging one big-bang failure.
- The specific discipline behind Phase 4: the gap between "each piece
  works alone" and "I verified the whole chain" — that gap is where most
  real outages live.

## Confirmed architecture (from README, unchanged)

- `terraform/` provisions one Docker network and three containers: `lb`,
  `app1`, `app2`. It writes an Ansible inventory from its own outputs.
- `ansible/` configures those containers: the `lb` role installs and
  configures nginx as a round-robin reverse proxy; the `app` role installs
  and starts a minimal Flask backend on `app1` and `app2`.
- `.github/workflows/` runs `terraform validate` and `ansible-lint` on
  every push.
- Nodes are Docker containers, not VMs — a deliberate choice for a fast,
  dependency-light local dev loop.

## Environment (confirmed by inspection, 2026-08-23)

- Host: WSL2, Ubuntu 26.04, systemd enabled as PID 1 (`/etc/wsl.conf` has
  `[boot] systemd=true`) — normal `systemctl` service management works.
- `sudo` requires an interactive password — commands needing it can't be
  run silently on your behalf; you'll type these yourself, which matches
  the "I type it, you guide" workflow.
- Nothing is installed yet: no `docker`, `terraform`, or `ansible` on PATH.
- Python 3.14 is present, but Ubuntu enforces PEP 668
  (externally-managed-environment) — no bare `pip install` into system
  Python. Tooling that needs Python packages goes through `pipx` instead.
  The same constraint exists inside the app containers (Debian 12 also
  marks system Python externally-managed), which is why Phase 3 installs
  Flask into a venv rather than via system pip.

## Key design decisions (and why)

These aren't in the README yet because they're implementation-level, but
they shape almost every step below, so they're recorded here rather than
re-derived every time.

1. **Ansible reaches containers via the `community.docker` connection
   plugin (docker exec), not SSH.** These are local dev containers, not
   remote hosts — running an SSH daemon inside minimal images just to let
   Ansible connect would add a whole extra service to install, secure, and
   debug, for zero benefit in a local-only lab. This requires the `docker`
   Python SDK and the `community.docker` Ansible collection on the control
   node (this WSL2 host) — no SSH keys anywhere in this project.
2. **All three containers start from a plain, minimal base image
   (`debian:bookworm-slim`) with nothing pre-installed.** If the images
   already had nginx/Flask baked in, Ansible's role would have nothing real
   to do. Starting from a blank box is what makes "Ansible installs and
   configures the software" a genuine step instead of theater — it's the
   closest local-Docker equivalent of handing Ansible a freshly-booted VM.
3. **No init system inside the containers — that has two consequences.**
   Docker containers exit when their PID 1 process exits, and these
   minimal images have no systemd. So: Terraform starts each container
   with `sleep infinity` as its command purely to keep the container
   alive, and later, the services Ansible installs manage their own
   foreground/background state instead of relying on `systemctl`
   (nginx daemonizes itself by default; Flask is started backgrounded via
   a plain `nohup ... &` task). This is a known, deliberate limitation of
   minimal containers, not production practice — worth noticing, not
   worth solving here.
4. **The inventory handoff uses `local_file` + `templatefile()` fed by
   Terraform outputs — no provisioners.** `local_execute`/provisioners are
   a Terraform anti-pattern (they hide imperative logic inside a
   declarative tool and aren't tracked well in state). A `local_file`
   resource rendering a template from real outputs (container names, the
   network) is the idiomatic way to do this, and it's also the most
   literal, visible version of "Terraform's output becomes Ansible's
   input" — you'll be able to point at the generated file and see exactly
   where the handoff happens.
5. **Docker Engine (not Docker Desktop), Terraform, and Ansible are all
   installed directly in this WSL2 shell** via each project's official
   apt repository (HashiCorp's for Terraform, Docker's for Engine) rather
   than snap or a Windows-side GUI app — everything stays in the one
   terminal you're already working in. Ansible goes in via `pipx` (not
   system pip) because of PEP 668 above.
6. **Dependencies are pinned on both sides of the handoff, not just
   Terraform's.** `terraform/versions.tf` already pins the Docker provider
   version. Ansible gets the same treatment via `ansible/requirements.yml`,
   which pins the `community.docker` collection version — otherwise "it
   worked when I built it" silently stops being true after an unrelated
   `ansible-galaxy` upgrade months from now.
7. **No remote Terraform state and no secrets management — on purpose.**
   State stays local (`terraform.tfstate`, already gitignored) and there
   are no credentials anywhere in this project (Docker's local API needs
   none). That's a real tradeoff being made for lab scope, not a gap that
   was missed — remote state and secrets handling are exactly the kind of
   "production-ish ops" concern Phase 7's roadmap could pick up later.

## Phases

### Phase 0 — Toolchain install & verification ✅ done 2026-08-24
Goal: `docker`, `terraform`, and `ansible` all runnable from this shell,
and you can prove Docker actually works (not just that the binary exists).
- [x] Install Docker Engine from Docker's official apt repo
- [x] Add your user to the `docker` group; confirm `docker run hello-world`
      works without `sudo`
- [x] Install Terraform from HashiCorp's official apt repo (v1.15.9)
- [x] Install `pipx`, then `ansible-core` via `pipx` (ansible-core 2.21.3)
- [x] Create `ansible/requirements.yml` pinning the `community.docker`
      collection version; install it from that file (not an ad hoc
      `ansible-galaxy collection install`) — pinned to 5.2.2
- [x] Install the `docker` Python SDK into the same pipx-managed
      environment as `ansible-core` (via `pipx inject ansible-core docker`)
- [x] Verify: `docker --version`, `terraform --version`,
      `ansible --version` all succeed

### Phase 1 — Terraform: network + containers + inventory handoff ✅ done 2026-08-26
Goal: `terraform apply` produces a running network and three blank
containers, and generates a valid Ansible inventory file from its outputs.
- [x] `ansible.cfg` at repo root: default inventory path, roles path, so
      later commands don't need `-i ansible/inventory/hosts.ini` by hand
- [x] `docker_network` resource for the lab network
- [x] Three `docker_container` resources (`lb`, `app1`, `app2`) on that
      network, `debian:bookworm-slim` image, `sleep infinity` command
- [x] Outputs exposing container names (and anything else the inventory
      needs)
- [x] Inventory template (`.tpl`) + `local_file` resource rendering it from
      those outputs into `ansible/inventory/hosts.ini`
- [x] `terraform validate` and `terraform apply` both succeed; inspect the
      generated inventory file by hand

### Phase 2 — Ansible: `lb` role (nginx round-robin)
Goal: `app1`/`app2` groups in inventory determine the containers nginx
proxies to — no hardcoded backend list.

**Note (2026-09-02):** the tasks/handler/template below were already
written in a prior session but never actually run or verified — found
during the Phase 0-1 re-grounding pass. Checking boxes off as they're
*verified*, not just as files that exist.
- [x] Tasks: apt-get update + install nginx (`ansible/roles/lb/tasks/main.yml`)
- [x] Template: nginx config with an `upstream` block built from the
      `app` inventory group (Jinja loop), proxying `/` to it round-robin
      (`ansible/roles/lb/templates/nginx.conf.j2`)
- [x] Handler: reload/restart nginx on config change
      (`ansible/roles/lb/handlers/main.yml`)
- [ ] Run against just the `lb` host; verify nginx is listening — **not
      yet done, next concrete step**

### Phase 3 — Ansible: `app` role (Flask backend)
Goal: each app node runs a minimal Flask app that identifies itself in its
response, so round-robin behavior is externally observable.
- [ ] Tasks: apt-get update + install `python3-venv`; create a venv under
      `/opt/app`; install Flask into it (not system pip — same
      externally-managed-environment constraint as the host)
- [ ] Template: minimal `app.py` that returns its own hostname/identity
- [ ] Task: start it backgrounded (`nohup ... &`) bound to a port the lb
      upstream expects
- [ ] Run against `app1`/`app2`; verify each responds directly on its
      container

### Phase 4 — Integration test (the actual payoff)
Goal: prove the whole chain works together, not just each piece alone.
- [ ] Full sequence: `terraform apply` → `ansible-playbook` against the
      generated inventory → curl the `lb` container repeatedly
- [ ] Confirm responses alternate between `app1` and `app2` (round-robin
      is real, not assumed)
- [ ] `terraform destroy` cleanly tears everything down with no leftovers

### Phase 5 — CI
Goal: the two workflows the README already promises actually exist and
pass.
- [ ] `.github/workflows/` job running `terraform validate`
- [ ] `.github/workflows/` job running `ansible-lint`
- [ ] Push and confirm both go green

### Phase 6 — Docs cleanup
- [ ] Replace README's "Coming soon" Quickstart with the real, tested
      command sequence from Phase 4
- [ ] Confirm `.gitignore` actually covers everything generated
      (`ansible/inventory/hosts.ini` is already listed — verify nothing
      else leaks into git status after a full apply/destroy cycle)

### Phase 7 — Roadmap (intentionally undecided)
You chose not to lock in a phase-2 direction yet — decide after Phase 1
is fully working end to end and you've felt what part you enjoyed most.
Candidates on the table when that time comes: pointing Terraform at a
real cloud provider instead of local Docker, adding production-ish ops
concerns (secrets, TLS, remote state, health checks), or growing the
topology itself (a database tier, more nodes, service discovery).
