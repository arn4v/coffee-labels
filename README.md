# Coffee labels

Make coffee bag labels that match the roaster's packaging, using its real logo and verified coffee details. Export an editable SVG and a monochrome PNG. Preview first, print after approval.

## Install

### Claude Code

```sh
git clone https://github.com/arn4v/coffee-labels.git
mkdir -p ~/.claude/skills
ln -s "$(pwd)/coffee-labels/skills/coffee-labels" ~/.claude/skills/coffee-labels
```

Use `/coffee-labels`.

### Codex

Ask Codex:

```text
$skill-installer install https://github.com/arn4v/coffee-labels/tree/main/skills/coffee-labels
```

Use `$coffee-labels`.

### ChatGPT

Attach [SKILL.md](skills/coffee-labels/SKILL.md) and your packaging photo to a chat with file creation tools. Ask it to follow the attached instructions. This applies to that conversation.

For a reusable desktop skill, [download and extract the repo](https://github.com/arn4v/coffee-labels/archive/refs/heads/main.zip), give local Work access to the folder, and ask `@skill-creator` to import `skills/coffee-labels`, including its supporting files. Then select Coffee Labels with `@`.

## Make a label

```text
Make a label using the attached packaging.
Coffee: [exact name and lot]
Weight: 100 g
Roast date: 05/10
Printer: [model, label size, DPI, printable dot dimensions]
Show the preview before printing.
```

## Printing

Includes a macOS Bluetooth client for a WePrint-compatible P2 / Seznik Josh: 50 × 50 mm stock, 384 × 400 dots, 203 DPI. [Setup and print commands](skills/coffee-labels/references/weprint.txt).

Bluetooth printing requires a local Mac. Inspect one test label before a batch. Other printers need their own workflow.

[MIT license](LICENSE) · [Claude Code docs](https://code.claude.com/docs/en/skills) · [ChatGPT and Codex docs](https://learn.chatgpt.com/docs/build-skills)
