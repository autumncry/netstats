# NetStats surface design

## Scope

This record specifies the Terminal detail redesign only. Native details and the glass feature hub preserve their existing implementation and behavior.

## Terminal detail — Operate

- Deep charcoal surface, warm-white primary text, legible warm-gray secondary text, restrained warm orange accent. Status colors have accompanying text.
- Monospaced measurement columns and compact row rhythm. Thin section rules replace the six large dashboard cards.
- Stable app header and a quiet status footer. A scrollable body prevents clipping with long process names, localized copy and error states.
- CPU and memory process rankings remain readable; memory utilization and pressure are explicitly distinguished.
- No composite Health score, decorative ASCII logo, fake command input, or network bar suggesting an unknown link capacity.
- Settings and public-IP copy remain working native controls. Module, history and process-list switches govern this surface as well.
- Numeric refreshes do not blink or animate the whole page. Native controls retain keyboard and accessibility behavior.

## References

- Claude Code official demo: https://github.com/anthropics/claude-code#readme — restrained accent, monospaced hierarchy, simple separators.
- Codex CLI: https://developers.openai.com/codex/cli — compact terminal interaction language.

These are visual references; NetStats does not embed either product or claim an affiliation.
