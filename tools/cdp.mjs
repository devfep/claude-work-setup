#!/usr/bin/env node
// Zero-dependency Chrome DevTools Protocol control CLI. Node >= 22 (global WebSocket + fetch).
// Env: CDP_URL (default http://127.0.0.1:9222), CDP_TARGET (target id from `new`).
const base = (process.env.CDP_URL ?? 'http://127.0.0.1:9222').replace(/\/$/, '');
const [cmd, ...args] = process.argv.slice(2);

const usage = `usage: cdp <command> [args]
  doctor                       browser version and open targets
  new [url]                    open a target, print its id (export CDP_TARGET=<id>)
  close <id>                   close a target
  nav <url>                    navigate the current target and wait for load
  wait <css> [ms]              wait for a selector (default 10000 ms)
  click <css>                  real mouse click on the first match
  type <css> <text>            click then insert text
  eval <js>                    evaluate in page, print JSON
  screenshot <file.png>        viewport PNG
  snapshot                     accessibility tree, one "role  name" per line
  console <seconds>            console/exception entries since page load; exit 1 if any error
  network <seconds>            collect failed or >=400 requests; exit 1 if any`;

const die = (msg) => {
  console.error(`cdp: ${msg}`);
  process.exit(2);
};

async function http(path, method = 'GET') {
  const r = await fetch(base + path, { method });
  if (!r.ok) throw new Error(`${method} ${path}: HTTP ${r.status}`);
  const text = await r.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function target() {
  const list = await http('/json/list');
  const id = process.env.CDP_TARGET;
  const t = id ? list.find((x) => x.id === id) : list.find((x) => x.type === 'page');
  if (!t) die(id ? `target ${id} not found (cdp new <url>)` : 'no page target (cdp new <url>)');
  return t;
}

class Session {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.seq = 0;
    this.pending = new Map();
    this.listeners = [];
    this.ws.onmessage = (e) => {
      const m = JSON.parse(e.data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        if (m.error) reject(new Error(m.error.message));
        else resolve(m.result);
      } else if (m.method) {
        for (const l of this.listeners) l(m);
      }
    };
  }
  open() {
    return new Promise((res, rej) => {
      this.ws.onopen = () => res();
      this.ws.onerror = () => rej(new Error(`websocket failed: ${this.ws.url}`));
    });
  }
  send(method, params = {}) {
    const id = ++this.seq;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }
  on(fn) {
    this.listeners.push(fn);
  }
  close() {
    this.ws.close();
  }
}

async function withSession(fn) {
  const t = await target();
  const s = new Session(t.webSocketDebuggerUrl);
  await s.open();
  try {
    return await fn(s, t);
  } finally {
    s.close();
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function evaluate(s, expression) {
  const params = { expression, returnByValue: true, awaitPromise: true };
  const r = await s.send('Runtime.evaluate', params);
  if (r.exceptionDetails) {
    throw new Error(r.exceptionDetails.exception?.description ?? 'evaluation threw');
  }
  return r.result.value;
}

async function nodeCenter(s, selector) {
  const { root } = await s.send('DOM.getDocument', { depth: 0 });
  const { nodeId } = await s.send('DOM.querySelector', { nodeId: root.nodeId, selector });
  if (!nodeId) die(`no element matches ${selector}`);
  await s.send('DOM.scrollIntoViewIfNeeded', { nodeId }).catch(() => {});
  const { model } = await s.send('DOM.getBoxModel', { nodeId });
  const q = model.content; // quad: x1,y1,x2,y2,x3,y3,x4,y4
  return { x: (q[0] + q[4]) / 2, y: (q[1] + q[5]) / 2 };
}

async function click(s, selector) {
  const { x, y } = await nodeCenter(s, selector);
  for (const type of ['mousePressed', 'mouseReleased']) {
    await s.send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
  }
}

// Print each entry the handler returns as a JSON line for `seconds`; return the error count.
async function collect(s, seconds, enable, handler) {
  let bad = 0;
  s.on((m) => {
    const out = handler(m);
    if (!out) return;
    console.log(JSON.stringify(out));
    if (out.severity === 'error') bad++;
  });
  for (const method of enable) await s.send(method);
  await sleep(Number(seconds) * 1000);
  return bad;
}

function consoleEntry(m) {
  if (m.method === 'Runtime.consoleAPICalled') {
    const text = m.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
    return { severity: m.params.type === 'error' ? 'error' : m.params.type, text };
  }
  if (m.method === 'Runtime.exceptionThrown') {
    const d = m.params.exceptionDetails;
    return { severity: 'error', text: d.exception?.description ?? d.text };
  }
  if (m.method === 'Log.entryAdded') {
    return { severity: m.params.entry.level, text: m.params.entry.text };
  }
  return null;
}

function networkEntry(m) {
  if (m.method === 'Network.loadingFailed') {
    return { severity: 'error', text: m.params.errorText, requestId: m.params.requestId };
  }
  if (m.method === 'Network.responseReceived' && m.params.response.status >= 400) {
    const { status, url } = m.params.response;
    return { severity: 'error', text: `HTTP ${status}`, url };
  }
  return null;
}

const commands = {
  async doctor() {
    const v = await http('/json/version');
    const list = await http('/json/list');
    console.log(`Browser: ${v.Browser}`);
    console.log(`Protocol: ${v['Protocol-Version']}`);
    console.log(`Targets: ${list.length}`);
    for (const t of list) console.log(`  ${t.id}  ${t.type}  ${t.url}`);
  },
  async new(url = 'about:blank') {
    const path = `/json/new?${encodeURIComponent(url)}`;
    let t;
    try {
      t = await http(path, 'PUT');
    } catch {
      t = await http(path);
    }
    console.log(t.id);
  },
  async close(id) {
    if (!id) die('close needs a target id');
    await http(`/json/close/${id}`);
  },
  async nav(url) {
    if (!url) die('nav needs a url');
    await withSession(async (s) => {
      await s.send('Page.enable');
      const loaded = new Promise((r) => s.on((m) => m.method === 'Page.loadEventFired' && r()));
      const timer = setTimeout(() => die('load timed out after 30 s'), 30000);
      await s.send('Page.navigate', { url });
      await loaded;
      clearTimeout(timer);
    });
  },
  async wait(selector, ms = '10000') {
    if (!selector) die('wait needs a selector');
    await withSession(async (s) => {
      const deadline = Date.now() + Number(ms);
      while (Date.now() < deadline) {
        if (await evaluate(s, `!!document.querySelector(${JSON.stringify(selector)})`)) return;
        await sleep(200);
      }
      die(`timed out waiting for ${selector}`);
    });
  },
  async click(selector) {
    if (!selector) die('click needs a selector');
    await withSession((s) => click(s, selector));
  },
  async type(selector, ...text) {
    if (!selector || text.length === 0) die('type needs a selector and text');
    await withSession(async (s) => {
      await click(s, selector);
      await s.send('Input.insertText', { text: text.join(' ') });
    });
  },
  async eval(...js) {
    if (js.length === 0) die('eval needs an expression');
    const v = await withSession((s) => evaluate(s, js.join(' ')));
    console.log(JSON.stringify(v));
  },
  async screenshot(file) {
    if (!file) die('screenshot needs an output file');
    const { data } = await withSession((s) => s.send('Page.captureScreenshot', { format: 'png' }));
    const fs = await import('node:fs/promises');
    await fs.writeFile(file, Buffer.from(data, 'base64'));
  },
  async snapshot() {
    const named = ['button', 'link', 'textbox', 'checkbox', 'combobox', 'heading'];
    await withSession(async (s) => {
      await s.send('Accessibility.enable');
      const { nodes } = await s.send('Accessibility.getFullAXTree');
      for (const n of nodes) {
        if (n.ignored) continue;
        const role = n.role?.value ?? '';
        const name = n.name?.value ?? '';
        if (!name && !named.includes(role)) continue;
        console.log(`${role}  ${name}`);
      }
    });
  },
  async console(seconds = '5') {
    const enable = ['Runtime.enable', 'Log.enable'];
    const bad = await withSession((s) => collect(s, seconds, enable, consoleEntry));
    process.exitCode = bad > 0 ? 1 : 0;
  },
  async network(seconds = '5') {
    const bad = await withSession((s) => collect(s, seconds, ['Network.enable'], networkEntry));
    process.exitCode = bad > 0 ? 1 : 0;
  },
};

if (!cmd || !Object.hasOwn(commands, cmd)) {
  console.error(usage);
  process.exit(cmd ? 2 : 0);
}
commands[cmd](...args).catch((e) => die(e.message));
