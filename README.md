# To recreate the analysis

Use `targets` and `capsule` to recreate the paper.

-   `targets` is the workflow system that ensures the steps required to
    complete the paper are completed in the right order.
-   `capsule` locks in the R package versions, including where they were
    downloaded from (github or CRAN, for example), so that these can be
    locked in. Under the hood it uses the `renv` R package.

There are three steps to reproduce the analysis

## Step 1: Install `capsule`

``` r
install.packages('capsule', repos = c('https://milesmcbain.r-universe.dev', 'https://cloud.r-project.org'))
```

## Step 2: Reproduce the libraries used

``` r
capsule::reproduce_lib()
```

This recreates all of the R packages used in the analysis on your
computer. Importantly, this will not change where your existing R
packages are installed. It is just for this repository. So no need to be
concerned about this impacting other analyses you run.

## Step 3: Run the target workflow

``` r
capsule::run(targets::tar_make())
```

This runs our targets workflow using the R packages specified.

This will check if the targets are written, and if they aren’t, it will
re-run the necessary ones.

## Step 4: Add new dependencies into "packages.R"?

Run:

``` r
capsule::recreate("./packages.R")
```

## Step 5 - ?

Make some changes to the analysis and want to see them? Run the capsule
again:

``` r
capsule::run(targets::tar_make())
```

And the analysis will be recreated.
