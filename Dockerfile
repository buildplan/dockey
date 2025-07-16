FROM python:3.11-slim

WORKDIR /app

# This build argument is automatically provided by buildx for multi-arch builds
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

# Install yq manually using the TARGETARCH variable
RUN wget "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH}" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install the Docker CLI static binary manually for the correct architecture
RUN DOCKER_ARCH=$(echo "$TARGETARCH" | sed 's/amd64/x86_64/') && \
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
