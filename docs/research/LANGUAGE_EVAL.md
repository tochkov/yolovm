# yolovm host CLI: implementation-language evaluation

Date: 2026-09-19. Read-only research; nothing under /home/tochkov/PROJ was modified.
Candidates: Python, Go, Rust, TypeScript/Node (Bun/Deno where relevant), plus Bash-as-is and Kotlin (JVM + Native) for completeness.
Every factual claim carries a source link or is marked **unverified**. "Observed" means measured on this machine (an Ubuntu 26.04.1 host with Incus 7.0.1 from Zabbly), which is the exact target environment.

---

## 0. What a real target host looks like (observed on this machine)

| Item | Observed value |
|---|---|
| OS / kernel | Ubuntu 26.04.1 LTS "Resolute Raccoon", kernel 7.0.0-31-generic |
| Preinstalled Python | `/usr/bin/python3` = **3.14.4**; `python3-yaml` 6.0.3 is installed only as a dependency of netplan/cloud-init/apport/ubuntu-pro-client; `tomllib`, `pty`, `asyncio`, `venv` import fine; **no** `pip`, `pipx`, `uv`, `ensurepip` |
| Preinstalled Node / Go / Rust / Java | **none** (`node`, `go`, `rustc`, `cargo`, `java`, `kotlin` all "command not found") |
| Incus | 7.0.1, package `1:7.0.1-ubuntu26.04-202607310253` from `https://pkgs.zabbly.com/incus/lts-7.0` |
| `/usr/bin/incus` | a 101-byte `sh` wrapper that sets `PATH=/opt/incus/bin` and `LD_LIBRARY_PATH=/opt/incus/lib` then `exec incus "$@"` |
| Real CLI binary | `/opt/incus/bin/incus`: **23.6 MB** ELF, dynamically linked (Go). `incusd` is 64.7 MB |
| Socket | `/var/lib/incus/unix.socket`, `srw-rw---- root incus-admin`; the current user is in `incus-admin` |
| `incus query /1.0` | `api_version 1.0`, `api_status stable`, `auth: trusted`, `auth_methods: [tls]`, `auth_user_method: unix`, `auth_user_name: tochkov`, **529** `api_extensions`, `driver: lxc \| qemu`, `driver_version: 7.0.0 \| 11.0.3` |
| CLI output formats | `incus list -f csv\|json\|table\|yaml\|compact\|markdown` (with `,noheader`/`,header` suffixes); `incus monitor -f json\|pretty\|yaml --type lifecycle`; `incus query -X … --data … --raw --wait` |
| Startup time | `python3 -c pass`: reported 0.00 s (~10 MB RSS); `python3 -c 'import json,subprocess,argparse,tomllib'`: 0.01 s; `incus --version`: 0.00 s (~23 MB RSS); `incus list -f json`: 0.01 s |
| apt candidates (26.04, not installed) | pipx 1.8.0, nodejs 22.22.1, npm 9.2.0, golang-go 1.26, rustc/cargo 1.93.1, default-jre (OpenJDK 25), **kotlin 1.3.31** (2019-era), python3-pydantic 2.12.5, python3-textual 2.1.2, python3-typer 0.19.2, python3-websockets 15.0.1, python3-keyring 25.7.0, shellcheck 0.11.0, bats 1.13.0, yq 3.4.3 (this is the Python `yq`, not mikefarah's Go one); **uv and cargo-binstall are not packaged** |
| Other | `snap` 2.76.3 present; `jq` present only because `fwupd` depends on it; `virt-viewer` was installed manually |

Ubuntu 24.04 (from package pages, not observed live): Python 3.12 is the default interpreter ([Canonical release announcement](https://canonical.com/blog/canonical-releases-ubuntu-24-04-noble-numbat)); `pipx` 1.4.3 is in *universe* ([packages.ubuntu.com](https://packages.ubuntu.com/noble/pipx)); `nodejs` is **18.19.1** in *universe* ([packages.ubuntu.com](https://packages.ubuntu.com/noble/nodejs)) and Node 18 has been end-of-life since 2025-04-30 ([nodejs/release](https://github.com/nodejs/release)); `golang-go` is 1.22 ([packages.ubuntu.com](https://packages.ubuntu.com/noble/golang-go)). That Node/Go/Rust/Java are absent from a fresh 24.04 desktop/server install is consistent with them living outside the default seeds, but I only verified absence live on 26.04 — treat 24.04 absence as **highly likely, unverified**.

---

## 1. Incus integration

### 1a. The REST API over the unix socket (verified facts)

- Transport/auth: "All communication between Incus and its clients happens using a RESTful API over HTTP. This API is encapsulated over either TLS (for remote operations) or a Unix socket (for local operations)." Over the socket the caller is simply trusted (observed: `auth: trusted`, `auth_user_method: unix`). "Local access to Incus through the Unix socket always grants full access to Incus … you should only give such access to users who you'd trust with root access to your system." Root and members of `incus-admin` get that; a separate `incus` group gets a restricted per-user socket via `incus-user` ([REST API](https://linuxcontainers.org/incus/docs/main/rest-api/), [Installing](https://linuxcontainers.org/incus/docs/main/installing/)). Consequence: no auth code at all for the local case; the only failure mode is group membership.
- Async operations: background tasks return HTTP 202 with a `Location` header pointing at `/1.0/operations/<id>`; clients "poll for a status update or wait for a notification using the long-poll API", and the docs recommend subscribing to `operation` events before triggering operations ([REST API](https://linuxcontainers.org/incus/docs/main/rest-api/)).
- Exec: `POST /1.0/instances/{name}/exec` takes `command`, `environment`, `wait-for-websocket`, `interactive` ("singled PTY instead of 3 PIPEs"), `width`, `height`, `user`, `group`, `cwd`, `record-output` ([rest-api.yaml](https://raw.githubusercontent.com/lxc/incus/main/doc/rest-api.yaml)). The operation metadata carries an `fds` map; interactive mode uses one websocket (`"0"`) plus `"control"`, non-interactive uses `"0"`,`"1"`,`"2"` plus `"control"`; each is opened at `/1.0/operations/{id}/websocket?secret=…` ([client/incus_instances.go](https://raw.githubusercontent.com/lxc/incus/main/client/incus_instances.go)). The control socket carries `window-resize` and `signal` messages (`api.InstanceExecControl`, [shared/api](https://pkg.go.dev/github.com/lxc/incus/v7/shared/api#InstanceExecPost)). For VMs "the `incus-agent` process must be running inside of the virtual machine for this to work" ([instance-exec](https://linuxcontainers.org/incus/docs/main/instance-exec/)).
- Files: `GET/POST /1.0/instances/{name}/files?path=…` with headers `X-Incus-uid`, `X-Incus-gid`, `X-Incus-mode`, `X-Incus-type` (file/directory/symlink), `X-Incus-write` (append) ([client/incus_instances.go](https://raw.githubusercontent.com/lxc/incus/main/client/incus_instances.go)). The CLI adds recursion on top: `incus file push -r` / `pull -r`, plus `file mount` (sshfs/SFTP) ([Access files](https://linuxcontainers.org/incus/docs/main/howto/instances_access_files/)).
- Events: websocket at `/1.0/events`, types `logging`, `operation`, `lifecycle`; events arrive in generation order, and a listener that cannot keep up "gets disconnected rather than silently dropping events"; the Go `EventListener.AddHandler` runs handlers concurrently (may reorder) while `AddChannel` delivers in order ([Events](https://linuxcontainers.org/incus/docs/main/events/)).
- Stability: "Feature additions done without breaking backward compatibility only result in addition to `api_extensions`" ([REST API](https://linuxcontainers.org/incus/docs/main/rest-api/)). Incus 7.0 LTS shipped 2026-05-05 with support through June 2031 and requires Go ≥ 1.25 to build ([forum announcement](https://discuss.linuxcontainers.org/t/incus-7-0-lts-has-been-released/26641)).

### 1b. Is the `incus` CLI's machine-readable output stable?

- `incus list --format json` marshals the API type `[]api.InstanceFull` (i.e. the same JSON the REST API returns), while `csv` and `yaml` render only the selected table columns ([cmd/incus/list.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/list.go)). So JSON inherits the API's add-only compatibility promise; CSV/YAML depend on your `-c` column selection (your current `incus list -c s -f csv` is fine as long as you always pass `-c`).
- `incus query` returns raw API responses, so it is exactly as stable as the API ([REST API](https://linuxcontainers.org/incus/docs/main/rest-api/); observed `--raw`, `--wait`, `-X`, `--data` flags).
- The Zabbly wrapper means anything that shells out must find `incus` via `PATH` (the wrapper sets `LD_LIBRARY_PATH`); anything that talks to the socket directly needs `incus-admin` membership (observed).

### 1c. Client libraries per language

| Language | What exists | Assessment |
|---|---|---|
| Go | `github.com/lxc/incus/v7/client` (v7.4.0 published 2026-08-27): `ConnectIncusUnix`, `ExecInstance(name, api.InstanceExecPost, *InstanceExecArgs{Stdin, Stdout, Stderr, Control, DataDone})`, `ConsoleInstance`, `GetInstanceFile`/`CreateInstanceFile`, `GetEvents`→`EventListener`, `GetInstances`, operation `Wait` ([pkg.go.dev](https://pkg.go.dev/github.com/lxc/incus/v7/client)). **It is the same package the `incus` CLI uses**: `cmd/incus/exec.go` imports `github.com/lxc/incus/v7/client`, puts the terminal in raw mode with `termios.MakeRaw`, and sends `window-resize` control messages ([exec.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/exec.go)); `console.go` implements `--type vga` by proxying the SPICE websocket to a local `spice+unix://` socket and launching `remote-viewer` or `spicy`, printing the socket path if neither is installed ([console.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/console.go)). Apache-2.0, so that code can be reused. | Official, complete, versioned in lock-step with the server. |
| Python | No official client and none planned: "Upstream Incus folks don't have a lot of python knowledge so we're not likely to create a pyincus", although "I would expect `pylxd` to actually work fine against the Incus" API (Stéphane Graber, Jan 2024, [forum](https://discuss.linuxcontainers.org/t/moving-to-incus-for-users-of-pylxd/18601)). `pylxd` is still released by Canonical (2.4.2, 2026-08-18, Python ≥ 3.10, [PyPI](https://pypi.org/pypi/pylxd/json)); nobody upstream tests it against Incus (**unverified** whether its exec/websocket path works on Incus 7). Community: `pyincusd` 7.4.0 (2026-08-28) is auto-generated with OpenAPI Generator from the Incus spec and exposes `instance_exec_post`, `instance_files_get/post`, `events_get`, `operation_websocket_get` ([PyPI](https://pypi.org/pypi/pyincusd/json), [GitHub](https://github.com/anonhostpi/pyincusd)) — generated clients give you the REST calls, not the websocket streaming loop (**unverified** that it streams exec at all); `incus-sdk` 1.0.0 is "Development Status: Alpha", last release 2025-03-21 ([PyPI](https://pypi.org/project/incus-sdk/)); `container_client` and `bsd-ac/incus-lxd` are small wrappers (activity **unverified**). Ansible's own Incus connection plugin runs everything through the `incus` CLI ([docs](https://docs.ansible.com/ansible/latest/collections/community/general/incus_connection.html)). DIY REST is easy: `httpx.HTTPTransport(uds=...)` ([httpx](https://www.python-httpx.org/advanced/transports/)) and `websockets.asyncio.client.unix_connect()` ([websockets](https://websockets.readthedocs.io/en/stable/reference/asyncio/client.html)). | Wrap the CLI; add a ~150-line REST/events helper only if you need events or typed errors. |
| Rust | `incus-client` 0.1.1, "Auto-generated Rust client", first published 2026-05-06, 56 downloads total ([crates.io](https://crates.io/api/v1/crates/incus-client)). `hyperlocal` (unix-socket HTTP) last updated 2024-07 ([crates.io](https://crates.io/api/v1/crates/hyperlocal)); websockets over `UnixStream` via `tokio-tungstenite` is possible (reasoning). | Nothing you would depend on; you would write the client. |
| TypeScript/Node | `incus-ts` 0.1.6 (2026-03-17, "Lightweight TypeScript API for Incus") and `@containernerds/incus-client` 1.0.1 (2025-02-22) ([npm registry](https://registry.npmjs.org/-/v1/search?text=incus&size=15)); neither is affiliated with the project. Node's `http.request` accepts a unix `socketPath` and `ws` can dial unix sockets — **unverified** in the fetched docs, but standard. Adjacent projects worth a look: `companion-incus` ("Incus-powered web UI for Claude Code & Codex agents", 0.93.0, 2026-03) and `paraspace` ("parallel dev workspaces on Incus", 0.4.3, 2026-08). | DIY or wrap the CLI. |
| Bash | The CLI itself: `--format json` + `jq`, `incus query` for anything else. | Fine for reads; no exec-stream control, no events handling beyond `incus monitor` text. |
| Kotlin | Nothing Incus-specific found. JVM `java.net.http.HttpClient` has no unix-socket support (reasoning; you would need OkHttp/Netty + `UnixDomainSocketAddress`); Kotlin/Native would need POSIX interop. | Not viable without writing a client. |

### 1d. Wrap the CLI vs use the API — per language

What you lose by wrapping the CLI (any language):
- **Exec streaming and control**: no separate stdout/stderr websockets, no `window-resize`/`signal` control messages, no `DataDone` synchronisation; you get whatever the CLI prints, and interactive vs non-interactive is decided by the CLI's TTY detection unless you pass `-t/-T` (observed help text).
- **Progress**: operations report progress through `operation` events; the CLI renders it as text (`-q` disables) — you cannot get structured progress.
- **Error typing**: the API returns structured `error`/`error_code`; the CLI collapses it to an exit code plus a message on stderr.
- **Events**: `incus monitor -f json` works but you parse a text stream and reconnect yourself; the API's "slow listener is disconnected" semantics apply either way.
- **Version coupling**: CLI flags can change; the JSON of `list`/`query` is the API and therefore add-only.

What you keep by wrapping: the CLI's tested `exec -t` raw-mode/resize handling and the `console --type vga` viewer launch, `file push -r` recursion, and the Zabbly wrapper's library path handling — all of which you would otherwise reimplement.

Recommendation per language:
- **Go**: use the client for everything non-interactive (list, launch, wait via `Wait()`/events, file push, snapshots/export, doctor probes, typed errors). For `exec -t` sign-ins, either reuse the CLI's Apache-2.0 exec/console code (same module, same types) or shell out to `incus exec -t` / `incus console --type vga` — both are cheap. Pin `github.com/lxc/incus/v7` to the server's LTS minor (7.0.x) and gate optional features on `api_extensions`.
- **Python**: wrap the CLI (as the Ansible plugin does) and parse `--format json`; add a small `httpx`+`websockets` helper only for `/1.0/events` and structured errors. Do not build on the alpha/generated SDKs.
- **Rust / TypeScript / Kotlin**: wrap the CLI; the API path means writing and maintaining your own client.
- **Bash**: CLI only, `jq` required.

---

## 2. Interactive passthrough (inherited TTY for `incus exec -t` and `incus console --type vga`)

Common ground (reasoning, standard POSIX semantics): when the child shares the parent's controlling terminal, Ctrl-C generates SIGINT for the whole foreground process group, so no "forwarding" is needed for TTY sign-ins; what matters is that the parent does not die first and that it restores the terminal state. Signal forwarding only matters when you pipe I/O yourself.

| Language | Facts | Verdict |
|---|---|---|
| Python | `subprocess.run/Popen`: "With the default settings of `None`, no redirection will occur" (child inherits fds); `start_new_session`/`process_group` documented ([docs](https://docs.python.org/3/library/subprocess.html)). Python's default SIGINT handler raises `KeyboardInterrupt` in the parent, so wrap the call. `pty` module in stdlib (observed importable), `pexpect` for scripted TTY interaction. | Good; the only trap is the parent's own `KeyboardInterrupt`. |
| Go | `os/exec`: if `Stdin`/`Stdout`/`Stderr` is an `*os.File`, "the process's standard input is connected directly to that file" (no goroutine copy) ([os/exec](https://pkg.go.dev/os/exec#Cmd)); `creack/pty` provides `pty.Start` for `exec.Cmd` in pure Go ([GitHub](https://github.com/creack/pty)); the reference implementation of raw-mode + resize for Incus is in the same language ([exec.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/exec.go)). | Best in class for this exact tool. |
| Rust | `Command::spawn()/status()` default stdio to `inherit`; `output()` captures ([std docs](https://doc.rust-lang.org/std/process/struct.Command.html)); `portable-pty` 0.9.0 (2025-02) ([crates.io](https://crates.io/api/v1/crates/portable-pty)). Codex CLI is the proof that a Rust agent CLI does this at scale ([InfoQ](https://www.infoq.com/news/2025/06/codex-cli-rust-native-rewrite/)). | Equivalent to Go. |
| TypeScript/Node | `stdio: 'inherit'` "Pass through the corresponding stdio stream to/from the parent process"; note "Node.js establishes signal handlers for SIGINT and SIGTERM … will perform a sequence of cleanup actions and then re-raise" ([child_process](https://nodejs.org/api/child_process.html)). `node-pty` 1.1.0 (2025-12) is a native addon; installing without a compiler needs a prebuilt fork such as `@homebridge/node-pty-prebuilt-multiarch` ([npm](https://registry.npmjs.org/node-pty), [fork](https://github.com/homebridge/node-pty-prebuilt-multiarch)). | Works for plain passthrough; PTY use drags in native builds. |
| Bash | Native. | Trivial. |
| Kotlin | JVM: `ProcessBuilder.inheritIO()` (standard JDK API; reasoning). Kotlin/Native has no process API; you call `popen`/`posix_spawn` through cinterop ([Kotlin discussions](https://discuss.kotlinlang.org/t/idiomatic-way-to-spawn-subprocesses/27222)). | JVM fine, Native painful. |

---

## 3. Distribution on a fresh Ubuntu 24.04 / 26.04 host

| Language | Install path on a fresh host | Update story | Size / startup (order of magnitude) |
|---|---|---|---|
| Python | Interpreter is preinstalled (3.12 / 3.14, observed 3.14.4) but PEP 668 makes `pip install` into the system interpreter refuse by default; the recommended paths are venvs or `pipx` ([PEP 668](https://peps.python.org/pep-0668/)). Realistic: `sudo apt install pipx && pipx install yolovm` (pipx 1.4.3 on 24.04, 1.8.0 on 26.04) or `curl -LsSf https://astral.sh/uv/install.sh \| sh && uv tool install yolovm`; uv installs tools into isolated environments and "will automatically download Python versions when needed" so the 3.12-vs-3.14 gap can be made irrelevant ([uv tools](https://docs.astral.sh/uv/guides/tools/), [uv python versions](https://docs.astral.sh/uv/concepts/python-versions/)). A `.deb` in your own apt repo is also natural for Python (dh-python; reasoning). Single-file binaries via PyInstaller 6.22 exist ([PyPI](https://pypi.org/pypi/pyinstaller/json)) but are a second build system. | `pipx upgrade` / `uv tool upgrade` (respects pins) | No binary; interpreter start observed ≤ 10 ms, ~10–13 MB RSS. |
| Go | One static-ish binary from GitHub Releases via a `curl \| sh` installer; GoReleaser builds archives, deb/rpm (nFPM), Homebrew, snap, install scripts and can push to Cloudsmith/Gemfury apt repos ([goreleaser.com](https://goreleaser.com/)). `go install …@latest` needs Go (1.22 on 24.04, 1.26 on 26.04) — not for end users. | Re-run installer, apt, or a self-update library (reasoning) | Observed: the real `incus` CLI is 23.6 MB; small CLIs are single-digit to ~15 MB (reasoning). Start ~ms (observed 0.00 s). |
| Rust | Same shape as Go: `cargo-dist` generates shell/PowerShell installers, Homebrew, npm and MSI artifacts ([cargo-dist](https://github.com/axodotdev/cargo-dist)); `cargo-binstall` fetches prebuilt release binaries and does not need Rust installed ([cargo-binstall](https://github.com/cargo-bins/cargo-binstall)); `self_update` 1.3.0 crate exists ([crates.io](https://crates.io/api/v1/crates/self_update)). | Installer re-run / `self_update` | Typically smaller than Go (e.g. "4.5 MB [Kotlin/Native] vs 3.5 MB for Rust" for an HTTP+JSON tool, [Kotlin discussions](https://discuss.kotlinlang.org/t/kotlinc-as-a-native-binary/20702)); start ~ms. |
| TypeScript/Node | No Node on the host; 24.04's apt Node 18 is EOL, 26.04's is Node 22 (Maintenance LTS until 2027-04-30) ([nodejs/release](https://github.com/nodejs/release)); otherwise NodeSource/nvm, then `npm i -g` (Claude Code's docs warn "Do NOT use `sudo npm install -g`") ([Claude Code setup](https://code.claude.com/docs/en/setup)). Or ship a self-contained binary: `bun build --compile` hello-world is 57–94 MB, Node SEA ≈ 48 MB baseline ([search summary; Bun docs](https://bun.com/docs/bundler/executables)). Data point: Anthropic's own TypeScript CLI now recommends a **native installer** whose binary "does not itself invoke Node", plus apt/dnf/apk repos ([Claude Code setup](https://code.claude.com/docs/en/setup)); OpenAI rewrote Codex CLI in Rust with "zero-dependency install" as the first stated reason because "Node v22+ is required, which is frustrating or a blocker for some users" ([devclass](https://www.devclass.com/ai-ml/2025/06/02/nodejs-frustrating-and-inefficient-openai-rewrites-ai-coding-tool-in-rust/1619589)). | `npm i -g pkg@latest` or installer re-run | Runtime ≈ 50–95 MB if bundled; start ≈ 40 ms (secondary benchmark, [go-on-aws](https://www.go-on-aws.com/optimize/poly-start/)). |
| Bash | Nothing to install (bash, coreutils present); structured data needs `jq` (present here only via `fwupd`) or `yq`. | `git pull` / re-download | n/a |
| Kotlin | JVM: `default-jre` must be installed (OpenJDK 21 on 24.04 / 25 on 26.04; apt `kotlin` is 1.3.31 from 2019 — unusable); JVM CLIs start in the hundreds of ms (**unverified**, order of magnitude). Kotlin/Native: a normal native binary (~80 ms hello-world start, 4.5 MB for HTTP+JSON per the same forum thread) but LTO release builds are slow ([Kotlin docs](https://kotlinlang.org/docs/native-improving-compilation-time.html)). | Installer re-run | see left |
| snap (any language) | Strict confinement has no Incus interface; a tool that opens `/var/lib/incus/unix.socket` and spawns `remote-viewer` would need classic confinement (manual review). **Reasoning, unverified.** | | |

Blunt: for a host-side tool, "one curl line and you have a binary" (Go/Rust) beats "one curl line to get uv, then one uv line" (Python) only slightly; both beat "install Node first" by a lot. Startup time is irrelevant for a tool that waits minutes for VM boots.

---

## 4. Config: YAML/TOML parsing, schema validation, secrets

| Language | YAML | TOML | Validation / schema | Secrets |
|---|---|---|---|---|
| Python | PyYAML 6.0.3 (2025-09; YAML 1.1 semantics, reasoning), ruamel.yaml 0.19.1 (2026-01) ([PyPI](https://pypi.org/pypi/ruamel.yaml/json)) | `tomllib` in stdlib since 3.11, read-only ([docs](https://docs.python.org/3/library/tomllib.html)) | pydantic 2.13.5 (2026-08; typed models + JSON Schema export) ([PyPI](https://pypi.org/pypi/pydantic/json)); packaged as `python3-pydantic` 2.12.5 on 26.04 (observed) | `keyring` 25.7.0 (Secret Service on Linux) ([PyPI](https://pypi.org/pypi/keyring/json)) |
| Go | `gopkg.in/yaml.v3` was archived 2025-04-01 and its README says "THIS PROJECT IS UNMAINTAINED" ([GitHub](https://github.com/go-yaml/yaml)); `goccy/go-yaml` is the maintained replacement that gh CLI and yq are migrating to ([cli/cli#10784](https://github.com/cli/cli/issues/10784)) | `BurntSushi/toml` (long-standing; **activity unverified** this session) | `go-playground/validator` struct tags, or hand-written checks; no pydantic-equivalent culture (reasoning) | `zalando/go-keyring`: Secret Service D-Bus on Linux, no cgo ([GitHub](https://github.com/zalando/go-keyring)) |
| Rust | `serde_yaml` is 0.9.34+**deprecated** (2024-03-25, 407 M downloads); forks `serde_yaml_ng` (last 2024-05) and `serde_norway` (last 2024-12) look stalled, `serde_yaml_bw` 2.5.8 is active (2026-09) ([crates.io](https://crates.io/api/v1/crates/serde_yaml), forum thread [users.rust-lang.org](https://users.rust-lang.org/t/serde-yaml-deprecation-alternatives/108868)) | `toml` 1.1.6 (+spec 1.1.0, 2026-09, 919 M downloads) — excellent | `schemars` 1.2.2 (JSON Schema from types), `serde` derive; `garde`/`validator` (**unverified** this session) | `keyring` 4.2.0 (2026-08) ([crates.io](https://crates.io/api/v1/crates/keyring)) |
| TypeScript | `yaml` 2.9.1 (2026-09) | `smol-toml` 1.8.0 (2026-08) | `zod` 4.6.5 (2026-09; parse + static types) ([npm](https://registry.npmjs.org/zod)) | `@napi-rs/keyring` 2.1.0 (2026-09; binding of keyring-rs); `keytar` last published 2022-02 ([npm](https://registry.npmjs.org/keytar)) |
| Bash | `yq`/`jq` only | none | none | none |
| Kotlin | `kaml` archived 2025-11-30, JVM-only ([GitHub](https://github.com/charleskorn/kaml)) | `ktoml` multiplatform ([GitHub](https://github.com/orchestr7/ktoml)) | kotlinx.serialization | JVM keychain libs (reasoning) |

Secrets, bluntly: yolovm's host side holds almost no secrets — `claude auth login` and `gh auth login` store tokens **inside the VM**. The host needs at most an OS keyring for an optional API key; every language above has one. This factor barely discriminates.

---

## 5. Extensibility (future pluggable hypervisor backend; guest packs stay bash)

| Language | Mechanism | Cost |
|---|---|---|
| Python | `importlib.metadata.entry_points(group=...)` — stdlib, non-provisional since 3.10 ([docs](https://docs.python.org/3/library/importlib.metadata.html)); or plain `importlib.import_module`. | Near zero; third-party backends can be separate PyPI packages. |
| Go | Build-time registration (interface + registry map) is the idiomatic choice and fits here: both likely future backends have Go packages — Lima (`github.com/lima-vm/lima/v2`, [pkg.go.dev](https://pkg.go.dev/github.com/lima-vm/lima/v2/cmd/limactl)) and Apple Virtualization.framework via `Code-Hex/vz` v3 ([GitHub](https://github.com/Code-Hex/vz)). Out-of-process plugins: `hashicorp/go-plugin` (subprocess + gRPC, "battle hardened", used by Terraform/Vault) ([GitHub](https://github.com/hashicorp/go-plugin)). Avoid the stdlib `plugin` package: "Runtime crashes are likely to occur unless all parts of the program … are compiled using exactly the same version of the toolchain" ([pkg.go.dev/plugin](https://pkg.go.dev/plugin)). | Low for compiled-in backends; medium for go-plugin (a second binary + protobuf). |
| Rust | Trait objects + Cargo features for compiled-in backends: trivial. Dynamic loading has no stable ABI; `abi_stable` last updated 2023-10 ([crates.io](https://crates.io/api/v1/crates/abi_stable)), `libloading` is C-ABI only. Subprocess protocol otherwise. | Low compiled-in; high dynamic. |
| TypeScript | Dynamic `import()`; npm packages as plugins. | Near zero. |
| Bash | `source backend.sh`; no interface enforcement. | Low effort, high fragility. |
| Kotlin | JVM `ServiceLoader`; Native compile-time only. | Medium. |

Blunt: you do not need runtime plugins. A compiled-in `Backend` interface with two implementations (Incus now, Lima later) is the right design in any language, which makes this factor mostly a tie between Go/Rust/Python/TS.

---

## 6. Testing and quality

Language-independent CI fact: since 2024-04-02 GitHub's standard 2-vCPU hosted Linux runners expose `/dev/kvm` once you add the udev rule `KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"` (previously 4+ vCPU only) ([GitHub changelog](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/)); public-repo `ubuntu-latest` jobs run on 4-vCPU/16 GB VMs since 2023-12 ([GitHub blog](https://github.blog/news-insights/product-news/github-hosted-runners-double-the-power-for-open-source/)). Nested virtualization is still not formally documented as a supported feature (open documentation request, [runner-images#12933](https://github.com/actions/runner-images/issues/12933)) — treat it as working-but-best-effort; a community report notes the udev rule must be in place before udev settles ([community discussion](https://github.com/orgs/community/discussions/160591)). Installing Incus from Zabbly on the runner and booting a small VM is therefore feasible; the 6-hour job limit and disk (~14 GB free) are the practical limits (**limits unverified**).

| Language | Unit tests | Mocking subprocesses | Lint / types |
|---|---|---|---|
| Python | pytest | `pytest-subprocess` 1.6.0 (2026-05) ([PyPI](https://pypi.org/pypi/pytest-subprocess/json)) | ruff 0.16.8; mypy 2.3.1; pyright 1.1.414; Astral's `ty` is still beta/0.0.x ([GitHub](https://github.com/astral-sh/ty)). Typing is opt-in: quality depends on enforcing strict mode in CI. |
| Go | `go test`, race detector | `testscript` (txtar CLI tests, runs your `main` as a command; v1.16.0, 2026-07) ([pkg.go.dev](https://pkg.go.dev/github.com/rogpeppe/go-internal/testscript)); interface + fake for the Incus client | `gofmt`, `go vet`, staticcheck, golangci-lint (standard; **not re-verified**). Compiler enforces types. |
| Rust | `cargo test` | `assert_cmd` 2.2.2 (2026-05) ([crates.io](https://crates.io/api/v1/crates/assert_cmd)); trait + fake | `clippy`, `rustfmt` (standard). Strongest static checks. |
| TypeScript | vitest 5.0.1 (2026-09) ([npm](https://registry.npmjs.org/vitest)) | `execa` 10.0.1 wrappers + vi.mock | `tsc --strict`, Biome 2.5.14 / ESLint |
| Bash | bats 1.13.0 (apt, observed) | PATH shims | shellcheck 0.11.0 (apt, observed); no types |
| Kotlin | Kotest/JUnit ([search](https://github.com/ajalt/clikt)) | fakes | detekt/ktlint; Native test runs are slow (LTO) |

---

## 7. TUI options (maturity, one line each)

- **Textual (Python)** 8.2.8 (2026-06-30, Python ≥ 3.9) ([PyPI](https://pypi.org/pypi/textual/json)); Textualize the company shut down in 2025 but the project continues under Will McGugan ([The future of Textualize](https://textual.textualize.io/blog/2025/05/07/the-future-of-textualize/)) — mature, single-maintainer risk.
- **Bubble Tea (Go)** v2.0.0 landed 2026-02 (first breaking release in six years, new `charm.land/bubbletea/v2` path), current v2.0.9 (2026-08-19) ([discussion #1374](https://github.com/charmbracelet/bubbletea/discussions/1374), [releases](https://github.com/charmbracelet/bubbletea/releases/latest), [pkg.go.dev](https://pkg.go.dev/charm.land/bubbletea/v2)) — very mature, company-backed.
- **ratatui (Rust)** 0.30.2 (2026-06-19), 52 M downloads, still 0.x ([crates.io](https://crates.io/api/v1/crates/ratatui)) — mature, immediate-mode.
- **Ink (TypeScript)** 7.1.1 (2026-07-16), React model; used by Claude Code, Gemini CLI and GitHub Copilot CLI ([npm](https://registry.npmjs.org/ink), [README](https://github.com/vadimdemedes/ink)) — mature.
- **Bash**: `gum`/`dialog`/`whiptail` only — not a TUI framework (reasoning).
- **Kotlin**: Mosaic 0.18.0 (Compose for terminals) ([GitHub](https://github.com/JakeWharton/mosaic)) — niche, pre-1.0.

---

## 8. Ergonomics for AI-agent-authored code

Published evidence (all with caveats):
- **SWE-PolyBench** (Amazon, 2,110 repo-level tasks in Java/JS/TS/Python): "All agents demonstrate their strongest performance in Python (20% to 24%)"; best per-language: Python 24.1%, Java 16.4%, TypeScript 13.0%, JavaScript 12.6% ([arXiv 2504.08703](https://arxiv.org/html/2504.08703v1)).
- **SWE-bench Multilingual** (300 tasks, 9 languages, SWE-agent + Claude 3.7 Sonnet): Rust 58.1%, Java 53.5%, PHP 48.8%, Ruby 43.2%, JS/TS 34.9%, **Go 31.0%**, C/C++ 28.6%; "Resolution rate varies by language" ([swebench.com](https://www.swebench.com/multilingual.html)).
- **Multi-SWE-bench** (ByteDance, 1,632 instances, 7 languages) exists but its abstract gives no per-language ranking ([arXiv 2504.02605](https://arxiv.org/abs/2504.02605)).
- **Aider polyglot** (225 Exercism problems: C++ 26, Go 39, Java 47, JS 49, Python 34, Rust 30) publishes no per-language breakdown ([aider blog](https://aider.chat/2024/12/21/polyglot.html)); third-party claims that Go/Rust are "hardest" there are unsourced — **unverified**.
- **Octoverse 2025**: TypeScript became #1 by contributors in Aug 2025 and GitHub attributes it to "typed languages working well with agent-assisted coding"; it cites a study claiming 94% of LLM compilation errors are type-check failures ([GitHub blog](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/)) — I could not find that sentence in the cited paper's abstract/PDF ([arXiv 2504.09246](https://arxiv.org/abs/2504.09246)); **unverified**.
- Vendor behaviour: Claude Code is TypeScript/Ink; Gemini CLI and Copilot CLI are Ink ([Ink README](https://github.com/vadimdemedes/ink)); OpenAI moved Codex CLI from TypeScript to Rust ([InfoQ](https://www.infoq.com/news/2025/06/codex-cli-rust-native-rewrite/)); Microsoft ported the TypeScript compiler to Go citing "syntactic simplicity" ([TS 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)). No Anthropic/OpenAI statement ranking languages for agent reliability was found.

Conclusion (explicitly reasoning, because the benchmarks disagree and are dominated by which repos they sampled): the data support only "Python is the safest bet; nothing shows Go, Rust or TS being unworkable". For *fewest iteration loops* on a small CLI, what matters is (a) corpus size (Python, TS, Go all huge; Rust smaller), (b) how much the compiler catches before a test run (Rust > Go ≈ TS > Python-with-strict-pyright > Python), and (c) how long each loop is (Go's compile is seconds; Rust's is longer and the borrow checker/async add semantic loops; Python/TS need a type checker run to get the same signal). Go's `gofmt`/`go vet`/single-way-to-do-things style is unusually agent-friendly; Rust is the only one where agents routinely need several compile rounds.

---

## 9. Contributor pool

- Stack Overflow 2025 (49k respondents): JavaScript 66%, Python 57.9%, Bash/Shell 48.7%, TypeScript 43.6%, Java 29.4%, Go 16.4%, Rust 14.8%, Kotlin 10.8%; Rust is the most admired language at 72% ([survey](https://survey.stackoverflow.co/2025/technology), [press release](https://stackoverflow.co/company/press/archive/stack-overflow-2025-developer-survey/)).
- Octoverse 2025 (contributors, Aug 2025): 1 TypeScript (2.64 M, +66.6% YoY), 2 Python (~2.55 M, +48.8%), 3 JavaScript, 4 Java, 5 C#, 6 PHP, 7 Shell, 8 C++, 9 HCL, 10 Go; Rust and Kotlin outside the top 10 ([GitHub blog](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/)).
- For the infra-minded slice: Incus, Lima, the Terraform provider and the Incus client are Go; the maintainer's Incus-related bug reports and upstream discussions will be in Go terms (reasoning).
- Blunt: your target users (people running Claude Code/Codex) will file issues, not PRs, whatever the language. The contributors who fix VM/Incus bugs are more likely to be Go-literate; the contributors who add packs write bash.

---

## 10. Long-term maintenance (one maintainer, years)

| Language | Stability guarantees | Dependency / tooling churn | Supply chain |
|---|---|---|---|
| Go | "programs written to the Go 1 specification will continue to compile and run correctly, unchanged, over the lifetime of that specification" ([go1compat](https://go.dev/doc/go1compat)). | Low; big stdlib; yaml.v3 archival shows churn is possible but rare. | `go.sum` + append-only checksum DB, minimal version selection, and "Neither fetching nor building code will let that code execute" (no install hooks) ([Go blog](https://go.dev/blog/supply-chain)). |
| Rust | "stability without stagnation"; editions are opt-in and "crates in one edition must seamlessly interoperate with those compiled with other editions" ([edition guide](https://doc.rust-lang.org/edition-guide/editions/index.html)). | Medium: serde_yaml deprecation and stalled forks, `abi_stable` stale, 0.x crates common; slow compiles. | crates.io phishing campaign 2025-09 ([Rust blog](https://blog.rust-lang.org/2025/09/12/crates-io-phishing-campaign)) and malicious `faster_log`/`async_println` crates ([Rust blog](https://blog.rust-lang.org/2025/09/24/crates.io-malicious-crates-fasterlog-and-asyncprintln)); `build.rs` executes at build time (reasoning). |
| Python | Annual releases; 2 years bug-fix + 3 years security per version ([PEP 602](https://peps.python.org/pep-0602/)); deprecations land yearly, and a tool must span the 3.12 (24.04) to 3.14 (26.04) range. | Medium: packaging keeps evolving (uv is the current answer), typing is gradual, pydantic v1→v2-style breaks happen. | PyPI 2025: phishing incident with four compromised accounts (07-31), token-exfiltration via GitHub Actions (09-16), domain-resurrection defences, Shai-Hulud advisory ([PyPI blog 2025](https://blog.pypi.org/archive/2025/)); sdists can run code at install (reasoning). |
| TypeScript | Node LTS lines get 12 months active + 18 months maintenance (~30 months) ([nodejs/release](https://github.com/nodejs/release)), so the runtime floor moves every two years; TypeScript 7 is a Go rewrite of the compiler (2026-07) — faster, but a major tooling transition ([TS 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)). | High: test/lint/bundler generations turn over every few years (reasoning). | 2025 was bad: chalk/debug takeover (~2 B weekly downloads affected), the self-replicating Shai-Hulud worm using install scripts; GitHub responded with mandatory 2FA, 7-day tokens and trusted publishing ([GitHub security plan](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/), [pnpm blog](https://pnpm.io/blog/2025/12/05/newsroom-npm-supply-chain-security)). |
| Bash | The language is frozen; that is also the problem: no types, no refactoring tools beyond shellcheck. | None. | None (but `curl \| sh` is the install). |
| Kotlin | JVM stable; Kotlin/Native declared stable in 1.9.20 but its library ecosystem is thin (kaml archived, no process API). | Gradle/Kotlin plugin churn (reasoning). | Maven Central (no notable 2025 incident found; **unverified**). |

---

## Scored matrix (1 = poor, 5 = excellent)

| Requirement | Python | Go | Rust | TypeScript | Bash | Kotlin |
|---|---|---|---|---|---|---|
| 1 Incus integration | 3 | 5 | 2 | 2 | 3 | 2 |
| 2 Interactive passthrough | 4 | 5 | 5 | 4 | 5 | 3 |
| 3 Distribution (24.04/26.04) | 3 | 5 | 5 | 2 | 5 | 2 |
| 4 Config + validation + secrets | 5 | 4 | 4 | 5 | 1 | 3 |
| 5 Extensibility (backend) | 5 | 4 | 3 | 5 | 2 | 3 |
| 6 Testing and quality | 4 | 5 | 5 | 4 | 2 | 4 |
| 7 TUI | 5 | 5 | 5 | 4 | 2 | 2 |
| 8 AI-agent ergonomics | 5 | 4 | 3 | 4 | 3 | 3 |
| 9 Contributor pool | 5 | 4 | 3 | 5 | 4 | 2 |
| 10 Long-term maintenance | 3 | 5 | 4 | 2 | 2 | 3 |
| **Unweighted total** | **42** | **46** | **39** | **37** | **29** | **27** |

One-line justifications:

1. Incus integration — Python 3: no official client, pylxd "expected to work" but untested upstream, generated SDKs immature, so you wrap the CLI. Go 5: official client, literally the CLI's own package, exec/files/events/console covered. Rust 2: one auto-generated 0.1.x crate with 56 downloads. TS 2: two small community packages. Bash 3: CLI JSON + jq works but nothing structured beyond that. Kotlin 2: nothing, and JVM HTTP lacks unix sockets.
2. Interactive passthrough — Python 4: stdio inherits by default, `pty` in stdlib, only trap is the parent's KeyboardInterrupt. Go 5: direct fd hand-off, creack/pty, reference code exists in-language. Rust 5: inherit by default, portable-pty, Codex proves it. TS 4: `stdio:'inherit'` fine, node-pty needs native builds, Node re-raises signals. Bash 5: native. Kotlin 3: JVM `inheritIO` ok, Native needs cinterop.
3. Distribution — Python 3: interpreter present but PEP 668 forces pipx/uv (a second bootstrap) and two interpreter versions to support. Go 5: one static binary, installer/apt/deb via GoReleaser. Rust 5: same via cargo-dist/binstall. TS 2: no Node on the host, apt Node 18 on 24.04 is EOL, bundled binaries are 50–95 MB; both major AI CLIs abandoned "install Node first". Bash 5: nothing to install. Kotlin 2: needs a JRE, or a heavy Native toolchain few can build.
4. Config — Python 5: tomllib stdlib, PyYAML/ruamel, pydantic with JSON Schema. Go 4: goccy/go-yaml is solid but yaml.v3 was just archived; validation is manual. Rust 4: toml is best-in-class, YAML is fragmented post-serde_yaml. TS 5: yaml + smol-toml + zod. Bash 1: yq/jq, no validation. Kotlin 3: ktoml fine, kaml archived.
5. Extensibility — Python 5: entry points in stdlib. Go 4: compiled-in registry is idiomatic and Lima/vz are Go packages; go-plugin if ever needed. Rust 3: traits/features easy, dynamic loading hard. TS 5: dynamic import. Bash 2: `source`. Kotlin 3: ServiceLoader on JVM only.
6. Testing/quality — Python 4: pytest + pytest-subprocess + ruff/mypy/pyright, but typing must be enforced. Go 5: go test, race detector, testscript, compiler-enforced types. Rust 5: cargo test, assert_cmd, clippy. TS 4: vitest/tsc/biome. Bash 2: bats + shellcheck only. Kotlin 4: Kotest, but slow Native test loops.
7. TUI — Python 5: Textual mature (single maintainer). Go 5: Bubble Tea v2. Rust 5: ratatui. TS 4: Ink (powers Claude Code). Bash 2: gum/whiptail. Kotlin 2: Mosaic pre-1.0.
8. AI ergonomics — Python 5: every benchmark's best language, biggest corpus. Go 4: huge corpus, simplest syntax, fast compile loop, but lower SWE-bench Multilingual score. Rust 3: highest Multilingual score yet longest compile/borrow-checker loops. TS 4: Octoverse #1 for agent-written code, typed, but lower than Python on SWE-PolyBench. Bash 3: agents write it fluently and get quoting/`set -e` wrong silently. Kotlin 3: decent corpus, Native-specific idioms rare.
9. Contributor pool — Python 5 / TS 5: the target audience's languages (SO 58%/44%, Octoverse #2/#1). Go 4: SO 16%, Octoverse #10, but the Incus/Lima/infra crowd. Rust 3: SO 15%, enthusiast-heavy. Bash 4: everyone reads it, fewer write it well. Kotlin 2: SO 11%, Android-centric.
10. Long-term — Python 3: annual deprecations, packaging churn, gradual typing. Go 5: Go 1 promise, no install hooks, checksum DB. Rust 4: stability promise, but crate churn and slow builds. TS 2: 30-month runtime lines, 2025 npm worm year, tooling turnover. Bash 2: frozen but unrefactorable. Kotlin 3: JVM stable, Native ecosystem thin.

Weighting note: for this project the discriminating rows are 1, 3, 8 and 10 (the tool is a thin orchestrator that must install cleanly on a fresh Ubuntu box, be written mostly by agents, and be maintained by one person for years). Rows 4, 5 and 7 are near-ties and row 2 is a tie between everything except Kotlin.

---

## Recommendation

**Write the host CLI in Go.** Keep the guest provisioner and the packs in bash.

Why, in order of weight:
1. Incus's only official client is Go, and it is the same package the `incus` CLI is built from — exec with a control websocket, file push, events, operations and even the VGA-console launcher are already written, typed, Apache-2.0, and versioned with the server you target (7.0 LTS through 2031). Every other language starts from "wrap the CLI and parse JSON", which is fine today but becomes the ceiling when you want events, progress, typed errors, or a second backend.
2. Distribution is one static binary. Both vendors of your users' tools converged on that: Claude Code recommends a native installer whose binary "does not itself invoke Node", and Codex was rewritten for "zero-dependency install". Go gets you there without a second build system (no PyInstaller, no Bun bundling).
3. Maintenance profile matches "slow, methodical, one maintainer": the Go 1 compatibility promise, a large stdlib, no install-time code execution in the module system, and a compiler + `gofmt` + `go vet` loop that gives an AI agent unambiguous, fast feedback. The future backends (Lima, Apple Virtualization via `vz`) are Go packages, so the "pluggable backend" is a compiled-in interface, not a plugin system.
4. Rust would buy static guarantees the project does not need (it waits minutes on VM boots) at the price of no Incus client, slower agent iteration, and a YAML ecosystem in flux. TypeScript loses on distribution and supply-chain risk on a fresh Ubuntu host. Kotlin has no client, no process API on Native, and a 2019-era apt package. Bash is fine at 130 lines and will not be fine at 1,500 lines with YAML config, per-pack doctors and snapshots.

Practical shape: `internal/incus` wraps `github.com/lxc/incus/v7/client` behind a small `Backend` interface; interactive sign-ins call `incus exec -t` and `incus console --type vga` via `os/exec` with `*os.File` stdio (or reuse the CLI's exec/console code), because reimplementing raw-mode/resize/viewer-launch buys nothing; `GetEvents` + `AddChannel` replaces the `incus list -c s -f csv` polling; `testscript` covers the CLI surface, and one GitHub Actions job installs Incus from Zabbly on a `/dev/kvm`-enabled `ubuntu-latest` runner for a real boot test.

**The single strongest counter-argument: Python.** Your audience and your coding agents are Python-first; Python wins or ties rows 4, 5, 7, 8 and 9; every Ubuntu host already has a working interpreter; and the honest truth about row 1 is that *the CLI is the reference implementation in every language including Go* — for exec-with-TTY and the VGA console you will shell out anyway, so the official client's advantage shrinks to events, typed errors and file push, which a 150-line `httpx`+`websockets` helper covers. A Python tool installed with `uv tool install` (uv fetches its own Python, so 3.12 vs 3.14 stops mattering) is one `curl | sh` line away from the same user experience as a Go binary. If the maintainer is measurably faster and more careful reviewing Python than Go — which for a Python/TS person is plausible — that outweighs Go's structural advantages for a tool of this size.

---

## What would change the answer

- **Run a one-week spike before deciding**: port the current 130 lines to both Go and Python with your usual agent workflow; count compile/type/test loops per feature and how many bugs the reviewer caught. If Python wins clearly on your own throughput, take Python + uv; the structural Go advantages are real but not decisive at this size.
- **If the Incus project blesses a Python client** (e.g. `pyincusd` gets upstream endorsement or pylxd formally supports Incus) — Python's row 1 rises to 4 and the totals tie.
- **If you will ship a `.deb` in your own apt repo anyway** (you already ask users to add Zabbly's) — apt resolves Python dependencies, Python's distribution score rises to 4, and the Go lead narrows to rows 1 and 10.
- **If macOS becomes a primary target with Lima or Apple Virtualization** — Go strengthens further (Lima and `vz` are Go; Python would shell out to `limactl`).
- **If a TUI-first product (a dashboard for many agent VMs) becomes the goal** — no change in ranking (Bubble Tea v2, Textual and ratatui are all mature), but Textual's ability to serve the same UI in a browser is a unique Python feature that could matter.
- **If you need runtime plugins written by third parties** (not just compiled-in backends) — Python/TS entry points beat Go's go-plugin ceremony.
- **If the tool must also run inside guests or on minimal hosts without Python** (Alpine, containers) — Go/Rust only.
- **If you decide the host CLI should embed a hypervisor driver or sandboxing itself** (what pushed Codex to Rust) — Rust becomes worth its iteration cost; nothing in the current roadmap requires it.
- **If Node becomes preinstalled on Ubuntu or your users are overwhelmingly on machines with Node already** — TypeScript's row 3 rises, but the 2025 npm supply-chain record would still keep it below Go/Python for a tool whose whole purpose is isolation.
- **If the roadmap stalls at "config file + a few packs"** — stay in Bash with bats + shellcheck and `jq`; the rewrite is only justified by the snapshots/doctor/backend/TUI items.

---

## Source list (primary)

- Incus docs: [REST API](https://linuxcontainers.org/incus/docs/main/rest-api/), [Events](https://linuxcontainers.org/incus/docs/main/events/), [Access files](https://linuxcontainers.org/incus/docs/main/howto/instances_access_files/), [instance-exec](https://linuxcontainers.org/incus/docs/main/instance-exec/), [Installing](https://linuxcontainers.org/incus/docs/main/installing/), [Third-party tools](https://linuxcontainers.org/incus/docs/main/third_party/), [7.0 LTS announcement](https://discuss.linuxcontainers.org/t/incus-7-0-lts-has-been-released/26641)
- Incus source: [client pkg](https://pkg.go.dev/github.com/lxc/incus/v7/client), [client/incus_instances.go](https://raw.githubusercontent.com/lxc/incus/main/client/incus_instances.go), [cmd/incus/exec.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/exec.go), [cmd/incus/console.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/console.go), [cmd/incus/list.go](https://raw.githubusercontent.com/lxc/incus/main/cmd/incus/list.go), [shared/api](https://pkg.go.dev/github.com/lxc/incus/v7/shared/api#InstanceExecPost), [rest-api.yaml](https://raw.githubusercontent.com/lxc/incus/main/doc/rest-api.yaml)
- Python clients: [pylxd forum thread](https://discuss.linuxcontainers.org/t/moving-to-incus-for-users-of-pylxd/18601), [pylxd PyPI](https://pypi.org/pypi/pylxd/json), [pyincusd](https://github.com/anonhostpi/pyincusd), [incus-sdk](https://pypi.org/project/incus-sdk/), [Ansible incus connection](https://docs.ansible.com/ansible/latest/collections/community/general/incus_connection.html), [httpx UDS](https://www.python-httpx.org/advanced/transports/), [websockets unix_connect](https://websockets.readthedocs.io/en/stable/reference/asyncio/client.html)
- Other clients: [incus-client crate](https://crates.io/api/v1/crates/incus-client), [npm search](https://registry.npmjs.org/-/v1/search?text=incus&size=15)
- Process/TTY docs: [Python subprocess](https://docs.python.org/3/library/subprocess.html), [Go os/exec](https://pkg.go.dev/os/exec#Cmd), [creack/pty](https://github.com/creack/pty), [Rust Command](https://doc.rust-lang.org/std/process/struct.Command.html), [Node child_process](https://nodejs.org/api/child_process.html), [node-pty prebuilt fork](https://github.com/homebridge/node-pty-prebuilt-multiarch), [Kotlin/Native subprocess thread](https://discuss.kotlinlang.org/t/idiomatic-way-to-spawn-subprocesses/27222)
- Distribution: [Ubuntu 24.04 announcement](https://canonical.com/blog/canonical-releases-ubuntu-24-04-noble-numbat), [Ubuntu 26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/), [noble pipx](https://packages.ubuntu.com/noble/pipx), [noble nodejs](https://packages.ubuntu.com/noble/nodejs), [noble golang-go](https://packages.ubuntu.com/noble/golang-go), [PEP 668](https://peps.python.org/pep-0668/), [uv tools](https://docs.astral.sh/uv/guides/tools/), [uv Python versions](https://docs.astral.sh/uv/concepts/python-versions/), [GoReleaser](https://goreleaser.com/), [cargo-dist](https://github.com/axodotdev/cargo-dist), [cargo-binstall](https://github.com/cargo-bins/cargo-binstall), [Bun executables](https://bun.com/docs/bundler/executables), [Claude Code setup](https://code.claude.com/docs/en/setup), [Codex Rust rewrite (InfoQ)](https://www.infoq.com/news/2025/06/codex-cli-rust-native-rewrite/), [devclass](https://www.devclass.com/ai-ml/2025/06/02/nodejs-frustrating-and-inefficient-openai-rewrites-ai-coding-tool-in-rust/1619589), [Kotlin/Native compile time](https://kotlinlang.org/docs/native-improving-compilation-time.html), [Node release schedule](https://github.com/nodejs/release)
- Config: [tomllib](https://docs.python.org/3/library/tomllib.html), [go-yaml archived](https://github.com/go-yaml/yaml), [gh CLI migration issue](https://github.com/cli/cli/issues/10784), [serde_yaml](https://crates.io/api/v1/crates/serde_yaml), [serde-yaml alternatives thread](https://users.rust-lang.org/t/serde-yaml-deprecation-alternatives/108868), [go-keyring](https://github.com/zalando/go-keyring), [kaml archived](https://github.com/charleskorn/kaml), [ktoml](https://github.com/orchestr7/ktoml), npm/PyPI/crates registry JSON for versions
- Extensibility: [importlib.metadata](https://docs.python.org/3/library/importlib.metadata.html), [go-plugin](https://github.com/hashicorp/go-plugin), [Go plugin package](https://pkg.go.dev/plugin), [Lima Go module](https://pkg.go.dev/github.com/lima-vm/lima/v2/cmd/limactl), [Code-Hex/vz](https://github.com/Code-Hex/vz), [abi_stable](https://crates.io/api/v1/crates/abi_stable)
- CI/testing: [GitHub KVM changelog 2024-04-02](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/), [4-vCPU runners](https://github.blog/news-insights/product-news/github-hosted-runners-double-the-power-for-open-source/), [runner-images#12933](https://github.com/actions/runner-images/issues/12933), [testscript](https://pkg.go.dev/github.com/rogpeppe/go-internal/testscript), [ty](https://github.com/astral-sh/ty)
- TUI: [Textual PyPI](https://pypi.org/pypi/textual/json), [Textualize future](https://textual.textualize.io/blog/2025/05/07/the-future-of-textualize/), [Bubble Tea v2 discussion](https://github.com/charmbracelet/bubbletea/discussions/1374), [Bubble Tea releases](https://github.com/charmbracelet/bubbletea/releases/latest), [ratatui](https://crates.io/api/v1/crates/ratatui), [Ink](https://github.com/vadimdemedes/ink), [Mosaic](https://github.com/JakeWharton/mosaic)
- Benchmarks/rankings: [SWE-PolyBench](https://arxiv.org/html/2504.08703v1), [SWE-bench Multilingual](https://www.swebench.com/multilingual.html), [Multi-SWE-bench](https://arxiv.org/abs/2504.02605), [Aider polyglot](https://aider.chat/2024/12/21/polyglot.html), [Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/), [type-constrained generation paper](https://arxiv.org/abs/2504.09246), [Stack Overflow 2025](https://survey.stackoverflow.co/2025/technology), [TypeScript 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)
- Maintenance/supply chain: [Go 1 compat](https://go.dev/doc/go1compat), [Go supply chain](https://go.dev/blog/supply-chain), [Rust editions](https://doc.rust-lang.org/edition-guide/editions/index.html), [PEP 602](https://peps.python.org/pep-0602/), [PyPI blog 2025](https://blog.pypi.org/archive/2025/), [crates.io phishing](https://blog.rust-lang.org/2025/09/12/crates-io-phishing-campaign), [malicious crates](https://blog.rust-lang.org/2025/09/24/crates.io-malicious-crates-fasterlog-and-asyncprintln), [npm security plan](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/), [pnpm on Shai-Hulud](https://pnpm.io/blog/2025/12/05/newsroom-npm-supply-chain-security)
