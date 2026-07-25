# EMBER Official Website

The official marketing website for EMBER, a personal rest coach for iPhone.
Built with Next.js and configured for native deployment on Vercel.

## Local development

Requirements:

- Node.js 22
- pnpm

```bash
pnpm install
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).

## Production checks

```bash
pnpm test
pnpm lint
pnpm build
```

## Deploy on Vercel

Import the `HackTheRest-Ember` Git repository and use:

- Root Directory: `official-website`
- Framework Preset: `Next.js`
- Install Command: `pnpm install --frozen-lockfile`
- Build Command: `pnpm run build`
- Output Directory: leave at the Next.js default

The committed `vercel.json` contains the framework, install, and build settings,
so only the Root Directory needs to be selected in the Vercel dashboard.
