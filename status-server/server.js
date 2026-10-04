const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const PORT = process.env.STATUS_PORT || 8080;
const SESSION = process.env.TMUX_SESSION || 'agents';
const LINES = 40;
const POLL_MS = 2000;

let state = { updatedAt: null, panes: [], error: null };

const stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');

function listPanes() {
  const out = execFileSync('tmux', ['list-panes', '-s', '-t', SESSION, '-F',
    '#{window_index}.#{pane_index}\t#{window_name}\t#{pane_current_command}'],
    { encoding: 'utf8' });
  return out.trim().split('\n').filter(Boolean).map((line) => {
    const [idx, windowName, cmd] = line.split('\t');
    return { target: `${SESSION}:${idx}`, windowName, cmd };
  });
}

function capture(target) {
  const out = execFileSync('tmux',
    ['capture-pane', '-p', '-t', target, '-S', `-${LINES}`],
    { encoding: 'utf8' });
  return stripAnsi(out).split('\n').slice(-LINES).join('\n');
}

function poll() {
  try {
    const panes = listPanes().map((p) => ({
      id: p.target,
      label: `${p.windowName} — ${p.cmd}`,
      text: capture(p.target),
    }));
    state = { updatedAt: new Date().toISOString(), panes, error: null };
  } catch (e) {
    state = { updatedAt: new Date().toISOString(), panes: [], error: e.message };
  }
}
poll();
setInterval(poll, POLL_MS);

const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript' };

http.createServer((req, res) => {
  if (req.url === '/status.json') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(state));
  }
  const rel = req.url === '/' ? '/index.html' : req.url;
  const filePath = path.join(__dirname, 'public', rel);
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath)] || 'text/plain' });
    res.end(data);
  });
}).listen(PORT, () => console.log(`status server listening on :${PORT}`));
