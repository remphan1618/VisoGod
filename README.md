# VisoMaster Deployment Guide: GitHub Actions -> DockerHub -> Vast.ai (Jupyter)

**Welcome!** This guide provides a comprehensive walkthrough for deploying the VisoMaster application using an automated pipeline. We'll go from your source code in GitHub, build a Docker image using GitHub Actions, push it to DockerHub, and finally run it on a Vast.ai instance with GPU support, specifically using their Jupyter Notebook launch environment.

This guide is designed for **beginners** with coding, Docker, and cloud platforms. We'll explain the concepts and steps clearly.

**The Goal:** To have a repeatable, automated way to get the VisoMaster application running in a cloud environment with the necessary GPU hardware and a graphical interface (VNC), accessible via Vast.ai's Jupyter interface.

**Internal Guide:** Once your instance is running on Vast.ai, you'll find an interactive Jupyter Notebook named `visomaster_deploy_Install_Guide.ipynb` inside the container. That notebook is your primary tool for **validating** the setup, **troubleshooting** issues, viewing **logs**, and performing **manual fixes** *after* launch. This document focuses on getting you *to* that point.

---

## Table of Contents

1.  [Pipeline Overview](#1-pipeline-overview)
2.  [Core Concepts Explained](#2-core-concepts-explained)
    *   [Docker (Images vs. Containers)](#docker-images-vs-containers)
    *   [Miniconda & Virtual Environments](#miniconda--virtual-environments)
    *   [CUDA (Runtime vs. Drivers)](#cuda-runtime-vs-drivers)
    *   [Vast.ai Basics (Instances, Jupyter, Storage, GPU, Portal)](#vastai-basics)
    *   [GitHub Actions (CI/CD)](#github-actions-cicd)
    *   [DockerHub (Registry)](#dockerhub-registry)
    *   [Supervisor (Process Management)](#supervisor-process-management)
    *   [VNC/GUI in Docker](#vncgui-in-docker)
3.  [Prerequisites](#3-prerequisites)
4.  [Setup Steps](#4-setup-steps)
    *   [Repository Structure](#repository-structure)
    *   [Populating the `dependencies` Folder](#populating-the-dependencies-folder)
    *   [Review `requirements.txt`](#review-requirementstxt)
    *   [GitHub Secrets Configuration](#github-secrets-configuration)
    *   [Pushing to GitHub](#pushing-to-github)
5.  [The Build Process (GitHub Actions)](#5-the-build-process-github-actions)
6.  [Launching on Vast.ai (Jupyter Template)](#6-launching-on-vastai-jupyter-template)
    *   [Finding Your Docker Image](#finding-your-docker-image)
    *   [Configuring the Instance](#configuring-the-instance)
    *   [Starting the Instance](#starting-the-instance)
7.  [Accessing the Application & Internal Guide](#7-accessing-the-application--internal-guide)
    *   [Connecting via VNC](#connecting-via-vnc)
    *   [Using the Vast.ai Jupyter Interface](#using-the-vastai-jupyter-interface)
    *   [Accessing the `visomaster_deploy_Install_Guide.ipynb`](#accessing-the-visomaster_deploy_install_guideipynb)
8.  [Understanding the Configuration Files](#8-understanding-the-configuration-files)
    *   [`visomaster_deploy_Dockerfile`](#visomaster_deploy_dockerfile)
    *   [`visomaster_deploy_supervisord.conf`](#visomaster_deploy_supervisordconf)
    *   [`visomaster_deploy_docker-compose.yml`](#visomaster_deploy_docker-composeyml)
    *   [`visomaster_deploy_GitHub_Actions_Workflow.yml`](#visomaster_deploy_github_actions_workflowyml)
    *   [`visomaster_deploy_Install_Guide.ipynb`](#visomaster_deploy_install_guideipynb)
9.  [Alternative Configurations & Strategies](#9-alternative-configurations--strategies)
    *   [Alternative Dockerfile (`visomaster_deploy_alt_dockerfile_ubuntu.Dockerfile`)](#alternative-dockerfile-visomaster_deploy_alt_dockerfile_ubuntudockerfile)
    *   [Alternative Supervisor Config (`visomaster_deploy_supervisord_alt_portal.conf`)](#alternative-supervisor-config-visomaster_deploy_supervisord_alt_portalconf)
    *   [Alternative Docker Compose (`visomaster_deploy_alt_docker-compose_portal.yml`)](#alternative-docker-compose-visomaster_deploy_alt_docker-compose_portalyml)
    *   [Alternative GitHub Actions Workflow (`visomaster_deploy_alt_GitHub_Actions_Workflow_release.yml`)](#alternative-github-actions-workflow-visomaster_deploy_alt_github_actions_workflow_releaseyml)
    *   [Alternative Deployment Strategy (Provisioning Script)](#alternative-deployment-strategy-provisioning-script)
10. [Logging & Troubleshooting (External View)](#10-logging--troubleshooting-external-view)
    *   [GitHub Actions Logs](#github-actions-logs)
    *   [DockerHub](#dockerhub)
    *   [Vast.ai Instance Logs](#vastai-instance-logs)
    *   [Inside the Container (via Internal Notebook)](#inside-the-container-via-internal-notebook)
11. [Conclusion](#11-conclusion)

---

## 1. Pipeline Overview

This diagram shows how the pieces fit together:

```mermaid
graph LR
    A[1. Your Code (GitHub Repo)\n- VisoMaster Code\n- dependencies/ folder\n- requirements.txt\n- Dockerfile\n- Supervisord.conf\n- Actions Workflow\n- .ipynb Guide] --> B{2. GitHub Actions (Build)};
    B -- Build Image --> C[3. DockerHub (Registry)\n- Stores your_username/visomaster:latest];
    C -- Pull Image --> D{4. Vast.ai Instance (Jupyter Launch)\n- Runs Container\n- Provides GPU & VNC\n- Uses /workspace\n- Access via Jupyter UI};
    D -- Access --> E[5. User Interaction\n- Connect via VNC\n- Use Jupyter Interface\n- Run .ipynb Guide for Validation/Troubleshooting];

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#ccf,stroke:#333,stroke-width:2px
    style C fill:#9cf,stroke:#333,stroke-width:2px
    style D fill:#cff,stroke:#333,stroke-width:2px
    style E fill:#cfc,stroke:#333,stroke-width:2px
```

*   **Source (GitHub):** You store your application code (`VisoMaster`), required non-pip/conda assets (in `dependencies/`), Python package list (`requirements.txt`), the instructions to build the environment (`visomaster_deploy_Dockerfile`), the configuration for services inside the container (`visomaster_deploy_supervisord.conf`), the automation script (`visomaster_deploy_GitHub_Actions_Workflow.yml`), and the internal validation notebook (`visomaster_deploy_Install_Guide.ipynb`).
*   **Build (GitHub Actions):** When you push changes to GitHub, an automated process (Action) reads your `Dockerfile` and builds a runnable "package" called a Docker image. This image contains the OS, Miniconda, specific Python/CUDA versions, all dependencies, your code, assets, models, and the internal `.ipynb` guide.
*   **Artifact (DockerHub):** The built image is uploaded (pushed) to DockerHub, a public (or private) storage place for Docker images. It gets tagged (like `latest` or a version number) so you can easily refer to it.
*   **Deployment & Runtime (Vast.ai):** You go to Vast.ai, choose a machine with a GPU, and tell it to run your image from DockerHub using the "Jupyter Notebook" template. Vast.ai starts a container from your image, connects the GPU, sets up storage (`/workspace`), and gives you access through a web-based Jupyter interface. Inside this running container, Supervisor manages the VNC server and the VisoMaster application.
*   **Interaction:** You connect to the running application via VNC for the GUI, or interact with the container environment (including running the `.ipynb` guide) through the Jupyter interface provided by Vast.ai.

---

## 2. Core Concepts Explained

*   ### Docker (Images vs. Containers)
    *   **Image:** A blueprint or template. It contains the operating system, code, libraries, environment variables, and configurations needed to run an application. Our `visomaster_deploy_Dockerfile` defines how to build the VisoMaster image. Images are read-only.
    *   **Container:** A running instance of an image. You can start, stop, and interact with containers. When Vast.ai runs your image, it creates a container. Changes inside a running container (like creating files outside of `/workspace`) are usually lost when the container stops, unless you use volumes.
    *   **Why Docker?** It packages your application and *all* its dependencies together, ensuring it runs consistently anywhere Docker is installed (your machine, GitHub Actions, Vast.ai). This avoids the "it works on my machine" problem.

*   ### Miniconda & Virtual Environments
    *   **Miniconda:** A minimal installer for Conda, a package and environment manager. It helps manage different project dependencies separately. (Docs: [Miniconda](https://docs.conda.io/projects/miniconda/en/latest/))
    *   **Environment (`visomaster`):** We create an isolated space called `visomaster` using Conda. Inside this environment, we install the specific Python version (3.10.13) and all the libraries (like PyTorch, TensorFlow, CUDA Toolkit) VisoMaster needs, without conflicting with other projects or the base system. (Example Dockerfile using Conda: [SkywardAI/bundoora](https://github.com/SkywardAI/bundoora/blob/main/Dockerfile.conda))
    *   **Why Conda?** It's excellent at managing complex dependencies, especially those involving Python and non-Python libraries like CUDA. VisoMaster specifically requires CUDA 12.4.1 installed via Conda.

*   ### CUDA (Runtime vs. Drivers)
    *   **NVIDIA Driver:** Software installed on the host machine (the Vast.ai server) that allows the operating system to talk to the NVIDIA GPU hardware. **You don't install this in Docker.** Vast.ai provides it.
    *   **CUDA Toolkit/Runtime:** Libraries and tools (like `nvcc` compiler, `cuDNN` for deep learning) needed by your *application* (VisoMaster, PyTorch, TensorFlow) to execute code on the GPU. **This IS installed inside the Docker image** (using `conda install -c nvidia/label/cuda-12.4.1 cuda-runtime` and `conda install -c conda-forge cudnn`). The version inside the container must be compatible with the driver version provided by Vast.ai (Vast.ai generally keeps drivers updated, and CUDA 12.x is widely compatible).
    *   **Why install in Docker?** Your application code needs these specific library versions to function correctly, regardless of the host machine's setup.

*   ### Vast.ai Basics
    *   **Instances:** Virtual machines or containers you rent on Vast.ai, often equipped with powerful GPUs. (Docs: [Instances](https://docs.vast.ai/instances/templates))
    *   **Jupyter Launch Mode:** A Vast.ai template type that launches your Docker container and provides access via a web-based JupyterLab interface. This includes a terminal, file browser, and the ability to run Jupyter notebooks (`.ipynb` files) like our internal guide. (Docs: [Jupyter Interface](https://docs.vast.ai/instances/jupyter))
    *   **`/workspace` Storage:** A special directory inside the Vast.ai instance container that is *persistent*. Files saved here (like VisoMaster outputs, downloaded models if configured) will remain even if you stop and restart the instance. Other directories inside the container are usually temporary. (Docs: [Persistent Storage](https://docs.vast.ai/instances/virtual-machines#persistent-storage))
    *   **GPU:** Vast.ai allows you to select instances with specific NVIDIA GPUs required for accelerating VisoMaster. The Docker setup ensures the container can use the provided GPU.
    *   **Docker Execution Environment:** Vast.ai uses Docker to run your application based on the image you specify. (Docs: [Docker Execution Environment](https://docs.vast.ai/instances/docker-execution-environment))
    *   **Instance Portal / Open Button:** An optional, more advanced Vast.ai feature (often used in their standard templates) that provides a secure web dashboard (usually via Caddy webserver) to access services inside the container (like VNC, web UIs, logs) using a secure token (`OPEN_BUTTON_TOKEN`). It centralizes access and logging (`/var/log/portal/`). See the alternative configurations section for how this can be set up. (Context: [Vast.ai Base Images](https://github.com/vast-ai/base-image), [Caddy Docs](https://caddyserver.com/docs/))

*   ### GitHub Actions (CI/CD)
    *   **CI/CD:** Continuous Integration / Continuous Deployment. Automating the process of building, testing, and deploying code.
    *   **Workflow:** A `.yml` file (like our `visomaster_deploy_GitHub_Actions_Workflow.yml`) that defines automated tasks.
    *   **Trigger:** An event that starts the workflow (e.g., pushing code to the `main` branch).
    *   **Jobs & Steps:** Workflows consist of jobs, which run on virtual machines (runners). Each job has steps that execute commands or use pre-built Actions (like logging into DockerHub, building the image).
    *   **Why Actions?** It automatically builds and pushes your Docker image whenever you update your code, saving you manual steps and ensuring the image reflects the latest changes.

*   ### DockerHub (Registry)
    *   **Registry:** A storage service for Docker images. DockerHub is the most popular public registry.
    *   **Repository:** Your personal space on DockerHub where your images are stored (e.g., `your_dockerhub_username/visomaster`).
    *   **Tag:** A label applied to an image version (e.g., `latest`, `v1.0`, or a commit SHA). Used to identify specific image builds.
    *   **Why DockerHub?** It makes your image accessible to services like Vast.ai from anywhere.

*   ### Supervisor (Process Management)
    *   **Supervisor:** A tool that runs inside the container to start, monitor, and automatically restart multiple processes (like the VNC server and the VisoMaster application). (Docs: [Supervisor](https://supervisord.readthedocs.io/en/latest/))
    *   **`supervisord.conf`:** The configuration file telling Supervisor which programs to run, how to run them, and where to log their output.
    *   **Why Supervisor?** Docker containers typically run only one main process. Supervisor allows us to easily manage several essential background services needed for VisoMaster and VNC.

*   ### VNC/GUI in Docker
    *   **VNC (Virtual Network Computing):** A protocol to remotely view and control a graphical desktop environment.
    *   **Components:**
        *   `Xvfb` (X Virtual Framebuffer): Creates a "fake" display in memory since the container has no physical screen.
        *   `fluxbox` (Window Manager): Provides basic window decorations and management for applications running in Xvfb.
        *   `x11vnc` (VNC Server): Shares the Xvfb display over the network via the VNC protocol (typically on port 5901).
    *   **Why VNC?** Allows you to interact with the graphical parts of VisoMaster (if any) or use GUI tools inside the container remotely. (Examples: [Balena Blog](https://www.balena.io/blog/blog/running-a-gui-application-with-balenacloud/), [Stack Overflow](https://stackoverflow.com/questions/12149006/how-to-make-xvfb-display-visible))

---

## 3. Prerequisites

Before you begin, make sure you have:

1.  **Git:** Installed on your local machine ([Download Git](https://git-scm.com/downloads)).
2.  **GitHub Account:** A free account on [GitHub](https://github.com/).
3.  **Docker Desktop (Optional but Recommended):** For potentially testing the Docker build locally ([Install Docker Desktop](https://www.docker.com/products/docker-desktop/)).
4.  **DockerHub Account:** A free account on [DockerHub](https://hub.docker.com/). Note your username.
5.  **Vast.ai Account:** An account on [Vast.ai](https://vast.ai/) with payment method added to rent instances.
6.  **VisoMaster Source Code:** Clone or download the VisoMaster source code from its repository (`https://github.com/remphan1618/VisoMaster`).
7.  **VisoMaster Assets:** Download the required assets (e.g., models, data files *excluding* source code zip) from the VisoMaster assets release page (e.g., `https://github.com/visomaster/visomaster-assets/releases/tag/v0.1.0_dp`). You will place these in the `dependencies` folder.

---

## 4. Setup Steps

1.  ### Repository Structure
    *   Create a new repository on GitHub (or use an existing one).
    *   Clone the repository to your local machine.
    *   Inside your local repository, create the following structure:

        ```
        your-repo-name/
        ├── VisoMaster/             # <-- Paste the VisoMaster application code here
        │   ├── main.py
        │   ├── download_models.py
        │   └── ... (other app files/folders)
        ├── dependencies/           # <-- Create this folder
        │   └── # (Place downloaded VisoMaster assets here - see next step)
        ├── requirements.txt        # <-- The requirements file from VisoMaster source
        ├── visomaster_deploy_Dockerfile
        ├── visomaster_deploy_supervisord.conf
        ├── visomaster_deploy_docker-compose.yml # (Mainly for reference/local test)
        ├── visomaster_deploy_GitHub_Actions_Workflow.yml
        ├── visomaster_deploy_Install_Guide.ipynb
        ├── visomaster_deploy_documentation.md # (This file)
        ├── # Add alternative config files here if using them
        ├── visomaster_deploy_alt_dockerfile_ubuntu.Dockerfile
        ├── visomaster_deploy_supervisord_alt_portal.conf
        ├── visomaster_deploy_alt_docker-compose_portal.yml
        ├── visomaster_deploy_alt_GitHub_Actions_Workflow_release.yml
        └── visomaster_deploy_provisioning_script.sh # (Example script)
        ```
    *   Copy the VisoMaster application code into the `VisoMaster/` directory.
    *   Copy the `requirements.txt` file from the VisoMaster source code to the root of your repository.
    *   Copy the configuration files provided in this guide (`visomaster_deploy_*`, `.ipynb`, `.md`, and any `_alt_` files you want to keep) into the root of your repository. Make sure the `.github/workflows/` directory exists and place the `visomaster_deploy_GitHub_Actions_Workflow.yml` file inside it (or rename it appropriately like `docker-build.yml`).

2.  ### Populating the `dependencies` Folder
    *   This step is **CRUCIAL**. The `Dockerfile` is configured to `COPY` the contents of the `dependencies/` folder into the image.
    *   Download the necessary assets (models, configuration files, etc., *excluding* the source code zip/tar.gz) from the VisoMaster assets releases page (e.g., `https://github.com/visomaster/visomaster-assets/releases/tag/v0.1.0_dp`).
    *   Place these downloaded asset files directly inside the `dependencies/` folder in your local repository.
    *   **Do not commit large binary files directly to Git if possible.** If assets are very large, consider using Git LFS or the Provisioning Script alternative. However, for simplicity, this guide assumes they are copied here and included in the build.

3.  ### Review `requirements.txt`
    *   Ensure the `requirements.txt` file in your repository root is the correct one from VisoMaster.
    *   The `Dockerfile` uses this file with specific `--extra-index-url` flags for PyTorch (`https://download.pytorch.org/whl/cu124`) and Nvidia (`https://pypi.nvidia.com`) as required by VisoMaster's dependencies.

4.  ### GitHub Secrets Configuration
    *   The GitHub Actions workflow needs your DockerHub credentials to push the image. Store these securely as GitHub Secrets.
    *   Go to your GitHub repository > Settings > Secrets and variables > Actions.
    *   Click "New repository secret".
    *   Create a secret named `DOCKERHUB_USERNAME` with your DockerHub username as the value.
    *   Create another secret named `DOCKERHUB_TOKEN`. For the value, generate an Access Token on DockerHub (Account Settings > Security > New Access Token) with Read, Write, Delete permissions and paste the token here. **Do not use your password.**

5.  ### Pushing to GitHub
    *   Add all the files to Git:
        ```bash
        git add .
        ```
    *   Commit the changes:
        ```bash
        git commit -m "Initial setup for VisoMaster deployment pipeline"
        ```
    *   Push to your GitHub repository:
        ```bash
        git push origin main # Or your default branch name
        ```

---

## 5. The Build Process (GitHub Actions)

*   Pushing your code (or merging a PR, depending on the trigger in your `.yml` file) will automatically start the GitHub Actions workflow defined in `.github/workflows/visomaster_deploy_GitHub_Actions_Workflow.yml`.
*   You can monitor the progress in the "Actions" tab of your GitHub repository.
*   The workflow will:
    1.  Check out your code.
    2.  Set up the Docker build environment.
    3.  Log in to DockerHub using your secrets.
    4.  Build the Docker image using `visomaster_deploy_Dockerfile` (this includes installing Conda, Python, CUDA, dependencies, copying your code/assets/notebook, and running `download_models.py`).
    5.  Push the built image to your DockerHub repository with the tags `latest` and the commit SHA.
*   If the build fails, check the logs in the Actions tab for errors (see Logging section below). Common issues include errors in the `Dockerfile`, missing files in `dependencies/`, or problems installing packages.

---

## 6. Launching on Vast.ai (Jupyter Template)

Once the GitHub Actions workflow successfully builds and pushes your image to DockerHub:

1.  ### Finding Your Docker Image
    *   Log in to your [DockerHub account](https://hub.docker.com/).
    *   You should see your repository (e.g., `your_dockerhub_username/visomaster`) with the `latest` tag and a tag matching the latest commit SHA from GitHub. Note the full image name: `your_dockerhub_username/visomaster`.

2.  ### Configuring the Instance
    *   Log in to [Vast.ai](https://vast.ai/).
    *   Go to the "Create" or "Templates" section to set up a new instance.
    *   **Choose Template / Image:**
        *   Select the **"Jupyter Notebook + Persistent /workspace"** template type or similar.
        *   In the "Docker Image" or "Template Config" section, find the field for the Docker image name. Enter your **full DockerHub image name** (e.g., `your_dockerhub_username/visomaster:latest`). Ensure you specify `:latest` or the specific commit SHA tag you want to deploy.
    *   **Select GPU:** Choose an instance type with a suitable NVIDIA GPU (check VisoMaster requirements). Ensure you have enough GPU RAM.
    *   **Storage:** Allocate sufficient disk space. The `/workspace` directory mapping is usually included by default with the Jupyter template, ensuring persistence.
    *   **Ports:** The Jupyter template typically handles mapping the Jupyter port automatically. For VNC, you need to explicitly map the VNC port:
        *   Find the "Port Forwarding" or similar section.
        *   Map Host Port `5901` (or another available port on the host if 5901 is taken) to Container Port `5901`. Remember the Host Port number Vast.ai assigns you.
    *   **Environment Variables:** Add any specific environment variables needed by VisoMaster or if using alternatives like the Instance Portal (`PORTAL_CONFIG`).
    *   **Launch Mode / Run Policy:** Ensure it's set to run interactively or as needed.
    *   **Review Costs:** Check the estimated hourly cost before launching.

3.  ### Starting the Instance
    *   Click the "Rent" or "Create Instance" button.
    *   Vast.ai will provision the machine, pull your Docker image from DockerHub (this might take a few minutes the first time), and start the container.
    *   Go to the "Instances" page on Vast.ai to monitor the status. Wait for it to show "Running".

---

## 7. Accessing the Application & Internal Guide

Once the instance is "Running":

1.  ### Connecting via VNC
    *   You'll need a VNC client application (e.g., [TigerVNC](https://tigervnc.org/), [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/), TightVNC).
    *   Find the public IP address and the mapped VNC Host Port (e.g., 5901, or whatever Vast.ai assigned) for your instance on the Vast.ai "Instances" page.
    *   Open your VNC client and connect to `<Instance_IP_Address>:<VNC_Host_Port>`.
    *   You should see the desktop environment running inside the container (provided by Fluxbox/Xvfb). You can now launch and interact with VisoMaster's GUI if it has one. (Note: The primary `supervisord.conf` runs VisoMaster as a background process; you might need to adjust the command if it's meant to be launched manually from a terminal within VNC).

2.  ### Using the Vast.ai Jupyter Interface
    *   On the Vast.ai "Instances" page, find the "Open" or "Jupyter" button/link for your running instance. Click it.
    *   This will open the JupyterLab interface in your web browser, connected directly to the running container.
    *   Here you can:
        *   **Browse Files:** Navigate the container's filesystem (including `/app`, `/workspace`).
        *   **Open Terminals:** Get a command-line shell inside the container (`File -> New -> Terminal`). This is useful for running commands, checking processes, etc. Remember to `conda activate visomaster` in the terminal if you need to run commands within the specific environment.
        *   **Run Notebooks:** Open and execute `.ipynb` files.

3.  ### Accessing the `visomaster_deploy_Install_Guide.ipynb`
    *   In the JupyterLab file browser (accessed via the web link from Vast.ai), navigate to the directory where the notebook was copied in the `Dockerfile` (e.g., `/app/VisoMaster/`).
    *   Double-click `visomaster_deploy_Install_Guide.ipynb`.
    *   This notebook is your **essential tool** inside the container. Run the cells (`Shift+Enter`) to:
        *   Verify the Conda environment, Python version, CUDA setup, dependencies, models, and GPU access.
        *   Check the status of running services (`supervisorctl status`).
        *   View logs directly within the notebook.
        *   Find commands to manually fix installation steps if the build failed silently.
        *   Get instructions for restarting services.
    *   **Use this notebook first if you encounter issues after launch!**

---

## 8. Understanding the Configuration Files

*   ### `visomaster_deploy_Dockerfile`
    *   **Purpose:** Instructions to build the Docker image layer by layer.
    *   **Key Steps:** Installs Miniconda, creates the `visomaster` environment (Python 3.10.13), installs CUDA 12.4.1/cuDNN via Conda, installs GUI tools (Xvfb, Fluxbox, x11vnc), installs Supervisor, installs Python packages from `requirements.txt` (using specific `--extra-index-url`s), copies the `dependencies` folder contents, copies your VisoMaster code, copies the `.ipynb` guide, runs the `download_models.py` script, and sets `supervisord` as the default command.
    *   **Optimization:** Combines `RUN` commands and cleans package manager caches (`apt-get clean`, `conda clean`) to reduce final image size. Smaller images build/pull faster.

*   ### `visomaster_deploy_supervisord.conf`
    *   **Purpose:** Tells the `supervisord` process inside the container what programs to run and manage.
    *   **Programs:**
        *   `xvfb`: Starts the virtual display.
        *   `fluxbox`: Starts the window manager on the virtual display.
        *   `x11vnc`: Starts the VNC server, sharing the virtual display on port 5901.
        *   `visomaster_app`: Starts the main VisoMaster application (e.g., `python main.py`) within the `visomaster` conda environment. **Crucially, it redirects output to `/workspace` subdirectories.**
    *   **Management:** Configures logging locations (to `/var/log/supervisor/`) and ensures programs are automatically started and restarted if they crash.

*   ### `visomaster_deploy_docker-compose.yml`
    *   **Purpose:** Defines how to run the container, mostly for local testing or as a reference for Vast.ai settings. Vast.ai uses its own UI/API, but the settings correspond to this file.
    *   **Key Settings:** Specifies the image name, enables GPU access (`deploy/resources`), maps the VNC port (`5901:5901`), maps the persistent volume (`/workspace:/workspace`), and sets the container to restart automatically.

*   ### `visomaster_deploy_GitHub_Actions_Workflow.yml`
    *   **Purpose:** Automates the build and push process on GitHub.
    *   **Trigger:** Runs on `push` to the `main` branch (or manually).
    *   **Steps:** Checks out code, sets up Docker build tools, logs into DockerHub (using secrets `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`), builds the image using the `Dockerfile`, and pushes the image to DockerHub with `latest` and commit SHA tags.

*   ### `visomaster_deploy_Install_Guide.ipynb`
    *   **Purpose:** The **INTERNAL**, interactive guide for use *inside* the running container via the Vast.ai Jupyter interface.
    *   **Contents:** Sections with runnable cells for:
        *   **Automated Checks:** Verify Conda env, Python version, CUDA/cuDNN, pip packages, copied dependencies, downloaded models, GPU access, service status.
        *   **Manual Fallback:** Provides the exact commands to run in a terminal to fix failed installation steps (Conda install, pip install, model download).
        *   **Troubleshooting:** Commands to restart services (`supervisorctl restart ...`) and tips for common issues.
        *   **Log Viewer:** Commands to view key log files (`supervisord` logs, application logs, VNC logs, potentially `/var/log/portal` logs if using that alternative).

---

## 9. Alternative Configurations & Strategies

These provide different ways to achieve parts of the pipeline, offering trade-offs. Choose the primary files unless you have a specific reason to use an alternative. **Always use the complete alternative file**, do not mix and match parts.

*   ### Alternative Dockerfile (`visomaster_deploy_alt_dockerfile_ubuntu.Dockerfile`)
    *   **Role:** Build Stage (Image Creation)
    *   **Difference:** Uses a standard `ubuntu:22.04` base image instead of `continuumio/miniconda3`. Manually installs Miniconda within the Dockerfile.
    *   **Pros:**
        *   More control over the base OS environment.
        *   Might be preferred if specific OS packages are needed.
    *   **Cons:**
        *   More setup steps required in the Dockerfile (installing wget, Miniconda itself).
        *   Potentially slightly larger base image layer than the official Miniconda image.
        *   No significant functional difference for this specific VisoMaster setup if Conda is the primary package manager anyway.
    *   **Choice:** Stick with the primary `visomaster_deploy_Dockerfile` unless you have strong reasons to manage the base OS more directly.

*   ### Alternative Supervisor Config (`visomaster_deploy_supervisord_alt_portal.conf`)
    *   **Role:** Runtime Stage (Container Process Management)
    *   **Difference:** Configured to work with the Vast.ai Instance Portal feature. Assumes Caddy webserver is installed (via Dockerfile) and uses environment variables (`PORTAL_CONFIG`) to configure services. Logs are typically directed to `/var/log/portal/`. VNC runs on localhost, proxied by Caddy.
    *   **Pros:**
        *   Provides a secure, web-based dashboard (the "Open" button on Vast.ai) to access services (VNC, potentially others) and logs.
        *   Centralized access and authentication via Vast.ai's token system (`OPEN_BUTTON_TOKEN`).
        *   Consolidated logging in `/var/log/portal/`.
    *   **Cons:**
        *   More complex setup: Requires Caddy installation and configuration (often via a `Caddyfile`), potentially wrapper scripts for services, and careful setting of the `PORTAL_CONFIG` environment variable during Vast.ai instance launch.
        *   Relies more heavily on specific Vast.ai template patterns and environment variables. (See [Vast.ai Base Images](https://github.com/vast-ai/base-image)).
        *   Adds overhead of running the Caddy webserver.
    *   **Choice:** Use if you prefer the centralized web dashboard access provided by Vast.ai's standard templates and are comfortable with the added complexity. Requires modifications to the Dockerfile (install Caddy) and Docker Compose/Vast.ai launch settings (set `PORTAL_CONFIG`).

*   ### Alternative Docker Compose (`visomaster_deploy_alt_docker-compose_portal.yml`)
    *   **Role:** Runtime Stage (Container Configuration - Reference for Vast.ai)
    *   **Difference:** Complements the `visomaster_deploy_supervisord_alt_portal.conf`. It maps the Caddy port (e.g., `1111:11111`) and crucially defines how the `PORTAL_CONFIG` environment variable would be set (though on Vast.ai, you set this via the UI/API). It does *not* typically expose the VNC port (5901) directly.
    *   **Pros:** Shows how the environment variables and port mappings differ for the Portal setup.
    *   **Cons:** Only a reference file; the actual configuration happens in the Vast.ai launch interface. Requires careful construction of the `PORTAL_CONFIG` JSON string.
    *   **Choice:** Use this as a reference if implementing the Instance Portal alternative.

*   ### Alternative GitHub Actions Workflow (`visomaster_deploy_alt_GitHub_Actions_Workflow_release.yml`)
    *   **Role:** Automation / CI/CD Stage
    *   **Difference:** Triggers the build/push process when a GitHub Release is published (using tags like `v1.0`, `v1.1`), instead of on every push to `main`. Includes an example (best-effort) step to test GPU access inside the built container.
    *   **Pros:**
        *   More controlled deployment aligned with versioned releases.
        *   Keeps DockerHub cleaner, only pushing tagged release images (plus `latest`).
        *   Includes a basic post-build test attempt.
    *   **Cons:**
        *   Image isn't updated on every push to `main`, only when you create a release.
        *   The GPU test step might not work reliably on standard GitHub-hosted runners (which usually lack GPUs) and is marked `continue-on-error`. A self-hosted runner with GPU would be needed for reliable testing.
    *   **Choice:** Use if you prefer a release-based workflow over continuous deployment from the main branch.

*   ### Alternative Deployment Strategy (Provisioning Script)
    *   **Role:** Runtime Stage (Late-stage Configuration)
    *   **Difference:** Instead of running `download_models.py` during the `Dockerfile` build, you use Vast.ai's `PROVISIONING_SCRIPT` feature. You provide a script (like `visomaster_deploy_provisioning_script.sh`) that Vast.ai runs *after* the container starts but *before* the main command (`supervisord`) executes. This script would contain the `conda run ... python download_models.py ...` command.
    *   **Pros:**
        *   Keeps the Docker image significantly smaller, as large model files aren't included.
        *   Faster image builds and pushes to DockerHub.
        *   Models can potentially be updated just by restarting the instance (if the script always fetches the latest).
    *   **Cons:**
        *   Instance startup time increases because models are downloaded every time the instance starts (unless downloaded to persistent `/workspace` and the script checks for existence).
        *   Requires the instance to have reliable internet access at startup.
        *   Adds another piece to manage (the script itself, which needs to be hosted somewhere accessible or embedded in the launch command/env var).
        *   Potential for download failures at runtime.
    *   **Choice:** Consider this if your models are very large (> few GB), change frequently, or if minimizing image size is critical. You would remove the `RUN python download_models.py` step from the `Dockerfile` and configure the `PROVISIONING_SCRIPT` environment variable in the Vast.ai launch settings (pointing to your script URL or embedding the script content).

---

## 10. Logging & Troubleshooting (External View)

Before diving into the internal `.ipynb` guide, check these logs if you encounter issues earlier in the pipeline:

*   ### GitHub Actions Logs
    *   **Location:** "Actions" tab in your GitHub repository. Click on the specific workflow run.
    *   **Purpose:** Diagnose Docker image build failures. Look for errors during `RUN` commands in the `Dockerfile` (e.g., package installation failed, script errors like `download_models.py` crashing, file not found).

*   ### DockerHub
    *   **Location:** Your repository page on [hub.docker.com](https://hub.docker.com/).
    *   **Purpose:** Verify that the image was pushed successfully after a green GitHub Actions run. Check the tags (`latest`, commit SHA) and push times.

*   ### Vast.ai Instance Logs
    *   **Location:** "Instances" page on Vast.ai. Click the "Logs" button for your instance.
    *   **Purpose:** Diagnose issues during instance startup *before* supervisord takes over, or issues with the container itself. This includes:
        *   Docker image pull errors (e.g., image not found, authentication error).
        *   Errors running the main container command (`supervisord` in our case).
        *   Output from the `PROVISIONING_SCRIPT` if used.
        *   Initial output from `supervisord` itself.

*   ### Inside the Container (via Internal Notebook)
    *   **Location:** Run the `visomaster_deploy_Install_Guide.ipynb` via the Vast.ai Jupyter interface.
    *   **Purpose:** This is the **primary place** to check logs and status *after* the instance is running. The notebook provides easy access to:
        *   Supervisor logs (`/var/log/supervisor/*`) for VNC, VisoMaster app, etc.
        *   Portal logs (`/var/log/portal/*`) if using that alternative.
        *   Service status (`supervisorctl status`).

---

## 11. Conclusion

This pipeline provides a robust and automated way to deploy VisoMaster on Vast.ai. By understanding the components and following the setup steps, you can create a repeatable workflow. Remember to populate the `dependencies` folder correctly and configure your GitHub secrets.

Once launched, the `visomaster_deploy_Install_Guide.ipynb` notebook inside the Jupyter environment is your go-to tool for validation and troubleshooting. Good luck!
