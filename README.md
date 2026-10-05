# Coffee labels

An agent skill for making coffee bag and split labels that match the roaster's packaging. It checks the coffee lot, uses the real logo, exports an editable SVG and a monochrome PNG, and shows the finished label before asking to print.

Includes an optional macOS Bluetooth client for a WePrint-compatible P2 / Seznik Josh printer. Label creation works without that printer. The tested setup uses 50 × 50 mm stock, a 384 × 400 dot printable area, and 203 DPI.

## Install in Claude Code

Run from a directory where you keep Git repositories:

```sh
git clone https://github.com/arn4v/coffee-labels.git
mkdir -p ~/.claude/skills
ln -s "$(pwd)/coffee-labels/skills/coffee-labels" ~/.claude/skills/coffee-labels
```

Invoke with `/coffee-labels`, followed by the coffee details. For a project-only install, use `.claude/skills` instead of `~/.claude/skills`.

If a destination already exists, inspect it before replacing it. These commands intentionally do not overwrite an existing skill.

[Claude Code skill documentation](https://code.claude.com/docs/en/skills).

## Install in Codex

Ask Codex:

```text
$skill-installer install the coffee-labels skill from
https://github.com/arn4v/coffee-labels/tree/main/skills/coffee-labels
```

Or install manually:

```sh
git clone https://github.com/arn4v/coffee-labels.git
mkdir -p ~/.agents/skills
ln -s "$(pwd)/coffee-labels/skills/coffee-labels" ~/.agents/skills/coffee-labels
```

Skip cloning again if you already cloned for Claude Code. Use `.agents/skills` for a project-only install. Invoke with `$coffee-labels`. Restart Codex if the skill does not appear.

[Codex skill locations and installer](https://learn.chatgpt.com/docs/build-skills).

## Use in ChatGPT

### Desktop with local Work access

Clone this repository or download and extract its [ZIP](https://github.com/arn4v/coffee-labels/archive/refs/heads/main.zip). Give ChatGPT access to the extracted folder, then ask:

```text
@skill-creator Create a local skill named coffee-labels from
skills/coffee-labels in this folder. Preserve SKILL.md, the printer reference,
the Swift client, and the agent metadata. Do not print anything during setup.
```

Open Skills in the sidebar to check the created skill. Mention it with `@` when making a label. This uses the built-in creator to register a local skill; this repository is not a published ChatGPT marketplace plugin.

[ChatGPT skill creation and invocation](https://learn.chatgpt.com/docs/build-skills).

### Web, mobile, or a chat without local skill access

Download [SKILL.md](skills/coffee-labels/SKILL.md), attach it to a chat with your packaging reference, and say:

```text
Follow the attached coffee-labels instructions to make this label.
Export the SVG and monochrome PNG, then show the PNG preview.
Coffee: [exact name and lot]
Weight: [weight]
Roast date: [date]
Printer: [model, DPI, printable dot dimensions, label stock size]
```

This applies the instructions to that conversation. It does not install a persistent skill. File export requires a chat with file creation tools. Print the downloaded PNG locally; the bundled Bluetooth client must run on a Mac with access to the printer.

## Make a label

Supply the coffee name and exact lot, weight, roast date, and packaging photo or official product link. Include the printer dimensions if they differ from the tested P2 setup.

```text
Make a 50 × 50 mm label for this coffee using the attached packaging.
Coffee: [name and lot]
Weight: 100 g
Roast date: 05/10
Printer: WePrint-compatible P2, 203 DPI, 384 × 400 printable dots
Show the final preview before printing.
```

The skill omits uncertain optional details and asks when a coffee name could mean several lots. It can also make a simple shipping label using only the recipient details you provide.

Making a label does not authorize printing. Approve the exact preview and quantity separately. A changed layout needs a new preview and one physical test before a batch.

## Print with the bundled P2 client

Requires macOS, Bluetooth permission, and Xcode Command Line Tools. If `swiftc` is missing, install the tools with `xcode-select --install`.

From the repository root:

```sh
mkdir -p work/swift-module-cache
swiftc -module-cache-path work/swift-module-cache \
  skills/coffee-labels/scripts/weprint.swift -o work/weprint
./work/weprint --self-test
```

Query your printer without printing. Replace `PRINTER_NAME` with its exact Bluetooth name:

```sh
./work/weprint 'PRINTER_NAME'
```

After approving the preview, send one copy:

```sh
./work/weprint 'PRINTER_NAME' /absolute/path/to/label-384x400.png 10
```

Each invocation sends one label. Darkness 10 worked on the tested printer. The client preserves existing speed, paper mode, and gap settings. Inspect the physical label, including thin borders and dividers. A ready status confirms neither the page nor its quality. Do not automatically retry an uncertain job.

You can check image encoding without Bluetooth:

```sh
./work/weprint --encode /absolute/path/to/label-384x400.png work/label.bin
```

See [the printer reference](skills/coffee-labels/references/weprint.txt) for protocol sources, tested firmware, and completion limits. Other printers need their own workflow. No roaster logos or fonts are bundled.

## Update

Run `git pull --ff-only` inside your clone. Symlink installations pick up the new files. A skill copied or recreated in ChatGPT must be updated from the changed folder separately.

## License

[MIT](LICENSE). Roaster trademarks and third-party logo/font assets remain subject to their owners' rights.
