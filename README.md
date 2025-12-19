# 🖌️ nrx-graffiti

A simple, wall-only graffiti system for FiveM using image URLs.

Built to avoid common decal issues like tilting, jitter, and accidental floor placement, while keeping placement fast and predictable.

---

## Features

- Wall-only graffiti placement
- Always vertical and flush to the surface
- Image URLs rendered via DUI
- Live preview before placing
- Adjustable size and rotation
- Mouse wheel roll adjustment
- No camera rotation hacks

---

## Dependencies

- qb-core
- ox_lib
- ox_inventory

---

## Installation

1. Drop the resource into your `resources` folder
2. Add to your `server.cfg`:

3. Restart the server

---

## Item

You’ll need a spray paint item in **ox_inventory**:

```lua
['spray_paint'] = {
 label = 'Spray Paint',
 weight = 200,
 stack = true,
 close = true
}
