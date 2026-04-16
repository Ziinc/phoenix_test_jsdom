import { resolve } from "path";
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
    target: "node18",
  },
  plugins: [
    {
      name: "patch-xhr-sync-worker",
      // jsdom uses require.resolve("./xhr-sync-worker.js") at load time for
      // synchronous XHR. The worker requires jsdom internals so it can't be
      // bundled separately. Since this project never uses sync XHR, replace
      // the resolve call with null.
      transform(code, id) {
        if (id.includes("XMLHttpRequest-impl")) {
          return code.replace(
            /require\.resolve\s*\?\s*require\.resolve\(["']\.\/xhr-sync-worker\.js["']\)\s*:\s*null/,
            "null"
          );
        }
      },
    },
  ],
});
