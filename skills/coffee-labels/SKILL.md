---
name: coffee-labels
description: Create coffee bag or split labels using the roaster's actual logo and packaging design language, show a preview, then ask whether to print. Use for new labels, roast-date or weight edits, and approved label printing.
---

# Coffee labels

Create a readable label that belongs visually to the coffee's roaster. Show the finished label before asking to print. Keep design approval and physical printing separate.

## Confirm the coffee

Use the user's coffee, lot, weight, and roast date. Preserve their date format or normalize day/month with leading zeroes; do not invent a year. Distinguish roast date from harvest date.

Check the exact lot against the roaster's official product page, supplied packaging, or the user's previous conversation. If a product has disappeared, recover its historical details instead of substituting the current release. Ask one concise question when the name covers multiple processes or lots. Do not guess tasting notes, variety, altitude, or process. Omit uncertain optional details.

## Design from the roaster

Inspect the supplied packaging reference and official branding before designing. Use the real logo asset, not a typed approximation. Keep only the logo or wordmark; crop unrelated descriptors such as “Specialty Coffee Roasters” unless requested. Preserve the logo's proportions and any scripts already in the asset. Do not invent multilingual lettering.

Carry through recognizable typography, framing, motifs, and hierarchy. A packaging seal can become an outlined seal for thermal printing; decorative borders should remain subordinate to the coffee name and date. Do not reuse another roaster's font, logo, or layout merely because an earlier label used it. For example, Subko Project Everest uses a serif wordmark, serif headings, an oval process seal, and a geometric border. That is a reference for this package, not a universal Subko template.

Prefer editable SVG with outlined text and an exact-size monochrome PNG for text-heavy thermal labels. Preserve genuine logo assets in the SVG. Use relevant image-generation tools for tasks that actually need generated or edited bitmap artwork, when available.

Confirm the printer, stock size, DPI, and printable dot dimensions before rendering. The bundled WePrint client supports a 384-dot, 203-DPI P2 with 50 × 50 mm stock and a 384 × 400 dot image. Use those dimensions only for that setup; recheck for another printer or stock. Render at the final dot dimensions with pure black and white, generous readable type, and clear margins. Avoid a second image resampling or large solid black fields. Thin rules can disappear on thermal output; inspect a test print before relying on them.

Verify all supplied facts and dates, inspect the rendered PNG, and check for clipped content, missing glyphs, and grayscale pixels. Save the editable source and print-ready PNG under the task's outputs directory, or the user's chosen output directory. Use only supplied fields for a shipping label; omit coffee branding and coffee metadata when none is provided.

## Preview, then print

Show the actual final PNG inline. Briefly state its weight and roast date when provided, then ask “Print one copy?” Wait for the user's answer. A general request to make labels does not authorize printing. If the user already approved this exact preview and quantity, proceed without asking again. Revisions require a fresh preview before printing.

After approval, use the user's existing printer workflow. For a compatible P2 on a local Mac, read [the printer reference](references/weprint.txt). Use the exact Bluetooth name supplied by the user, never choose a nearby printer by guesswork. If local hardware access is unavailable, provide the print-ready file and local printing instructions. Print one test when introducing a new layout or setting, then print the approved remainder after quality is confirmed.

Distinguish bytes transmitted, printer status, and a physically verified label. A disconnect or reboot is not success, and “ready” after a reset does not prove the job finished. Stop automatic retries after a disconnect or uncertain output to avoid duplicate or partial labels; report what happened and ask for the next action. Keep the last successful settings available for reuse.
