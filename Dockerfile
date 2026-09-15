FROM rocker/r-ver:4.5.3

# Cairo/font libs so headless renderPlot() can rasterise PNGs (the ggplot apps).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libcairo2 \
      libpng16-16 \
      fontconfig \
      fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Pinned snapshot => reproducible rebuilds, and prebuilt Linux binaries so
# nothing compiles from source. Bump the date to pick up newer packages.
# install.packages() only warns on failure, so verify the loads explicitly.
ARG CRAN_SNAPSHOT=2026-09-12
RUN . /etc/os-release && \
    R -q -e "install.packages(c('shiny','ggplot2'), repos='https://packagemanager.posit.co/cran/__linux__/${VERSION_CODENAME}/${CRAN_SNAPSHOT}')" && \
    R -q -e "stopifnot(requireNamespace('shiny', quietly=TRUE), requireNamespace('ggplot2', quietly=TRUE))"

# Public Sans is the ANU brand face and the apps' UI font. The browser pulls it
# from Google Fonts, but renderPlot() rasterises charts server-side, so the
# graphics device needs it installed here too or the charts come out in
# DejaVu while the page around them is Public Sans. No apt package ships it,
# so take the pinned upstream release; R's own download.file() and unzip()
# save pulling curl and unzip into the image. Only the non-bold faces are
# installed — nothing in these apps is set bold.
ARG PUBLIC_SANS_VERSION=2.001
RUN R -q -e "ver <- '${PUBLIC_SANS_VERSION}'; \
      url <- sprintf('https://github.com/uswds/public-sans/releases/download/v%s/public-sans-v%s.zip', ver, ver); \
      zf <- tempfile(fileext = '.zip'); \
      download.file(url, zf, quiet = TRUE); \
      dest <- '/usr/share/fonts/truetype/public-sans'; \
      dir.create(dest, recursive = TRUE, showWarnings = FALSE); \
      want <- c('Regular', 'Italic', 'Medium', 'MediumItalic'); \
      unzip(zf, files = sprintf('fonts/ttf/PublicSans-%s.ttf', want), \
            junkpaths = TRUE, exdir = dest); \
      stopifnot(length(list.files(dest, pattern = '[.]ttf\$')) == length(want))" \
    && fc-cache -f \
    && fc-list | grep -q 'Public Sans'

# Which app under apps/ this image serves. Set per-service in docker-compose.yml.
ARG APP
COPY apps/${APP} /srv/app

EXPOSE 3838
CMD ["R", "-q", "-e", "shiny::runApp('/srv/app', host = '0.0.0.0', port = 3838)"]
