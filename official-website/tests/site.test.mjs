import assert from "node:assert/strict";
import { access, readFile, readdir } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

test("contains the complete EMBER landing page", async () => {
  const page = await readFile(new URL("app/page.tsx", root), "utf8");

  assert.match(page, /Sleep is a skill/);
  assert.match(page, /One plan\. Four signals\./);
  assert.match(page, /Private by design/i);
  assert.match(page, /The sleepy Blue Box character/);
});

test("contains production metadata and brand assets", async () => {
  const [layout, files] = await Promise.all([
    readFile(new URL("app/layout.tsx", root), "utf8"),
    readdir(new URL("public/assets/", root)),
  ]);

  assert.match(layout, /EMBER — Sleep is a skill/);
  assert.match(layout, /og\.png/);
  assert.ok(files.includes("ember-app-icon.png"));
  assert.ok(files.includes("sleepy-blue.png"));
  await access(new URL("public/og.png", root));
});

test("is configured for a native Vercel Next.js build", async () => {
  const [packageJson, vercelJson] = await Promise.all([
    readFile(new URL("package.json", root), "utf8"),
    readFile(new URL("vercel.json", root), "utf8"),
  ]);

  const pkg = JSON.parse(packageJson);
  const vercel = JSON.parse(vercelJson);

  assert.equal(pkg.scripts.build, "next build");
  assert.equal(pkg.scripts.dev, "next dev");
  assert.equal(vercel.framework, "nextjs");
  assert.equal(vercel.buildCommand, "pnpm run build");
  assert.doesNotMatch(packageJson, /vinext|wrangler|drizzle|cloudflare/i);
});
