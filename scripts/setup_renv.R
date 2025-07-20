options(renv.config.auto.snapshot = FALSE)

# load the renv package to manage reproducible R environments
suppressPackageStartupMessages(library(renv))

# initialize renv using the existing lockfile
cat("\nrenv::init\n")
renv::init(bare = FALSE)

# restore packages from the renv lockfile
cat("\nrenv::restore\n\n")
renv::restore(lockfile = "/home/rstudio/renv_library/renv.lock")

# update all packages in the renv environment
cat("\nrenv::update all packages\n")
renv::update(prompt = FALSE)

# install the qs2 package from source with specific configuration options
if (requireNamespace("qs2", quietly = TRUE)) {
	cat("\ninstall qs2 package\n")
	renv::install(
		"qs2", repos = "https://cran.r-project.org", type="source",
		configure.args = "--with-TBB --with-simd=AVX2", verbose = TRUE)
}

# install the languageserver package for VS Code support
if (!requireNamespace("languageserver", quietly = TRUE)) {
	cat("\ninstall languageserver package\n")
	renv::install("languageserver")
}

# isolate the environment to ensure no external packages interfere with the project
cat("\nrenv::isolate\n")
renv::isolate()

# update the renv lockfile to reflect all installed packages
cat("\nrenv::snapshot\n")
renv::snapshot(type = "all", lockfile = "/home/rstudio/renv_library/renv.lock")
