// Local-only fixture server: exercise a Pages-like subdirectory and SW updates.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, sep, extname } from 'node:path';

const root = resolve('dist');
let revision = 0;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png' };
createServer(async (request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1:4174');
  if (request.method === 'POST' && url.pathname === '/__update') {
    revision++;
    response.writeHead(204).end();
    return;
  }
  if (!url.pathname.startsWith('/liftosaur/')) { response.writeHead(404).end(); return; }
  const path = resolve(root, decodeURIComponent(url.pathname.slice('/liftosaur/'.length)) || 'index.html');
  if (!path.startsWith(root + sep)) { response.writeHead(403).end(); return; }
  try {
    let body = await readFile(path);
    if (path === resolve(root, 'sw.js')) {
      body = body.toString().replace(/const version = "([^"]+)"/, `const version = "$1-test-${revision}"`);
    }
    response.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    response.end(body);
  } catch { response.writeHead(404).end(); }
}).listen(4174, '127.0.0.1');
