# ===================================================
# Base image
# ===================================================

# Use rocker/geospatial:latest as the base image, providing R, RStudio Server, and geospatial tools (GDAL, GEOS, PROJ)
FROM rocker/geospatial:latest

# Metadata: Author and image information
LABEL maintainer="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.authors="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.description="RStudio Server with renv for reproducible R environments and geospatial tools" \
    org.opencontainers.image.source="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.created="2025-07-11"

# ===================================================
# General set up
# ===================================================

# set up project directories, configure RStudio, and install system dependencies
RUN echo "Setting up project directories, configuring RStudio, and installing dependencies" && \
    # create directories for the project, renv cache, renv library, and RStudio configuration
    mkdir -p \
        /home/rstudio/project \
        /home/rstudio/renv_library/renv/cache \
        /home/rstudio/renv_library/renv/library \ 
        /home/rstudio/.config/rstudio \
        /etc/rstudio && \
    # assign ownership of project and renv library directories to the rstudio user for proper access
    chown -R rstudio:rstudio /home/rstudio && \
    # assign ownership of RStudio configuration directories to the rstudio user
    chown -R rstudio:rstudio /etc/rstudio /home/rstudio/.config/rstudio && \
    # grant read, write, and execute permissions to all users for the R configuration directory
    chmod -R 777 /usr/local/lib/R/etc && \
    # configure RStudio to use /home/rstudio/project as the default working directory on startup
    echo  "session-default-working-dir=/home/rstudio/project" > /etc/rstudio/rsession.conf && \
    # update the apt package list to ensure the latest package information is available
    apt-get update -qq -y && \
    # install system packages
    # # - fontconfig: for Fira Code font support
    # # - libtbb-dev: dependency for the qs2 R package
    # # - default-jdk: required by the dismo R package (uses Java)
    # # - libarchive-dev: required by the archive R package
    apt-get install --no-install-recommends -y \
    fontconfig libtbb-dev default-jdk libarchive-dev && \
    # refresh the font cache to make newly installed fonts available
    fc-cache -fv && \
    # remove apt cache files to reduce the image size and clean up
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/* /tmp/* && \
    # clean up the apt cache to free up space
    apt-get clean

# set the working directory temporarily to the renv library folder
WORKDIR /home/rstudio/renv_library

# ===================================================
# Copy files
# ===================================================

# define renv_lock argument (default: "renv.lock") to specify the project-specific renv.lock file
# example usage: docker build --build-arg renv_lock=renv2.lock
ARG renv_lock=scripts/renv.lock

# copy RStudio preferences file to configure settings like Fira Code font, theme, and other UI preferences
COPY --chown=rstudio:rstudio scripts/rstudio-prefs.json /home/rstudio/.config/rstudio/rstudio-prefs.json

# copy the specified renv.lock file to the renv library directory
COPY --chown=rstudio:rstudio ${renv_lock} renv.lock

# copy the specified .Rprofile to the renv library directory
COPY --chown=rstudio:rstudio scripts/.Rprofile .Rprofile

# copy the renv setup R script into the container for execution
COPY --chown=rstudio:rstudio scripts/setup_renv.R setup_renv.R

# ===================================================
# Set environment variables for R package management and renv configuration
# ===================================================

# number of CPU cores to use for parallel compilation (default: 6)
# example use: docker build --build-arg n_cores=2
ARG n_cores=6

ENV RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.rstudio.com/cran/latest \
    # set the MAKEFLAGS environment variable to enable parallel compilation
    MAKEFLAGS="-j${n_cores}" \ 
    # location of the .Rprofile file to customize R startup behavior
    R_PROFILE_USER=/home/rstudio/renv_library/.Rprofile \ 
    # renv cache path for storing shared package installations across projects
    RENV_PATHS_CACHE=/home/rstudio/renv_library/renv/cache \
    # renv library path for isolating project-specific package installations
    RENV_PATHS_LIBRARY=/home/rstudio/renv_library/renv/library \
    # renv project root directory
    RENV_PROJECT=/home/rstudio/renv_library \
    # location of the renv lockfile
    RENV_PATHS_LOCKFILE=/home/rstudio/renv_library/renv.lock \
    # path to the renv package directory within the project
    RENV_PATHS_RENV=/home/rstudio/renv_library/renv \
    # disable synchronized checks to avoid unnecessary validation during builds
    RENV_CONFIG_SYNCHRONIZED_CHECK=false \ 
    # disable the renv watchdog
    RENV_CONFIG_WATCHDOG_ENABLED=false \
    # disable automatic snapshots to give manual control over lockfile updates
    RENV_CONFIG_AUTO_SNAPSHOT=false \
    # disable transactional installs to simplify the installation process
    RENV_CONFIG_INSTALL_TRANSACTIONAL=false

# ===================================================
# Configure and restore the R environment using renv
# ===================================================

RUN echo "Setting up renv" && \
    # execute the setup_renv.R script to configure and restore renv
    Rscript /home/rstudio/renv_library/setup_renv.R && \
    # clean up temporary files generated during the build process
    rm -rf /tmp/* && \
    # ensure the rstudio user owns the renv and project directories
    chown -R rstudio:rstudio /home/rstudio/renv_library && \
    # grant read, write, and execute permissions to the rstudio user for renv and project directories
    chmod -R u+rwX /home/rstudio/renv_library

# set the working directory for RStudio sessions ("project")
WORKDIR /home/rstudio/project
