# RStudio Server with renv and Geospatial Tools

## Overview

This repository provides a robust Docker-based setup for running **RStudio Server** with [`renv`](https://rstudio.github.io/renv/articles/renv.html) for fully reproducible R environments, along with the latest geospatial tools and **browser-based VS Code** (via code-server).  
It is ideal for data science, spatial analysis, and collaborative or reproducible R workflows.

> [Docker](https://docker.com/) is a platform that packages an application (like RStudio Server) and all its dependencies into a "container." Containers are portable and ensure consistent environments on any machine.

## What This Repository Does

This repository automates the creation and deployment of a ready-to-use RStudio Server and code-server (VS Code) environment tailored for reproducibility and geospatial data science.  
It enables you to:

- **Build custom Docker images** with RStudio Server, comprehensive geospatial libraries, renv for package management, Quarto for documents, and VS Code (via code-server) for browser-based editing.
- **Choose between two pre-configured environments**:
  - **Main**: uses `renv.lock` (core R packages).
  - **Full**: uses `renv_full.lock` (broad set of packages for advanced workflows).
- **Quickly launch RStudio Server and VS Code** in your browser, with all packages, settings, and extensions pre-installed.
- **Persist and access your R projects** via directory mapping between your computer and the container.
- **Pull prebuilt images from the GitLab Container Registry** if you do not wish to build locally.
- **Use the images on HPCs or clusters via Singularity/Apptainer** for seamless integration into research or teaching environments.
- **Automate builds and updates** using CI/CD with the included `.gitlab-ci.yml` file.
- **Customize R, RStudio, VS Code, and system-level settings** with easy-to-edit configuration files and scripts.

## Repository Structure

- **Dockerfile**:  
  The recipe for building the Docker image.
  - Starts from [`rocker/geospatial:latest`](https://hub.docker.com/r/rocker/geospatial), which includes R, RStudio Server, and essential geospatial libraries (GDAL, GEOS, PROJ, etc.).
  - Installs additional system dependencies, updates Quarto, and restores R packages from a specified lock file (`renv.lock` or `renv_full.lock`).
  - Installs code-server (browser-based VS Code), copies user settings, and installs a curated set of extensions for R/data science/workflow productivity.
  - Applies custom RStudio user preferences and project-level R configuration.

- **.gitlab-ci.yml**:  
  The GitLab CI/CD pipeline configuration file.
  - Automates building and publishing the Docker images (both main and full variants) to the GitLab Container Registry whenever relevant files are updated.
  - Ensures that up-to-date images are always available for pull or use in other environments.

- **.dockerignore**:  
  - Lists files and directories to exclude from the Docker build context.  
  - Improves build speed and keeps images clean by ignoring irrelevant files.

- **build_docker.sh**:  
  Bash script to automate building and running the Docker image.
  - Usage: `./build_docker.sh --renv path/to/renv.lock [--mount /host/project_dir]`
  - Builds the image using the given lock file.
  - Optionally mounts a local directory to `/home/rstudio/project` in the container.
  - Starts the container using Docker Compose.

- **docker-compose.yml**:  
  Docker Compose configuration for running the container.
  - Sets the container name (`rstudio_renv`), resource limits, and health checks.
  - Maps port *8787* for RStudio Server and *8080* for code-server (VS Code in browser).
  - Does **not** set up a default volume; use the `--mount` argument in the build script to map your local project directory.

- **scripts/**:  
  Contains supporting R and RStudio/VS Code configuration files:
  - **.Rprofile**: Sets R startup options for all sessions inside the container.
  - **renv.lock**: Main lockfile listing R packages for the core environment.
  - **renv_full.lock**: Extended lockfile with a larger set of R packages for more advanced or teaching use cases.
  - **rstudio-prefs.json**: Customizes RStudio UI and editor settings (theme, font, etc.).
  - **code_settings.json**: Customizes VS Code (code-server) settings and UI for all users in the container.
  - **setup_renv.R**: R script that restores all packages listed in the lockfile using `renv::restore()` during image build.

## Getting Started

1. **Install Docker**

   Make sure Docker and Docker Compose are installed and running.  
   [Download Docker here](https://www.docker.com/get-started).

2. **Clone the repository**

   Open a terminal or command prompt and run:

   ```bash
   git clone https://github.com/elgabbas/rstudio_renv.git
   cd rstudio_renv
   ```

   (If you don't have *git*, you can download and extract the ZIP from GitHub.)

3. **Configure the project volume**

   By default, no volume is set.  
   Use the `--mount` option of the build script to map your local project folder to `/home/rstudio/project` in the container.

   Example:

   ```bash
   ./build_docker.sh --renv scripts/renv.lock --mount /absolute/path/to/your/project
   ```

   - On Windows, use a format like `D:/your-project-path`.
   - On Linux/Mac, use `/home/username/your-project-path`.
   - To use an empty working directory, omit the `--mount` option.

4. **Build the Docker image**

   Use the provided script to build and start the container:

   - For the main environment (standard packages):

     ```bash
     ./build_docker.sh --renv scripts/renv.lock
     # or, to mount your project directory:
     ./build_docker.sh --renv scripts/renv.lock --mount /path/to/your/project
     ```

   - For the full environment (all packages):

     ```bash
     ./build_docker.sh --renv scripts/renv_full.lock
     # or, to mount your project directory:
     ./build_docker.sh --renv scripts/renv_full.lock --mount /path/to/your/project
     ```

   > **Tip:** If you get a permissions error, make the script executable:  
   > `chmod +x build_docker.sh`

   **Notes:**
   - The first build will be slow as it pulls the base image (~7GB as of July 2025) and installs all specified R packages.
   - Subsequent builds are faster if the base image and package layers are cached.
   - R packages are baked into the image; if you change the lock file, you’ll need to rebuild.

5. **Verify the container is running**

   After the script finishes, check that the container is running:

   ```bash
   docker ps
   ```

   You should see `rstudio_renv` listed. You can also use Docker Desktop’s UI if available.

6. **Access RStudio Server and VS Code**

   - Open your web browser to:
     - `http://localhost:8787` for RStudio Server
     - `http://localhost:8080` for VS Code (code-server)
   - By default, authentication is **disabled** (`DISABLE_AUTH: true` in `docker-compose.yml`).  
     - If authentication is enabled, log in as `rstudio` with password `password` (or as set in the compose file).
   - The default working directory is `/home/rstudio/project`, mapped to your local folder if you used `--mount`.
   - If the `magrittr` package is included in the lock file, it will be loaded by default for pipe operator (`%>%`) support.
   - **Persistence:**  
     - Only files in the mapped project directory persist.  
     - Any other container changes are ephemeral and will be lost upon stopping the container.

   **VS Code (code-server):**
   - The container includes code-server (VS Code in the browser) with a recommended set of extensions for R, Quarto, Markdown, YAML, CSV, Git, and productivity.
   - VS Code user settings are preconfigured (from `scripts/code_settings.json`).
   - To install additional extensions, use the code-server extension UI.

7. **Stopping the container**

   Stop and remove the running container with:

   ```bash
   docker compose down
   ```

   The image remains and can be restarted later with `docker compose up -d`.

---

## Pulling Prebuilt Images from GitLab Container Registry

If you do not want to build the Docker images yourself, you can **pull prebuilt images directly from the GitLab Container Registry** associated with this project.

### Available Images

There are **two main images**, each built from a different lock file:

- **Main Image** contains only the core R packages, as specified in `scripts/renv.lock`. This is *recommended for most users or when you want a minimal, fast-loading environment.*
- **Full Image** contains a comprehensive set of R packages, as specified in `scripts/renv_full.lock`.   This is *recommended for advanced workflows, teaching, or when you want all available features pre-installed.*

### How to Pull an Image

1. **Find the Registry Address**

   The images are hosted at the following addresses:

     ```bash
     # Main Image
     registry.gitlab.com/elgabbas/rstudio_renv:main-main
     # or use the full Image
     # registry.gitlab.com/elgabbas/rstudio_renv:main-full
     ```

   For example, to pull the main image built from the `main` branch:

   ```bash
   docker pull registry.gitlab.com/elgabbas/rstudio_renv:main-main
   ```

   To pull the full image:

   ```bash
   docker pull registry.gitlab.com/elgabbas/rstudio_renv:main-full
   ```

2. **Log in to GitLab Registry (if required)**

   If the registry is private, you will need to authenticate:

   ```bash
   docker login registry.gitlab.com
   # Enter your GitLab username and a personal access token as password (or use CI/CD variables)
   ```

3. **Run the Pulled Image**

   Once you have pulled the image, you can run it with Docker as described in earlier sections, or use it with Docker Compose by updating the `image:` field in `docker-compose.yml`.

---

## Using Images on HPCs with Singularity (Apptainer)

Many high-performance computing (HPC) systems use **Singularity** (also known as [Apptainer](https://apptainer.org/)) instead of Docker, as it is designed for secure, user-space container execution.

### What is Singularity?

Singularity is a container platform that allows you to run Docker images on HPC clusters **without requiring root permissions**. This is ideal for research, reproducibility, and sharing environments in academic settings.

### How to Use These Images with Singularity

#### 1. **Pull the Docker Image as a Singularity Image**

Singularity can pull directly from Docker registries and convert images into its own `.sif` format.

```bash
# for the main image
singularity pull rstudio_renv_main.sif docker://registry.gitlab.com/elgabbas/rstudio_renv:main-main
# for the full image
# singularity pull rstudio_renv_full.sif docker://registry.gitlab.com/elgabbas/rstudio_renv:main-full
```

This command will create a local file called `rstudio_renv_main.sif` or `rstudio_renv_full.sif`, which is your container image.

#### 2. **Run the Singularity Image**

You can now run the container on the HPC system. For example, to start an interactive shell inside the container:

```bash
singularity shell rstudio_renv_main.sif
# or to run a command in the container
# singularity exec rstudio_renv_main.sif Rscript --version
```

#### 3. **Bind-Mount Data Directories**

To access your project files or data inside the container, use the `--bind` option:

```bash
singularity shell --bind /path/to/your/project:/home/rstudio/project rstudio_renv_main.sif
```

This will make your local directory available inside the container, just like Docker volumes.

---

### Summary Table

| Image Name                               | Contents         | Use Case                | Pull Command Example                                                 |
|-------------------------------------------|------------------|-------------------------|----------------------------------------------------------------------|
| `registry.gitlab.com/elgabbas/rstudio_renv:main-main` | Main packages    | Standard workflows      | `docker pull registry.gitlab.com/elgabbas/rstudio_renv:main-main`    |
| `registry.gitlab.com/elgabbas/rstudio_renv:main-full` | All packages     | Advanced/teaching/all   | `docker pull registry.gitlab.com/elgabbas/rstudio_renv:main-full`    |

---

> **Tip:**  
> For more on using Docker images with Singularity/Apptainer, see the [official documentation](https://apptainer.org/docs/user/latest/docker_and_oci.html).

---

## Customization

### Changing R Packages

- The `renv.lock` file in `scripts/` defines the R packages installed in the image.
- **To use your own lock file:**
  - Replace `scripts/renv.lock` with your own (generated via `renv::snapshot()`), then rebuild.
  - Or, use the `--renv` argument to specify a different lockfile (see above).

### Using a Full Set of Packages

- The `scripts/renv_full.lock` file contains a larger set of packages for more advanced workflows.
- Build with this file using the provided build script and option:

  ```bash
  ./build_docker.sh --renv scripts/renv_full.lock
  ```

### Modifying RStudio or VS Code Settings

- Edit `scripts/rstudio-prefs.json` to change RStudio UI preferences (theme, font, etc.).
- Edit `scripts/code_settings.json` to change VS Code (code-server) settings and UI.
- Changes are applied on next rebuild.

### Adding System Dependencies

- To add Linux libraries for R packages, edit the `apt-get install` lines in the `Dockerfile`.
- Rebuild the image after making changes.

### Changing R Options

- Modify global R options in `scripts/.Rprofile`. This is sourced at the start of every R session in the container.

### Adjusting CPU Cores

- The build uses 6 CPU cores by default for parallel package compilation.
- To change this, edit the `n_cores` argument in the `Dockerfile` or build with:

  ```bash
  docker build --build-arg n_cores=4 -t rstudio_renv .
  ```

### RStudio Server Authentication

- By default, authentication is **disabled** for convenience.  
- **For production:** Set a strong password and/or enable authentication.

  ```yaml
    environment:
      DISABLE_AUTH: false
      PASSWORD: your_secure_password
  ```

### Updating the Docker Image

  ```bash
  # Pull the latest changes from GitHub:
  git pull origin main
  
  # Rebuild the Docker image to incorporate updates:
  bash ./build_docker.sh 
  # or for the full image:
  # bash ./build_docker.sh --renv scripts/renv_full.lock
  ```

---

## Summary

With this setup, you can launch an isolated *RStudio Server* instance equipped with geospatial tools, VS Code in the browser, and a project-specific, reproducible R environment in minutes.

- Clone the repo  
- Optionally configure your project volume  
- Build and run the image  
- Launch RStudio or VS Code in your browser

For questions or issues, please see [the GitHub repository](https://github.com/elgabbas/rstudio_renv).

---
