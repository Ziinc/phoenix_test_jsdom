// JSDom setup file — runs in Node scope with `window` as a parameter (see priv/server.js).
// Node globals (TextEncoder, TextDecoder, require, Buffer) are directly accessible here.
// Installs the globals Monaco editor needs to mount without errors.

// Re-root DOM constructors used below (bare names resolve in Node scope, not window)
const { HTMLCanvasElement, Element, performance } = window;

// Monaco's text rendering uses TextDecoder (UTF-16LE); jsdom doesn't expose it on window.
window.TextEncoder = TextEncoder;
window.TextDecoder = TextDecoder;

// Monaco calls matchMedia for theme detection
window.matchMedia = () => ({
  matches: false,
  media: "",
  onchange: null,
  addListener() {},
  removeListener() {},
  addEventListener() {},
  removeEventListener() {},
  dispatchEvent() { return false; },
});

// Monaco uses ResizeObserver for editor container size changes
window.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
};

window.IntersectionObserver = class IntersectionObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
  takeRecords() { return []; }
};

// Monaco measures character widths via a 2D canvas context
const stubCtx = {
  measureText: (s) => ({
    width: (s ? s.length : 0) * 7,
    actualBoundingBoxAscent: 10,
    actualBoundingBoxDescent: 2,
    fontBoundingBoxAscent: 10,
    fontBoundingBoxDescent: 2,
  }),
  fillText() {}, strokeText() {}, fillRect() {}, clearRect() {}, strokeRect() {},
  beginPath() {}, closePath() {}, moveTo() {}, lineTo() {}, stroke() {}, fill() {},
  save() {}, restore() {}, setTransform() {}, translate() {}, scale() {}, rotate() {},
  arc() {}, clip() {}, drawImage() {},
  createLinearGradient: () => ({ addColorStop() {} }),
  getImageData: () => ({ data: new Uint8ClampedArray(4) }),
  putImageData() {},
  createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4), width: w, height: h }),
  getContextAttributes: () => ({}),
  canvas: { width: 300, height: 150 },
};
HTMLCanvasElement.prototype.getContext = function () { return stubCtx; };
HTMLCanvasElement.prototype.toDataURL = function () { return "data:image/png;base64,"; };

// Monaco calls scrollIntoView on caret elements
Element.prototype.scrollIntoView = function () {};

// Monaco uses performance.mark/measure for profiling
const _perfEntry = { duration: 0, startTime: 0, entryType: "measure", name: "" };
if (!performance.mark) performance.mark = () => _perfEntry;
if (!performance.measure) performance.measure = () => _perfEntry;
if (!performance.clearMarks) performance.clearMarks = () => {};
if (!performance.clearMeasures) performance.clearMeasures = () => {};
if (!performance.getEntriesByName) performance.getEntriesByName = () => [];
if (!performance.getEntriesByType) performance.getEntriesByType = () => [];

// Stub Worker — Monaco spawns language service workers, not needed for editing
window.Worker = class StubWorker {
  postMessage() {}
  terminate() {}
  addEventListener() {}
  removeEventListener() {}
  dispatchEvent() { return false; }
};

// Tell Monaco to use stub workers instead of real web workers
window.MonacoEnvironment = {
  getWorker: () => new Worker(),
};

// // Monaco's cursor blink and layout use requestAnimationFrame in a continuous
// // loop. In JSDom, each rAF becomes a setTimeout(fn, 0), so the loop never
// // drains the Node.js event loop. Allow a burst for initial layout then stop.
// (function () {
//   let budget = 150;
//   const native = window.requestAnimationFrame;
//   window.requestAnimationFrame = function (cb) {
//     if (budget-- > 0) return native ? native.call(window, cb) : setTimeout(cb, 16);
//     return setTimeout(cb, 30000);
//   };
//   window.cancelAnimationFrame = function (id) { clearTimeout(id); };
// })();
