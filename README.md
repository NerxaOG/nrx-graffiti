nrx-graffiti

Simple, wall-only graffiti system for FiveM using image URLs.

Designed to avoid the usual decal issues (tilting, jitter, floor placement bugs) and keep placement predictable.

Features

Wall-only graffiti placement

Always vertical and flush to the surface

Image URLs via DUI

Live preview before placing

Adjustable size and rotation

Mouse wheel roll adjustment

No camera rotation hacks

Dependencies

qb-core

ox_lib

ox_inventory

Installation

Drop the resource into your resources folder

Add to server.cfg:

ensure nrx-graffiti


Restart the server

Item

You’ll need a spray paint item in ox_inventory:

['spray_paint'] = {
    label = 'Spray Paint',
    weight = 200,
    stack = true,
    close = true
}


Using the item opens the placement mode.

Controls
Action	Key
Increase size	Arrow Up
Decrease size	Arrow Down
Rotate (left/right)	Arrow Left / Right
Tilt (front/back)	Mouse Wheel
Place	Enter
Cancel	Backspace
Notes

Ground placement is intentionally blocked

Graffiti can be placed in air if misaligned and retried

Image domains can be restricted in config.lua

Marker-based rendering (no entities)

Author

Nerxa
