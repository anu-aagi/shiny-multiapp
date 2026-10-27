# How the automation works

`deploy/README.md` is the runbook — the commands to type. This file explains
what those commands set in motion, so that when something misbehaves you are
debugging a system you understand rather than a black box.

"Automated" here means two specific things, and it is worth separating them
because they fail in different ways:

1. **Nothing has to be started by hand.** The apps come back after a reboot, a
   crash, or a podman upgrade, with nobody logged in. This is systemd's job.
2. **A code change reaches production in one command.** Build, config install,
   restart and health check are a single script. This is `deploy.sh`'s job.

The first is continuous and unattended. The second is deliberate and manual —
there is no CI, so a change on `main` does nothing until someone runs the
deploy.

---

## Part one: systemd owns the containers

The containers are not started by `podman run`. They are described as systemd
units, and systemd starts them.

The reason is blunt: ITSU patches and reboots `CBEVLSAPP101` without notice,
and a container started by hand is gone after that reboot. Nothing notices
until a user complains. Under systemd the host comes back and so do the apps.

### Quadlet is a generator, not a service

This is the one concept that makes everything else make sense.

Podman ships **Quadlet**, a *systemd generator*. The files in
`/etc/containers/systemd/` are not units systemd runs directly. At every boot
and at every `systemctl daemon-reload`, systemd invokes
`/usr/libexec/podman/quadlet`, which reads those files and writes real
`.service` units into `/run/systemd/generator/`. Those generated units are what
systemd actually starts, and they are rewritten from scratch every time.

```
/etc/containers/systemd/shiny-met.container
            │
            │  quadlet generator, at boot and at daemon-reload
            ▼
/run/systemd/generator/shiny-met.service   ← what systemd runs
            │
            ▼
   podman run ... (as a long-running foreground process systemd supervises)
```

Four consequences follow, and all four have already bitten this deployment:

**Unit names drop the extension.** `shiny-met.container` becomes
`shiny-met.service`. `shiny.network` becomes `shiny-network.service`. You refer
to them by the `.service` name in every `systemctl` command.

**You never `systemctl enable` them.** systemd refuses to enable a generated
unit — it fails with "unit is transient or generated". Start-at-boot comes from
the `[Install] WantedBy=` lines inside each `.container` file, which Quadlet
translates into the target symlinks on your behalf. If you find yourself
reaching for `enable`, the unit is already handled.

**You never edit the generated unit.** Anything you change in
`/run/systemd/generator/` is destroyed at the next reload. Edit the
`.container` file in `/etc/containers/systemd/`, then `daemon-reload`.

**One unrecognised key discards the whole unit, silently.** Quadlet does not
warn and does not partially apply; the unit simply never appears, and
`systemctl restart shiny-met` answers "unit not found" as though you had
invented the name. This is exactly how the first install attempt failed: the
units carried `Init=yes`, which is **docker-compose's** key. Quadlet's is
`RunInit=`. Three units vanished without a word.

So when a unit does not exist after a reload, run the generator by hand and
read what it says:

```bash
sudo /usr/libexec/podman/quadlet -dryrun
```

It prints each generated unit to stdout and each rejected key to stderr. This
is the first diagnostic for any "unit not found", before anything else.

### The dependency graph

```
            shiny-network.service          (creates the podman network)
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   shiny-hub     shiny-met     shiny-trial   (one R process each, port 3838)
        └─────────────┼─────────────┘
                      ▼
               shiny-proxy.service          (nginx; the only unit with host ports)
                      │
          ports 80, 443, 8080 on the host
```

The proxy declares the three apps with `After=` **and** `Wants=`, never
`Requires=`. The distinction is the whole availability story:

- `After=` is ordering only. It gets the apps started before nginx, which
  matters because nginx refuses to start at all if a hostname in `proxy_pass`
  cannot be resolved.
- `Wants=` pulls the apps in but tolerates their failure. With `Requires=`, one
  broken app would prevent the proxy from starting, and a single bad app would
  take every other app offline with it.
- `Restart=always` with `RestartSec=5` closes the gap: if the proxy did start
  too early and died, it retries every five seconds until the apps answer.

That combination is what makes the stack self-healing rather than merely
ordered. An app that segfaults is restarted within five seconds. A proxy that
lost its upstreams recovers on its own.

### Two settings that are load-bearing

**`IP=` — the fixed addresses.** nginx resolves the names in `proxy_pass` once,
when the worker starts, and caches the result for the life of the process. A
container that comes back on a different address leaves the proxy sending
traffic to an address nothing is listening on: **502 on every route, with three
healthy apps running and nothing in any app's log**. It is a thoroughly
misleading failure. Pinning each container's address in its unit — and pinning
the network's subnet in `shiny.network` so podman cannot move it — makes that
cache permanently valid, which is why `deploy.sh` can restart an app without
restarting the proxy.

**`RunInit=yes` — a real init at PID 1.** Linux applies no default signal
disposition to PID 1, and R installs no SIGTERM handler, so R running as PID 1
ignores SIGTERM outright. Every stop then waits out systemd's ten-second
timeout and ends in SIGKILL, dropping live user sessions mid-request. An init
process at PID 1 forwards the signal and R exits on it. If you ever see
`SIGTERM ... SIGKILL` pairs in the journal during a deploy, this setting has
gone missing.

If a future podman release rejects `RunInit=`, the portable equivalent is
`PodmanArgs=--init`, which passes the flag straight through.

### Rootful, deliberately

These are root-owned units in `/etc/containers/systemd/`, not user units in
`~/.config/containers/systemd/`. Rootless containers cannot bind ports below
1024 without extra configuration, and the proxy needs 80 and 443. The cost is
that `podman ps` as your own user shows nothing — every podman command here
needs `sudo`, and the two storage trees are entirely separate. An image you
built without `sudo` is invisible to the units.

---

## Part two: `deploy.sh`

One script, run as root on the VM, carrying a change from the checkout in
`~/shiny-multiapp` to running containers:

```bash
rsync -av --delete --exclude '.git' ~/Documents/shiny-multiapp/ 10.40.87.20:~/shiny-multiapp/
ssh -t 10.40.87.20 'sudo ~/shiny-multiapp/deploy/deploy.sh'
```

What it does, and what each step is there to guarantee:

| Step | Action | Why |
| --- | --- | --- |
| 1 | Refuse to run unless `EUID` is 0 | The units are rootful; a non-root build lands in the wrong image store and the restart silently uses the old image |
| 2 | `podman build --build-arg APP=<app>` for hub, met, trial | One parameterised `Dockerfile`; the expensive layers sit above `ARG APP` so all three builds share them |
| 3 | `install -D -m 0644 -t /opt/shiny-proxy` the four nginx configs | The proxy mounts its config from the host, so an nginx change needs no image rebuild |
| 4 | `systemctl restart shiny-hub shiny-met shiny-trial` | Recreates each container on the new image, on its same fixed IP |
| 5 | `systemctl restart shiny-proxy` | Only to pick up the config from step 3 — not for DNS, which the fixed IPs make unnecessary |
| 6 | Poll `http://127.0.0.1/hub/` for up to 30s | R takes a few seconds to attach packages; without this the health check races the app |
| 7 | Assert HTTP 200 on `/hub/`, `/met/`, `/trial/` | Exits non-zero on anything else, so a broken deploy is loud rather than discovered by a user |

`set -euo pipefail` means any failing step aborts the rest. A failed build never
reaches the restart.

Package versions are not part of what a deploy can change: `Dockerfile` installs
from the pinned `CRAN_SNAPSHOT` date against a frozen Posit Package Manager
snapshot. Two deploys a month apart resolve to identical package versions.
Picking up newer packages is a deliberate edit to that date.

---

## What is automated, and what is not

| Event | What happens | Who acts |
| --- | --- | --- |
| Host reboot | All five units start from `WantedBy=` | Nobody |
| An app crashes | systemd restarts it within 5s | Nobody |
| Proxy starts before an app is ready | `Restart=always` retries until it resolves | Nobody |
| podman or host package upgrade | Units regenerate at the next reload or boot | Nobody |
| Code or nginx change | rsync, then one `deploy.sh` | You, on purpose |
| New app added | Four repo edits (see the main README), plus a new `.container` file, `cp` to `/etc/containers/systemd/`, `daemon-reload`, add it to the `apps=()` array in `deploy.sh` | You |
| Unit file change | `cp` to `/etc/containers/systemd/` and `daemon-reload` — `deploy.sh` does **not** install unit files | You |
| `/var` fills with old images | Nothing; builds accumulate untagged layers | You: `sudo podman system prune -a` |
| TLS certificate renewal | Nothing | You (and currently the F5 holds the public certificate) |

Three things are worth calling out as genuinely absent rather than merely
manual:

**There is no CI.** A commit does nothing. Delivery is rsync from the laptop,
which means the deployed code is whatever was in that working tree, committed
or not. Now that the VM has outbound internet this is the most worthwhile thing
to fix — see "Where to take this next".

**There is no rollback.** Every build overwrites the `:latest` tag; the previous
image becomes an untagged dangling layer set, with no name to restart against.
Recovering from a bad deploy means checking out an earlier commit and building
again, with the site degraded in the meantime.

**`deploy.sh` does not build the proxy image.** It builds the three app images
only. nginx comes from a pinned image already in root's podman storage, left
over from the air-gapped delivery. If that image is ever pruned, `shiny-proxy`
will fail to start with an image-not-found error that mentions nothing about
pruning.

---

## Prerequisites the units assume

Two files have to exist before `shiny-proxy` can start, and neither is created
by `deploy.sh`. Both are inferred from `shiny-proxy.container` rather than
verified on the host — check them before trusting this section:

- **The nginx image**, at the tag named in `shiny-proxy.container`
  (`Image=localhost/nginx:1.27-alpine`). Confirm with
  `sudo podman images | grep nginx`.
- **`/opt/shiny-proxy/tls/server.crt` and `server.key`.** The unit mounts that
  directory and `nginx-tls.conf` references the certificate, so nginx will
  refuse to start without it. A self-signed pair is sufficient for the backend
  hop if the F5 terminates TLS at the edge:

  ```bash
  sudo mkdir -p /opt/shiny-proxy/tls
  sudo openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout /opt/shiny-proxy/tls/server.key \
    -out /opt/shiny-proxy/tls/server.crt \
    -subj "/CN=aagi-apps.anu.edu.au"
  ```

  Whether the F5 verifies that certificate is still an open question with ANU
  IT. If it does, this needs a CA-issued certificate instead.

One podman behaviour makes this sharper than it sounds: a bind mount whose host
path does not exist is created by podman **as a directory**. A missing
`nginx.conf` therefore appears inside the container as an empty directory where
nginx expects a file, and the error you get describes a configuration problem
rather than a missing mount.

---

## Verifying it

**All five units were generated.** Fewer than five means Quadlet rejected a
file — go to `-dryrun`:

```bash
systemctl list-unit-files 'shiny-*'
# expect: shiny-network.service, shiny-hub, shiny-met, shiny-trial, shiny-proxy
```

**Everything is running, and the routes answer:**

```bash
systemctl is-active shiny-hub shiny-met shiny-trial shiny-proxy
for p in hub met trial; do curl -sI "http://127.0.0.1/$p/" | head -1; done
```

**One container's own logs** — note the unit name, not the container name:

```bash
journalctl -u shiny-met -n 50 --no-pager
```

**The reboot survives**, which is the entire justification for this machinery
and the one claim worth proving rather than assuming:

```bash
sudo reboot
# then, once it answers ssh again:
systemctl is-active shiny-hub shiny-met shiny-trial shiny-proxy
curl -I http://127.0.0.1/
```

---

## Where to take this next

In rough order of value:

1. **Push the repo to GitHub and build in CI.** The VM has outbound internet
   now, so a GitHub Actions job can build and push the three images to a
   registry and the VM can pull them. That removes rsync-from-a-laptop as the
   delivery mechanism and makes the deployed code identical to a known commit.
2. **Tag images by commit SHA** as well as `:latest`. That alone buys a
   rollback: `systemctl restart` against a previous tag, instead of a rebuild.
3. **Address the apps by IP in `docker/app_routes.conf`.** nginx starts
   regardless of whether an IP answers, which removes the last way one app can
   keep the proxy down. Not done today because the addresses differ under
   `docker compose`, where local development runs — worth revisiting if an app
   from another team is ever hosted alongside these, since one tenant should
   not be able to affect another.
4. **Scope the firewall.** Ports 80, 443 and 8080 are open to any source; every
   other rule in that zone is scoped to the `anu`/`anu6` ipsets ITSU maintains.
5. **Retire port 8080** and its firewall rule once the F5 cutover is complete
   and users are reaching the public hostname.
