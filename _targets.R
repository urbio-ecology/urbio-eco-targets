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

  species_name <- tar_target("Blue-Tongued-Lizard")
  target_resolution <- tar_target(500)
  data_resolution <- tar_target(10)
  aggregation_factor <- tar_target(target_resolution / data_resolution)
  buffer_distance <- tar_target(100)

  barrier_rasterised <- terra::rasterize(
    x = barrier,
    y = terra::rast(
      x = ext(habitat),
      res = data_resolution,
      crs = crs(habitat)
    ),
    background = 0
  ) |>
    tar_terra_rast()

  # aggregate rasters to make them the size of the overlay raster
  ## could generate an empty raster with this resolution instead of using
  ## barrier data directly - we could instead do raster of this grid spec
  coarse_raster <- terra::aggregate(
    barrier_rasterised * 0,
    aggregation_factor
  ) |>
    tar_terra_rast()

  ## making the grid finer
  coarse_template <- terra::disagg(coarse_raster, aggregation_factor) |>
    tar_terra_rast()
  ## terra resample or project could help us get to these different resolutions
  ## terra resample by util

  ## again, we could get around this by specifying a grid spec
  ## make sure the extent snaps to the right shape
  ## so give it the extent and resolution
  ## with the extent and the resolution, make sure that they snap together
  ## terra::rast(nrow = ..., ncol = ..., extent)
  habitat_raster <- terra::extend(
    x = habitat,
    y = coarse_template
  ) |>
    tar_terra_rast()
  barrier_raster <- terra::extend(barrier_rasterised, coarse_template) |>
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
    distance = buffer_distance
  ) |>
    tar_terra_rast(
      pattern = map(buffer_distance)
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

  # or as one step
  areas_connected <- habitat_connectivity(
    habitat = habitat_raster,
    barrier = barrier_raster,
    distance = buffer_distance
  ) |>
    tar_target(
      pattern = map(buffer_distance),
      iteration = "list"
    )

  results_connect_habitat <- summarise_connectivity(
    area_squared = areas_connected$area_squared,
    area_total = areas_connected$area,
    buffer_distance = buffer_distance,
    target_resolution = target_resolution,
    data_resolution = data_resolution,
    aggregation_factor = aggregation_factor,
    species_name = species_name
  ) |>
    tar_target(
      pattern = map(areas_connected, buffer_distance)
    )

  # some of the palettes that we liked:
  # scico::scico_palette_show(
  #     palettes = c("cork",
  #                  "bam",
  #                  "tofino",
  #                  "navia",
  #                  "vanimo")
  # )

  urbio_pal <- scico(n = 11, palette = "tofino") |>
    vec_slice(c(7, 10)) |>
    # add white
    c(col2hex("white")) |>
    tar_target()

  urbio_cols <- list(
    habitat = urbio_pal[1],
    buffer = urbio_pal[2],
    barrier = urbio_pal[3]
  ) |>
    tar_target()

  saved_spatraster <- plot_barrier_habitat_buffer(
    barrier = barrier_raster,
    buffered = buffered_habitat,
    habitat = habitat_raster,
    distance = buffer_distance,
    species_name = species_name,
    col_barrier = urbio_cols$barrier,
    col_buffer = urbio_cols$buffer,
    col_habitat = urbio_cols$habitat,
    col_paper = "grey96"
  ) |>
    tar_file(
      pattern = map(buffered_habitat, buffer_distance)
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

  explore_doc <- tar_quarto(path = "doc/explore.qmd", quiet = FALSE)
})
