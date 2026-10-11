# Workspace instructions

## Source control

- Use the Jujutsu command-line tool for all source-control operations in this workspace.
- Do not invoke the Git command-line client here, including for read-only
  operations such as status, diff, log, or file listing.
- Prefer commands such as jj status, jj diff, jj log, and jj file list.
- If the Jujutsu command is unavailable, stop before running any source-control
  command and tell the user that Jujutsu needs to be installed or added to PATH.


## Mermaid diagrams

- Keep state diagram transition labels short and plain. Put explanations in Markdown prose or tables; avoid semicolons and long sentences in Mermaid labels because Mermaid may parse them as separate statements.
