# Alternative Dockerfile using Ubuntu 22.04 as base
# Manually installs Miniconda and dependencies.
# See documentation for Pros/Cons (more control vs. more setup steps).

FROM ubuntu:22.04 AS builder

# --- Environment Setup ---
ARG PYTHON_VERSION=3.10.13
ARG CONDA_ENV_NAME=visomaster
ARG CUDA_VERSION_CONDA=12.4.1 # Still installing CUDA via Conda for consistency
ARG APP_DIR=/app
ARG VISOMASTER_CODE_DIR=${APP_DIR}/VisoMaster
ARG VISOMASTER_DEPS_DIR=${APP_DIR}/dependencies
ARG VISOMASTER_MODELS_DIR=${APP_DIR}/models

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR ${APP_DIR}

# --- Install Base Dependencies & GUI ---
# Combine RUN instructions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    bzip2 \
    git \
    supervisor \
    xvfb \
    fluxbox \
    x11vnc \
    # Clean up apt cache
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Install Miniconda ---
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

# Add conda to PATH
ENV PATH /opt/conda/bin:$PATH

# --- Conda Environment & Dependencies ---
# Create environment
RUN conda create -y -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} && \
    conda clean -a -y

# Set SHELL to use bash and activate conda env
SHELL ["conda", "run", "-n", "${CONDA_ENV_NAME}", "/bin/bash", "-c"]

# Verify conda activation
RUN echo "Conda environment $CONDA_DEFAULT_ENV activated." && \
    python --version

# Install CUDA Toolkit and cuDNN via Conda
RUN conda install -y -c nvidia/label/cuda-${CUDA_VERSION_CONDA} cuda-runtime && \
    conda install -y -c conda-forge cudnn && \
    conda clean -a -y

# Install Python Dependencies via Pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/cu124 \
    --extra-index-url https://pypi.nvidia.com

# --- Copy Code, Dependencies, Guide ---
RUN mkdir -p ${VISOMASTER_CODE_DIR} ${VISOMASTER_DEPS_DIR} ${VISOMASTER_MODELS_DIR}
COPY dependencies/ ${VISOMASTER_DEPS_DIR}/
COPY . ${VISOMASTER_CODE_DIR}/
COPY visomaster_deploy_Install_Guide.ipynb ${VISOMASTER_CODE_DIR}/
WORKDIR ${VISOMASTER_CODE_DIR}

# --- Download Models ---
RUN echo "Running model download script..." && \
    python download_models.py --output_dir ${VISOMASTER_MODELS_DIR} && \
    echo "Model download script finished."

# --- Runtime Configuration ---
EXPOSE 5901
COPY visomaster_deploy_supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Reset SHELL
SHELL ["/bin/bash", "-c"]