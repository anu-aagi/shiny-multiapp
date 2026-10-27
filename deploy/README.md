# Deployment

How the apps run on `CBEVLSAPP101` (`10.40.87.20`), to be published as
`aagi-apps.anu.edu.au` behind the ANU F5 load balancer.

The containers are managed by **systemd via Quadlet**, not by `podman run`, so
they come back after a reboot — ITSU patches and restarts this host without
notice, and hand-started containers do not survive it.

```
deploy/
├── shiny.network           # the container network, with a pinned subnet
├── shiny-hub.container     # one unit per app
├── shiny-met.container
├── shiny-trial.container
├── shiny-proxy.container   # nginx; the only unit publishing host ports
├── deploy.sh               # rebuild images, restart units, health check
└── AUTOMATION.md           # how all of the above actually works
```

This file is the runbook — the commands to type.
[AUTOMATION.md](AUTOMATION.md) explains the mechanism behind them: how Quadlet
turns these files into units, which settings are load-bearing and why, what is
automated versus merely scripted, and how to diagnose it when a unit does not
appear. Read it before changing anything here.

## First-time install

Run once on the VM, as root. It replaces any hand-started containers.

```bash
# Stop and remove whatever is running by hand
sudo podman rm -f hub met trial proxy || true
sudo podman network rm shiny || true

# Install the units
sudo cp ~/shiny-multiapp/deploy/*.container ~/shiny-multiapp/deploy/*.network \
        /etc/containers/systemd/
sudo systemctl daemon-reload

# Build the images and start everything
sudo ~/shiny-multiapp/deploy/deploy.sh
```

There is no `systemctl enable` step. Quadlet regenerates these units from
`/etc/containers/systemd/` on every `daemon-reload` and boot, and systemd will
not enable a generated unit — `enable` fails with "unit is transient or
generated". Starting at boot comes from the `[Install] WantedBy=` lines in each
`.container` file, which Quadlet turns into the target symlinks itself.

Verify it really survives one — this is the whole point, and it is worth
proving rather than assuming:

```bash
sudo reboot
# wait, then:
sudo systemctl is-active shiny-hub shiny-met shiny-trial shiny-proxy
curl -I http://127.0.0.1/
```

## Deploying a change

From the laptop:

```bash
rsync -av --delete --exclude '.git' --exclude '.Rproj.user' --exclude '.Rhistory' \
  ~/Documents/shiny-multiapp/ 10.40.87.20:~/shiny-multiapp/
ssh -t 10.40.87.20 'sudo ~/shiny-multiapp/deploy/deploy.sh'
```

`deploy.sh` rebuilds all three images, installs the nginx configuration to
`/opt/shiny-proxy/`, restarts the units, and fails loudly if any app does not
return 200. The R package versions come from the pinned `CRAN_SNAPSHOT` in the
`Dockerfile`, so a deploy never silently changes them.

## When something is wrong

Start here, in this order:

```bash
systemctl list-unit-files 'shiny-*'       # expect five; fewer means Quadlet rejected a file
sudo /usr/libexec/podman/quadlet -dryrun  # ...and this says which key it choked on
systemctl is-active shiny-hub shiny-met shiny-trial shiny-proxy
journalctl -u shiny-met -n 50 --no-pager  # unit name, not container name
```

Two settings in the unit files are load-bearing and must not be dropped — the
fixed `IP=` addresses, and `RunInit=yes`. Both have failure modes that look like
something else entirely: 502s on every route with three healthy apps, and live
sessions killed on every deploy. [AUTOMATION.md](AUTOMATION.md) covers both, the
known availability gap in the proxy's startup, and what `deploy.sh` does not
do.
