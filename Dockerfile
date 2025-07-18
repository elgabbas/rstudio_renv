# ===================================================
# Base image
# ===================================================

# Use rocker/geospatial:latest as the base image, providing R, RStudio Server, and geospatial tools (GDAL, GEOS, PROJ)
FROM rocker/geospatial:latest

# Metadata: Author and image information
# Define build date argument (default: current date in YYYY-MM-DD format)
ARG build_date=2025-07-18

LABEL maintainer="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.authors="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.description="RStudio Server with renv for reproducible R environments and geospatial tools" \
    org.opencontainers.image.source="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.created="${build_date}"

# ===================================================
# General set up
# ===================================================

# Set up project directories, configure RStudio, and install system dependencies
RUN echo "Setting up project directories, configuring RStudio, and installing dependencies" && \
    # Create directories for the project, renv cache, renv library, and RStudio configuration
    mkdir -p \
        /home/rstudio/project \
        /home/rstudio/renv_library/renv/cache \
        /home/rstudio/renv_library/renv/library \
        /home/rstudio/.config/rstudio \
        /etc/rstudio && \
    # Assign ownership of project and renv library directories to rstudio user for proper access
    chown -R rstudio:rstudio /home/rstudio && \
    # Assign ownership of RStudio configuration directories to rstudio user
    chown -R rstudio:rstudio /etc/rstudio /home/rstudio/.config/rstudio && \
    # Grant read, write, and execute permissions to all users for the R configuration directory
    # This allows the rstudio user to modify R settings if needed
    chmod -R 777 /usr/local/lib/R/etc && \
    # Configure RStudio to use /home/rstudio/project as the default working directory on startup
    echo "session-default-working-dir=/home/rstudio/project" > /etc/rstudio/rsession.conf && \
    # Update the apt package list to ensure the latest package information is available
    apt-get update -qq -y && \
    # Install system packages required for R packages and Quarto
    # - fontconfig: for font management, including Fira Code support
    # - libtbb-dev: dependency for the qs2 R package (parallel computing)
    # - default-jdk: required by the dismo R package (uses Java for MaxEnt)
    # - libarchive-dev: required by the archive R package (file archiving)
    # - jq: for JSON parsing to fetch the latest Quarto version
=    apt-get install --no-install-recommends -y \
        fontconfig \
        libtbb-dev \
        default-jdk \
        libarchive-dev \
        jq && \
    # Refresh the font cache to make newly installed fonts available
    fc-cache -fv && \
    # Remove apt cache files to reduce the image size and clean up
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/* /tmp/* && \
    # Clean up the apt cache to free up space
    apt-get clean

# ===================================================
# Quarto installation and update
# ===================================================

# Update the existing Quarto installation to the latest stable version - https://quarto.org/docs/download/tarball.html
# Print the current Quarto version (if installed)
RUN echo \
    "Current Quarto version: $(quarto --version || echo 'Not installed')" && \
    # Fetch the latest stable version number from GitHub API (excluding pre-releases)
    QUARTO_VERSION=$(curl -s https://api.github.com/repos/quarto-dev/quarto-cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    # Check if the current version matches the latest version
    CURRENT_QUARTO_VERSION=$(quarto --version 2>/dev/null || echo '0.0.0') && \
    if [ "$CURRENT_QUARTO_VERSION" != "$QUARTO_VERSION" ]; then \
        echo "Updating to Quarto version $QUARTO_VERSION..." && \
        # Download the tarball for the latest stable version, suppressing progress output
        wget --quiet https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.tar.gz && \
        # Extract the full Quarto installation to /opt/quarto, suppressing output
        rm -rf /opt/quarto && \
        mkdir -p /opt/quarto && \
        tar -C /opt/quarto -xzf quarto-${QUARTO_VERSION}-linux-amd64.tar.gz --strip-components=1 && \
        # Clean up the tarball to reduce image size
        rm -f quarto-${QUARTO_VERSION}-linux-amd64.tar.gz && \
        # Ensure the rstudio user has access to the Quarto installation
        chown -R rstudio:rstudio /opt/quarto && \
        # Create a symlink in /usr/local/bin for system-wide access
        ln -sf /opt/quarto/bin/quarto /usr/local/bin/quarto && \
        # Update the PATH for the rstudio user to include Quarto's bin directory
        echo 'export PATH=/opt/quarto/bin:$PATH' >> /home/rstudio/.profile && \
        echo "Quarto updated to version $QUARTO_VERSION."; \
    else \
        echo "Quarto is already at the latest version ($QUARTO_VERSION). Skipping update."; \
    fi && \
    # Print the installed Quarto version as the rstudio user
    su - rstudio -c "source /home/rstudio/.profile && echo 'Installed Quarto version: \$(quarto --version)'" && \
    # Verify Quarto installation as the rstudio user
    su - rstudio -c "source /home/rstudio/.profile && quarto check"


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

# These variables configure renv for reproducible package environments and optimize R package installation

# number of CPU cores to use for parallel compilation (default: 6)
# example usage: docker build --build-arg n_cores=2
ARG n_cores=6

ENV RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.rstudio.com/cran/latest \
    # override the default CRAN repository to use RStudio's Package Manager for faster, cached access
    MAKEFLAGS="-j${n_cores}" \
    # enable parallel compilation of R packages using the specified number of cores
    R_PROFILE_USER=/home/rstudio/renv_library/.Rprofile \
    # path to the .Rprofile file for customizing R startup behavior within the project
    RENV_PATHS_CACHE=/home/rstudio/renv_library/renv/cache \
    # shared cache directory for renv to store package installations across projects
    RENV_PATHS_LIBRARY=/home/rstudio/renv_library/renv/library \
    # project-specific library directory for isolated package installations
    RENV_PROJECT=/home/rstudio/renv_library \
    # root directory for the renv project
    RENV_PATHS_LOCKFILE=/home/rstudio/renv_library/renv.lock \
    # path to the renv lockfile for reproducible environments
    RENV_PATHS_RENV=/home/rstudio/renv_library/renv \
    # path to the renv package directory within the project
    RENV_CONFIG_SYNCHRONIZED_CHECK=false \
    # disable synchronized checks to speed up renv operations during builds
    RENV_CONFIG_WATCHDOG_ENABLED=false \
    # disable the renv watchdog to avoid unnecessary background processes
    RENV_CONFIG_AUTO_SNAPSHOT=false \
    # disable automatic snapshots to manually control lockfile updates
    RENV_CONFIG_INSTALL_TRANSACTIONAL=false
    # disable transactional installs for simpler package installation behavior

# ===================================================
# Configure and restore the R environment using renv
# ===================================================

# This step sets up renv, restores the package environment from renv.lock, and ensures proper permissions

RUN echo "Setting up renv and restoring R environment" && \
    # execute the setup_renv.R script to configure renv and restore packages from renv.lock
    Rscript /home/rstudio/renv_library/setup_renv.R && \
    # clean up temporary files generated during the build process to reduce image size
    rm -rf /tmp/* && \
    # assign ownership of renv and project directories to rstudio user for proper access
    chown -R rstudio:rstudio /home/rstudio/renv_library && \
    # grant read, write, and execute permissions to the rstudio user for renv and project directories
    chmod -R u+rwX /home/rstudio/renv_library

# set the working directory for RStudio sessions ("project")
WORKDIR /home/rstudio/project
