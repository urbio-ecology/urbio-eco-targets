## Load your packages, e.g. library(targets).
source("packages.R")

## Load your R files
tar_source()

# facilitate this working in parallel
controller <- crew_controller_local(
  name = "my_controller",
  workers = 4,
  seconds_idle = 3
)

tar_option_set(
  controller = controller
)

## Assign like regular R, just make sure to pipe into a tar_ operation
tar_assign({
  barrier_file <- tar_file(here(
    "data/lizard/lizard_barrier.shp"
  ))
  habitat_file <- tar_file(here("data/lizard/lizard_habitat_raster.tif"))
  barrier <- read_geometry(barrier_file) |> st_as_sf() |> tar_target()
  habitat <- rast(habitat_file) |> tar_terra_rast()

  species <- tar_target("Blue-tongued Lizard")
  data_resolution <- tar_target(10)
  interpatch_distance <- tar_target(c(40, 100, 200))

  # the two steps prepare_rasters() takes, so each layer is its own target
  habitat_raster <- onto_grid(
    layer = habitat,
    grid = empty_grid(habitat, resolution = data_resolution),
    background = NA
  ) |>
    tar_terra_rast()
  barrier_raster <- onto_grid(
    layer = barrier,
    grid = habitat_raster,
    background = 0
  ) |>
    tar_terra_rast()

  barrier_mask <- create_barrier_mask(barrier = barrier_raster) |>
    tar_terra_rast()

  remaining_habitat <- drop_habitat_under_barrier(
    habitat = habitat_raster,
    barrier_mask = barrier_mask
  ) |>
    tar_terra_rast()

  buffered_habitat <- habitat_buffer(
    habitat = remaining_habitat,
    buffer_radius = interpatch_distance / 2
  ) |>
    tar_terra_rast(
      pattern = map(interpatch_distance)
    )

  # apply barriers to get the fragmentation
  fragmentation_raster <- fragment_habitat(
    buffered_habitat = buffered_habitat,
    barrier_mask = barrier_mask
  ) |>
    tar_terra_rast(
      pattern = map(buffered_habitat)
    )

  # get IDs of connected areas
  # intersect with habitat to get area IDs of habitat patches
  patch_id_raster <- assign_patches_to_fragments(
    remaining_habitat = remaining_habitat,
    fragment = fragmentation_raster
  ) |>
    add_patch_area() |>
    tar_terra_rast(
      pattern = map(fragmentation_raster)
    )

  patch_areas <- aggregate_connected_patches(patch_id_raster) |>
    tar_target(
      pattern = map(patch_id_raster)
    )

  connectivity <- patch_size_tbl(
    data = patch_areas,
    species = species,
    interpatch_distance = interpatch_distance,
    res = terra::res(habitat_raster)
  ) |>
    summarise_connectivity() |>
    tar_target(
      pattern = map(patch_areas, interpatch_distance)
    )

  barrier_plots <- write_barrier_habitat_plot(
    dir = "doc",
    barrier = barrier_raster,
    buffered = buffered_habitat,
    habitat = habitat_raster,
    interpatch_distance = interpatch_distance,
    species = species
  ) |>
    tar_file(
      pattern = map(buffered_habitat, interpatch_distance)
    )

  ## TODO query this from @mdsumner
  ## how connected is your landscape?
  ## provides a map output
  ## inputs: barriers (roads, houses, etc), habitat (grass, trees, water, etc)
  ## outputs are: the connectedness map, and measurements of connectedness

  # habitat - here all understorey from the LiDAR data
  # also clean up the edges, this helps remove some of the resolution
  # that is at a very high level of details which we do not need
  # buffer the habitat by distance

  explore_doc <- tar_quarto(
    path = "doc/explore.qmd",
    extra_files = "R/show_tabs.R",
    quiet = FALSE
  )
})
