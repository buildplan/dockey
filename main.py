import subprocess
import json
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# --- Basic Setup ---
app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="static")

# --- API Endpoints ---

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    """Serves the main HTML page."""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/v1/monitor")
async def get_monitor_data():
    """
    Runs the container-monitor script with 'json' output and returns the result.
    This is now the single source of truth for container data.
    """
    try:
        # Execute the shell script to get the JSON data
        result = subprocess.run(
            ["/usr/local/bin/container-monitor", "json"],
            capture_output=True,
            text=True,
            check=True,  # This will raise an exception if the script returns a non-zero exit code
            timeout=30  # Add a timeout for safety
        )

        # Parse the JSON output from the script
        data = json.loads(result.stdout)
        return data

    except subprocess.CalledProcessError as e:
        # If the script fails, return a detailed error
        raise HTTPException(
            status_code=500,
            detail=f"Error executing monitor script: {e.stderr}"
        )
    except json.JSONDecodeError:
        # If the script output isn't valid JSON
        raise HTTPException(
            status_code=500,
            detail="Failed to parse JSON output from monitor script."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/logs/{container_id}", response_class=PlainTextResponse)
async def get_container_logs(container_id: str):
    """
    Gets the last 200 lines of logs for a container. This is a simple,
    reliable HTTP request, replacing the problematic WebSocket.
    """
    try:
        # Use the official docker CLI to get logs
        result = subprocess.run(
            ["docker", "logs", "--tail", "200", container_id],
            capture_output=True,
            text=True,
            check=True,
            timeout=15
        )
        return result.stdout or "No log output in the last 200 lines."

    except subprocess.CalledProcessError as e:
        # Return the error from the docker command itself (e.g., container not found)
        return e.stderr
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
