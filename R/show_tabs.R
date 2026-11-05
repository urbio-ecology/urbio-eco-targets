# print each plot under its own heading, for a quarto `panel: tabset`
show_tabs <- function(plots, message) {
  iwalk(plots, function(plot, name) {
    cat(sprintf("## %s %s\n", message, name))
    print(plot)
    cat("\n\n")
  })
}

# the same for image files, given as paths from the document's folder
show_image_tabs <- function(paths, message) {
  iwalk(paths, function(path, name) {
    cat(sprintf("## %s %s\n\n![](%s)\n\n", message, name, path))
  })
}
