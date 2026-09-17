# Page chrome: masthead, gold title band, body, footer, and the stat tiles.
# The same markup is in every app, so it stays in step with the shared
# stylesheet below.

# One stylesheet serves every app, from a www directory one level above this
# one: apps/www when the app is run from the repo, /srv/www in the image (the
# Dockerfile puts it there, beside /srv/app, so the same relative path works).
# Shiny only serves the app's own directory, so the folder is registered as a
# resource prefix; the href stays relative, or it would miss the /trial/ path
# the proxy serves the app under.
addResourcePath("assets", normalizePath(file.path("..", "www"), mustWork = TRUE))

# Wraps the app's content in the ANU page furniture. `...` is the body.
anu_page <- function(browser_title, title, lede, ...) {
  fluidPage(
    title = browser_title,
    tags$head(
      tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
      tags$link(rel = "preconnect", href = "https://fonts.gstatic.com",
                crossorigin = NA),
      tags$link(rel = "stylesheet", href = paste0(
        "https://fonts.googleapis.com/css2?family=Public+Sans:",
        "wght@400;500&display=swap"
      )),
      tags$link(rel = "stylesheet", href = "assets/app.css"),
      # Restoring this page from the browser's back/forward cache leaves a dead
      # websocket and Shiny's grey disconnect overlay; force a fresh load.
      tags$script(HTML(
        "window.addEventListener('pageshow', function(e) {
           if (e.persisted) location.reload();
         });"
      ))
    ),

    tags$a(href = "#main", class = "skip-link", "Skip to main content"),

    tags$header(
      class = "anu-masthead",
      tags$div(
        class = "anu-masthead-inner",
        tags$a(
          class = "anu-mark", href = hub_url,
          tags$div(class = "anu-mark-rule", `aria-hidden` = "true"),
          tags$div(
            class = "anu-mark-text",
            tags$span(class = "anu-mark-the", "The"),
            "Australian National University"
          )
        ),
        tags$a(class = "back-link", href = hub_url,
               HTML("&larr;&nbsp; All applications"))
      )
    ),

    tags$div(
      class = "anu-band",
      tags$div(
        class = "anu-band-inner",
        h1(class = "app-title", title),
        p(class = "app-lede", lede)
      )
    ),

    tags$main(id = "main", class = "app-body", ...),

    tags$footer(
      class = "anu-footer",
      tags$div(
        class = "anu-footer-inner",
        "The Australian National University, Canberra. ",
        "CRICOS Provider: 00120C · ABN: 52 234 063 906 · ",
        "TEQSA Provider ID: PRV12002"
      )
    )
  )
}

stat_tile <- function(label, value, sub) {
  div(class = "tile",
      div(class = "label", label),
      div(class = "value", value),
      div(class = "sub", sub))
}

stat_tiles <- function(...) div(class = "tile-row", ...)

# A plot with a hover readout floating over it; the tip itself is rendered
# server-side into `id`_tip.
hover_plot <- function(id, height) {
  div(
    class = "viz-wrap",
    plotOutput(id, height = height,
               hover = hoverOpts(paste0(id, "_hover"), delay = 60,
                                 delayType = "debounce")),
    uiOutput(paste0(id, "_tip"))
  )
}

# Positions a hover readout next to the cursor. `...` is the tip's content.
hover_tip <- function(hover, ...) {
  div(
    class = "viz-tip",
    style = sprintf("position:absolute;z-index:100;left:%.0fpx;top:%.0fpx;",
                    hover$coords_css$x + 14, hover$coords_css$y + 6),
    ...
  )
}

# A table built from a header vector and a list of row tag lists.
data_table <- function(headers, rows) {
  div(
    class = "table-scroll",
    tags$table(
      class = "data-table",
      tags$thead(tags$tr(lapply(headers, tags$th))),
      tags$tbody(rows)
    )
  )
}
