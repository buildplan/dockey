// app.js - Frontend JavaScript for Dockey

document.addEventListener('DOMContentLoaded', () => {

    const containerList = document.getElementById('container-list');
    const logModal = document.getElementById('log-modal');
    const logModalTitle = document.getElementById('log-modal-title');
    const logContent = document.getElementById('log-content');
    const closeModalBtn = document.getElementById('close-modal-btn');
    let logWebSocket;

    /**
     * Fetches container data from the API and updates the UI.
     */
    const fetchContainers = async () => {
        try {
            const response = await fetch('/api/containers');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const containers = await response.json();

            // Clear the current list
            containerList.innerHTML = '';

            if (containers.error) {
                displayError(containers.error);
                return;
            }

            // Populate the table with new data
            containers.forEach(container => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td class="p-4 whitespace-nowrap">
                        <div class="flex items-center">
                            <div class="w-3 h-3 ${container.status_color} rounded-full mr-2"></div>
                            <span class="text-sm">${container.status}</span>
                        </div>
                    </td>
                    <td class="p-4 whitespace-nowrap text-sm font-medium">${container.name}</td>
                    <td class="p-4 whitespace-nowrap text-sm text-gray-400">${container.image}</td>
                    <td class="p-4 whitespace-nowrap text-sm text-gray-400">${container.ports}</td>
                    <td class="p-4 whitespace-nowrap text-sm font-medium">
                        <button data-id="${container.id}" data-name="${container.name}" class="view-logs-btn text-blue-400 hover:text-blue-300 mr-3">Logs</button>
                        <button data-id="${container.id}" data-action="start" class="action-btn text-green-400 hover:text-green-300 mr-3">Start</button>
                        <button data-id="${container.id}" data-action="stop" class="action-btn text-red-400 hover:text-red-300 mr-3">Stop</button>
                        <button data-id="${container.id}" data-action="restart" class="action-btn text-yellow-400 hover:text-yellow-300">Restart</button>
                    </td>
                `;
                containerList.appendChild(row);
            });

        } catch (error) {
            console.error("Failed to fetch containers:", error);
            displayError("Could not connect to the Dockey backend. Is it running?");
        }
    };

    /**
     * Displays an error message in the container list area.
     * @param {string} message - The error message to display.
     */
    const displayError = (message) => {
        containerList.innerHTML = `<tr><td colspan="5" class="p-4 text-center text-red-400">${message}</td></tr>`;
    };

    /**
     * Opens the log viewer modal and establishes a WebSocket connection.
     * @param {string} containerId - The ID of the container to view logs for.
     * @param {string} containerName - The name of the container.
     */
    const openLogModal = (containerId, containerName) => {
        logModalTitle.textContent = `Logs for ${containerName}`;
        logContent.innerHTML = '<p class="text-gray-500">Connecting to log stream...</p>';
        logModal.classList.remove('hidden');
        document.body.classList.add('overflow-hidden'); // Prevent background scrolling

        // Establish WebSocket connection
        const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        logWebSocket = new WebSocket(`${wsProtocol}//${window.location.host}/ws/logs/${containerId}`);

        logWebSocket.onopen = () => {
            logContent.innerHTML = ''; // Clear "Connecting..." message
        };

        logWebSocket.onmessage = (event) => {
            // Sanitize the log line before appending to prevent potential XSS
            const logLine = document.createElement('div');
            logLine.textContent = event.data;
            logContent.appendChild(logLine);
            // Auto-scroll to the bottom
            logContent.scrollTop = logContent.scrollHeight;
        };

        logWebSocket.onerror = (error) => {
            console.error('WebSocket Error:', error);
            logContent.innerHTML += '<p class="text-red-400">Error connecting to log stream.</p>';
        };

        logWebSocket.onclose = () => {
             logContent.innerHTML += '<p class="text-yellow-400">Log stream closed.</p>';
        };
    };

    /**
     * Closes the log viewer modal and terminates the WebSocket connection.
     */
    const closeLogModal = () => {
        if (logWebSocket) {
            logWebSocket.close();
        }
        logModal.classList.add('hidden');
        document.body.classList.remove('overflow-hidden');
    };

    /**
     * Handles clicks on action buttons (start, stop, restart).
     * @param {Event} event - The click event.
     */
    const handleContainerAction = async (event) => {
        const button = event.target;
        const containerId = button.dataset.id;
        const action = button.dataset.action;

        button.disabled = true;
        button.textContent = '...';

        try {
            const response = await fetch(`/api/containers/${containerId}/${action}`, {
                method: 'POST',
            });
            const result = await response.json();

            if (result.status !== 'success') {
                alert(`Error: ${result.message}`);
            }

            // Refresh the container list to show the new status
            setTimeout(fetchContainers, 500);

        } catch (error) {
            console.error(`Failed to ${action} container:`, error);
            alert(`An error occurred while trying to ${action} the container.`);
        } finally {
            // The button will be re-rendered on the next fetch
        }
    };

    // --- Event Listeners ---

    // Use event delegation for dynamically created buttons
    document.body.addEventListener('click', (event) => {
        if (event.target.classList.contains('view-logs-btn')) {
            const containerId = event.target.dataset.id;
            const containerName = event.target.dataset.name;
            openLogModal(containerId, containerName);
        }
        if (event.target.classList.contains('action-btn')) {
            handleContainerAction(event);
        }
    });

    closeModalBtn.addEventListener('click', closeLogModal);

    // Close modal with the Escape key
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !logModal.classList.contains('hidden')) {
            closeLogModal();
        }
    });

    // --- Initial Load & Refresh ---
    fetchContainers();
    // Refresh the container list every 5 seconds
    setInterval(fetchContainers, 5000);
});
