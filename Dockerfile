FROM python:3.11-slim

WORKDIR /app

# This build argument is automatically provided by buildx and will be 'amd64' or 'arm64'
ARG TARGETARCH

# Install dependencies for both the Python app and the shell script.
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq skopeo wget && \
    rm -rf /var/lib/apt/lists/*

# Install yq manually, using the TARGETARCH variable for multi-arch builds
RUN wget "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH}" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Copy the requirements file for the Python app
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the shell script into the image and make it executable
# This script is the new core of our monitoring logic
COPY container-monitor.sh /usr/local/bin/container-monitor
RUN chmod +x /usr/local/bin/container-monitor

# Copy the application code (backend and frontend) into the container
COPY ./main.py .
COPY ./static ./static

# Expose the port the app runs on
EXPOSE 8000

# Define the command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
