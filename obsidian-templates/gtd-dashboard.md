---
type: dashboard
---
# GTD Dashboard

## 📥 Inbox (unprocessed)

```dataview
LIST
FROM ""
WHERE type = "inbox" AND processed = false
SORT captured DESC
```

## 🔥 Active Projects

```dataview
TABLE status, client, next_review
FROM ""
WHERE type = "project" AND status = "active"
SORT next_review ASC
```

## ⏳ Waiting For

```dataview
TASK
FROM ""
WHERE type = "project" AND contains(text, "Waiting")
AND !completed
```

## 🌤️ Someday / Maybe

```dataview
LIST
FROM ""
WHERE type = "project" AND status = "someday"
SORT file.name ASC
```

## ✅ Recently Completed

```dataview
TABLE date
FROM ""
WHERE type = "solution"
SORT date DESC
LIMIT 10
```
