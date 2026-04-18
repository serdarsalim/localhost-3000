# Localhost 3000

A native macOS app for managing your local dev projects. Start, stop, and monitor any project in your portfolio folder without touching the terminal.

---

## What it does

Point it at a folder full of web projects (Next.js, Vite, etc.) and you get a live dashboard. One click starts a dev server. Another stops it. Port conflicts, external processes, git status, network URLs — all visible at a glance.

---

## Requirements

- macOS 14 (Sonoma) or later
- [Node.js](https://nodejs.org) installed (the app runs `npm run dev` under the hood)
- Your projects must have a `"dev"` script in their `package.json`

---

## How to build and run

No Xcode needed.

**1. Clone or download this repo**

**2. Build the app**

```bash
cd localhost-3000
./build-app.sh
```

This compiles the Swift code and produces `dist/Localhost 3000.app`.

**3. Open the app**

```bash
open "dist/Localhost 3000.app"
```

Or double-click it in Finder.

> First launch: macOS may warn "unidentified developer". Right-click the app → Open → Open anyway. This happens because the app isn't signed with a paid Apple developer certificate. It's safe — you built it yourself.

---

## First time setup

On first launch the app asks you to pick your **portfolio root folder** — the folder that contains all your projects.

Example: if your projects live at `~/my-portfolio/cadencia`, `~/my-portfolio/yummii`, etc., pick `~/my-portfolio`.

The app remembers this. You only need to set it once.

---

## The dashboard

Once your folder is selected, the app scans it and lists every project that has a `"dev"` script.

### Each row shows

| Column | What it means |
|--------|--------------|
| **▶ / ■** | Play to start, stop to stop. Green = can start, red = running |
| **App** | Project folder name |
| **go/ link** | Browser shortcut alias (when go/ links are enabled in Settings) |
| **Port** | The port it runs on — grey when free, orange when taken by another process |
| **Git** | Clean = no uncommitted changes · number = uncommitted file count (hover for detail) |
| **Action icons** | Browser, copy URL, QR code, terminal, VS Code, Finder |

### Action icons

| Icon | What it does |
|------|-------------|
| 🌐 Globe | Opens the project in your browser |
| 📋 Clipboard | Copies the network URL (`192.168.x.x:PORT`) for other devices on the same Wi-Fi |
| ⬛ QR | Shows a QR code — scan with your phone to open the project instantly |
| `>_` Terminal | Opens the project folder in Terminal |
| `</>` Code | Opens in VS Code |
| 📁 Folder | Opens in Finder |

Globe, clipboard, and QR only appear when the project is running.

---

## Ports

Each project gets a port assigned automatically (starting at 3001). The assignment is saved and stays consistent across restarts.

**To change a port:**
- Click the port number to edit it (only works when the server is stopped)
- Type a new number and press Enter, or scroll the mouse wheel to nudge ±1
- The nudge skips ports already assigned to other projects

Port turns **orange** when another process on your machine is already using it. Change the port before starting.

---

## go/ links

go/ links let you type `http://go/alias` in any browser to open a project instantly — the same way internal tools work at tech companies.

### How to enable

1. Open **Settings** (gear icon in the footer)
2. Toggle **go/ links** on
3. Click **Setup System** — this runs a one-time setup that requires your password

The setup adds `127.0.0.1 go` to `/etc/hosts` and installs a port forwarder as a LaunchDaemon so `http://go/alias` works system-wide, in any browser, even after a restart.

### How to set an alias

When go/ links are enabled, each row shows a **go/ link** column. Click the alias text to edit it inline. Default alias is the project folder name lowercased.

Example: project `SerdarSalim-Blog` gets `go/serdarsalim-blog` by default. Change it to `go/blog` and `http://go/blog` opens that project.

---

## External processes

If a project's dev server is already running (started outside this app — in another terminal, for example), the app detects it automatically and shows it as running. You can stop it from the dashboard just like any other server.

---

## Settings

Open Settings from the gear icon in the footer.

| Setting | What it does |
|---------|-------------|
| **Launch at startup** | Starts Localhost 3000 automatically when you log in |
| **Menu bar quick launch** | Adds a menu bar icon with your full app list — start/stop any server without opening the main window |
| **go/ links** | Enables browser shortcuts and inline alias editing in the dashboard |

---

## Menu bar quick launch

When enabled in Settings, a network icon appears in your menu bar. Click it to see all your projects with colored indicators (green = can start, red = running) and start or stop any of them directly from the menu. The icon disappears when you turn this off.

---

## QR codes

When a server is running, click the QR icon in its row. Scan the code with your phone and it opens the project on your device over your local network — no copy-pasting needed.

---

## Network URL

The clipboard icon copies a URL like `http://192.168.1.42:3001`. Paste it into any browser on your phone, tablet, or another laptop on the same Wi-Fi.

> Some dev servers (particularly Next.js) need to be configured to listen on `0.0.0.0`. Add `--hostname 0.0.0.0` to your dev script if another device can't connect.

---

## Footer buttons

| Button | What it does |
|--------|-------------|
| **Stop All** | Stops every running dev server at once |
| **↺ Refresh** | Re-scans your folder and updates git status |
| **Folder** | Pick a different portfolio root |
| **?** | In-app help |
| **⚙ Settings** | Open Settings |
| **☀/🌙** | Toggle light / dark mode |

---

## Background mode

Closing the window doesn't quit the app. Running dev servers keep going. Reopen from the Dock or the menu bar icon (if quick launch is on).

---

## Troubleshooting

**"No apps found"**
Your projects need a `"dev"` script in `package.json`. Check that the folder you picked is the right root and that at least one project has `"scripts": { "dev": "..." }`.

**A project won't start**
Make sure `node` and `npm` are installed and accessible. The app looks for npm in `/opt/homebrew/bin` and `/usr/local/bin`. If you use `nvm`, set a default: `nvm alias default <version>`.

**Port is orange**
Another process owns that port. Change the port number in the app, or kill the process manually: `lsof -ti :PORT | xargs kill`.

**go/alias doesn't work in the browser**
Make sure you ran Setup System in Settings (one-time, requires password). Use `http://go/alias` with the `http://` prefix — browsers won't resolve bare `go/alias` without it.

**Git status shows nothing or wrong info**
The project folder must be a git repo (`git init` must have been run). The app runs `git status --porcelain` to count uncommitted changes.

**"Unidentified developer" warning on launch**
Right-click the app → Open → Open. macOS only asks once.

---

## Rebuilding after changes

```bash
./build-app.sh
```

The new app lands in `dist/Localhost 3000.app`. Quit the old one and open the new one.
