# Localhost 3000

A native macOS app for managing your local dev projects. Start, stop, and open any project in your portfolio folder without touching the terminal.

---

## What it does

If you have a folder full of web projects (Next.js, Vite, etc.), Localhost 3000 scans that folder and gives you a dashboard. One click starts a project's dev server. Another click stops it. No terminal needed.

It also shows you:
- Which projects have uncommitted git changes
- What port each project is running on
- A network URL you can copy and open on your phone or another device on the same Wi-Fi

---

## Requirements

- macOS 14 (Sonoma) or later
- [Node.js](https://nodejs.org) installed (the app runs `npm run dev` under the hood)
- Your projects must have a `"dev"` script in their `package.json`

---

## How to build and run

You don't need Xcode. Everything runs from the terminal.

**1. Clone or download this folder**

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

Or just double-click it in Finder.

> First launch: macOS may warn "unidentified developer". Right-click the app → Open → Open anyway. This happens because the app is not signed with a paid Apple developer certificate. It's safe — you built it yourself.

---

## First time setup

When you open the app for the first time, it asks you to pick your **portfolio root folder** — the folder that contains all your projects.

Example: if your projects live at `~/my-portfolio/cadencia`, `~/my-portfolio/yummii`, etc., pick `~/my-portfolio`.

The app remembers this folder. You only need to set it once.

---

## The dashboard

Once your folder is selected, the app scans it and lists every project that has a `"dev"` script.

### Each row shows

| Column | What it means |
|--------|--------------|
| **Dot** | Green = running, grey = stopped |
| **Name** | Your project folder name |
| **Port** | The port it runs on (click to edit, scroll to nudge) |
| **Git status** | Clean = no uncommitted changes, orange = you have unsaved git work |
| **Icons** | Action buttons (see below) |
| **Start / Stop** | Starts or stops the dev server |

### Action icons (right side of each row)

| Icon | What it does |
|------|-------------|
| 🌐 Globe | Opens the project in your browser (`localhost:PORT`) |
| 📋 Clipboard | Copies the **network URL** (`192.168.x.x:PORT`) — open this on your phone or any device on the same Wi-Fi |
| `>_` Terminal | Opens the project folder in Terminal |
| `</>` Code | Opens the project in VS Code |
| 📁 Folder | Opens the project in Finder |

> The globe and clipboard icons only appear when the project is running.

---

## Ports

Each project gets a port assigned automatically (starting at 3001). The assignment is saved so it stays consistent across restarts.

**To change a port:**
- Click the port number to edit it
- Type a new number and press Enter
- Or scroll up/down with your mouse wheel to nudge it ±1

Changes take effect the next time you start the project.

---

## Footer buttons

| Button | What it does |
|--------|-------------|
| **Stop All** | Stops every running dev server at once |
| **Refresh** | Re-scans your folder and updates git status |
| **Change Folder** | Pick a different portfolio root |
| **Appearance icon** | Toggles light mode → dark mode → system default |

---

## Network URL (for other devices)

When a project is running, the clipboard icon copies a URL like `http://192.168.1.42:3001`. Paste that into a browser on your phone, tablet, or another laptop — as long as all devices are on the same Wi-Fi, it works.

> Note: some dev servers (particularly Next.js) need to be configured to listen on `0.0.0.0` instead of `localhost` for this to work. Add `--hostname 0.0.0.0` to your `dev` script if the device can't connect.

---

## Troubleshooting

**The app says "No apps found"**
Your projects need a `"dev"` script in `package.json`. Check that the folder you picked is the right root and that at least one project has `"scripts": { "dev": "..." }`.

**A project won't start**
Make sure `node` and `npm` are installed and accessible. The app looks for npm in `/opt/homebrew/bin` and `/usr/local/bin`. If you use `nvm`, your Node version should be set as default (`nvm alias default <version>`).

**Port already in use**
If another process is holding the port, the dev server will fail silently. Change the port to a free one, or find and kill the process: `lsof -ti :3001 | xargs kill`.

**Git status shows nothing / wrong info**
The project folder must be a git repository (`git init` has been run). The app runs `git status --porcelain` to count uncommitted changes.

**"Unidentified developer" warning on launch**
Right-click the app → Open → Open. macOS only asks once. After that it opens normally.

---

## Rebuilding after changes

Any time you pull updates or change the code, just run:

```bash
./build-app.sh
```

The new app lands in `dist/Localhost 3000.app`. Quit the old one and open the new one.
