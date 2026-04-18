import fs from "node:fs";
import path, { resolve } from "path";
import { defineConfig } from "vite";

export default defineConfig({
  resolve: {
    // Force Node.js resolution — without this, Vite picks up "browser" export
    // conditions (e.g. ws/browser.js which throws at runtime).
    conditions: ["node", "require"],
    mainFields: ["main", "module"],
  },
  build: {
    lib: {
      entry: resolve(__dirname, "server.js"),
      formats: ["cjs"],
      fileName: "server.bundle",
    },
    rollupOptions: {
      external: [
        /^node:/,
        "module",
        "readline",
        "http",
        "https",
        "url",
        "vm",
        "fs",
        "path",
        "crypto",
        "stream",
        "events",
        "buffer",
        "util",
        "os",
        "child_process",
        "net",
        "tls",
        "zlib",
        "string_decoder",
        "querystring",
        "assert",
        "punycode",
        "perf_hooks",
        "worker_threads",
        "async_hooks",
        "dns",
        "tty",
        "constants",
      ],
    },
    minify: false,
    target: "node22",
  },
  plugins: [
    {
      name: "patch-websocket-url-parse",
      // jsdom's WebSocket-impl calls the deprecated url.parse() to pass the
      // result into tough-cookie's getCookieStringSync, which also accepts a
      // URL string. Pass this.url (already a serialized WHATWG URL) directly.
      transform(code, id) {
        if (id.includes("WebSocket-impl")) {
          return code
            .replace(
              /const\s+nodeParsedURL\s*=\s*nodeURL\.parse\(this\.url\);?/,
              ""
            )
            .replace(/getCookieStringSync\(nodeParsedURL,/g, "getCookieStringSync(this.url,")
            .replace(/setCookieSync\(([^,]+),\s*nodeParsedURL,/g, "setCookieSync($1, this.url,");
        }
      },
    },
    {
      name: "patch-default-stylesheet",
      // jsdom reads default-stylesheet.css from disk at runtime using __dirname,
      // which points to priv/dist after bundling — wrong path. Inline the CSS at build time.
      transform(code, id) {
        if (id.includes("living/css/helpers/computed-style")) {
          const cssPath = path.resolve(path.dirname(id), "../../../browser/default-stylesheet.css");
          const css = fs.readFileSync(cssPath, "utf-8");
          return code.replace(
            /fs\.readFileSync\(\s*path\.resolve\(__dirname,\s*"\.\.\/\.\.\/\.\.\/browser\/default-stylesheet\.css"\)\s*,\s*\{\s*encoding:\s*"utf-8"\s*\}\s*\)/,
            JSON.stringify(css)
          );
        }
      },
    },
    {
      name: "patch-css-tree-create-require",
      // css-tree ESM sources call createRequire(import.meta.url) to load JSON
      // data files. Rollup replaces import.meta.url with {}.url (undefined) in
      // CJS output, causing createRequire(undefined) to throw at startup.
      // Inline each JSON at build time instead.
      transform(code, id) {
        if (id.includes("css-tree/lib/data-patch.js")) {
          const json = fs.readFileSync(path.resolve(path.dirname(id), "../data/patch.json"), "utf-8");
          return code
            .replace(/import\s*\{[^}]*createRequire[^}]*\}\s*from\s*['"]module['"];?\n?/, "")
            .replace(/const require = createRequire\(import\.meta\.url\);\n?/, "")
            .replace(/const patch = require\(['"]\.\.\/data\/patch\.json['"]\);/, () => `const patch = ${json};`);
        }
        if (id.includes("css-tree/lib/data.js")) {
          const atrules = fs.readFileSync(path.resolve(path.dirname(id), "../../mdn-data/css/at-rules.json"), "utf-8");
          const properties = fs.readFileSync(path.resolve(path.dirname(id), "../../mdn-data/css/properties.json"), "utf-8");
          const syntaxes = fs.readFileSync(path.resolve(path.dirname(id), "../../mdn-data/css/syntaxes.json"), "utf-8");
          return code
            .replace(/import\s*\{[^}]*createRequire[^}]*\}\s*from\s*['"]module['"];?\n?/, "")
            .replace(/const require = createRequire\(import\.meta\.url\);\n?/, "")
            .replace(/const mdnAtrules = require\(['"]mdn-data\/css\/at-rules\.json['"]\);/, () => `const mdnAtrules = ${atrules};`)
            .replace(/const mdnProperties = require\(['"]mdn-data\/css\/properties\.json['"]\);/, () => `const mdnProperties = ${properties};`)
            .replace(/const mdnSyntaxes = require\(['"]mdn-data\/css\/syntaxes\.json['"]\);/, () => `const mdnSyntaxes = ${syntaxes};`);
        }
        if (id.includes("css-tree/lib/version.js")) {
          const pkg = JSON.parse(fs.readFileSync(path.resolve(path.dirname(id), "../package.json"), "utf-8"));
          return code
            .replace(/import\s*\{[^}]*createRequire[^}]*\}\s*from\s*['"]module['"];?\n?/, "")
            .replace(/const require = createRequire\(import\.meta\.url\);\n?/, "")
            .replace(/require\(['"]\.\.\/package\.json['"]\)/, () => `{ version: ${JSON.stringify(pkg.version)} }`);
        }
      },
    },
    {
      name: "patch-xhr-sync-worker",
      // jsdom uses require.resolve("./xhr-sync-worker.js") at load time for
      // synchronous XHR. The worker requires jsdom internals so it can't be
      // bundled separately. Since this project never uses sync XHR, replace
      // the resolve call with null.
      transform(code, id) {
        if (id.includes("XMLHttpRequest-impl")) {
          return code.replace(
            /require\.resolve\(["']\.\/xhr-sync-worker\.js["']\)/,
            "null"
          );
        }
      },
    },
  ],
});
