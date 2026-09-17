library(shiny)

# Hub: The landing page
#
# Clicking a card does a full page navigation to that app (not an iframe),
# so each app keeps running as its own independent Shiny process.
#
# HUB_MODE picks where the cards point:
#   "docker" (default) -> /met/, /trial/ — nginx serves every app under one
#                         origin, so relative paths are correct
#   "local"            -> http://127.0.0.1:<port>, for running each app
#                         directly with Rscript (see README)
#
# Styling follows the ANU web brand: Public Sans, ANU gold (#BE830E) used
# only as a highlight, gold tint (#F5EDDE) for secondary surfaces, black and
# white doing the structural work. The masthead is a typographic lockup, not
# the official crest — the crest may not be redrawn or approximated, so drop
# the real logo asset in here if you have it.

mode <- Sys.getenv("HUB_MODE", unset = "docker")

apps <- list(
  list(name = "MET Explorer",
       subtitle = "Variety performance across environments, factor analytic",
       icon = "🌾",
       url = if (mode == "local") "http://127.0.0.1:3838" else "/met/"),
  list(name = "Field Trial Analyser",
       subtitle = "Spatial adjustment of a single-site variety trial",
       icon = "🗺️",
       url = if (mode == "local") "http://127.0.0.1:3839" else "/trial/")
)

app_card <- function(app) {
  tags$a(
    href = app$url,
    target = "_self",
    class = "app-card",
    tags$div(class = "app-icon", `aria-hidden` = "true", app$icon),
    tags$div(
      class = "app-text",
      tags$h3(class = "app-name", app$name),
      tags$p(class = "app-subtitle", app$subtitle)
    ),
    tags$div(class = "app-chevron", `aria-hidden` = "true", HTML("&rarr;"))
  )
}

ui <- fluidPage(
  title = "Applications | The Australian National University",
  tags$head(
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com",
              crossorigin = NA),
    tags$link(rel = "stylesheet", href = paste0(
      "https://fonts.googleapis.com/css2?family=Public+Sans:",
      "wght@400;500&display=swap"
    )),
    tags$style(HTML("
    :root {
      --anu-gold: #BE830E;
      --anu-gold-tint: #F5EDDE;
      --anu-black: #000000;
      --anu-white: #FFFFFF;
      --anu-unigrey: #333333;
      --anu-rule: #d5d5d5;
      --anu-muted: #5c5c5c;
    }
    body {
      background: var(--anu-white);
      color: var(--anu-unigrey);
      font-family: 'Public Sans', -apple-system, BlinkMacSystemFont,
                   'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.55;
      margin: 0;
    }
    /* fluidPage wraps everything in a padded container we don't want.
       It's also given flex-column layout so the footer sits at the
       bottom of the viewport instead of floating mid-page on short
       content, rather than being pushed down by real page height. */
    html, body { height: 100%; }
    .container-fluid {
      padding: 0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    .hub-wrap { flex: 1 0 auto; }

    /* Nothing in these apps is bold. Public Sans at 400, with 500 carrying the
       hierarchy; headings, table headers and <b> would otherwise inherit the
       browser's bold. */
    b, strong, th, label, legend, optgroup, .btn, dt,
    h1, h2, h3, h4, h5, h6, .h1, .h2, .h3, .h4, .h5, .h6 { font-weight: 500; }

    /* Skip link — keyboard users get past the masthead */
    .skip-link {
      position: absolute;
      left: -9999px;
      top: 0;
      background: var(--anu-gold);
      color: var(--anu-black);
      padding: 10px 16px;
      font-weight: 500;
      z-index: 10;
    }
    .skip-link:focus { left: 0; color: var(--anu-black); }

    /* ---- Masthead ---------------------------------------------------- */
    .anu-masthead {
      background: var(--anu-black);
      border-bottom: 4px solid var(--anu-gold);
    }
    .anu-masthead-inner {
      max-width: 1080px;
      margin: 0 auto;
      padding: 22px 32px;
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .anu-mark {
      display: flex;
      align-items: center;
      gap: 16px;
      text-decoration: none;
    }
    .anu-mark:hover, .anu-mark:focus { text-decoration: none; }
    .anu-mark-rule {
      width: 4px;
      align-self: stretch;
      min-height: 38px;
      background: var(--anu-gold);
      flex: none;
    }
    .anu-mark-text {
      color: var(--anu-white);
      font-weight: 500;
      font-size: 17px;
      line-height: 1.25;
      letter-spacing: 0.01em;
    }
    .anu-mark-text .anu-mark-the {
      display: block;
      font-weight: 400;
      font-size: 12px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: #c9c9c9;
      margin-bottom: 2px;
    }

    /* ---- Page heading band ------------------------------------------- */
    .anu-band {
      background: var(--anu-gold-tint);
      border-bottom: 1px solid #e6dcc7;
    }
    .anu-band-inner {
      max-width: 1080px;
      margin: 0 auto;
      padding: 48px 32px 40px;
    }
    h1.hub-title {
      font-size: 40px;
      font-weight: 500;
      line-height: 1.15;
      letter-spacing: -0.015em;
      color: var(--anu-black);
      margin: 0 0 10px;
    }
    p.hub-lede {
      font-size: 17px;
      color: var(--anu-unigrey);
      margin: 0;
      max-width: 52ch;
    }

    /* ---- Main ---------------------------------------------------------- */
    .hub-wrap {
      max-width: 1080px;
      margin: 0 auto;
      padding: 44px 32px 72px;
    }
    h2.section-title {
      font-size: 13px;
      font-weight: 500;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--anu-black);
      margin: 0 0 4px;
    }
    .section-rule {
      border: 0;
      border-top: 3px solid var(--anu-gold);
      width: 48px;
      margin: 0 0 24px;
    }
    .app-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 20px;
    }
    .app-card {
      display: flex;
      align-items: center;
      gap: 18px;
      padding: 22px 24px;
      background: var(--anu-white);
      border: 1px solid var(--anu-rule);
      border-left: 4px solid var(--anu-black);
      text-decoration: none;
      color: inherit;
      transition: border-left-color 0.15s ease, box-shadow 0.15s ease,
                  transform 0.15s ease;
    }
    .app-card:hover, .app-card:focus-visible {
      border-left-color: var(--anu-gold);
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
      transform: translateY(-2px);
      text-decoration: none;
      color: inherit;
    }
    .app-card:focus-visible {
      outline: 3px solid var(--anu-gold);
      outline-offset: 2px;
    }
    .app-icon {
      flex: none;
      width: 48px;
      height: 48px;
      background: var(--anu-gold-tint);
      border: 1px solid #e6dcc7;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
    }
    .app-text { flex: 1; min-width: 0; }
    h3.app-name {
      font-size: 19px;
      font-weight: 500;
      color: var(--anu-black);
      margin: 0 0 2px;
      line-height: 1.3;
    }
    p.app-subtitle {
      font-size: 15px;
      color: var(--anu-muted);
      margin: 0;
    }
    .app-chevron {
      flex: none;
      color: var(--anu-black);
      font-size: 20px;
      transition: transform 0.15s ease;
    }
    .app-card:hover .app-chevron { transform: translateX(4px); }

    /* ---- Footer -------------------------------------------------------- */
    .anu-footer {
      background: var(--anu-black);
      color: #d4d4d4;
      border-top: 4px solid var(--anu-gold);
    }
    .anu-footer-inner {
      max-width: 1080px;
      margin: 0 auto;
      padding: 40px 32px 44px;
    }
    h2.acknowledgement-title {
      font-size: 13px;
      font-weight: 500;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--anu-gold);
      margin: 0 0 10px;
    }
    .acknowledgement {
      font-size: 14.5px;
      line-height: 1.65;
      max-width: 78ch;
      margin: 0 0 28px;
      color: #d4d4d4;
    }
    .anu-legal {
      border-top: 1px solid #333;
      padding-top: 20px;
      font-size: 13px;
      color: #9a9a9a;
      margin: 0;
    }

    @media (max-width: 640px) {
      .anu-masthead-inner, .anu-band-inner, .hub-wrap, .anu-footer-inner {
        padding-left: 20px;
        padding-right: 20px;
      }
      h1.hub-title { font-size: 30px; }
      .anu-band-inner { padding-top: 36px; padding-bottom: 30px; }
    }
  ")),
    # Shiny shows a gray disconnected overlay if the browser restores this
    # page from its back/forward cache (e.g. hitting Back after a card takes
    # you to another app) because the old websocket connection is dead.
    # Force a fresh load in that case so the app reconnects cleanly.
    tags$script(HTML("
    window.addEventListener('pageshow', function(e) {
      if (e.persisted) location.reload();
    });
  "))),

  tags$a(href = "#main", class = "skip-link", "Skip to main content"),

  tags$header(
    class = "anu-masthead",
    tags$div(
      class = "anu-masthead-inner",
      tags$a(
        class = "anu-mark",
        # local mode gives the hub a random port, so stay relative
        href = if (mode == "local") "./" else "/hub/",
        tags$div(class = "anu-mark-rule", `aria-hidden` = "true"),
        tags$div(
          class = "anu-mark-text",
          tags$span(class = "anu-mark-the", "The"),
          "Australian National University"
        )
      )
    )
  ),

  tags$div(
    class = "anu-band",
    tags$div(
      class = "anu-band-inner",
      h1(class = "hub-title", "Crop analytics"),
      p(class = "hub-lede",
        "Analysis tools for crop variety trials. Select an application below ",
        "to open it. Each one runs as its own independent service.")
    )
  ),

  tags$main(
    id = "main",
    class = "hub-wrap",
    tags$h2(class = "section-title", "Available applications"),
    tags$hr(class = "section-rule"),
    div(class = "app-grid", lapply(apps, app_card))
  ),

  tags$footer(
    class = "anu-footer",
    tags$div(
      class = "anu-footer-inner",
      tags$h2(class = "acknowledgement-title", "Acknowledgement of Country"),
      tags$p(
        class = "acknowledgement",
        "The Australian National University acknowledges, celebrates and pays ",
        "our respects to the Ngunnawal and Ngambri people of the Canberra ",
        "region and to all First Nations Australians on whose traditional ",
        "lands we meet and work, and whose cultures are among the oldest ",
        "continuing cultures in human history."
      ),
      tags$p(
        class = "anu-legal",
        "The Australian National University, Canberra. ",
        "CRICOS Provider: 00120C · ABN: 52 234 063 906 · ",
        "TEQSA Provider ID: PRV12002 (Australian University)"
      )
    )
  )
)

server <- function(input, output, session) {
  # Browsers throttle/suspend background tabs and drop the websocket; without
  # this the reconnect grace period is off and Shiny shows a dead gray
  # overlay requiring a full reload instead of reconnecting transparently.
  session$allowReconnect(TRUE)
}

shinyApp(ui, server)
