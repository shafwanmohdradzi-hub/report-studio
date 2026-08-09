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

A report can be edited by several people at once, in real time. It builds on the
**share** feature below: you collaborate on a report once everyone has it loaded
locally, and a **share link** makes that one step.

**Link flow (recommended).** The owner opens a report → **Publish** → gets a
link. Anyone who opens the link automatically pulls a copy into their library and
drops straight into a live session — no code or password to type. The link
carries the report's code + secret in its URL fragment (which never reaches a
server), so the link itself is the capability.

**Always live, online only.** A shared report is always a live session — there's
no "leave". Opening one (owner or pulled) automatically joins its room; the top
bar shows a **● Live** pill (or **Reconnect** if the link dropped). First-timers
are asked for a display name, and each person gets a distinct colour for their
avatar and authorship dots. Because everyone must stay on one version, a shared
report **can't be opened or edited offline** — trying to open one offline shows a
warning, and going offline mid-session makes it view-only (with a banner) until
you reconnect. All edits live in the cloud room, so everyone sees the same report
and who changed what.

**Get a shared report** still pulls one manually by code + password.

The live room is keyed to the **share code**, so everyone with the same report
meets in the same room. Collaboration is explicit or link-triggered — reports
never auto-join a room just from being opened, which prevents a stale room from
overwriting a freshly opened report. The **first person** into an empty room seeds
it from their local copy; anyone who joins a room that already has content adopts
the live shared state (decided by room content, not presence, so a slow-to-arrive
peer can't cause a wrong seed). A small **coloured dot** in each block's margin
marks who last edited it during a session, to make changes easy to review.

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

**Configuration.** Live collaboration is enabled (`SHARING_ENABLED = true` in
`index.html`) and uses [Liveblocks](https://liveblocks.io). The Liveblocks
*public* key embedded in `index.html` (`LB_KEY`) is a **production** key
(`pk_prod_…`). To use a different Liveblocks project, replace `LB_KEY` with that
project's public key from the dashboard's **API keys** tab. Two things to know:

- The public key is committed to the repo and visible to anyone who loads the
  app. That is normal for a public key, but it means *anyone with the key and a
  room id (a share code) can join that room*. Access control needs a Liveblocks
  **secret** key with a server auth endpoint (a small backend, not wired up in
  this static build), so treat share codes like the password they're paired with.
- Reports live in **two** places now: still in each browser's IndexedDB as a
  local cache, and — once shared — in the Liveblocks room. **Save file** remains
  the real backup.

Known limits of this version: locking is page-level (no two people typing in the
same paragraph — by design); embedded images sync through the CRDT as base64, so
the Liveblocks client is created with `largeMessageStrategy: 'split'` to chunk
oversized messages (otherwise Liveblocks drops them — *"Message is too large for
websockets, not sending"*), and very large images are still heavy to sync;
document-wide design settings are last-writer-wins if two people change them at
the same instant.

## Full cloud sync (all your reports, every device)

Separate from live collaboration. This backs up your **entire library** to your
own account and syncs it to any device you sign in on. It uses
[Supabase](https://supabase.com) (Postgres + email magic-link auth) and still
needs no build step — the SDK loads from a CDN.

**Model.** IndexedDB stays the working copy; the cloud is a mirror. On sign-in
the two reconcile both ways by each report's `updated` timestamp (last write
wins). A Realtime subscription pulls changes made on your other devices while a
tab is open. Signed out or offline, the app is exactly the local-first app it
was — pending changes queue and flush on reconnect. The report currently open in
the editor is never overwritten by a remote pull.

### One-time setup

1. Create a free project at [supabase.com](https://supabase.com).
2. In the Supabase dashboard open **SQL Editor** and run:

   ```sql
   -- one row per report, keyed to the signed-in user
   create table if not exists public.reports (
     user_id uuid    not null default auth.uid() references auth.users on delete cascade,
     id      text    not null,
     name    text,
     body    jsonb   not null,
     thumb   text,
     updated bigint  not null default 0,
     deleted boolean not null default false,
     synced_at timestamptz not null default now(),
     primary key (user_id, id)
   );

   -- images stored separately, mirroring the app's local layout
   create table if not exists public.report_images (
     user_id uuid not null default auth.uid() references auth.users on delete cascade,
     doc_id  text not null,
     img_id  text not null,
     data    text not null,
     primary key (user_id, doc_id, img_id)
   );

   -- Row-Level Security: each account sees only its own rows
   alter table public.reports        enable row level security;
   alter table public.report_images  enable row level security;

   create policy "own reports" on public.reports
     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
   create policy "own images" on public.report_images
     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

   -- let the app hear changes made on your other devices
   alter publication supabase_realtime add table public.reports;
   ```

   (If the last line errors that the table is already a member, ignore it.)

3. **Project Settings → API**: copy the **Project URL** and the **anon public**
   key into the `CLOUD` config near the top of the cloud-sync section in
   `index.html`. That flips `CLOUD.enabled` on automatically.
4. **Authentication → URL Configuration**: set the **Site URL** and add to
   **Redirect URLs** every origin you run the app from — e.g.
   `https://your-app.vercel.app`, plus `http://localhost:8000` (or whatever you
   use locally). Magic-link sign-in redirects back to these.

Both keys are safe in committed client code: the anon key only grants what
Row-Level Security allows, which is each user's own rows and nothing else.

### How it behaves

- Press **Sign in to sync** (top-right of the library), enter your email, click
  the link. Your library uploads, and the button turns green (**Synced**).
- Sign in with the same email on another device → your reports appear there, and
  edits flow both ways while tabs are open.
- Deletes propagate (a soft-delete tombstone, so a deleted report doesn't
  reappear from another device). **Save file** still works as an offline backup.

Known limits of this version: conflict handling is last-writer-wins per report
(fine for a mostly single-editor library — for real-time co-editing of one
report, use live collaboration above); images sync as base64 rows, so very large
embedded images are heavy; replacing an image can leave the old one orphaned in
the cloud until that report is next deleted.

## Share a report with a password

Separate from personal sync (which is private to you) and from live collab. This
lets you **publish one report behind a password**: anyone you give the code *and*
the password to can pull a copy into their own library — no account needed on
their side — and re-pull your latest version later.

**How it works.** You (signed in) open a report → **Publish** (button in the
editor top bar, or the link icon on a library card) → set a password → you get an
8-character code like `ABCD-2345`. You send the code and password to whoever you
want. They open the library → **Get a shared report** → enter the code +
password → a copy lands in their library. Re-entering the same code + password
later pulls your newest version in place instead of making a duplicate. **Stop
sharing** removes it from the cloud (copies people already pulled stay on their
devices — sharing can't reach back and delete them).

**Security model.** The password is checked *in the database*, never in the
browser: reads go through a `SECURITY DEFINER` function that compares a bcrypt
hash (`pgcrypto`), and the `shared_reports` table is not directly readable by
anyone but its owner. So the anon key alone can't list or read shared reports —
you need a valid code + password. Caveats worth knowing: there is **no
server-side rate limiting**, so a weak password is brute-forceable — use a strong
one; and once someone has pulled a copy, it's theirs (unpublishing doesn't erase
it). Passwords are never stored in plaintext, in the cloud or locally.

**Setup.** In the Supabase **SQL Editor**, run this once (in addition to the sync
SQL above):

```sql
-- Supabase keeps pgcrypto (crypt/gen_salt) in the `extensions` schema, so every
-- function below sets `search_path = public, extensions` to find it.
create extension if not exists pgcrypto with schema extensions;

-- one published, password-locked report per code
create table if not exists public.shared_reports (
  code       text   primary key,
  owner_id   uuid   not null default auth.uid() references auth.users on delete cascade,
  name       text,
  body       jsonb  not null,
  images     jsonb  not null default '{}'::jsonb,
  pass_hash  text   not null,
  updated    bigint not null default 0,
  created_at timestamptz not null default now()
);

-- owners manage their own shares; NOBODY gets direct SELECT (reads go via the RPC)
alter table public.shared_reports enable row level security;
create policy "owner manages shares" on public.shared_reports
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- publish/update a share (owner only). Hashes the password; keeps the old hash
-- when p_password is blank. Returns the code on success, null if the code is
-- taken by someone else.
create or replace function public.publish_shared_report(
  p_code text, p_name text, p_body jsonb, p_images jsonb, p_password text, p_updated bigint)
  returns text language plpgsql security definer set search_path = public, extensions as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'auth required'; end if;
  insert into public.shared_reports as s (code, owner_id, name, body, images, pass_hash, updated)
    values (p_code, auth.uid(), p_name, p_body, p_images, crypt(p_password, gen_salt('bf')), p_updated)
  on conflict (code) do update
     set name = excluded.name, body = excluded.body, images = excluded.images, updated = excluded.updated,
         pass_hash = case when p_password <> '' then excluded.pass_hash else s.pass_hash end
     where s.owner_id = auth.uid()
  returning s.code into v_code;
  return v_code;
end; $$;

-- fetch a shared report by code + password (anyone). Returns nothing on a miss.
create or replace function public.get_shared_report(p_code text, p_password text)
  returns table(code text, name text, body jsonb, images jsonb, updated bigint)
  language plpgsql security definer set search_path = public, extensions as $$
begin
  return query
    select s.code, s.name, s.body, s.images, s.updated
      from public.shared_reports s
     where s.code = p_code and s.pass_hash = crypt(p_password, s.pass_hash);
end; $$;

-- current published version stamp for a code (no password): lets a recipient's
-- library show "update available" without pulling. Returns null if unpublished.
create or replace function public.shared_report_version(p_code text)
  returns bigint language sql security definer set search_path = public, extensions as $$
  select updated from public.shared_reports where code = p_code;
$$;

revoke all on function public.get_shared_report(text, text) from public;
revoke all on function public.publish_shared_report(text, text, jsonb, jsonb, text, bigint) from public;
grant execute on function public.get_shared_report(text, text) to anon, authenticated;
grant execute on function public.publish_shared_report(text, text, jsonb, jsonb, text, bigint) to authenticated;
grant execute on function public.shared_report_version(text) to anon, authenticated;
```

A pulled report shows a **Shared** badge in the library and a live status — *Up to
date*, *Update available* (click to pull the latest), or *No longer shared* if the
owner unpublished it. Reports you published show a **Published** badge.

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
