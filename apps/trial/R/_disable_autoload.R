# Turns off Shiny's automatic sourcing of this directory.
#
# Auto-loading sources R/*.R in alphabetical order and, for an app.R-style app,
# never sources global.R at all so there is no reliable place to attach
# packages before the rest of the files need them. app.R sources these files
# itself instead, in a written-down order. See ?shiny::loadSupport.
