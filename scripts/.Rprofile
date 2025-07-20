# a custom quit function that exits R without saving the workspace by default
q <- function(save="no", ...) { 
    quit(save = save, ...)
}

# set global R options to customize behavior and performance
options(
    # number of CPU used for installing packages using install.packages
    Ncpus = parallel::detectCores(),
    # do not convert strings to factors [probably not needed anymore]
	stringsAsFactors = FALSE,
    # numbers in scientific notation
	scipen = 8,
    # set the continuation prompt to "... " for multi-line inputs
	continue = "... ",
    # configuration arguments for specific packages during installation
	configure.args = list(
        qs2 = "--with-TBB --with-simd=AVX2",
        arrow = "--enable-zstd"))

# activate the renv environment
if (file.exists("/home/rstudio/renv_library/renv/activate.R")) {
    source("/home/rstudio/renv_library/renv/activate.R")
}

# load magrittr library if installed
if (requireNamespace("magrittr", quietly = TRUE)) {
    suppressPackageStartupMessages(
        library("magrittr", quietly = FALSE, verbose = FALSE))
}
