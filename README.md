# RStudio Server with renv and Geospatial Tools

## Overview

This repository provides a Docker-based setup for running **RStudio Server** with [`renv`](https://rstudio.github.io/renv/articles/renv.html) for managing reproducible R environments, along with pre-installed geospatial tools such as *GDAL*, *GEOS*, and *PROJ*. It simplifies the process of creating a consistent, isolated environment for R projects, ensuring that your analyses can be replicated across different machines without dependency issues.

> [Docker](https://docker.com/) is a tool that lets you package an application (like RStudio Server) with all its dependencies into a "container." Containers are portable and run the same way on any system with Docker installed, making them perfect for reproducible research. By combining Docker with the *renv* package manager, we fix both the underlying OS and the exact R package versions for reproducibility.

## What This Repository Does

The repository automates the setup of a Docker container running RStudio Server. Here's the workflow:

- A **Dockerfile** defines how to build a custom Docker image with *RStudio*, geospatial libraries, and *renv*.
- A **docker-compose.yml** file configures how the container runs, including port mappings and file sharing between your computer and the container.
- A **build_docker.sh** script ties it all together, building the image and starting the container with a single command.

Once running, you can access RStudio Server in your web browser and work in a fully configured R environment.

## Repository Structure

- **Dockerfile**: Defines the recipe for building the Docker image setup. It starts from [`rocker/geospatial:latest`](https://hub.docker.com/r/rocker/geospatial) base image (which includes R, RStudio Server, and geospatial tools), creates necessary directories, configures RStudio’s default working directory and settings, installs system dependencies (fonts, Java, etc.), and copies in the specified `renv.lock`, RStudio prefs, and startup scripts. It sets environment variables for *renv* and runs a setup script (`setup_renv.R`) to restore the R package environment.

- **.dockerignore**: Lists files/directories to exclude from the Docker build context. This keeps the image build context clean by ignoring irrelevant files.

- **build_docker.sh**: A *bash* script that automates building and running the Docker image. It runs `docker build` with the `renv.lock` build argument, tags the image as `aelgabbas/rstudio_renv`, and then uses Docker Compose to start the container using `docker compose up`. This script orchestrates the entire build-and-run workflow.

- **docker-compose.yml**: Configuration for Docker Compose, defines how the container runs:
  - sets the container name (`rstudio_renv`),
  - setting resource limits and health checks.
  - maps port *8787* on your computer to RStudio Server's default port (*8787*) in the container.
  - mounts local directories:
    - The file maps `/mnt/d/IASDT.R` to `/home/rstudio/project` (default *Rstudio* working directory) inside the container.
    - You should change this path to your own project folder on your computer or comment the *volumes* section altogether if you want to use an empty working directory.
    - This allows you to work on your R scripts and data files directly from your host machine while running RStudio in the container.

- **scripts/**: A directory containing supporting R configuration files. All these files can be modified to customize the R environment inside the container.

  - **.Rprofile**: Custom R startup options. These options apply inside the container for all R sessions.

  - **renv.lock**: The lockfile listing all R package versions needed for the environment. This file is used by `setup_renv.R` script to install all the listed packages into the image.

  - **rstudio-prefs.json**: RStudio configuration (e.g., UI theme, font settings). This is copied into the container’s RStudio settings to customize the IDE appearance (e.g., setting Fira Code font, themes).

  - **setup_renv.R** – R script that runs inside the Docker image build. It calls `renv::restore()` to install all required R packages into the container’s library from `scripts/renv.lock`.

## Getting Started

1. Ensure that Docker is installed and running on your machine. You can download Docker from [Docker's official website](https://www.docker.com/get-started).

2. **Clone the repository**

   Open a *terminal* or *command prompt* and run:

    ```bash
    git clone https://github.com/elgabbas/rstudio_renv.git
    cd rstudio_renv
    ```

    This clones the repository to your local machine and changes into the project directory. Make sure you have *git* installed; if not, you can download the ZIP file from GitHub and extract it instead.

3. **Configure the project volume**

    By default, `docker-compose.yml` mounts `/mnt/d/IASDT.R` on your machine into the container’s working directory (`/home/rstudio/project`).

    You should edit `docker-compose.yml` and update the *volumes* section to point to a real directory on your computer containing your R project files. You can also remove or comment out the *volumes* section altogether if you want an empty working directory. For example:

    ```bash
        # specify the local project directory

        volumes:
          - type: bind
            source: /path/to/your/local/project
            target: /home/rstudio/project
    ```

    or comment out the volumes section to use an empty working directory

    ```bash
        # volumes:
          # - type: bind
            # source: /path/to/your/local/project
            # target: /home/rstudio/project
    ```

4. **Build the Docker image**

    The `build_docker.sh` script does all the heavy lifting. Run it with either of the following commands in your terminal:

    ```bash
    ./build_docker.sh
    ```

    ```bash
    # on git bash or similar terminals:
    bash build_docker.sh 
    ```

    This script:
    - builds the Docker image using the `Dockerfile` (including necessary dependencies and R packages listed in `renv.lock`), tagging it as `aelgabbas/rstudio_renv`;
    - runs `docker compose up -d` to start a container from that image in the background (detached mode). You should see output from Docker build and then confirmation of the new image.

    If you encounter permission issues, ensure the script is executable by running:

    ```bash
    chmod +x build_docker.sh
    ```

    **Note:**

    - Building the Docker image requires downloading the base image and installing a couple of system packages and many R packages, which will take time depending on your internet speed and system performance.
    - The base image is ~ 7 GB (July 2025). The total size of the image after building will be larger, depending on the R packages listed in `renv.lock`. The first build downloads the base image, but subsequent builds will be faster as it will re-use the cached layers.
    - R packages installation and caching is stored inside the image, thus rebuilding the image will re-download and re-install all R packages listed in `renv.lock`, so it may take a while if you have many packages or large ones.

5. **Verify the container is running:**

    After the script completes, check that the container is up by running:

    ```bash
    docker ps
    ```

    You should see a container named `rstudio_renv` running. If using Docker Desktop, you can also see it in the UI.

6. **Access RStudio:**

    - Open your web browser and go to [http://localhost:8787](http://localhost:8787).
    - You should see the RStudio Server login page. By default, authentication is disabled (`DISABLE_AUTH: true`) for convenience, so you may not need to log in. If prompted, use: *rstudio/password* as the username and password (you can change the password in `docker-compose.yml` file  if needed).
    - Inside RStudio, the working directory is `/home/rstudio/project`, which is linked to the local folder you mounted (or is an empty directory if you commented out the *volumes* section). This means you can access your R scripts and data files directly from the RStudio interface, and any changes will be saved to your host machine.
    - If `magrittr` R package is installed from the `renv.lock`, it will be loaded silently at startup to facilitate the use of the pipe operator (`%>%`) in your R scripts.
    - **Important note**:

      - Docker containers are **_ephemeral_**, meaning any changes made inside the container (like installing new R packages) will not persist after stopping the container. To add install a new R package, you need to update the `renv.lock` file and rebuild the image.
      - Any changes (like changing R options or creating or modifying files and directories) will be lost, except for those in the mounted project directory. All your R scripts, data files, and outputs will be saved in the `/home/rstudio/project` directory, which is linked to your local project folder. If no project folder is mounted, the working directory will not be persistent, and any files created there will be lost when the container stops.

7. **Stopping the container:**

    When done, you can stop the container with:

    ```bash
    docker compose down
    ```

    This stops and removes the container. The image remains on your system (you can restart it later with `docker compose up -d`).

## Customization

### Changing R Packages

The `renv.lock` file in the `scripts/` directory lists the R packages installed in the container. To use your own packages:

- **Option 1:** replace `scripts/renv.lock` with your own (generated by `renv::snapshot()` in an R project) and rebuild the image by running `./build_docker.sh` again.
- **Option 2:**: Use `--build-arg` to pass a different `renv.lock` file when building the image.  This allows you to specify a different lockfile without modifying the repository. For example:

    ```bash
    docker build --build-arg renv.lock=path/to/your/renv.lock -t aelgabbas/rstudio_renv .
    ```

### Modifying RStudio Settings

You can customize RStudio settings by editing the `scripts/rstudio-prefs.json` file. This file contains preferences like themes, font sizes, and other UI settings. The changes will be applied when you rebuild the Docker image. You can find more information about RStudio preferences in the [RStudio documentation](https://support.posit.co/hc/en-us/articles/200549016-Customizing-the-RStudio-IDE).

### Adding System Dependencies

If you need additional system libraries or tools (e.g., R packages dependencies), you can modify the `Dockerfile` to install them. Search for lines starting with `RUN apt-get install` in the Dockerfile and add any required system packages. This will ensure the package is available in the container when it rebuilds.

### Changing R Options

You can modify the global R options in the `scripts/.Rprofile` file. This file is sourced at the start of every R session in the container.

### Adjusting CPU Cores

The `Dockerfile` uses 6 CPU cores by default for compiling packages. To change this, edit the `n_cores` argument in the `Dockerfile` or rebuild with:

```bash
docker build --build-arg n_cores=4 -t aelgabbas/rstudio_renv .
```

### RStudio Server Authentication

By default, authentication is disabled (`DISABLE_AUTH: true`) for convenience. If you want to enable authentication, set `DISABLE_AUTH: false` or comment this line out in the `docker-compose.yml` file and specify a *username* and *password*. This will require users to log in to RStudio Server.

```yaml
environment:
  DISABLE_AUTH: false
  # DISABLE_AUTH: true # comment this line to enable authentication
  RSTUDIO_USER: your_username
  RSTUDIO_PASSWORD: your_password
```

This will enable authentication, and users will need to log in with the specified credentials.

### Updating the Docker Image

To update the Docker image with the latest changes from this repository:

- Pull the latest changes from the GitHub repository:

   ```bash
   git pull origin main
   ```

- Rebuild the Docker image by running:

   ```bash
   ./build_docker.sh
   ```

This will rebuild the image with any updates to the Dockerfile, `renv.lock`, or other configuration files.

## Summary

With this setup, users can launch an isolated *RStudio* Server instance equipped with spatial libraries and a project-specific package environment. You simply install Docker, clone the repo, configure your project folder path in `docker-compose.yml`, and run the provided script. The container then handles everything: opening *RStudio* in your browser, maintaining packages via `renv`, and giving you a reproducible environment for spatial R work.
