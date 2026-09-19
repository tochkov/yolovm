# Research

Reports that informed yolovm's design decisions. Each was produced by AI
research agents that read the cited primary sources on the stated date; every
claim links its source, and anything the agent could not confirm is marked
"unverified" in the text. Treat them as evidence collected on that date, not as
maintained documentation.

| Date | Report | Question it answers |
| --- | --- | --- |
| 2026-09-17 | [YOLO_RESEARCH.md](YOLO_RESEARCH.md) | Incus, Multipass, Docker Sandboxes or libvirt for the original draft, and when a headless sandbox would do |
| 2026-09-17 | [NATIVE_AGENT_RESEARCH.md](NATIVE_AGENT_RESEARCH.md) | Whether the vendors' native browser and desktop integrations survive a split between a host app and a remote agent; why a full desktop VM |
| 2026-09-17 | [APP_BROWSER_EVIDENCE.md](APP_BROWSER_EVIDENCE.md) | Static evidence from the installed ChatGPT app that its browser integration is local-host only |
| 2026-09-19 | [COMPARABLE_TOOLS.md](COMPARABLE_TOOLS.md) | What comparable VM managers, agent sandboxes and agent CLIs are written in, how they talk to their backend, and why the ones that changed language did |
| 2026-09-19 | [LANGUAGE_EVAL.md](LANGUAGE_EVAL.md) | Python, Go, Rust, TypeScript, Bash and Kotlin scored against the host CLI's requirements, with a recommendation and what would change it |
| 2026-09-19 | [CORE_DEFAULTS_PACKS.md](CORE_DEFAULTS_PACKS.md) | How comparable tools draw the core / default / extension lines, criteria for yolovm's tiers, and the pack interface. The per-family sweeps it condenses are in [core-defaults-packs/](core-defaults-packs/) |
