# Project State Presentation Assets

This folder contains a Marp slide deck and SVG assets for the project-state update.

## Files

- `project_state_slides.md`: Main slide deck (Marp Markdown).
- `figures/*.mmd`: Primary Mermaid diagram sources.
- `figures/variants/*.mmd`: Alternative Mermaid variants.
- `figures/*.svg`: Rendered diagram and placeholder assets.

## Regenerate Mermaid SVGs

From repository root:

```bash
for f in docs/presentation/figures/*.mmd; do
  mmdc -i "$f" -o "${f%.mmd}.svg"
done

for f in docs/presentation/figures/variants/*.mmd; do
  mmdc -i "$f" -o "${f%.mmd}.svg"
done
```

## Regenerate AXI_RGB2GRAY Figure SVG

```bash
pdftocairo -svg -f 1 -l 1 docs/figures/IP_RGB2GRAY.pdf docs/figures/axi_rgb2gray_ip
mv docs/figures/axi_rgb2gray_ip docs/figures/axi_rgb2gray_ip.svg
```

## Optional: Export Slides

If Marp CLI is available:

```bash
npx @marp-team/marp-cli docs/presentation/project_state_slides.md \
  --allow-local-files \
  -o docs/presentation/project_state_slides.pdf
```
