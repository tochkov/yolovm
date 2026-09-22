# TODO

- [ ] Settle names once they have been used for a while: `doctor`, `provision`,
  `sh`, role `dev`.
- [ ] Decide the remote desktop password: random per VM, as now, or a fixed
  default such as `yolovm`. On a tailnet where every device can already SSH in
  as `ubuntu`, it protects nothing, so convenience decides. Same session as the
  naming.
- [ ] Rename the VM user from `ubuntu`, which the image creates, to something
  like `yolovm`. Not in focus now.
- [ ] A per-host config file for what is hard-coded today: default CPU, memory
  and disk, the role, Chrome's search engine.
- [ ] Doctor polish, later: colour for `ok` and `!!` when on a terminal, and a
  verbose mode that prints versions.
- [ ] Add roles beyond `dev` (research, news): `provision_NAME` plus
  `status_NAME_apps|boot|signin|settings` functions in `guest/yolovm-guest`, and files
  under `guest/roles/NAME/`.
- [ ] Optional: a reusable template image for faster creation. Explain how
  publishing an image differs from a snapshot, and how to strip credentials and
  machine identity first.
- [ ] Optional: `yolovm tailnet` to apply `host/tailscale-policy.json` through
  the Tailscale API instead of the admin console.
- [ ] Discuss Tailscale's place in future onboarding alongside the broader
  auth, networking and CLI design. Consider moving detailed setup out of the
  README into `docs/tailscale.md` or `TAILSCALE_SETUP.md`, keeping a short link
  for optional setup, and showing `yolovm auth NAME --no-tailscale` in the main
  quickstart. Account for starting without Tailscale and enabling it later.
  Revisit auth defaults and the `--no-*` flags in that wider discussion. This
  is an open proposal to discuss with the other moving parts before implementing.
- [ ] When the stable channel passes 2.1.278, look at `claude remote-control
  --chrome`: it appeared between 2.1.272 and 2.1.278 and only forwards `--chrome`
  to the sessions the server starts, which `CLAUDE_CODE_ENABLE_CFC=1` in the unit
  already does on every version. On stable 2.1.267 it is an unknown argument that
  would crash-loop the unit, so it is a readability choice for later, not a need.
