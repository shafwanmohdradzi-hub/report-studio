# Report Studio

A4 annual report builder. Single static page, no build step, no server.

## Deploy to Vercel

```bash
cd report-studio
npx vercel          # first run links/creates the project
npx vercel --prod
```

Or drag this folder onto the Vercel dashboard. No `package.json`, no
framework preset, no configuration required — Vercel serves it as static
files.

Any static host works the same way (Netlify, Cloudflare Pages, GitHub
Pages, S3, nginx). The only requirement is that `fonts/` is served
alongside `index.html`.

## Files

```
index.html     the whole application
fonts/         6 self-hosted families, woff2, latin + latin-ext
fonts/OFL-*    licences (SIL Open Font License)
```

## Where things are stored

Reports live in **IndexedDB in each visitor's browser**. Nothing is
uploaded; the server only ever sends `index.html` and the fonts.

| key                          | contents                            |
|------------------------------|-------------------------------------|
| `studio:index`               | library list, names, cover thumbs   |
| `studio:doc:{id}`            | one report: blocks, text, settings  |
| `studio:img:{docId}:{imgId}` | one image, as a data URL            |
| `studio:ui`                  | light/dark interface preference      |

Consequences worth knowing:

- Per browser and per device. Chrome on your laptop and Safari on your
  phone are separate libraries.
- Per origin. `*.vercel.app` and a custom domain are different origins and
  do not share reports. Preview deployments each start empty.
- Sharing a report means **Save file** → send the `.json` → **Open a file**.
  Exports are self-contained; images are inlined.

The app calls `navigator.storage.persist()` on first save to ask the
browser not to evict the library under disk pressure. Treat Save file as
the real backup regardless.

## Fonts

Self-hosted deliberately. Pagination is computed by measuring real text
against real font metrics, so a blocked or slow CDN would shift page
breaks between machines. `unicode-range` is preserved, so a browser only
downloads the subsets it actually renders (~150 KB for English text out of
1 MB on disk).

## Printing

Export PDF uses the browser's print engine. In the print dialog set
**Margins: None** and **Scale: 100%**, and turn off browser headers and
footers. Sheet count in the top bar matches the exported page count.
