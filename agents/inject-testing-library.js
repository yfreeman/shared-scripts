#!/usr/bin/env node

/**
 * Standalone CDP script that connects to Chrome, injects @testing-library/dom
 * into the active page, and disconnects. Runs independently of the MCP server.
 *
 * Usage: node inject-testing-library.js --page-id=<CDP_TARGET_ID> [--browser-url=URL]
 *
 * Options:
 *   --page-id      CDP target ID of the page to inject into (required)
 *   --browser-url  Chrome DevTools Protocol URL (default: http://192.168.65.254:9222)
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');

const args = process.argv.slice(2).reduce((acc, arg) => {
  const match = arg.match(/^--([^=]+)=(.+)$/);
  if (match) acc[match[1]] = match[2];
  return acc;
}, {});

const BROWSER_URL = args['browser-url'] || process.env.BROWSER_URL || 'http://192.168.65.254:9222';
const PAGE_ID = args['page-id'];
const LIBRARY_PATH = path.join(__dirname, 'testing-library-dom.umd.min.js');

if (!PAGE_ID) {
  console.error('Usage: node inject-testing-library.js --page-id=<CDP_TARGET_ID>');
  process.exit(1);
}

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve(JSON.parse(data)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

/**
 * Raw WebSocket client using Node.js net/http — no dependencies.
 * Implements just enough of the WebSocket protocol for CDP.
 */
function connectWebSocket(wsUrl) {
  return new Promise((resolve, reject) => {
    const url = new URL(wsUrl);
    const key = crypto.randomBytes(16).toString('base64');

    const reqOptions = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname + url.search,
      headers: {
        'Connection': 'Upgrade',
        'Upgrade': 'websocket',
        'Sec-WebSocket-Key': key,
        'Sec-WebSocket-Version': '13',
      },
    };

    const req = http.request(reqOptions);
    req.on('upgrade', (res, socket) => {
      let buffer = Buffer.alloc(0);

      const ws = {
        _socket: socket,

        send(data) {
          const payload = Buffer.from(data, 'utf-8');
          const mask = crypto.randomBytes(4);
          let header;

          if (payload.length < 126) {
            header = Buffer.alloc(6);
            header[0] = 0x81; // FIN + text
            header[1] = 0x80 | payload.length; // MASK + length
            mask.copy(header, 2);
          } else if (payload.length < 65536) {
            header = Buffer.alloc(8);
            header[0] = 0x81;
            header[1] = 0x80 | 126;
            header.writeUInt16BE(payload.length, 2);
            mask.copy(header, 4);
          } else {
            header = Buffer.alloc(14);
            header[0] = 0x81;
            header[1] = 0x80 | 127;
            header.writeBigUInt64BE(BigInt(payload.length), 2);
            mask.copy(header, 10);
          }

          const masked = Buffer.alloc(payload.length);
          for (let i = 0; i < payload.length; i++) {
            masked[i] = payload[i] ^ mask[i % 4];
          }

          socket.write(Buffer.concat([header, masked]));
        },

        close() {
          const frame = Buffer.alloc(6);
          frame[0] = 0x88; // FIN + close
          frame[1] = 0x80; // MASK + 0 length
          crypto.randomBytes(4).copy(frame, 2);
          socket.write(frame);
          socket.end();
        },

        _listeners: [],
        onMessage(fn) { this._listeners.push(fn); },
      };

      socket.on('data', (chunk) => {
        buffer = Buffer.concat([buffer, chunk]);

        while (buffer.length >= 2) {
          const secondByte = buffer[1] & 0x7f;
          let payloadLength, headerLength;

          if (secondByte < 126) {
            payloadLength = secondByte;
            headerLength = 2;
          } else if (secondByte === 126) {
            if (buffer.length < 4) return;
            payloadLength = buffer.readUInt16BE(2);
            headerLength = 4;
          } else {
            if (buffer.length < 10) return;
            payloadLength = Number(buffer.readBigUInt64BE(2));
            headerLength = 10;
          }

          const totalLength = headerLength + payloadLength;
          if (buffer.length < totalLength) return;

          const payload = buffer.subarray(headerLength, totalLength);
          buffer = buffer.subarray(totalLength);

          const text = payload.toString('utf-8');
          for (const fn of ws._listeners) fn(text);
        }
      });

      socket.on('error', (err) => reject(err));
      resolve(ws);
    });

    req.on('error', reject);
    req.end();
  });
}

function sendCDP(ws, method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = Math.floor(Math.random() * 1e9);
    const handler = (text) => {
      const data = JSON.parse(text);
      if (data.id === id) {
        ws._listeners = ws._listeners.filter(fn => fn !== handler);
        if (data.error) reject(new Error(`CDP error: ${JSON.stringify(data.error)}`));
        else resolve(data.result);
      }
    };
    ws.onMessage(handler);
    ws.send(JSON.stringify({ id, method, params }));
  });
}

async function main() {
  // 1. Read the library source
  if (!fs.existsSync(LIBRARY_PATH)) {
    console.error(`Library not found at ${LIBRARY_PATH}`);
    process.exit(1);
  }
  const librarySource = fs.readFileSync(LIBRARY_PATH, 'utf-8');

  // 2. Get list of pages from Chrome
  const pages = await httpGet(`${BROWSER_URL}/json`);
  const targets = pages.filter(p => p.type === 'page');

  if (targets.length === 0) {
    console.error('No open pages found.');
    process.exit(1);
  }

  // 3. Find the target page by ID
  const target = targets.find(p => p.id === PAGE_ID);
  if (!target) {
    console.error(`No page with ID "${PAGE_ID}" found.`);
    console.error('Available pages:');
    targets.forEach(p => console.error(`  ${p.id}  ${p.url}`));
    process.exit(1);
  }

  console.log(`Injecting into: ${target.url}`);

  // 4. Connect via CDP WebSocket
  const ws = await connectWebSocket(target.webSocketDebuggerUrl);

  try {
    // 5. Inject the library and set up window.TL
    const expression = `
      (function() {
        if (window.TL && window.TestingLibraryDom) {
          return 'already loaded';
        }
        ${librarySource}
        window.TL = window.TestingLibraryDom;
        return window.TL ? 'injected' : 'failed';
      })()
    `;

    const result = await sendCDP(ws, 'Runtime.evaluate', {
      expression,
      returnByValue: true,
    });

    console.log(`Result: ${result.result.value}`);
  } finally {
    // 6. Disconnect
    ws.close();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
