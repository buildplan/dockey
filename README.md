# Dockey - A Simple Docker Monitoring UI

Dockey is a lightweight, containerized web application that provides a clean and simple interface for monitoring and managing your Docker containers. It's the web UI evolution of the `container-monitor.sh` script.

### Features

-   **Container Dashboard:** View all your containers, their status, image, and port mappings in a single, clean interface.
 
-   **Live Status:** Real-time status indicators (running, stopped, paused) with a 5-second auto-refresh.
 
-   **Live Log Streaming:** Open a modal to view live, streaming logs for any container.
 
-   **Basic Container Actions:** Start, stop, and restart containers directly from the UI.
 
-   **Simple & Lightweight:** Built with FastAPI and vanilla JavaScript, ensuring minimal resource usage.
 
-   **Easy to Deploy:** Runs as a single Docker container itself.
 

### Project Structure

```
.
├── docker-compose.yml
├── Dockerfile
├── main.py              # FastAPI Backend
├── README.md
├── requirements.txt
└── static/
    ├── app.js           # Frontend JavaScript
    ├── index.html       # Main HTML page
    └── style.css        # Custom CSS
```

### How to Run Dockey

#### Prerequisites

-   Docker
 
-   Docker Compose
 

#### 1\. Clone the Repository

If you've pushed these files to your GitHub repo, clone it:

```
git clone https://github.com/your-username/dockey.git
cd dockey
```

#### 2\. Build and Run with Docker Compose

This is the simplest method. It will build the `dockey` image and run it in a container.

```
docker-compose up --build
```

You can add the `-d` flag (`docker-compose up -d --build`) to run it in detached mode (in the background).

#### 3\. Access the Web UI

Once it's running, open your web browser and go to:

**http://localhost:8000**

You should see the Dockey dashboard listing all the containers on your machine.

### Building and Pushing to Docker Hub

If you want to push your image to Docker Hub to easily deploy it on other machines without needing the source code.

#### 1\. Login to Docker Hub

```
docker login
```

#### 2\. Build the Image

Build the image and tag it with your Docker Hub username and the repository name you created.

```
# Replace 'your-dockerhub-username' with your actual username
docker build -t your-dockerhub-username/dockey:latest .
```

#### 3\. Push the Image

```
docker push your-dockerhub-username/dockey:latest
```

Now, on any other machine with Docker, you can run Dockey with a single command, without needing the `docker-compose.yml` file or the source code:

```
docker run -d -p 8000:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name dockey \
  your-dockerhub-username/dockey:latest
```

### Security Note

This application requires access to the Docker socket (`/var/run/docker.sock`). Mounting this socket into a container is equivalent to giving that container **root access to your host machine**. Only run this application in a trusted environment.
