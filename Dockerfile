# ==============================================================================
# RStudio Server + renv Geospatial Environment + code-server Dockerfile
# ==============================================================================

# This Dockerfile builds an RStudio Server image with:
# - Reproducible R package management using renv and a user-specified lock file
# - Latest Quarto installed for publishing and reporting
# - VS Code (via code-server) accessible from the browser, running in parallel to RStudio Server via s6
#
# See https://github.com/elgabbas/rstudio_renv for usage and more details.

# ==============================================================================
# Base image
# ==============================================================================

# Use rocker/geospatial:latest as the base image. Provides R, RStudio Server, 
# and geospatial tools (GDAL, GEOS, PROJ).
FROM rocker/geospatial:latest

# ==============================================================================
# Metadata
# ==============================================================================

LABEL maintainer="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.authors="Ahmed El-Gabbas <elgabbas@outlook.com>" \
    org.opencontainers.image.description="RStudio Server with renv for reproducible R environments, geospatial tools, and browser-based VS Code" \
    org.opencontainers.image.source="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.title="RStudio Server Geospatial" \
    org.opencontainers.image.documentation="https://github.com/elgabbas/rstudio_renv" \
    org.opencontainers.image.url="https://github.com/elgabbas/rstudio_renv"

# ==============================================================================
# Setting up directories
# ==============================================================================

RUN echo "\nSetting up directories and permissions\n" && \
    rm -rf /opt/quarto && \
    # Create directories for project, renv cache/library, and RStudio config
    mkdir -p \
        /etc/rstudio \
        /home/rstudio/.config/rstudio \
        /home/rstudio/.config/code-server \
        /home/rstudio/.local/share/code-server/User \
        /home/rstudio/.local/share/quarto \
        /home/rstudio/project \
        /home/rstudio/renv_library/renv/cache \
        /home/rstudio/renv_library/renv/library \
        /opt/quarto && \
    # Set ownership for rstudio user (important for permissions)
    chown -R rstudio:rstudio /home/rstudio && \
    chown -R rstudio:rstudio /etc/rstudio && \
    # Grant full permissions to R config (needed for RStudio user settings)
    chmod -R 777 /usr/local/lib/R/etc && \
    # Set RStudio's default working directory
    echo "session-default-working-dir=/home/rstudio/project" > /etc/rstudio/rsession.conf

# ==============================================================================
# Install system dependencies
# ==============================================================================

RUN echo "\nInstalling system dependencies...\n\n" && \
    # Update package lists and install required system packages
    # - fontconfig: for font management, including Fira Code support
    # - libtbb-dev: dependency for the qs2 R package (parallel computing)
    # - default-jdk: required by the dismo R package (uses Java for MaxEnt)
    # - libarchive-dev: required by the archive R package (file archiving)
    # - jq: for JSON parsing to fetch the latest Quarto version
    apt-get update -qq -y && \
    apt-get install -qq --no-install-recommends -y \
        fontconfig libtbb-dev default-jdk libarchive-dev jq sudo && \
    # Refresh font cache for newly installed fonts
    fc-cache -fv && \
    apt-get clean

# ==============================================================================
# Install code-server (VS Code in browser) and extensions
# ==============================================================================

# Copy code-server user settings (must exist before installing extensions)
COPY scripts/code_settings.json /home/rstudio/.local/share/code-server/User/settings.json

# Install code-server globally for browser-based VS Code experience
RUN echo "\nInstalling code-server and extensions...\n" && \
    curl -fsSL https://code-server.dev/install.sh | sh && \
    # Initialize code-server data directory for rstudio user before installing extensions
    su - rstudio -c \
    # Allow pkill to fail gracefully if code-server exits before pkill runs
    "code-server --bind-addr 127.0.0.1:8080 --auth none & sleep 5; pkill code-server || true" && \
    # Install VS Code extensions for R, Quarto, Markdown, CSV, YAML, Git, and general productivity
    for ext in \
        reditorsupport.r \
        rdebugger.r-debugger \
        quarto.quarto \
        shd101wyy.markdown-preview-enhanced \
        davidanson.vscode-markdownlint \
        esbenp.prettier-vscode \
        redhat.vscode-yaml \
        mechatroner.rainbow-csv \
        oderwat.indent-rainbow \
        christian-kohler.path-intellisense \
        ionutvmi.path-autocomplete \
        eamodio.gitlens \
        github.vscode-pull-request-github \
        streetsidesoftware.code-spell-checker \
        pkief.material-icon-theme \
        thenikso.github-plus-theme \
    ; do \
        su - rstudio -c "code-server --install-extension $ext"; \
    done

# ==============================================================================
# Quarto installation and update
# ==============================================================================

# Automatically update Quarto to the latest stable version using GitHub API.
# https://quarto.org/docs/download/tarball.html

RUN echo "\nQuarto installation and update...\n" && \
    # Print the current Quarto version (if installed)
    echo "Current Quarto version: $(quarto --version || echo 'Not installed')" && \
    # Fetch the latest stable version number (excluding pre-releases)
    QUARTO_VERSION=$(curl -s https://api.github.com/repos/quarto-dev/quarto-cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    # Check if the current version matches the latest version
    CURRENT_QUARTO_VERSION=$(quarto --version 2>/dev/null || echo '0.0.0') && \
    if [ "$CURRENT_QUARTO_VERSION" != "$QUARTO_VERSION" ]; then \
        echo "Updating to Quarto version $QUARTO_VERSION..." && \
        # Download the tarball for the latest stable version, suppressing progress output
        wget --quiet https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.tar.gz && \
        # Extract the full Quarto installation to /opt/quarto, suppressing output
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

# ==============================================================================
# R and renv project configuration files
# ==============================================================================

# Set working directory for subsequent file operations to renv library folder
WORKDIR /home/rstudio/renv_library

# Allow build-time override of renv lock file (default: scripts/renv.lock)
# You can override this at build time:
# > docker build --build-arg renv_lock=scripts/renv_full.lock .
ARG renv_lock=scripts/renv.lock

# Copy RStudio preferences (font, theme, UI settings)
COPY --chown=rstudio:rstudio scripts/rstudio-prefs.json /home/rstudio/.config/rstudio/rstudio-prefs.json

# Copy the specified renv.lock file for package environment reproducibility
# This must use the build arg!
COPY --chown=rstudio:rstudio ${renv_lock} renv.lock

# Copy project-level R profile for custom R session behavior
COPY --chown=rstudio:rstudio scripts/.Rprofile .Rprofile

# Copy renv setup script to automate environment restore
COPY --chown=rstudio:rstudio scripts/setup_renv.R setup_renv.R

# ==============================================================================
# Environment variables for reproducible R and renv configuration
# ==============================================================================

# n_cores can be set at build time (default: 6)
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

# ==============================================================================
# Setup and restore R environment using renv
# ==============================================================================

# Restore all R packages with renv and set proper permissions.
RUN echo "\nSetting up renv and restoring R environment\n" && \
    # Run setup R script (restores packages and initializes the environment)
    Rscript /home/rstudio/renv_library/setup_renv.R && \
    # Grant read, write, and execute permissions to the rstudio user for renv
    # and project directories
    chmod -R u+rwX /home/rstudio/renv_library

# ==============================================================================
# Clean up unnecessary files to reduce image size
# ==============================================================================

RUN echo "\nClean up\n" && \
    # Remove apt package lists, temp files, caches to minimize image size
    rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /usr/local/lib/R/site-library/* \
    /root/.cache/R/renv \
    /var/cache/* \
    /var/tmp/* \
    /home/rstudio/.cache/*

# ==============================================================================
# Configure code-server (VS Code in the browser)
# ==============================================================================

# This script will be run by s6 and supervises code-server in the background.
# It runs as the rstudio user, unsets $PASSWORD so code-server uses 
# config. yaml, and ensures HOME is correct for code-server (important for
#  auth and extensions).
COPY scripts/code-server-run /etc/services.d/code-server/run

RUN echo "\nConfiguring code-server\n" && \
    # After cleanup, create code-server config and set permissions.
    # Do NOT remove .config or code-server config after this step!
    echo 'bind-addr: 0.0.0.0:8080' > /home/rstudio/.config/code-server/config.yaml && \
    echo 'auth: none' >> /home/rstudio/.config/code-server/config.yaml && \
    # Add code-server as an s6 service to run alongside RStudio
    chmod +x /etc/services.d/code-server/run

# ==============================================================================
# Set default project working directory for RStudio sessions
# ==============================================================================

WORKDIR /home/rstudio/project

# Expose VS Code (code-server) port to the host.
EXPOSE 8080

# ==============================================================================
