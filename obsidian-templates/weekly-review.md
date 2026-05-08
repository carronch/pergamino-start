---
type: weekly-review
week: <% tp.date.now("YYYY-[W]ww") %>
date: <% tp.date.now("YYYY-MM-DD") %>
---
# Weekly Review — <% tp.date.now("YYYY-[W]ww") %>

## 1. Clear
- [ ] Obsidian inbox — all items processed
- [ ] Email inbox — processed to zero or near-zero
- [ ] Messages (Telegram, WhatsApp) — anything actionable captured
- [ ] Browser tabs — close or capture
- [ ] Physical notes — transfer to Obsidian

## 2. Review
- [ ] Calendar: past 7 days — anything missed?
- [ ] Calendar: next 14 days — anything to prepare?
- [ ] Active projects — each has a next action?
- [ ] Waiting For — follow up needed?
- [ ] Someday/Maybe — anything to activate?

## 3. Reflect
### What went well this week?


### What didn't work?


### What to focus next week?


## 4. Pomodoro Stats

> [!example]- This week's Pomodoros
> ```dataview
> TABLE pomodoros_completed AS "🍅", energy
> FROM "daily"
> WHERE date >= date(<% tp.date.now("YYYY-MM-DD", -7) %>)
> SORT date ASC
> ```
