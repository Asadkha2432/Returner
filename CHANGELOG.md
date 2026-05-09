# Changelog

## 1.0.1 (2026-05-09)
- add /rt simulate <days> command for testing the auto-popup behavior, plus seenUntil in /rt status output

## 1.0.0
- Initial release
- Auto-popup on login after configurable absence (default 7 days)
- Scrollable panel showing news since last login, with category color coding
- Slash command `/rt` (or `/returner`) to open anytime
- Settings: threshold, enable/disable, reset read state, status
- Daily GitHub Action that regenerates `Data.lua` from Blizzard WoW news RSS
