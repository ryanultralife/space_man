# space_man 🚀

A Roblox game built with [Rojo](https://rojo.space) — the filesystem is the source
of truth, and code syncs live into Roblox Studio.

## Project layout

```
space_man/
├── default.project.json   # Rojo project: maps these folders into the Roblox DataModel
├── rokit.toml             # Pinned toolchain (Rojo)
├── stylua.toml            # Luau formatter config
└── src/
    ├── client/            # → StarterPlayer.StarterPlayerScripts.Client (runs per player)
    ├── server/            # → ServerScriptService.Server (runs on the server)
    └── shared/            # → ReplicatedStorage.Shared (shared modules)
```

`Workspace.Gravity` is set to `50` (vs. the default `196.2`) for a floaty, in-space feel.

## Getting started

1. **Install the toolchain** (Rojo is already installed globally; this pins it per-project):
   ```sh
   rokit install      # if you use rokit; otherwise `rojo` on PATH works as-is
   ```
2. **Start the Rojo server** from the project root:
   ```sh
   rojo serve
   ```
3. **In Roblox Studio**, install the [Rojo plugin](https://create.roblox.com/store/asset/13916111004/Rojo),
   open a new baseplate, click the Rojo plugin, and **Connect**. Edits to files in `src/`
   now sync into Studio instantly.

## Building a place file (optional)

```sh
rojo build -o space_man.rbxlx
```

Open the generated `.rbxlx` directly in Studio. (Build artifacts are git-ignored.)
