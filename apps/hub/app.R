library(shiny)

# --- Hub: an iOS-springboard-style landing page ---
#
# Tapping a tile does a full page navigation to that app (not an iframe),
# same as tapping an app icon on an iPhone takes you into the app.
#
# Each app runs as its own process on its own port (see README), so tiles
# point at http://127.0.0.1:<port>.

apps <- list(
  list(name = "App 1", subtitle = "Counter", icon = "🔢",
       url = "http://127.0.0.1:3838"),
  list(name = "App 2", subtitle = "mtcars Explorer", icon = "📊",
       url = "http://127.0.0.1:3839")
)

app_tile <- function(app) {
  tags$a(
    href = app$url,
    target = "_self",
    class = "app-tile",
    tags$div(class = "app-icon", app$icon),
    tags$div(class = "app-name", app$name),
    tags$div(class = "app-subtitle", app$subtitle)
  )
}

ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { background: #f2f2f7; }
    .springboard {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
      gap: 24px;
      max-width: 600px;
      margin: 60px auto;
      padding: 0 20px;
    }
    .app-tile {
      text-decoration: none;
      color: #1c1c1e;
      text-align: center;
      display: block;
    }
    .app-icon {
      width: 72px;
      height: 72px;
      margin: 0 auto 8px auto;
      background: linear-gradient(135deg, #5AC8FA, #007AFF);
      border-radius: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.15);
      transition: transform 0.15s ease;
    }
    .app-tile:hover .app-icon { transform: scale(1.06); }
    .app-name { font-weight: 600; font-size: 14px; }
    .app-subtitle { font-size: 11px; color: #6e6e73; }
    h1.hub-title { text-align: center; padding-top: 40px; font-weight: 700; color: #1c1c1e; }
  ")),
  # Shiny shows a gray "disconnected" overlay if the browser restores this
  # page from its back/forward cache (e.g. hitting Back after a tile takes
  # you to another app) because the old websocket connection is dead.
  # Force a fresh load in that case so the app reconnects cleanly.
  tags$script(HTML("
    window.addEventListener('pageshow', function(e) {
      if (e.persisted) location.reload();
    });
  "))),
  h1(class = "hub-title", "My Apps"),
  div(class = "springboard", lapply(apps, app_tile))
)

server <- function(input, output, session) {}

shinyApp(ui, server)
