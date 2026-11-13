// 완성된 Flutter Web 파일만 제공하는 로컬 미리보기 도구. 앱 백엔드는 없다.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
const root = path.resolve('build/web');
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json','.ttf':'font/ttf','.otf':'font/otf','.png':'image/png'};
http.createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
    const body = await readFile(file);
    res.writeHead(200, {'Content-Type':types[path.extname(file)] ?? 'application/octet-stream', 'Cache-Control':'no-cache'}).end(body);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(7357, '0.0.0.0', () => console.log('MovieLog: http://localhost:7357'));
