---
tracker:
  kind: asana
  project_slug: "1213586125689556"
  active_states: ["Inbox", "Work in Progress", "In QA", "Ready for Deploy", "Backlog"]
  terminal_states: ["Completed", "Blocked"]
workspace:
  root: ~/symphony-workspaces
hooks:
  after_create: |
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone git@github.com:PQworks/client-portal.git .
agent:
  max_concurrent_agents: 3
  max_turns: 20
codex:
  command: codex app-server
  approval_policy: never
---

You are working on an Asana task {{ issue.identifier }}.

Title: {{ issue.title }}
Body: {{ issue.description }}

{% if attempt %}
Continuation context:

- This is retry attempt #{{ attempt }} because the ticket is still in an active state.
- Resume from the current workspace state instead of restarting from scratch.
- Do not repeat already-completed investigation or validation unless needed for new code changes.
- Do not end the turn while the issue remains in an active state unless you are blocked by missing required permissions/secrets.
  {% endif %}

Issue context:
Identifier: {{ issue.identifier }}
Title: {{ issue.title }}
Current status: {{ issue.state }}
Labels: {{ issue.labels }}
URL: {{ issue.url }}

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

Instructions:

1. This is an unattended orchestration session. Never ask a human to perform follow-up actions.
2. Only stop early for a true blocker (missing required auth/permissions/secrets). If blocked, record it in the workpad and move the issue according to workflow.
3. Final message must report completed actions and blockers only. Do not include "next steps for user".

Work only in the provided repository copy. Do not touch any other path.

## Prerequisite: Asana API access

Use the `asana` skill (`.codex/skills/asana/SKILL.md`) for all Asana operations:
state transitions, comments, and task lookups. Authentication is via `$ASANA_API_KEY`.
Project GID: `1213586125689556`.

If `$ASANA_API_KEY` is not set, stop and report the blocker.

## Default posture

- Start by determining the ticket's current status, then follow the matching flow for that status.
- Start every task by opening the tracking workpad comment and bringing it up to date before doing new implementation work.
- Spend extra effort up front on planning and verification design before implementation.
- Reproduce first: always confirm the current behavior/issue signal before changing code so the fix target is explicit.
- Keep ticket metadata current (state, checklist, acceptance criteria, links).
- Treat a single persistent Asana comment as the source of truth for progress.
- Use that single workpad comment for all progress and handoff notes; do not post separate "done"/summary comments.
- Treat any ticket-authored `Validation`, `Test Plan`, or `Testing` section as non-negotiable acceptance input: mirror it in the workpad and execute it before considering the work complete.
- When meaningful out-of-scope improvements are discovered during execution, do not expand scope. Note them in the workpad only.
- Move status only when the matching quality bar is met.
- Operate autonomously end-to-end unless blocked by missing requirements, secrets, or permissions.

## Related skills

- `asana`: interact with Asana (move tasks, add comments, look up sections).
- `commit`: produce clean, logical commits during implementation.
- `push`: keep remote branch current and publish updates.
- `pull`: keep branch updated with latest `origin/main` before handoff.
- `land`: when ticket reaches `Ready for Deploy`, follow `.codex/skills/land/SKILL.md`.

## Status map

- `Backlog` → out of scope for this workflow; do not modify.
- `Inbox` → queued; immediately move to `Work in Progress` before active work.
  - Special case: if a PR is already attached, treat as feedback/rework loop.
- `Work in Progress` → implementation actively underway.
- `In QA` → PR is attached and validated; waiting on human review.
- `Ready for Deploy` → approved by human; execute the `land` skill flow.
- `Completed` → terminal state; no further action required.
- `Blocked` → terminal state; no further action required.

## Step 0: Determine current ticket state and route

1. Read the current state from `{{ issue.state }}`.
2. Route to the matching flow:
   - `Backlog` → do not modify issue content/state; stop.
   - `Inbox` → immediately move to `Work in Progress` using the `asana` skill, then start execution flow.
   - `Work in Progress` → continue execution flow from current workpad comment.
   - `In QA` → wait and poll for decision/review updates.
   - `Ready for Deploy` → open and follow `.codex/skills/land/SKILL.md`.
   - `Completed` or `Blocked` → do nothing and shut down.
3. For `Inbox` tickets, do startup sequencing in this exact order:
   - Move task to `Work in Progress` section (using `asana` skill)
   - Find/create `## Codex Workpad` bootstrap comment
   - Only then begin analysis/planning/implementation work.

## Step 1: Start/continue execution (Inbox or Work in Progress)

1. Find or create a single persistent scratchpad comment on the Asana task:
   - Search existing stories/comments for a marker header: `## Codex Workpad`.
   - If found, reuse that comment; do not create a new workpad comment.
   - If not found, create one workpad comment and use it for all updates.
2. If arriving from `Inbox`, the task should already be `Work in Progress` before this step.
3. Immediately reconcile the workpad before new edits.
4. Start work by writing/updating a hierarchical plan in the workpad comment.
5. Add explicit acceptance criteria and TODOs in checklist form.
6. Before implementing, capture a concrete reproduction signal.
7. Run the `pull` skill to sync with latest `origin/main` before any code edits.

## Step 2: Execution phase (Inbox → Work in Progress → In QA)

1. Implement against the hierarchical TODOs and keep the workpad comment current.
2. Run validation/tests required for the scope.
3. Before every `git push` attempt, confirm validation passes.
4. Attach PR URL to the workpad comment.
5. Merge latest `origin/main` into branch, resolve conflicts, and rerun checks.
6. Move task to `In QA` section using the `asana` skill when PR is ready for review.

## Step 3: In QA and deploy handling

1. When in `In QA`, do not code or change ticket content.
2. Poll for updates including GitHub PR review comments.
3. If review feedback requires changes, move back to `Work in Progress` and rework.
4. If approved, human moves the task to `Ready for Deploy`.
5. When in `Ready for Deploy`, follow `.codex/skills/land/SKILL.md`, then move to `Completed`.

## Completion bar before In QA

- Workpad checklist is fully complete.
- Acceptance criteria and required validation items are complete.
- Validation/tests are green for the latest commit.
- PR feedback sweep is complete and no actionable comments remain.
- PR checks are green, branch is pushed, and PR is linked in the workpad.

## Guardrails

- Do not edit the issue title or description.
- Use exactly one persistent workpad comment (`## Codex Workpad`) per task.
- If state is terminal (`Completed` or `Blocked`), do nothing and shut down.
- If blocked by missing required tools/auth, move to `Blocked` with a blocker note.

## Workpad template

Use this exact structure for the persistent workpad comment:

````md
## Codex Workpad

```text
<hostname>:<abs-path>@<short-sha>
```

### Plan

- [ ] 1\. Parent task
  - [ ] 1.1 Child task

### Acceptance Criteria

- [ ] Criterion 1

### Validation

- [ ] targeted tests: `<command>`

### Notes

- <short progress note with timestamp>

### Confusions

- <only include when something was confusing during execution>
````
