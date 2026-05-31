# space_man 🚀

An original space-flight game for Roblox — build rockets, suit up, launch to orbit,
deploy satellites, splash down for rescue, and (soon) explore the Moon and Mars.

Built with [Rojo](https://rojo.space): the filesystem is the source of truth and code
syncs live into Roblox Studio.

> Inspired by the spaceflight genre and real NASA operations. All code, models, and
> assets in this repo are original to this project.

## What works now

- A compact **launch complex** generated from code: Mission Control, Vehicle Assembly
  Building, crawlerway, launch pad + service tower.
- An original **two-stage orbital rocket**: first stage with an engine cluster, base
  fins and grid fins, an interstage, a second stage, and a tapered payload fairing.
- **Suit-up gate** — hold the Suit Station prompt to put on a space suit (helmet +
  life-support pack appear on your avatar).
- **Boarding gate** — the rocket only lets you board once you're suited up.
- **Full launch → orbit sequence**: 5-second countdown, engine ignition (flame, smoke,
  light) + camera shake, an accelerating climb, stage-separation call-out, then a
  fade-to-black transition into orbit above a planet, where a **satellite deploys**.
- **Return to Earth → splashdown**: the orbit capsule re-enters under a **parachute**,
  descends, and **splashes down into a real ocean** (terrain water), floating instead
  of sinking.
- **Rescue**: a small "Activate Rescue Boats" button appears; press it and a rescue
  boat drives out, picks you up, and brings you back to the Cape.
- **Destinations**: a flight-plan console at the Cape switches the mission between
  **Earth Orbit**, the **Moon**, and **Mars**.
- **Rover payload**: the rover rides in the rocket's (semi-transparent) fairing, then
  **deploys on the Moon/Mars surface** — walk up and **drive it** in low gravity around
  a small surface base. Head to the ascent stage to splash down home.
- On-screen toast notifications, screen fades, and a small action button (client HUD).

## Roadmap

1. ✅ Launch complex + suit-up gate + boarding gate
2. Rocket assembly + **30s crawler rollout** from the VAB to the pad
3. ✅ Launch & ascent → **orbit** with satellite deployment + return
4. **Mission Control** satellite-monitoring screen
5. ✅ Re-entry + **splashdown**: float under parachute, small "Activate Rescue Boats" pickup
6. ✅ New worlds: **Moon & Mars** (low gravity), a drivable rover payload, surface base

> Note: while a player is in orbit the whole place switches to a starry "space"
> lighting (it's global for now). Multiplayer worlds will move to separate Roblox
> places in a later milestone.

## Project layout

```
src/
├── shared/
│   ├── Config.luau     # tunables: per-world gravity, timings, suit settings
│   └── Remotes.luau    # RemoteEvent accessor (server creates, client waits)
├── server/
│   ├── init.server.luau
│   └── systems/
│       ├── WorldBuilder.luau    # builds the complex, rocket, orbit, ocean, surface + rover
│       ├── SuitSystem.luau      # suit-up prompt + avatar suit visuals
│       ├── RocketBoarding.luau  # boarding gated on having a suit
│       └── LaunchSystem.luau    # countdown → ascent → orbit → satellite → return
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
