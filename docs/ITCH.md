# Shipping Overstomp on itch.io

The store-page half of playtesting: two uploads (a Windows download and a
browser build), what each one can and cannot do online, and the exact commands.
Nothing here needs an itch account beyond the free one.

## What works where — read this before promising anyone multiplayer

| | Local multiplayer | Online (host) | Online (join) |
|---|---|---|---|
| **Windows download** | yes, 6 seats | **yes** (ENet, port 30567) | **yes** |
| **Browser build** | yes (one keyboard + pads) | no | no |

The online mode (IMPLEMENTATION §9a) is host-authoritative ENet over UDP. A
browser cannot listen on a socket or dial a raw UDP address, so the web build is
**local-play only** — it exists because a click-and-play link is the lowest
possible friction for "try this game", not because it replaces the download.
Getting browser players online needs WebRTC plus a signaling service someone has
to host; that is the documented follow-up, not a checkbox.

Two more honest caveats for the page text:

- **Hosting over the internet needs a reachable port.** Same-network play works
  as-is; across the internet the host must forward UDP 30567 (or use a
  tunnel like Tailscale/ZeroTier, which needs no forwarding). A relay service
  would remove this; none is wired yet.
- **Clients feel their own inputs one round trip late** (no prediction in v1).
  On a LAN this is imperceptible; across a continent it is not. Set
  expectations on the page rather than in the reviews.

## Building the uploads

```bash
powershell -ExecutionPolicy Bypass -File tools/build_itch.ps1
```

Runs every harness (including the two-process net harness) and refuses to build
on any failure, then produces:

- `build/itch/overstomp-windows.zip` — the self-contained exe.
- `build/itch/overstomp-web.zip` — the browser build, `index.html` at the zip
  root (itch requires that).

The web preset is **single-threaded on purpose** (`variant/thread_support=false`):
a threaded Godot web build needs cross-origin isolation (SharedArrayBuffer),
which on itch means an extra embed setting and a class of support questions.
Single-threaded runs everywhere with zero configuration and this game is light
enough not to care.

## Page setup (one time)

1. itch.io → Dashboard → **Create new project**. Kind: **HTML**.
2. Upload `overstomp-web.zip`, tick **"This file will be played in the
   browser"**. Viewport **1280 × 720**, fullscreen button on.
3. Upload `overstomp-windows.zip`, platform **Windows**.
4. Embed options: leave SharedArrayBuffer support **off** (single-threaded
   build; it is not needed).
5. Page text: paste the controls table from `docs/PLAYTEST.md`, the one-line
   pitch ("stomp heads — nothing else takes a life"), and the online caveats
   above.

## Updating with butler (recommended after the first upload)

[butler](https://itch.io/docs/butler/) is itch's CLI; it diffs uploads so a
104 MB build pushes in seconds after the first time.

```bash
butler login
```

```bash
butler push build/itch/overstomp-windows.zip YOUR_USER/overstomp:windows
```

```bash
butler push build/itch/overstomp-web.zip YOUR_USER/overstomp:web
```

Channel names (`windows`, `web`) are stable; butler creates them on first push
and the page maps them to files. Re-running `build_itch.ps1` + the two pushes is
the whole release process.

## Running an online session (Windows download)

1. Host: lobby → **HOST ONLINE** (left card). Status shows the port and how
   many have connected.
2. Friends: lobby → **JOIN** → type the host's address (`ip` or `ip:port`).
   They appear in the host's seat list as "online".
3. Host claims a local seat (SPACE / pad), sets the format, presses ability to
   start. Online matches currently skip hero/stage select: every seat gets a
   fallback trio on the host's current stage. Returning to the lobby ends the
   session on both ends.

## What online v1 does not do yet

So follow-ups land as decisions, not surprises: no client-side prediction; no
ability/terrain **effect visuals** on clients (the bodies they move are
replicated; the rope/ring/block drawings are not); no select screens online; no
relay or matchmaking (direct IP only); no browser online play. The path to each
is sketched in IMPLEMENTATION §9a, and rollback — the real answer for feel —
remains open because every input still flows through `InputFrame`.
