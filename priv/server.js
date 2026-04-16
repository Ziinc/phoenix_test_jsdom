const { JSDOM } = require("jsdom");
const readline = require("readline");
const cssEscape = require("css.escape");

const instances = new Map();

// --- JSDOM options ---

function installWindowShims(window) {
  // Stub location.reload — LiveView JS calls it on connect, JSDom doesn't support navigation
  try {
    Object.defineProperty(window.location, "reload", {
      value: () => {},
      writable: true,
      configurable: true,
    });
  } catch {
    // Location properties may be frozen in some JSDom versions
  }
  if (!window.CSS) window.CSS = {};
  if (typeof window.CSS.escape !== "function") {
    window.CSS.escape = cssEscape;
  }
  if (typeof window.CSS.supports !== "function") {
    window.CSS.supports = () => false;
  }
}

function jsdomOpts(url, forFromURL = false) {
  const opts = {
    runScripts: "dangerously",
    resources: "usable",
    pretendToBeVisual: true,
    beforeParse(window) {
      installWindowShims(window);
    },
  };
  // JSDOM.fromURL sets url automatically — only set it for new JSDOM(html, opts)
  if (!forFromURL) opts.url = url;
  return opts;
}

// --- DOM settle ---

function waitForDomSettle(dom, timeout = 5000) {
  return new Promise((resolve) => {
    const doc = dom.window.document;
    let timer = null;
    let done = false;

    const finish = () => {
      if (done) return;
      done = true;
      observer.disconnect();
      clearTimeout(hardTimeout);
      resolve();
    };

    const observer = new dom.window.MutationObserver(() => {
      clearTimeout(timer);
      timer = setTimeout(finish, 150);
    });

    observer.observe(doc, {
      childList: true,
      subtree: true,
      attributes: true,
      characterData: true,
    });

    // If no mutations within 300ms, consider it settled
    timer = setTimeout(finish, 300);

    // Hard timeout
    const hardTimeout = setTimeout(finish, timeout);
  });
}

function waitForLoad(dom) {
  return new Promise((resolve) => {
    if (dom.window.document.readyState === "complete") {
      resolve();
    } else {
      dom.window.addEventListener("load", resolve, { once: true });
      // Safety timeout
      setTimeout(resolve, 5000);
    }
  });
}

// --- Element finding helpers ---

function getScope(dom, within) {
  const doc = dom.window.document;
  if (!within) return doc;
  const el = doc.querySelector(within);
  if (!el) throw new Error(`Scope not found: ${within}`);
  return el;
}

function findByText(elements, text) {
  if (!text) return elements[0] || null;
  for (const el of elements) {
    if (el.textContent.trim().includes(text)) return el;
  }
  return null;
}

function findInputByLabel(dom, selector, label, within) {
  const scope = getScope(dom, within);
  const doc = dom.window.document;

  // Find label element containing the text
  for (const lbl of scope.querySelectorAll("label")) {
    if (!lbl.textContent.trim().includes(label)) continue;

    // Try for= attribute
    if (lbl.htmlFor) {
      const input = doc.getElementById(lbl.htmlFor);
      if (input && input.matches(selector)) return input;
    }

    // Try nested input
    const nested = lbl.querySelector(selector);
    if (nested) return nested;
  }

  // Try by placeholder or name
  for (const input of scope.querySelectorAll(selector)) {
    if (
      input.placeholder === label ||
      input.name === label ||
      input.getAttribute("aria-label") === label
    )
      return input;
  }

  return null;
}

function getInstance(id) {
  const dom = instances.get(id);
  if (!dom) throw new Error("instance not found: " + id);
  return dom;
}

// --- LiveView connection detection ---

function waitForLiveView(dom, timeout = 5000) {
  return new Promise((resolve) => {
    const doc = dom.window.document;
    const main = doc.querySelector("[data-phx-main]");
    if (!main) { resolve(); return; }
    if (!main.classList.contains("phx-loading")) { resolve(); return; }

    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      observer.disconnect();
      clearTimeout(hardTimeout);
      resolve();
    };

    const observer = new dom.window.MutationObserver(() => {
      if (!main.classList.contains("phx-loading")) finish();
    });

    observer.observe(main, { attributes: true, attributeFilter: ["class"] });
    const hardTimeout = setTimeout(finish, timeout);
  });
}

// --- Navigation helper ---

async function navigateTo(id, url, method, body) {
  const old = instances.get(id);
  // Extract cookies (including HttpOnly) from jsdom's cookie jar before closing
  const oldCookie = old ? old.cookieJar.getCookieStringSync(url) : "";
  if (old) old.window.close();

  if (method && method !== "GET") {
    // POST/PUT/etc: use fetch, then create JSDOM from response
    const headers = { "Content-Type": "application/x-www-form-urlencoded" };
    if (oldCookie) headers["Cookie"] = oldCookie;
    const fetchOpts = {
      method,
      headers,
      redirect: "follow",
    };
    if (body) fetchOpts.body = body;
    const resp = await fetch(url, fetchOpts);
    const html = await resp.text();
    const finalUrl = resp.url;
    const dom = new JSDOM(html, jsdomOpts(finalUrl, false));
    instances.set(id, dom);
    await waitForLoad(dom);
    await waitForLiveView(dom);
    await waitForDomSettle(dom);
    return dom;
  } else {
    const dom = await JSDOM.fromURL(url, jsdomOpts(url, true));
    instances.set(id, dom);
    await waitForLoad(dom);
    await waitForLiveView(dom);
    await waitForDomSettle(dom);
    return dom;
  }
}

// --- Handlers ---

const handlers = {
  ping: () => "pong",

  visit: async ([id, url]) => {
    await navigateTo(id, url);
    return { ok: true };
  },

  waitForSelector: async ([id, selector, timeout = 5000]) => {
    const dom = getInstance(id);
    const doc = dom.window.document;
    if (doc.querySelector(selector)) return { ok: true };
    return new Promise((resolve) => {
      let done = false;
      const finish = (found) => {
        if (done) return;
        done = true;
        observer.disconnect();
        clearTimeout(hard);
        resolve(found ? { ok: true } : { error: `Timeout waiting for "${selector}"` });
      };
      const observer = new dom.window.MutationObserver(() => {
        if (doc.querySelector(selector)) finish(true);
      });
      observer.observe(doc, { childList: true, subtree: true, attributes: true, characterData: true });
      const hard = setTimeout(() => finish(false), timeout);
    });
  },

  destroy: ([id]) => {
    const dom = instances.get(id);
    if (dom) {
      dom.window.close();
      instances.delete(id);
    }
    return "ok";
  },

  getHtml: ([id]) => {
    const dom = getInstance(id);
    return { ok: dom.serialize() };
  },

  getTitle: ([id]) => {
    const dom = getInstance(id);
    return { ok: dom.window.document.title };
  },

  getCurrentPath: ([id]) => {
    const dom = getInstance(id);
    const loc = dom.window.location;
    const path = loc.pathname + (loc.search || "");
    return { ok: path };
  },

  clickLink: async ([id, selector, text, within]) => {
    const dom = getInstance(id);
    const scope = getScope(dom, within);
    const links = scope.querySelectorAll(selector || "a");
    const link = findByText(links, text);
    if (!link) return { error: `Could not find link "${text}"` };

    const href = link.href;

    // Check if LiveView handles it (has data-phx-link)
    if (link.dataset.phxLink) {
      link.click();
      await waitForDomSettle(dom);
      return { ok: true };
    }

    // Static link — navigate
    await navigateTo(id, href);
    return { ok: true };
  },

  clickButton: async ([id, selector, text, within]) => {
    const dom = getInstance(id);
    const scope = getScope(dom, within);
    const sel = selector || "button, input[type='submit'], input[type='button']";
    const buttons = scope.querySelectorAll(sel);
    const button = findByText(buttons, text);
    if (!button) return { error: `Could not find button "${text}"` };

    // Check if it's in a phx-submit form or has phx-click
    const form = button.closest("form");
    const isLiveView = button.hasAttribute("phx-click") || (form && form.hasAttribute("phx-submit"));

    if (isLiveView) {
      button.click();
      await waitForDomSettle(dom);
      return { ok: true };
    }

    // Static form submission
    if (form) {
      const formData = new dom.window.FormData(form);
      const method = (form.method || "GET").toUpperCase();
      const action = form.action || dom.window.location.href;

      // Add button value if it has one
      if (button.name && button.value) {
        formData.set(button.name, button.value);
      }

      const params = new URLSearchParams(formData).toString();

      if (method === "GET") {
        const url = new URL(action);
        url.search = params;
        await navigateTo(id, url.href);
      } else {
        await navigateTo(id, action, method, params);
      }
      return { ok: true };
    }

    // Button without form — just click
    button.click();
    await waitForDomSettle(dom);
    return { ok: true };
  },

  fillIn: async ([id, selector, label, value, within]) => {
    const dom = getInstance(id);
    const input = findInputByLabel(dom, selector || "input, textarea", label, within);
    if (!input) return { error: `Could not find input "${label}"` };

    const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
      dom.window.HTMLInputElement.prototype, "value"
    )?.set || Object.getOwnPropertyDescriptor(
      dom.window.HTMLTextAreaElement.prototype, "value"
    )?.set;

    if (nativeInputValueSetter) {
      nativeInputValueSetter.call(input, value);
    } else {
      input.value = value;
    }

    input.dispatchEvent(new dom.window.Event("input", { bubbles: true }));
    input.dispatchEvent(new dom.window.Event("change", { bubbles: true }));
    await waitForDomSettle(dom);
    return { ok: true };
  },

  selectOption: async ([id, selector, label, option, within]) => {
    const dom = getInstance(id);
    const select = findInputByLabel(dom, selector || "select", label, within);
    if (!select) return { error: `Could not find select "${label}"` };

    // Find option by text
    let targetOption = null;
    for (const opt of select.options) {
      if (opt.textContent.trim() === option || opt.value === option) {
        targetOption = opt;
        break;
      }
    }
    if (!targetOption) return { error: `Could not find option "${option}" in "${label}"` };

    select.value = targetOption.value;
    select.dispatchEvent(new dom.window.Event("change", { bubbles: true }));
    await waitForDomSettle(dom);
    return { ok: true };
  },

  check: async ([id, selector, label, within]) => {
    const dom = getInstance(id);
    const input = findInputByLabel(dom, selector || "input[type='checkbox']", label, within);
    if (!input) return { error: `Could not find checkbox "${label}"` };

    if (!input.checked) {
      input.checked = true;
      input.dispatchEvent(new dom.window.Event("change", { bubbles: true }));
      input.dispatchEvent(new dom.window.Event("click", { bubbles: true }));
    }
    await waitForDomSettle(dom);
    return { ok: true };
  },

  uncheck: async ([id, selector, label, within]) => {
    const dom = getInstance(id);
    const input = findInputByLabel(dom, selector || "input[type='checkbox']", label, within);
    if (!input) return { error: `Could not find checkbox "${label}"` };

    if (input.checked) {
      input.checked = false;
      input.dispatchEvent(new dom.window.Event("change", { bubbles: true }));
      input.dispatchEvent(new dom.window.Event("click", { bubbles: true }));
    }
    await waitForDomSettle(dom);
    return { ok: true };
  },

  choose: async ([id, selector, label, within]) => {
    const dom = getInstance(id);
    const input = findInputByLabel(dom, selector || "input[type='radio']", label, within);
    if (!input) return { error: `Could not find radio "${label}"` };

    input.checked = true;
    input.dispatchEvent(new dom.window.Event("change", { bubbles: true }));
    input.dispatchEvent(new dom.window.Event("click", { bubbles: true }));
    await waitForDomSettle(dom);
    return { ok: true };
  },

  submitForm: async ([id, formSelector, within]) => {
    const dom = getInstance(id);
    const scope = getScope(dom, within);
    const form = scope.querySelector(formSelector || "form");
    if (!form) return { error: "Could not find form" };

    if (form.hasAttribute("phx-submit")) {
      form.dispatchEvent(new dom.window.Event("submit", { bubbles: true, cancelable: true }));
      await waitForDomSettle(dom);
      return { ok: true };
    }

    // Static form
    const formData = new dom.window.FormData(form);
    const method = (form.method || "GET").toUpperCase();
    const action = form.action || dom.window.location.href;
    const params = new URLSearchParams(formData).toString();

    if (method === "GET") {
      const url = new URL(action);
      url.search = params;
      await navigateTo(id, url.href);
    } else {
      await navigateTo(id, action, method, params);
    }
    return { ok: true };
  },

  // Debug: check window state
  execJs: ([id, code]) => {
    const dom = getInstance(id);
    try {
      const result = dom.window.eval(code);
      return { ok: String(result) };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Keep legacy handlers for jsdom_test.exs
  create: ([id, html, opts = {}]) => {
    const jsdomOptions = { contentType: "text/html", url: "http://localhost/" };
    if (opts.runScripts) jsdomOptions.runScripts = opts.runScripts;
    if (opts.url) jsdomOptions.url = opts.url;
    const dom = new JSDOM(html, jsdomOptions);
    installWindowShims(dom.window);
    instances.set(id, dom);
    return "ok";
  },

  query: ([id, selector, text, within]) => {
    const dom = instances.get(id);
    if (!dom) return { error: "instance not found" };
    const root = within ? dom.window.document.querySelector(within) : dom.window.document;
    if (!root) return { found: false };
    for (const el of root.querySelectorAll(selector)) {
      if (!text || el.textContent.includes(text)) {
        return { found: true, text: el.textContent.trim(), html: el.outerHTML };
      }
    }
    return { found: false };
  },
};

// --- JSON stdin/stdout protocol ---

const rl = readline.createInterface({ input: process.stdin });

rl.on("line", async (line) => {
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    process.stdout.write(JSON.stringify({ id: null, error: "invalid json" }) + "\n");
    return;
  }

  const { id, fn, args } = req;
  const handler = handlers[fn];
  if (!handler) {
    process.stdout.write(JSON.stringify({ id, error: `unknown function: ${fn}` }) + "\n");
    return;
  }

  try {
    const result = await handler(args || []);
    process.stdout.write(JSON.stringify({ id, result }) + "\n");
  } catch (e) {
    process.stdout.write(JSON.stringify({ id, error: e.message }) + "\n");
  }
});
