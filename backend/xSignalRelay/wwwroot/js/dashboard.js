const STATE_META = {
    Online: { icon: '🟢', label: 'Online', cls: 'running' },
    Unknown: { icon: '🟡', label: 'Unknown', cls: 'disabled' },
    Error: { icon: '🔴', label: 'Error', cls: 'error' }
};

function formatTimestamp(value) {
    return value ? new Date(value).toLocaleString('uk-UA') : '—';
}

function esc(text) {
    const div = document.createElement('div');
    div.textContent = text ?? '';
    return div.innerHTML;
}

async function loadStatus() {
    try {
        const response = await fetch('/api/status');
        const s = await response.json();
        const meta = STATE_META[s.state] ?? STATE_META.Unknown;

        const history = (s.history ?? []).map(entry => `
            <li><span class="history-time">${formatTimestamp(entry.timestampUtc)}</span> ${esc(entry.message)}</li>
        `).join('');

        document.getElementById('cards').innerHTML = `
            <div class="card ${meta.cls}">
                <div class="card-header">
                    <span class="card-name">Signal</span>
                    <span class="badge ${meta.cls}">${meta.icon} ${meta.label}</span>
                </div>
                <div class="card-detail"><span class="label">signal-cli:</span> ${esc(s.version) || '—'}</div>
                <div class="card-detail"><span class="label">Остання відправка:</span> ${formatTimestamp(s.lastActivityUtc)}</div>
                <div class="card-detail"><span class="label">Повідомлення:</span> ${esc(s.lastMessage) || '—'}</div>
                ${history ? `
                    <div class="card-detail history-label"><span class="label">Останні 5 повідомлень:</span></div>
                    <ul class="history">${history}</ul>
                ` : ''}
            </div>
        `;

        document.getElementById('timestamp').textContent =
            `Оновлено: ${new Date().toLocaleTimeString('uk-UA')}`;
    } catch (error) {
        console.error('Помилка завантаження статусу:', error);
    }
}

loadStatus();
setInterval(loadStatus, 5000);
