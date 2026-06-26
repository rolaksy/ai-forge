

### Tip 1

`/compact reduces the current chat/session context by summarizing the earlier conversation into a shorter form.`

#### What it does:
- Compresses old conversation history into a summary.
- Frees up context window space so Claude Code can continue working in a long session.
- Keeps important context, such as goals, decisions, files changed, bugs found, and next steps.
- May lose small details, especially exact wording, minor decisions, or one-off observations if they were not important enough to preserve.
- It is different from /clear:
    - /compact = keep a summarized memory of the session.
    - /clear = reset/remove the current context more aggressively.

```
/compact Keep the current task, files changed, important decisions, failing tests, and next steps. Drop unrelated discussion.
```