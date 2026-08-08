# Report Studio

A4 annual report builder. Single static page, no build step, no server.

## Deploy to Vercel

`index.html` lives at the repository root, so Vercel serves it with no
configuration. Two ways to ship:

**GitHub sync (recommended).** In the Vercel dashboard, *Add New → Project*
and import this repository. Leave every setting at its default — Framework
Preset **Other**, no build command, no output directory. Vercel finds the
root `index.html` and serves the repo as static files. Every push to the
default branch then deploys automatically.

**CLI.**

```bash
npx vercel          # first run links/creates the project
npx vercel --prod
```

No `package.json`, no framework preset, no `vercel.json` — Vercel serves it
as static files. The only requirement is that `fonts/` sits next to
`index.html` at the root, which it does.

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

## Live collaboration

A report can be edited by several people at once, in real time.

**Sharing.** Open a report and press **Share** in the top bar. The report is
copied into a shared room and a link (`…/#room=<id>`) is copied to your
clipboard. Anyone who opens that link edits the same report live. Reports you've
shared reconnect automatically when you reopen them.

**Editing.** The first time someone starts editing they're asked for a display
name. A row of coloured avatars in the top bar shows who's in the report.

**Page locking.** While someone is editing a page, that page is locked for
everyone else — it shows read-only with a *"🔒 Name is editing this page"*
banner. Different people can edit different pages at the same time; the lock
follows the blocks if pagination reflows them. This is what keeps edits
conflict-free: there is never more than one writer per page, so text never
collides mid-sentence.

**How it works.** The document body is mirrored into a
[Yjs](https://yjs.dev) CRDT — a `Y.Map` of doc-level fields, a `Y.Array` of
block order, and a `Y.Map` of blocks — synced over
[Liveblocks](https://liveblocks.io). Blocks are stored per-key so edits to
different blocks merge cleanly. Presence and page locks ride on Liveblocks
awareness. The libraries load from a CDN via an import map, so there is still no
build step; if the CDN is unreachable the app runs exactly as before, minus
collaboration.

**Configuration.** The Liveblocks *public* key is embedded in `index.html`
(`LB_KEY`). Public keys are meant to live in client code. Two things to know:

- It is committed to the repo and visible to anyone who loads the app. That is
  normal for a public key, but it means *anyone with the key and a room id can
  join that room*. For access control, move to a Liveblocks **secret** key with
  a server auth endpoint (this requires a small backend, so it is not wired up
  in this static build).
- Reports live in **two** places now: still in each browser's IndexedDB as a
  local cache, and — once shared — in the Liveblocks room. **Save file** remains
  the real backup.

Known limits of this version: locking is page-level (no two people typing in the
same paragraph — by design); very large embedded images sync through the CRDT and
can be heavy; document-wide design settings are last-writer-wins if two people
change them at the same instant.

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
