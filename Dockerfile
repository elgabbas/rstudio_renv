# ============================================================================
# RStudio Server + renv Geospatial Environment Dockerfile
# ============================================================================

# This Dockerfile builds an RStudio Server image with:
#  - Reproducible R package management using renv and a user-specified lock file
#  - Latest Quarto installed for publishing and reporting
#
# See https://github.com/elgabbas/rstudio_renv for usage and more details.

# ============================================================================
# Base image
# ============================================================================

# Use rocker/geospatial:latest as the base image, providing R, RStudio Server, 
# and geospatial tools (GDAL, GEOS, PROJ)
FROM rocker/geospatial:latest

# Metadata: Author and image information
LABEL maintainer="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.authors="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.description="RStudio Server with renv for reproducible R environments and geospatial tools" \
    org.opencontainers.image.source="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.title="RStudio Server Geospatial" \
    org.opencontainers.image.documentation="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.url="https://github.com/elgabbas/rstudio_renv"

# ============================================================================
# General system and directory setup
# ============================================================================

# Set up project directories, configure RStudio, and install system dependencies

RUN echo "Setting up project directories, configuring RStudio, and installing dependencies" && \
    # Create directories for the project, renv cache, renv library, and 
    # RStudio configuration
    mkdir -p \
        /home/rstudio/project \
        /home/rstudio/renv_library/renv/cache \
        /home/rstudio/renv_library/renv/library \
        /home/rstudio/.config/rstudio \
        /etc/rstudio && \
    # Assign ownership of main directories to rstudio user for correct permissions
    chown -R rstudio:rstudio /home/rstudio && \
    chown -R rstudio:rstudio /etc/rstudio /home/rstudio/.config/rstudio && \
    # Grant full permissions to R config (needed for RStudio user settings)
    chmod -R 777 /usr/local/lib/R/etc && \
    # Set RStudio's default working directory to /home/rstudio/project
    echo "session-default-working-dir=/home/rstudio/project" > /etc/rstudio/rsession.conf && \
    # Update the apt package list to ensure the latest package information is available
    apt-get update -qq -y && \
    # Install system packages required for R packages and Quarto
    # - fontconfig: for font management, including Fira Code support
    # - libtbb-dev: dependency for the qs2 R package (parallel computing)
    # - default-jdk: required by the dismo R package (uses Java for MaxEnt)
    # - libarchive-dev: required by the archive R package (file archiving)
    # - jq: for JSON parsing to fetch the latest Quarto version
    apt-get install --no-install-recommends -y \
        fontconfig libtbb-dev default-jdk libarchive-dev jq && \
    # Refresh the font cache for newly installed fonts
    fc-cache -fv && \
    apt-get clean
    
# ============================================================================
# Quarto installation and update
# ============================================================================
    
# Automatically update Quarto to the latest stable version using the GitHub API
# https://quarto.org/docs/download/tarball.html

RUN echo \
    # Print the current Quarto version (if installed)
    "Current Quarto version: $(quarto --version || echo 'Not installed')" && \
    # Fetch the latest stable version number (excluding pre-releases)
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
    # Print and verify the installed Quarto version as rstudio user
    su - rstudio -c "source /home/rstudio/.profile && echo 'Installed Quarto version: \$(quarto --version)'" && \
    su - rstudio -c "source /home/rstudio/.profile && quarto check"
    
# ============================================================================
# R and renv project configuration files
# ============================================================================

# Set working directory to renv library folder for subsequent file operations
WORKDIR /home/rstudio/renv_library

# Specify the renv lock file to use (default: scripts/renv.lock)
# You can override this at build time:
# > docker build --build-arg renv_lock=scripts/renv_full.lock .
ARG renv_lock=scripts/renv.lock

# Copy RStudio preferences (font, theme, UI settings) for user experience
COPY --chown=rstudio:rstudio scripts/rstudio-prefs.json \
/home/rstudio/.config/rstudio/rstudio-prefs.json

# Copy the specified renv.lock file for package environment reproducibility
COPY --chown=rstudio:rstudio ${renv_lock} renv.lock

# Copy project-level R profile for custom startup behavior
COPY --chown=rstudio:rstudio scripts/.Rprofile .Rprofile

# Copy script to automate renv setup and package restore
COPY --chown=rstudio:rstudio scripts/setup_renv.R setup_renv.R

# ============================================================================
# Environment variables for reproducible R and renv configuration
# ============================================================================

# These variables control repository source, parallelism, and renv library/cache/project locations
# n_cores can be set at build time to control parallel compilation (default: 6)
ARG n_cores=6

ENV RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.rstudio.com/cran/latest \
    # Override the default CRAN repository to use RStudio's Package Manager for faster, cached access
    MAKEFLAGS="-j${n_cores}" \
    # Enable parallel compilation of R packages using the specified number of cores
    R_PROFILE_USER=/home/rstudio/renv_library/.Rprofile \
    # Path to the .Rprofile file for customizing R startup behavior within the project
    RENV_PATHS_CACHE=/home/rstudio/renv_library/renv/cache \
    # Shared cache directory for renv to store package installations across projects
    RENV_PATHS_LIBRARY=/home/rstudio/renv_library/renv/library \
    # Project-specific library directory for isolated package installations
    RENV_PROJECT=/home/rstudio/renv_library \
    # Root directory for the renv project
    RENV_PATHS_LOCKFILE=/home/rstudio/renv_library/renv.lock \
    # Path to the renv lockfile for reproducible environments
    RENV_PATHS_RENV=/home/rstudio/renv_library/renv \
    # Path to the renv package directory within the project
    RENV_CONFIG_SYNCHRONIZED_CHECK=false \
    # Disable synchronized checks to speed up renv operations during builds
    RENV_CONFIG_WATCHDOG_ENABLED=false \
    # Disable the renv watchdog to avoid unnecessary background processes
    RENV_CONFIG_AUTO_SNAPSHOT=false \
    # Disable automatic snapshots to manually control lockfile updates
    RENV_CONFIG_INSTALL_TRANSACTIONAL=false
    # Disable transactional installs for simpler package installation behavior

# ============================================================================
# Setup and restore R environment using renv
# ============================================================================

# Restore all R packages as specified in renv.lock and set proper permissions
RUN echo "Setting up renv and restoring R environment" && \
    # Run setup R script (restores packages and initializes the environment)
    Rscript /home/rstudio/renv_library/setup_renv.R && \
    # Assign ownership of renv and project directories to rstudio user for proper access
    chown -R rstudio:rstudio /home/rstudio/renv_library && \
    # Grant read, write, and execute permissions to the rstudio user for renv
    # and project directories
    chmod -R u+rwX /home/rstudio/renv_library

# ============================================================================
# Clean up unnecessary files to reduce image size
# ============================================================================

RUN echo "Clean up" && \
    # Remove apt package lists to minimize image size
    rm -rf /var/lib/apt/lists/* && \
    # Remove all files from /tmp (temporary files created during build)
    rm -rf /tmp/* && \
    # Remove all default user-installed R packages to save image size
    rm -rf /usr/local/lib/R/site-library/* && \
    # Remove renv cache directories (package archives downloaded by renv, not needed at runtime)
    rm -rf /root/.cache/R/renv && \
    # Remove all user-level caches for rstudio user (deno, quarto, pip, renv, etc.)
    rm -rf /home/rstudio/.cache/* && \
    # Remove other system and package manager cache directories
    rm -rf /var/cache/* && \
    # Remove temporary files for system and user processes
    rm -rf /var/tmp/*

# ============================================================================
# Set default project working directory for RStudio sessions
# ============================================================================

WORKDIR /home/rstudio/project
