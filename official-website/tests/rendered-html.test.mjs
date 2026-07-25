import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the finished EMBER landing page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Sleep is a skill/);
  assert.match(html, /One plan\. Four signals\./);
  assert.match(html, /Private by design/i);
  assert.match(html, /og\.png/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton/i);
});

test("keeps site metadata and brand assets production-ready", async () => {
  const [page, layout, packageJson, files] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readdir(new URL("../public/assets/", import.meta.url)),
  ]);

  assert.match(page, /The sleepy Blue Box character/);
  assert.match(layout, /EMBER — Sleep is a skill/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(files.includes("ember-app-icon.png"));
  assert.ok(files.includes("sleepy-blue.png"));
});
