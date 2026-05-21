---
description: Execute a prompt from the prompt-library by name (e.g. /prompt localPack)
---

# Prompt Workflow

Use this workflow to trigger any prompt from the prompt-library directory.

## Usage

```
/prompt <promptName>
```

Example:
```
/prompt localPack
```

## Steps

1. Identify the prompt name provided by the user as the argument to `/prompt`.

2. Locate the corresponding prompt file at:
   `/home/laksyalamat/projects/KP-Xmit-WorkSpace/prompt-library/<promptName>.md`

3. Read the prompt file using the read_file tool with the resolved absolute path.

4. Execute the instructions defined in the prompt file exactly as written, applying them to the current workspace and context.

5. If the prompt file does not exist, list all available prompts in the prompt-library directory and inform the user which ones are available.
