FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq docker-cli && \
    rm -rf /var/lib/apt/lists/*

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

# Expose the port the app runs ong
EXPOSE 8000

# Define the command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
