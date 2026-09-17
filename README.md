# shiny-multiapp

A minimal two-app Shiny setup to serve as the basis for the potential future AAGI-ANU Shiny Server

`hub` is a landing page listing every app. Clicking a card does a full page
navigation to that app, not an embed, so each app still runs as its own
independent Shiny process.

```
shiny-multiapp/
├── apps/
│   ├── hub/app.R          # landing page listing the apps
│   ├── met/               # multi-environment trial explorer (needs ggplot2)
│   ├── trial/             # single-trial spatial analysis (needs ggplot2)
│   └── www/app.css        # the stylesheet both analysis apps share
├── Dockerfile             # one parameterised image, built once per app
├── docker-compose.yml     # hub + met + trial + nginx proxy
└── docker/
    ├── nginx.conf         # routes /hub/, /met/, /trial/
    └── shiny_proxy.conf   # shared websocket/proxy headers
```

The two analysis apps are split the same way:

```
apps/trial/
├── app.R                  # what the app is; attaches packages, sources R/, calls shinyApp()
└── R/
    ├── _disable_autoload.R  # see below
    ├── analysis.R         # the statistics, with no Shiny in it
    ├── constants.R        # sizes and the hub link
    ├── data.R             # the simulated data
    ├── layout.R           # ANU page chrome, small UI helpers, the stylesheet link
    ├── server.R           # reactives and outputs
    ├── theme.R            # chart palette and ggplot theme
    └── ui.R               # the page
```

Page styling is not in either app: both serve `apps/www/app.css`, so a change
to it reaches both at once. Shiny only serves an app's own directory, so
`R/layout.R` registers the folder one level up as a resource path
(`addResourcePath("assets", "../www")`) and links it as `assets/app.css` — a
relative href, so it still resolves under the `/trial/` path the proxy serves
the app under. The `Dockerfile` copies that folder to `/srv/www`, beside
`/srv/app`, so the same relative path works inside the image. The hub styles
itself inline and does not use it.

`app.R` sources `R/` itself, in an order written down in that file, rather than
using Shiny's auto-loading. Auto-loading sorts the directory alphabetically,
and for an `app.R`-style app it never sources `global.R` at all — so there is
no reliable place to attach ggplot2 before `R/theme.R` needs it while being
sourced. `R/_disable_autoload.R` turns the automatic pass off; see
`?shiny::loadSupport`.

`R/analysis.R` is plain R — no reactives, no `input`, and neither Shiny nor
ggplot2 needed — so the statistics can be run and checked on their own:

```bash
Rscript -e "for (f in c('constants','analysis','data')) \
              source(file.path('apps/trial/R', paste0(f, '.R'))); \
            print(compare_models(sims\$patchy\$data, sims\$patchy\$g_true))"
```

## The apps

Both are crop variety trial analytics, and they are two halves of the same
pipeline: `trial` produces adjusted variety means from one trial, `met`
takes a table of those means across many trials and turns it into advice.

**MET Explorer** (`apps/met`) analyses a multi-environment trial series. The
variety-by-environment table is decomposed into factors; the first factor gives
each variety an Overall Performance score and the departure from its regression
gives a stability measure (RMSD), which is how a grower reads the two together.
Also plots latent regressions, environment loadings and the genetic correlation
between trials. Follows Smith,
Ganesalingam, Kuchel & Cullis (2015), *Factor analytic mixed models for the
provision of grower information from national crop variety testing programs*,
Theor Appl Genet 128:55–72 ([doi:10.1007/s00122-014-2412-x][smith2015]). The
paper fits the factor analytic structure inside a mixed model; because the app's
input is already a table of per-trial means, the same structure is recovered by
singular value decomposition — identical algebra, no extra package.

**Field Trial Analyser** (`apps/trial`) works on a single site. A yield trial
sits on ground that is never uniform, and the app fits four spatial models —
from nothing at all through replicate blocks and a smooth surface to a free
constant per row and range — showing what each does to the entry means, to the
LSD and repeatability of the trial, and to the residuals left on the field map.
Three contrasting trials make the point
that the right model depends on the field: blocking in the wrong direction buys
nothing, and on a uniform block the elaborate models only spend degrees of
freedom.

Both apps use **simulated** data, generated from a known process with a fixed
seed, so the true answer is available to check against. Site names are real
locations; the yields, varieties and entries are invented, and nothing in either
app should be read as a variety recommendation. Neither needs any package beyond
`shiny` and `ggplot2`.

[smith2015]: https://doi.org/10.1007/s00122-014-2412-x

## Run it with Docker

The only requirement is Docker. R and the packages live inside the images.

```bash
docker compose up --build
```

Then open <http://localhost> — it redirects to the hub, and the cards take you
to `/met/` and `/trial/`. If something else already holds port 80, pick
another: `HTTP_PORT=8080 docker compose up --build`, then
<http://localhost:8080>.

Each app runs in its own container on its own internal port 3838. An nginx
container is the only thing published to the host; it routes each path to the
right app and carries Shiny's websocket.

Stop with `docker compose down`. Later runs skip the rebuild:

```bash
docker compose up
```

### Package versions

`Dockerfile` installs from a frozen Posit Package Manager snapshot, so every
build resolves to the same package versions and nothing compiles from source.
To pick up newer packages, bump the date:

```bash
docker compose build --build-arg CRAN_SNAPSHOT=2026-12-01
```

Snapshots lag a day or two behind the current date, so don't use today's.

The R version itself is pinned by the base image tag (`rocker/r-ver:4.5.3`).

### Fonts

Everything is set in Public Sans at weight 400, with 500 carrying the
hierarchy — nothing is bold. The browser pulls the font from Google Fonts, but
charts are rasterised server-side by `renderPlot()`, so the graphics device
needs the font installed on the machine as well or the charts come out in a
different face from the page around them. No apt package ships Public Sans, so
the Dockerfile fetches the pinned upstream release:

```bash
docker compose build --build-arg PUBLIC_SANS_VERSION=2.001
```

Running without Docker, the apps use Public Sans for charts if it is installed
locally and fall back to the device default font if it is not — the pages
themselves always get it from Google Fonts.

## Run it without Docker

You need R with `shiny` and `ggplot2` installed. Run all three apps at once,
each in its own terminal tab, and set `HUB_MODE=local` so the hub's cards point
at ports instead of proxy paths:

```bash
# Terminal 1
Rscript -e "shiny::runApp('apps/met', port = 3838)"

# Terminal 2
Rscript -e "shiny::runApp('apps/trial', port = 3839)"

# Terminal 3
HUB_MODE=local Rscript -e "shiny::runApp('apps/hub')"
```

Open the hub's URL (shown in Terminal 3) and click a card.

The apps' "All applications" link points at `/hub/`, which is correct behind the
proxy but not when they run on bare ports. Set `HUB_URL` to fix it — the hub's
local port is random, so read it off Terminal 3 first:

```bash
HUB_URL=http://127.0.0.1:1234 Rscript -e "shiny::runApp('apps/met', port = 3838)"
```

## Adding another app

The folder name under `apps/` is the service name, the URL path and the build
argument, so keep the four steps below in agreement.

1. Drop a new folder in `apps/` with its own `app.R` (and, for anything bigger
   than a page or two, the `R/` split the two analysis apps use — including
   their `R/layout.R` if it should share `apps/www/app.css`).
2. Add a service to `docker-compose.yml`, copying an existing one and changing
   `APP: <name>` and the service key, and list it under the proxy's
   `depends_on`.
3. Add the two `location` blocks to `docker/nginx.conf` — the `= /<name>`
   redirect and the `/<name>/` proxy.
4. Add a card to the `apps` list in `apps/hub/app.R` (name, subtitle, icon,
   and the `/<name>/` url).

If the new app needs extra R packages, add them to the `install.packages()`
call in `Dockerfile`.
