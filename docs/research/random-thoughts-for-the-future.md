# Random thoughts for the future

> These notes are for future discussion only. Nothing here is a decision or guidance, and they should not steer current work.

## Host and guest as separate packages

As yolovm develops into a proper tool (CLI or otherwise), consider two packages:

- **`yolovm-guest`** — the standalone environment setup, usable directly on an old, low-end PC without a host layer.
- **`yolovm-host`** — depends on `yolovm-guest` and adds VM provisioning and management, allowing more capable hardware to run multiple guest environments.

When provisioning a VM, the host installs `yolovm-guest` inside it and invokes commands such as `yolovm-guest init` and `yolovm-guest auth`. Physical machines and VMs share the same guest setup workflow.

*Package and command names are provisional; final naming comes later.*
