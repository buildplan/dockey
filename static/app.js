document.addEventListener('DOMContentLoaded', () => {

    const containerList = document.getElementById('container-list');
    const logModal = document.getElementById('log-modal');
    const logModalTitle = document.getElementById('log-modal-title');
    const logContent = document.getElementById('log-content');
    const closeModalBtn = document.getElementById('close-modal-btn');

    const fetchContainers = async () => {
        try {
            const response = await fetch('/api/v1/monitor');
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
            }
            const containers = await response.json();

            containerList.innerHTML = '';

            if (!containers || containers.length === 0) {
                containerList.innerHTML = `<tr><td colspan="6" class="p-4 text-center text-gray-400">No running containers found.</td></tr>`;
                return;
            }

            containers.forEach(container => {
                const row = document.createElement('tr');
                const statusColor = container.status === 'running' ? 'bg-green-500' : 'bg-red-500';

                row.innerHTML = `
                    <td class="p-4 whitespace-nowrap">
                        <div class="flex items-center">
                            <div class="w-3 h-3 ${statusColor} rounded-full mr-2"></div>
                            <span class="text-sm">${container.status}</span>
                        </div>
                    </td>
                    <td class="p-4 whitespace-nowrap text-sm font-medium">${container.name}</td>
                    <td class="p-4 whitespace-nowrap text-sm text-gray-400">${container.image}</td>
                    <td class="p-4 whitespace-nowrap text-sm text-gray-400">${container.cpu || '0'}%</td>
                    <td class="p-4 whitespace-nowrap text-sm text-gray-400">${container.mem || '0'}%</td>
                    <td class="p-4 whitespace-nowrap text-sm font-medium">
                        <button data-id="${container.id}" data-name="${container.name}" class="view-logs-btn text-blue-400 hover:text-blue-300">Logs</button>
                    </td>
                `;
                containerList.appendChild(row);
            });

        } catch (error) {
            console.error("Failed to fetch containers:", error);
            displayError(error.message);
        }
    };

    /**
     * Displays an error message in the container list area.
     */
    const displayError = (message) => {
        containerList.innerHTML = `<tr><td colspan="6" class="p-4 text-center text-red-400">${message}</td></tr>`;
    };

    /**
     * Opens the log viewer modal and fetches recent logs.
     */
    const openLogModal = async (containerId, containerName) => {
        logModalTitle.textContent = `Recent Logs for ${containerName}`;
        logContent.innerHTML = '<p class="text-gray-500">Fetching logs...</p>';
        logModal.classList.remove('hidden');
        document.body.classList.add('overflow-hidden');

        try {
            const response = await fetch(`/api/v1/logs/${containerId}`);
            const logText = await response.text();
            // Use <pre> for preserving whitespace and newlines from the logs
            logContent.innerHTML = `<pre class="whitespace-pre-wrap">${logText}</pre>`;
        } catch (error) {
            logContent.innerHTML = `<p class="text-red-400">Failed to fetch logs: ${error.message}</p>`;
        }
    };

    /**
     * Closes the log viewer modal.
     */
    const closeLogModal = () => {
        logModal.classList.add('hidden');
        document.body.classList.remove('overflow-hidden');
    };

    // --- Event Listeners ---
    document.body.addEventListener('click', (event) => {
        if (event.target.classList.contains('view-logs-btn')) {
            openLogModal(event.target.dataset.id, event.target.dataset.name);
        }
    });

    closeModalBtn.addEventListener('click', closeLogModal);

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !logModal.classList.contains('hidden')) {
            closeLogModal();
        }
    });

    // --- Initial Load & Refresh ---
    fetchContainers();
    setInterval(fetchContainers, 10000); // Refresh every 10 seconds
});
