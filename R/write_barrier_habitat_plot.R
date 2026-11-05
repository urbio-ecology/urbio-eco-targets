# plot_barrier_habitat_interpatch_dist() can only write to the working
# directory, so run it from `dir`
write_barrier_habitat_plot <- function(dir, ...) {
  dir_create(dir)
  file <- with_dir(dir, plot_barrier_habitat_interpatch_dist(...))
  file.path(dir, file)
}
