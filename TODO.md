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
  `status_NAME_apps|boot|settings` functions in `guest/yolovm-guest`, and files
  under `guest/roles/NAME/`.
- [ ] Optional: a reusable template image for faster creation. Explain how
  publishing an image differs from a snapshot, and how to strip credentials and
  machine identity first.
- [ ] Optional: `yolovm tailnet` to apply `host/tailscale-policy.json` through
  the Tailscale API instead of the admin console.
