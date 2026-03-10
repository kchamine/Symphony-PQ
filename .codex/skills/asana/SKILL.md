---
name: asana
description: |
  Use curl with the Asana REST API v1 for task state transitions, comments,
  and lookups. Authentication is via the ASANA_API_KEY environment variable.
---

# Asana REST API

Use this skill to interact with Asana during Symphony sessions.
Authentication is via `$ASANA_API_KEY` (a Personal Access Token).

The project GID is available as `{{ issue.url | split: '/' | slice: 4 }}` or
from context — default project GID is in WORKFLOW.md `tracker.project_slug`.

---

## Get task details

```bash
curl -s \
  -H "Authorization: Bearer $ASANA_API_KEY" \
  "https://app.asana.com/api/1.0/tasks/{task_gid}?opt_fields=gid,name,notes,memberships.section.name,memberships.project.gid"
```

---

## List sections for the project

Use this to look up the GID of a target section by name.

```bash
curl -s \
  -H "Authorization: Bearer $ASANA_API_KEY" \
  "https://app.asana.com/api/1.0/projects/{project_gid}/sections?opt_fields=gid,name"
```

Response shape:
```json
{"data": [{"gid": "123", "name": "Inbox"}, {"gid": "456", "name": "Work in Progress"}, ...]}
```

---

## Move a task to a section (state transition)

This is the Asana equivalent of changing a Linear issue's state.

```bash
curl -s -X POST \
  -H "Authorization: Bearer $ASANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"data\": {\"task\": \"{task_gid}\"}}" \
  "https://app.asana.com/api/1.0/sections/{section_gid}/addTask"
```

**Workflow for state transitions:**
1. List sections to find the target section GID by name
2. Call `addTask` with the task GID and target section GID

Example — move task to "Work in Progress":
```bash
# Step 1: get section GIDs
SECTIONS=$(curl -s -H "Authorization: Bearer $ASANA_API_KEY" \
  "https://app.asana.com/api/1.0/projects/PROJECT_GID/sections?opt_fields=gid,name")

# Step 2: parse the GID for the target section (use jq or grep)
WIP_GID=$(echo "$SECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
print(next(s['gid'] for s in data if s['name'] == 'Work in Progress'))
")

# Step 3: move the task
curl -s -X POST \
  -H "Authorization: Bearer $ASANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"data\": {\"task\": \"TASK_GID\"}}" \
  "https://app.asana.com/api/1.0/sections/$WIP_GID/addTask"
```

---

## Add a comment to a task

```bash
curl -s -X POST \
  -H "Authorization: Bearer $ASANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"data\": {\"text\": \"Your comment text here\"}}" \
  "https://app.asana.com/api/1.0/tasks/{task_gid}/stories"
```

---

## Usage rules

- Always use `$ASANA_API_KEY` — never hardcode the token.
- For state transitions, always list sections first to get the GID; do not hardcode section GIDs.
- Use `python3 -c` or `jq` to parse JSON responses in shell scripts.
- Add a comment to the task before and after major state transitions.
- A 200 response with `{"data": {}}` means success for `addTask`.
