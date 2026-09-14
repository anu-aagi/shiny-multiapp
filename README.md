# shiny-multiapp

A minimal two-app Shiny setup you clone and run locally.

```
shiny-multiapp/
├── apps/
│   ├── hub/app.R       # springboard landing page — tap a tile, go to that app
│   ├── app1/app.R      # simple counter
│   └── app2/app.R      # mtcars scatter explorer (needs ggplot2)
```

`hub` is just a grid of tiles styled like an iPhone home screen. Clicking a
tile does a full page navigation to that app — not an embed — so each app
still runs as its own independent Shiny process.

## Run it

```r
install.packages(c("shiny", "ggplot2", "renv"))
renv::init()      # first time only, creates renv.lock from installed packages
renv::snapshot()  # re-run any time you add/remove a package
```

Run all three at once, each in its own terminal tab, so the hub has
something to link to:

```bash
# Terminal 1
Rscript -e "shiny::runApp('apps/app1', port = 3838)"

# Terminal 2
Rscript -e "shiny::runApp('apps/app2', port = 3839)"

# Terminal 3
Rscript -e "shiny::runApp('apps/hub')"
```

Open the hub's URL (shown in Terminal 3, something like
`http://127.0.0.1:XXXX`) and click a tile — it navigates to app1 or app2
just like tapping an app icon.

Commit `renv.lock` — it's what lets anyone else who clones the repo
install the exact same package versions with `renv::restore()`.

## Adding another app

1. Drop a new folder in `apps/` with its own `app.R`.
2. Run it on its own port, same as app1/app2 above.
3. Add a tile for it in `apps/hub/app.R`'s `apps` list (name, subtitle,
   icon, url — pointing at that port).
