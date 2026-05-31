# space_man 🚀

An original space-flight game for Roblox — build rockets, suit up, launch to orbit,
deploy satellites, splash down for rescue, and (soon) explore the Moon and Mars.

Built with [Rojo](https://rojo.space): the filesystem is the source of truth and code
syncs live into Roblox Studio.

> Inspired by the spaceflight genre and real NASA operations. All code, models, and
> assets in this repo are original to this project.

## What works now

- A compact **launch complex** generated from code: Mission Control, Vehicle Assembly
  Building, crawlerway, launch pad + service tower, and a rocket.
- **Suit-up gate** — walk to the Suit Station and hold the prompt to put on a space
  suit (a helmet + life-support pack appear on your avatar).
- **Boarding gate** — the rocket's "Enter Rocket" prompt only seats you once you're
  suited up; otherwise it tells you to suit up first.
- On-screen toast notifications (client HUD).

## Roadmap

1. ✅ Launch complex + suit-up gate + boarding gate
2. Rocket assembly + **30s crawler rollout** from the VAB to the pad
3. Launch & ascent → **orbit** (Earth) with satellite deployment
4. **Mission Control** satellite-monitoring screen
5. Reentry + **splashdown**: float under parachute, "Activate Rescue Boats" pickup
6. New worlds: **Moon & Mars** (low gravity), rovers, surface stations

## Project layout

```
src/
├── shared/
│   ├── Config.luau     # tunables: per-world gravity, timings, suit settings
│   └── Remotes.luau    # RemoteEvent accessor (server creates, client waits)
├── server/
│   ├── init.server.luau
│   └── systems/
│       ├── WorldBuilder.luau    # builds the launch complex from Parts
│       ├── SuitSystem.luau      # suit-up prompt + avatar suit visuals
│       └── RocketBoarding.luau  # boarding gated on having a suit
└── client/
    ├── init.client.luau
    └── ui/
        └── Notifier.luau        # on-screen toast HUD
```

Gravity is applied per-world from `Config.Gravity` at runtime (Earth ≈ 196.2; Moon and
Mars are lower).

## Getting started

1. **Install the toolchain** (Rojo is already installed globally; this pins it per-project):
   ```sh
   rokit install      # optional — `rojo` on PATH works as-is
   ```
2. **Start the Rojo server** from the project root:
   ```sh
   rojo serve
   ```
3. **In Roblox Studio**, install the [Rojo plugin](https://create.roblox.com/store/asset/13916111004/Rojo),
   open a new **baseplate**, click the Rojo plugin, and **Connect**. Press **Play** —
   the launch complex builds itself and you spawn next to the Suit Station.

## Building a place file (optional)

```sh
rojo build -o space_man.rbxlx
```

Open the generated `.rbxlx` directly in Studio. (Build artifacts are git-ignored.)
