# Dockerfile for the final, robust Dockey

# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# This build argument is automatically provided by buildx and will be 'amd64' or 'arm64'
ARG TARGETARCH
# Define Docker version for consistency
ARG DOCKER_VERSION=26.1.4

# Install all dependencies: script tools and download tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    jq \
    skopeo \
    wget \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Install yq manually, using the TARGETARCH variable for multi-arch builds
RUN wget "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH}" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install the Docker CLI static binary manually for the correct architecture
# This uses a case statement to correctly map buildx arch to Docker arch names
RUN \
    case ${TARGETARCH} in \
        "amd64") DOCKER_ARCH="x86_64" ;; \
        "arm64") DOCKER_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    wget "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz" -O /tmp/docker.tgz && \
    tar --strip-components=1 -xzf /tmp/docker.tgz -C /usr/local/bin docker/docker && \
    rm /tmp/docker.tgz

# Copy the requirements file for the Python app
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the shell script into the image and make it executable
COPY container-monitor.sh /usr/local/bin/container-monitor
RUN chmod +x /usr/local/bin/container-monitor

# Copy the application code (backend and frontend) into the container
COPY ./main.py .
COPY ./static ./static

# Expose the port the app runs on
EXPOSE 8000

# Define the command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
