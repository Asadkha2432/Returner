# Returner

A welcome-back panel for World of Warcraft. When you log in after being away, Returner shows you what you missed: patches, events, hotfixes, and currently active in-game happenings. Auto-updated daily via a GitHub Action that scrapes the official Blizzard WoW news feed.

## Features

- Tracks your last login per WoW account
- Auto-popup when you return after a configurable number of days (default: 7)
- Scrollable list of relevant news since your last visit, color-coded by category
- Auto-updated content: a daily GitHub Action regenerates the bundled data file
- Slash commands to reopen the panel anytime, change threshold, mark as read

## Commands

- `/rt` or `/returner` : open the panel
- `/rt threshold 14` : set the auto-popup threshold (in days)
- `/rt on` / `/rt off` : enable/disable auto-popup
- `/rt reset` : clear read state (next open shows all items again)
- `/rt status` : print current settings

## Architecture

```
Blizzard WoW News RSS  →  GitHub Action (daily cron)
                              ↓
                       scripts/update_news.py
                              ↓
                          Data.lua (committed)
                              ↓
                      tag pushed if changed
                              ↓
                   release.yml + BigWigsMods/packager
                              ↓
                       CurseForge auto-publish
                              ↓
                       Players auto-update
```

## Manual data update (without GitHub)

If you want to regenerate `Data.lua` locally:

```bash
python3 scripts/update_news.py
```

Requires Python 3.9+ and the `feedparser` package (`pip install feedparser`).

## License

MIT.
