# 1. Docker Sandboxes (`sbx`)

## Core
- A sandbox is a microVM with its own kernel, its own Docker daemon, filesystem and network [src](https://docs.docker.com/ai/sandboxes/); Docker built one VMM per OS (Apple Hypervisor.framework, Windows Hypervisor Platform, KVM) and runs a private Docker engine inside the VM so agents can `docker build/run/compose` without Docker-in-Docker privileges [src](https://www.docker.com/blog/why-microvms-the-architecture-behind-docker-sandboxes/).
- Fixed, infrastructure-enforced pieces: the VM boundary, the private Docker daemon, a host-side forward proxy that carries all outbound TCP, enforces network policy and injects credentials, and a host-side MCP gateway; the workspace is exposed via filesystem passthrough at the same absolute path as on the host (virtiofs caching on by default) [src](https://docs.docker.com/ai/sandboxes/architecture/). Security is described as five layers (hypervisor, network, Docker Engine, workspace, credential isolation); credential values "never enter the VM"; UDP/ICMP are blocked; outbound TCP is deny-by-default [src](https://docs.docker.com/ai/sandboxes/security/).
- The CLI is the standalone `sbx` (proprietary binaries; brew/winget/apt; "YOLO mode by default") [src](https://github.com/docker/sbx-releases). Lineage: Nov 25 2025 experimental `docker sandbox run <agent>` in Docker Desktop 4.50+, container-based with bind-mounted cwd, Claude Code + Gemini only, microVM on the roadmap [src](https://www.docker.com/blog/docker-sandboxes-a-new-approach-for-coding-agent-safety/); Desktop 4.58.0 (2026-01-26) shipped the microVM version; 4.80.0 (2026-06-29): "The experimental `docker sandbox` plugin has been removed. Migrate to `docker sbx`" [src](https://docs.docker.com/desktop/release-notes/); standalone `sbx` launched March 31 2026 [src](https://www.docker.com/blog/docker-sandboxes-run-agents-in-yolo-mode-safely/); latest v0.43.0 on Sept 15 2026 [src](https://github.com/docker/sbx-releases/releases). Free for commercial use; sign-in required; org governance is paid; telemetry opt-out via `SBX_NO_TELEMETRY=1` [src](https://docs.docker.com/ai/sandboxes/faq/).

## Default experience (first run, no args)
- `sbx` with no arguments opens a dashboard of sandboxes; `sbx run claude` in a project dir mounts the cwd read-write, reuses an existing sandbox for the same path, `sbx create` creates without attaching [src](https://docs.docker.com/ai/sandboxes/usage/).
- First run prompts for a network preset: "Open — All network traffic allowed", "Balanced — Default deny, with common dev sites allowed" (recommended), "Locked Down — All network traffic blocked unless you allow it" [src](https://docs.docker.com/ai/sandboxes/get-started/).
- Claude runs as `claude --dangerously-skip-permissions` from image `docker/sandbox-templates:claude-code`; `~/.claude` is deliberately not visible inside, only project-level config [src](https://docs.docker.com/ai/sandboxes/agents/claude-code/). Auth: `/login` OAuth whose token stays on the host, or `sbx secret set anthropic` [src](https://docs.docker.com/ai/sandboxes/get-started/). No approval prompts because "The sandbox itself is the safety boundary" [src](https://docs.docker.com/ai/sandboxes/faq/).
- Agents: Claude Code, Codex, Copilot, Cursor, Devin, Docker Agent, Droid, Gemini, Kiro, OpenCode, plus `shell` ("agent-less sandbox") [src](https://docs.docker.com/ai/sandboxes/agents/).

## Extension unit and interface
- Two units: **templates** (Docker images built from a Dockerfile or saved from a running sandbox, pushed to a registry, pulled at creation) and **kits** (YAML applied at creation) [src](https://docs.docker.com/ai/sandboxes/customize/). Docker Agent docs define a template as "the OCI image the sandbox VM boots from", e.g. `docker/sandbox-templates:shell-docker` [src](https://docker.github.io/docker-agent/configuration/sandbox/).
- Kit = `spec.yaml` (+ optional `files/`), `kind: mixin` (extend an agent) or `kind: sandbox` (define an agent); fields: `schemaVersion`, `name`, `extends`, `permissions.network.allow/deny`, `credentials` (proxy-injected via sentinel value), `environment.variables`, `setup.install` (once at creation), `setup.startup` (idempotent per start), `agentInstructions.content`, `sandbox.image`; subcommands `sbx kit validate/inspect/pack/push/sign/verify`; must not target sandbox-managed paths like `~/.claude.json`; install commands run as root [src](https://docs.docker.com/ai/sandboxes/customize/kits/). A kit's `permissions.network.allow` is "its complete outbound network contract"; a TCK checks validation, policy, credentials, env, file injection and security mounts, and e2e tests run under deny-all while `sbx policy log` reveals blocked hosts [src](https://github.com/docker/sbx-kits-contrib). There is no dedicated "check/doctor" hook; verification is `sbx kit validate` plus the TCK (same source).
- Secrets: `sbx secret set <service>` for built-ins (anthropic, openai, github, google, cursor, droid, groq, mistral, xai), `--command 'gh auth token'`, `--ref` for 1Password/AWS SM, `set-custom --host --env --value`; OAuth runs on host [src](https://docs.docker.com/ai/sandboxes/configuration/credentials/).

## Discovery and distribution
- Kit sources: local path or zip, `git+https://...#ref=&dir=`, OCI registries; official kits are `docker.io/sbx/<name>-kit`; only Docker Hub kits are allowed by default (`kit.allowedSources`) [src](https://docs.docker.com/ai/sandboxes/customize/kits/). Every top-level dir with `spec.yaml` in the contrib repo auto-publishes as `docker.io/sbx/<kit>-kit:latest`; signed commits required [src](https://github.com/docker/sbx-kits-contrib). v0.43 added offline resolution of commit-pinned git kits and "OAuth credential gates" so third-party kits cannot inherit built-in agent trust [src](https://github.com/docker/sbx-releases/releases).

## Overriding defaults
- Network: `sbx policy ls/allow`, rules per machine or org-managed, org rules take precedence [src](https://docs.docker.com/ai/sandboxes/security/defaults); with org governance "local allow rules set with `sbx policy` are no longer evaluated" [src](https://docs.docker.com/ai/sandboxes/faq/). Workspaces: extra mounts with `:ro`, `--clone`, mountless; `-e/--env-file`; `--publish`/`sbx ports`; packages persist across restarts [src](https://docs.docker.com/ai/sandboxes/usage/). Settings like `clipboard.imagePaste` explicitly "relax the sandbox's isolation" [src](https://docs.docker.com/ai/sandboxes/faq/). Config subpages: credentials, environment files, GPU passthrough, registry mirror, upstream proxy [src](https://docs.docker.com/ai/sandboxes/configuration/).

## Lessons
- The preview-to-microVM rewrite and CLI rename hurt: a user upgrading Desktop 4.64→4.67 found docs "migrat[ed] from `docker sandbox` commands to a new `sbx` CLI... without any notice, any migration steps" and the `docker sandbox save` snapshot feature gone ("a DEAL BREAKER") [src](https://forums.docker.com/t/docker-sandbox-completely-changed-in-a-minor-update/151458).
- Early review: velocity gain from no prompts, but perf degradation a "deal breaker" in several scenarios, 1Password ssh-agent signing broken, worktree mode litters `.sbx/`, Balanced excluded doc sites so the author fell back to Open [src](https://andrewlock.net/running-ai-agents-safely-in-a-microvm-using-docker-sandbox/). Docker itself warns Balanced defaults "include broad wildcards" like `*.googleapis.com` [src](https://docs.docker.com/ai/sandboxes/security/).
- Extension-model friction visible in issues: agent kits exist only as full sandbox kits, so users wanting "multiple agent harnesses on the same sandbox" must reverse-engineer them (#594) [src](https://github.com/docker/sbx-releases/issues/594); template+kit+policy layering is opaque, prompting a request for `sbx kit inspect --resolved` (#606) [src](https://github.com/docker/sbx-releases/issues/606); plus regressions in custom-secret substitution and mounts in 0.43 [src](https://github.com/docker/sbx-releases/issues).
- Opinionated calls that made it usable: one command, three named presets, credentials never in the VM, YOLO by default, host config intentionally not synced.

# 2. Dev Containers

## Core
- `devcontainer.json` with three modes: `image`, `build.dockerfile`, or `dockerComposeFile`+`service`; no default image is defined by the spec [src](https://containers.dev/implementors/json_reference/). Lifecycle order: `initializeCommand` (host) → `onCreateCommand` → `updateContentCommand` → `postCreateCommand` → `postStartCommand` → `postAttachCommand`, with `waitFor` defaulting to `updateContentCommand` (same source).
- Reference implementation: the `devcontainer` CLI (`up`, `build`, `exec`, `run-user-commands`, `read-configuration`, `features test/package/publish/info`, `templates apply/publish/metadata`, `outdated`, `upgrade`) [src](https://github.com/devcontainers/cli). Supporting tools: VS Code (full), Visual Studio 17.4 (C++), IntelliJ "early support", Emacs, Codespaces, CodeSandbox (rootless Podman), DevPod, Ona/Gitpod [src](https://containers.dev/supporting).
- Lockfile `devcontainer-lock.json` records `version`, `resolved`, `integrity`, `dependsOn` per Feature for reproducibility, cachability and trust-on-first-use security [src](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-lockfile.md); an April 2026 issue proposed generating it by default with `--no-lockfile`/`--frozen-lockfile` (closed) [src](https://github.com/devcontainers/cli/issues/1195).

## Default experience
- Codespaces with no config uses the "universal" image (Python, Node, PHP, Java, Go, C++, Ruby, .NET, JupyterLab, Conda, git, gh) [src](https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces/adding-a-dev-container-configuration/introduction-to-dev-containers). The minimal opinionated base is `mcr.microsoft.com/devcontainers/base:ubuntu`: Git, zsh, Oh My Zsh, non-root `vscode` user with sudo [src](https://github.com/devcontainers/images/blob/main/src/base-ubuntu/README.md); images are "built with dev container features" [src](https://github.com/devcontainers/images), chiefly `common-utils` (zsh, Oh My Zsh, non-root user, package upgrade; "used in many of the dev container images") [src](https://github.com/devcontainers/features/blob/main/src/common-utils/README.md). Starter Templates: ubuntu, alpine, debian, docker-in-docker, python, node, go, rust, java, .NET, etc. at `ghcr.io/devcontainers/templates/<id>` [src](https://github.com/devcontainers/templates).

## Extension unit and interface
- **Feature** = folder with `devcontainer-feature.json` + `install.sh`. Manifest: `id`, `version`, `name`, `description`, `documentationURL`, `licenseURL`, `keywords`, `options` (`type`, `proposals`, `enum`, `default`), `containerEnv`, `privileged`, `init`, `capAdd`, `securityOpt`, `entrypoint`, `customizations`, `dependsOn`, `installsAfter`, `legacyIds`, `deprecated`, `mounts`, plus the five container lifecycle hooks (Feature hooks run before user hooks) [src](https://containers.dev/implementors/features/). Contract: `install.sh` runs as root at image build with `_REMOTE_USER`, `_CONTAINER_USER`, `_REMOTE_USER_HOME`, `_CONTAINER_USER_HOME` and options uppercased as env vars; one layer per Feature; `dependsOn` is hard (with options), `installsAfter` soft, `overrideFeatureInstallOrder` user-level; circular deps fail (same source). No "check" hook exists; verification is `devcontainer features test` [src](https://github.com/devcontainers/cli).
- **Template** = `devcontainer-template.json` (`id` = dir name, `version`, `name`, `platforms`, `publisher`, `options`, `optionalPaths`) + `.devcontainer.json`; `${templateOption:x}` substitution; templates reference Features in their devcontainer.json [src](https://containers.dev/implementors/templates/).

## Discovery and distribution
- Features: OCI registry is primary (`<registry>/<namespace>/<id>[:version]`, tags major/minor/patch/latest), `.tgz` URL (`devcontainer-feature-<id>.tgz`), or local `./feature`; `devcontainer-collection.json` and `dev.containers.metadata` annotation [src](https://containers.dev/implementors/features-distribution/). Templates: `devcontainer templates publish -r <registry> -n <namespace> ./src`, `templates apply -t ... -a ...`, media types `application/vnd.devcontainers` [src](https://containers.dev/implementors/templates-distribution/). Listing: >350 collections crawled for liveness, added via PR to `collection-index.yml` [src](https://containers.dev/collections). Starter repos + GitHub Action to GHCR [src](https://code.visualstudio.com/blogs/2022/09/15/dev-container-features).

## Overriding defaults
- Per-feature options (`"ghcr.io/x/y/go:1.18": {"optionA": "value"}`, string shorthand = version), `overrideFeatureInstallOrder`, `remoteUser`/`containerUser`, `mounts`, `workspaceMount`, `hostRequirements`, `${localEnv:VAR:default}`, `${devcontainerId}` [src](https://containers.dev/implementors/json_reference/); template options prompted at apply time [src](https://containers.dev/implementors/templates/); lockfile `outdated`/`upgrade` [src](https://github.com/devcontainers/cli).

## Lessons
- Features replaced the `script-library` because it lacked independent publishing, versioning and customization; the two-file model plus OCI distribution "transformed Feature development from a closed, repository-dependent process into an open... model" [src](https://code.visualstudio.com/blogs/2022/09/15/dev-container-features); vscode-dev-containers was archived Nov 2023 [src](https://github.com/microsoft/vscode-dev-containers).
- Performance is the standing complaint: single-layer builds invalidate everything (2022 proposal still open) [src](https://github.com/devcontainers/spec/issues/21); object ordering breaks cache and pinning is awkward [src](https://github.com/devcontainers/spec/discussions/327); no `RUN`-scoped caches, so keep core tooling in a base image and use `postCreateCommand` + volumes for extras [src](https://www.kenmuse.com/blog/improving-dev-container-feature-performance/).
- Coupling/complexity: `customizations` is product-specific and only VS Code has full support [src](https://containers.dev/supporting); reviews cite slow shared-folder I/O on macOS/Windows, maintenance burden, Docker barrier, arm64/x86 mismatches [src](https://blog.ugurelveren.com/post/dev-containers-fair-review-simple/). Claude Code treats a dev container as "a convention rather than an enforcement boundary" and ships one with a default-deny firewall [src](https://code.claude.com/docs/en/sandbox-environments).

# 3. Docker Compose

## Core
- Application model: services, networks, volumes, configs, secrets, project; default files `compose.yaml` (preferred), `compose.yml`, `docker-compose.yaml`, `docker-compose.yml` (compat) — "Compose prefers the canonical `compose.yaml`" [src](https://docs.docker.com/compose/intro/compose-application-model/). The CLI walks the working directory and parents; `COMPOSE_FILE` equals `-f`; project name precedence: `-p`, `COMPOSE_PROJECT_NAME`, top-level `name`, directory basename [src](https://docs.docker.com/reference/cli/docker/compose/). `version` is "only informative" and warns [src](https://docs.docker.com/reference/compose-file/version-and-name/).
- History: v1 Python 2014, v2 Go plugin 2020 ("ignores the `version` top-level element"), v5 2025 adds a Go SDK; formats 2.x/3.x "merged into the Compose Specification" [src](https://docs.docker.com/compose/intro/history/); spec announced April 7 2020 with AWS and Microsoft under open governance [src](https://www.docker.com/blog/announcing-the-compose-specification/); Docker Compose is the reference implementation among Kompose, nerdctl, Podman Compose etc. [src](https://github.com/compose-spec/compose-spec); spec "merges the 2.x and 3.x versions and is implemented by Compose 1.27.0+" [src](https://docs.docker.com/reference/compose-file/legacy-versions/).

## Default experience
- `docker compose up` reads `compose.yaml` plus optional `compose.override.yaml` automatically [src](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/); services without `profiles` always start [src](https://docs.docker.com/compose/how-tos/profiles/).

## Extension unit and interface
- Override/`-f` merge (files merge in order; paths relative to the first file; inspect with `docker compose config`) [src](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/).
- `extends: {file, service}`: mappings key-override, sequences unioned, scalars main-wins; referenced `depends_on`/`volumes`/`secrets` etc. are "not automatically import[ed]"; circular refs error [src](https://docs.docker.com/reference/compose-file/services/); not supported by `docker stack deploy` [src](https://docs.docker.com/compose/how-tos/multiple-compose-files/extends/).
- `include:` (Compose v2.20.0, Aug 1 2023): each included file "is loaded as an individual Compose application model, with its own project directory"; long form `path`/`project_directory`/`env_file` [src](https://docs.docker.com/reference/compose-file/include/), [src](https://www.docker.com/blog/improve-docker-compose-modularity-with-include/); remote `oci://` sources; note the how-to says conflicts "error" [src](https://docs.docker.com/compose/how-tos/multiple-compose-files/include/) while the reference says "warning" [src](https://docs.docker.com/reference/compose-file/include/) — inconsistent.
- `profiles:` for on-demand services; `x-` fields are "the sole exception where Compose silently ignores unrecognized fields", combined with YAML anchors; known prefixes `docker`, `kubernetes` [src](https://docs.docker.com/reference/compose-file/extension/).

## Discovery and distribution
- In-repo files only, plus `include` of OCI artifacts (above). Env: `.env`/`--env-file` are interpolation sources, not container env, which needs `environment` or `env_file` [src](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/).

## Overriding defaults
- Merge rules: mappings merge, sequences append; `command`, `entrypoint`, `healthcheck.test` replace; volumes/secrets/configs merge by `target`, ports by `{ip,target,published,protocol}`; `!reset` and `!override` tags escape the rules [src](https://docs.docker.com/reference/compose-file/merge/). Env precedence: `run -e` > interpolated `environment`/`env_file` > `environment` > `env_file` > Dockerfile `ENV` [src](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/). Profiles via `--profile`/`COMPOSE_PROFILES`; targeting a service auto-enables its profile; `down --profile` also stops unprofiled services [src](https://docs.docker.com/compose/how-tos/profiles/).

## Lessons
- V1 stopped receiving updates July 2023; GitHub removed it from runners July 9 2024 [src](https://github.blog/changelog/2024-04-10-github-hosted-runner-images-deprecation-notice-docker-compose-v1/); Docker's own post cited June 2023 and a Desktop symlink so `docker-compose` scripts keep working [src](https://www.docker.com/blog/new-docker-compose-v2-and-v1-deprecation/).
- The v2/v3 split was a mistake the spec undid; `extends` was dropped from v3 ("Support for `extends` is not implemented yet", 2017) [src](https://github.com/docker/compose/issues/4315) and docs still confused users about its status in 2023 [src](https://github.com/docker/docs/issues/18494). `include` was added because `extends` "only reuses a single service" and `-f` merging breaks relative paths [src](https://www.docker.com/blog/improve-docker-compose-modularity-with-include/).
- Merge surprises: override ports are appended, not replaced [src](https://akrabat.com/changing-port-maps-in-docker-compose/); `!reset`/`!override` are lost in `docker compose config` output (closed "not planned") [src](https://github.com/docker/compose/issues/12162).

# 4. Coder

## Core
- "Templates are written in Terraform and define the underlying infrastructure that all Coder workspaces run on" [src](https://coder.com/docs/admin/templates). Provider resources: `coder_agent`, `agent_instance`, `ai_task`, `app`, `devcontainer`, `env`, `external_agent`, `metadata`, `script` [src](https://github.com/coder/terraform-provider-coder/tree/main/docs/resources); data sources: `external_auth`, `parameter`, `provisioner`, `task`, `workspace`, `workspace_owner`, `workspace_preset`, `workspace_tags` [src](https://github.com/coder/terraform-provider-coder/tree/main/docs/data-sources).
- Roles: Template Admin manages all templates but cannot create workspaces; Members create their own workspaces; custom roles premium (v2.16+) [src](https://coder.com/docs/admin/users/groups-roles); only Template Admin or above creates templates [src](https://coder.com/docs/admin/templates/creating-templates).
- Core user-side personalization: `coder dotfiles <repo>` runs the first of `install.sh`, `install`, `bootstrap.sh`, `bootstrap`, `script/bootstrap`, `setup.sh`, `setup`, `script/setup`; templates may run `~/personalize` [src](https://coder.com/docs/user-guides/workspace-dotfiles). Dev containers integration (v2.24+) uses `@devcontainers/cli` + Docker in the workspace, Envbuilder as fallback, Linux only; admins control autostart, developers own `devcontainer.json` [src](https://coder.com/docs/user-guides/devcontainers).

## Default experience
- Template builder (recommended, on by default): pick base infra (Docker, AWS EC2, Kubernetes...), base parameters, registry modules "grouped by category and filtered for compatibility", module settings, metadata; needs egress to registry.coder.com [src](https://coder.com/docs/admin/templates/creating-templates). CLI: `coder templates init --id` with aws-devcontainer, aws-linux, aws-windows, azure-linux, digitalocean-linux, docker, docker-devcontainer, docker-envbuilder, gcp-devcontainer, gcp-linux, gcp-vm-container, gcp-windows, incus, kubernetes, kubernetes-devcontainer, nomad-docker, quickstart, scratch [src](https://coder.com/docs/reference/cli/templates_init). Docs advise "starting with a universal template" [src](https://coder.com/docs/admin/templates).

## Extension unit and interface
- Module = `registry/<ns>/modules/<name>/{main.tf, README.md, main.test.ts, run.sh?}`; README frontmatter `display_name`, `description`, `icon`, `tags`, `verified` (maintainers only); tests via `*.tftest.hcl` + `bun test`; semver bump script; templates live in `registry/<ns>/templates/<name>/` without required tests [src](https://github.com/coder/registry/blob/main/CONTRIBUTING.md). Referenced as `source = "registry.coder.com/coder/cursor/coder"`, `version`, `agent_id` [src](https://github.com/coder/registry).
- Examples: code-server v1.6.0 installs code-server, registers a `coder_app`, installs extensions/settings, `offline`/`use_cached` [src](https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/code-server/README.md); dotfiles v1.4.2 adds a `coder_parameter` prompting for the repo URL [src](https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/dotfiles/README.md); claude-code v5.5.1 installs/configures the CLI with one of API key, key-helper, OAuth token, AI Gateway, Bedrock, Vertex, Foundry — "v5 is a major refactor that drops support for Coder Tasks" [src](https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/claude-code/README.md). ~60 modules exist (cursor, jetbrains, git-clone, git-commit-signing, aider, goose, agentapi, vault-*, jfrog-*, devcontainers-cli, agent-firewall, kiro...) [src](https://github.com/coder/registry/tree/main/registry/coder/modules).
- Parameters: `coder_parameter` (`type`, `default`, `mutable`, `ephemeral`, `option`, `validation`), `coder_workspace_preset` bundles; dynamic parameters v2.24 [src](https://coder.com/docs/admin/templates/extending-templates/parameters); presets with `prebuilds { instances }` are premium, provider >= 2.4.1 [src](https://coder.com/docs/admin/templates/extending-templates/prebuilt-workspaces). Tasks (v2.30 docs): template must define `coder_ai_task` itself, agents ship with AgentAPI [src](https://raw.githubusercontent.com/coder/coder/v2.30.0/docs/ai-coder/tasks.md).

## Discovery and distribution
- registry.coder.com mirrors the GitHub repo; versions via git tags + README; `coder` namespace auto-verified [src](https://github.com/coder/registry); old coder/modules archived May 15 2025 [src](https://github.com/coder/modules). Motivation (Sept 2023): templates had grown to include IDE installs, auth and tool integration with duplicated code, so common pieces were extracted [src](https://coder.com/blog/introducing-the-coder-registry). Module caching (`.terraform/modules`, 20 MB) and Artifactory/private-git for air-gap [src](https://coder.com/docs/admin/templates/extending-templates/modules). Templates ship via `coder templates push`, with active versions and premium "Template Update Policies" [src](https://coder.com/docs/admin/templates/managing-templates).

## Overriding defaults
- Users: parameters at creation, dotfiles, `~/personalize`, repo `devcontainer.json`; admins: template versions, RBAC per template, module inputs (sources above). v2.37 made model configs and MCP settings org-scoped [src](https://coder.com/changelog/coder-2-37).

## Lessons
- Terraform is the entry tax: an operator lists Terraform, Docker, cloud, AI APIs and auth as required knowledge, "rough edges... docs, and user management (Premium)", though PoC took a day and the Docker template beat AWS on permission complexity [src](https://thetechenabler.substack.com/p/running-a-vibe-code-platform-coder). The 2022 Show HN pitch was flexibility ("any operating system on any kind of compute on any cloud") vs. Codespaces [src](https://news.ycombinator.com/item?id=32417258). The builder, `quickstart`, presets and prebuilds are the answers to that tax.
- Registry as attack surface: on Aug 31 2026 a stolen Cloudflare key pointed registry.coder.com at rogue servers serving modules with a `data.external` block exfiltrating provisioner secrets; CVSS 9.0; patched 2.37.0/2.36.4/2.35.7/2.34.9 [src](https://github.com/coder/coder/security/advisories/GHSA-vx42-ghc9-gw65); Terraform lockfiles pin providers, not modules, so version pinning did not help [src](https://labs.cloudsecurityalliance.org/research/csa-research-note-coder-registry-terraform-supply-chain-2026/).
- Agent strategy moved out of the extension layer: Coder Agents (beta May 2026) run the loop in the control plane so "LLM provider credentials never enter the workspace" [src](https://coder.com/blog/introducing-coder-agents), and Tasks are deprecated from v2.37 [src](https://coder.com/changelog/coder-2-37) — the workspace-side agent modules churned (claude-code v5 dropping Tasks).

# Cross-cutting takeaways for a core / default / packs design
- All four keep the isolation or provisioning boundary in core and push "install X + sign in" out: sbx kits, Features, Compose files, Coder modules. Only sbx kits and Coder modules model credentials as first-class; sbx does it by proxy injection so packs never hold secrets [src](https://docs.docker.com/ai/sandboxes/customize/kits/).
- A pack needs an explicit contract for network egress (sbx's "complete outbound network contract" + deny-all test) [src](https://github.com/docker/sbx-kits-contrib) and a lockfile/digest story (devcontainer-lock.json; Coder's incident shows the cost of lacking one).
- Defaults get criticized in both directions: Balanced is "too narrow for docs, too broad in wildcards"; Features are "too slow"; Coder is "too much Terraform". Named presets, a `--resolved`/`config`-style inspector (Compose has it; sbx users are asking for it) and non-breaking renames matter more than feature count.
- Unverified: exact `sbx run -t TAG` template syntax (CLI page not renderable; from a search snippet of https://docs.docker.com/reference/cli/sbx/template/) and Dependabot GA for Features (search snippet only, https://containers.dev/guide/dependabot).

# Sources
- https://docs.docker.com/ai/sandboxes/
- https://docs.docker.com/ai/sandboxes/get-started/
- https://docs.docker.com/ai/sandboxes/usage/
- https://docs.docker.com/ai/sandboxes/agents/
- https://docs.docker.com/ai/sandboxes/agents/claude-code/
- https://docs.docker.com/ai/sandboxes/architecture/
- https://docs.docker.com/ai/sandboxes/security/
- https://docs.docker.com/ai/sandboxes/security/defaults
- https://docs.docker.com/ai/sandboxes/configuration/
- https://docs.docker.com/ai/sandboxes/configuration/credentials/
- https://docs.docker.com/ai/sandboxes/customize/
- https://docs.docker.com/ai/sandboxes/customize/kits/
- https://docs.docker.com/ai/sandboxes/faq/
- https://docs.docker.com/desktop/release-notes/
- https://github.com/docker/sbx-releases
- https://github.com/docker/sbx-releases/releases
- https://github.com/docker/sbx-releases/issues
- https://github.com/docker/sbx-releases/issues/594
- https://github.com/docker/sbx-releases/issues/606
- https://github.com/docker/sbx-kits-contrib
- https://docker.github.io/docker-agent/configuration/sandbox/
- https://www.docker.com/blog/docker-sandboxes-a-new-approach-for-coding-agent-safety/
- https://www.docker.com/blog/docker-sandboxes-run-agents-in-yolo-mode-safely/
- https://www.docker.com/blog/why-microvms-the-architecture-behind-docker-sandboxes/
- https://andrewlock.net/running-ai-agents-safely-in-a-microvm-using-docker-sandbox/
- https://forums.docker.com/t/docker-sandbox-completely-changed-in-a-minor-update/151458
- https://code.claude.com/docs/en/sandbox-environments
- https://containers.dev/implementors/json_reference/
- https://containers.dev/implementors/features/
- https://containers.dev/implementors/features-distribution/
- https://containers.dev/implementors/templates/
- https://containers.dev/implementors/templates-distribution/
- https://containers.dev/collections
- https://containers.dev/supporting
- https://github.com/devcontainers/cli
- https://github.com/devcontainers/cli/issues/1195
- https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-lockfile.md
- https://github.com/devcontainers/spec/issues/21
- https://github.com/devcontainers/spec/discussions/327
- https://github.com/devcontainers/images
- https://github.com/devcontainers/images/blob/main/src/base-ubuntu/README.md
- https://github.com/devcontainers/features/blob/main/src/common-utils/README.md
- https://github.com/devcontainers/templates
- https://github.com/microsoft/vscode-dev-containers
- https://code.visualstudio.com/blogs/2022/09/15/dev-container-features
- https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces/adding-a-dev-container-configuration/introduction-to-dev-containers
- https://www.kenmuse.com/blog/improving-dev-container-feature-performance/
- https://blog.ugurelveren.com/post/dev-containers-fair-review-simple/
- https://docs.docker.com/compose/intro/compose-application-model/
- https://docs.docker.com/compose/intro/history/
- https://docs.docker.com/reference/cli/docker/compose/
- https://docs.docker.com/reference/compose-file/version-and-name/
- https://docs.docker.com/reference/compose-file/legacy-versions/
- https://docs.docker.com/reference/compose-file/merge/
- https://docs.docker.com/reference/compose-file/include/
- https://docs.docker.com/reference/compose-file/services/
- https://docs.docker.com/reference/compose-file/extension/
- https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/
- https://docs.docker.com/compose/how-tos/multiple-compose-files/extends/
- https://docs.docker.com/compose/how-tos/multiple-compose-files/include/
- https://docs.docker.com/compose/how-tos/profiles/
- https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/
- https://www.docker.com/blog/announcing-the-compose-specification/
- https://www.docker.com/blog/improve-docker-compose-modularity-with-include/
- https://www.docker.com/blog/new-docker-compose-v2-and-v1-deprecation/
- https://github.com/compose-spec/compose-spec
- https://github.com/docker/compose/issues/4315
- https://github.com/docker/compose/issues/12162
- https://github.com/docker/docs/issues/18494
- https://github.blog/changelog/2024-04-10-github-hosted-runner-images-deprecation-notice-docker-compose-v1/
- https://akrabat.com/changing-port-maps-in-docker-compose/
- https://coder.com/docs/admin/templates
- https://coder.com/docs/admin/templates/creating-templates
- https://coder.com/docs/admin/templates/managing-templates
- https://coder.com/docs/admin/templates/extending-templates/modules
- https://coder.com/docs/admin/templates/extending-templates/parameters
- https://coder.com/docs/admin/templates/extending-templates/prebuilt-workspaces
- https://coder.com/docs/admin/users/groups-roles
- https://coder.com/docs/reference/cli/templates_init
- https://coder.com/docs/user-guides/workspace-dotfiles
- https://coder.com/docs/user-guides/devcontainers
- https://coder.com/docs/ai-coder/tasks
- https://raw.githubusercontent.com/coder/coder/v2.30.0/docs/ai-coder/tasks.md
- https://coder.com/blog/introducing-the-coder-registry
- https://coder.com/blog/introducing-coder-agents
- https://coder.com/changelog/coder-2-37
- https://github.com/coder/registry
- https://github.com/coder/registry/blob/main/CONTRIBUTING.md
- https://github.com/coder/registry/tree/main/registry/coder/modules
- https://github.com/coder/registry/tree/main/registry/coder/templates
- https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/claude-code/README.md
- https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/code-server/README.md
- https://raw.githubusercontent.com/coder/registry/main/registry/coder/modules/dotfiles/README.md
- https://github.com/coder/modules
- https://github.com/coder/terraform-provider-coder/tree/main/docs/resources
- https://github.com/coder/terraform-provider-coder/tree/main/docs/data-sources
- https://github.com/coder/coder/security/advisories/GHSA-vx42-ghc9-gw65
- https://labs.cloudsecurityalliance.org/research/csa-research-note-coder-registry-terraform-supply-chain-2026/
- https://news.ycombinator.com/item?id=32417258
- https://thetechenabler.substack.com/p/running-a-vibe-code-platform-coder
