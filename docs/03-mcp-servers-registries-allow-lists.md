# MCP servers, registries, and allow lists (module 3 unit 3)

Source: https://learn.microsoft.com/en-us/training/modules/agent-tooling-mcp-execution-environments/3-model-context-protocol-servers-registries-allow-lists

Repo: `cuddy-five/agentic-cert-project`

MCP is a standard way a client talks to tools through servers:
discover tools, send a structured request, get a structured result.

## Server, registry, allow list

| Piece | Role |
| --- | --- |
| Server | Exposes tools. Local on a machine, or remote over HTTP. |
| GitHub remote MCP | Example they show: `https://api.githubcopilot.com/mcp/` |
| Registry | Catalog of servers. Default: GitHub MCP Registry. A custom registry must speak MCP registry v0.1 (`GET /v0.1/servers` and version routes). |
| Allow list | Policy for which servers may run. Org or enterprise Copilot policy: MCP on, optional registry URL, **Allow all** vs **Registry only**. |

**Allow all** — no restriction. **Registry only** — only registry servers; even a local server must be in the registry with the same server ID.

Enterprise can also pin servers in `managed-settings.json` (`allowedMcpServers` / `deniedMcpServers`). That is the stronger list.

## This repo

| Piece | Honest status |
| --- | --- |
| Account | Personal Copilot Student. No org or enterprise allow-list screen. |
| `copilot/managed-settings.json` | Live file is `{}`. Template leftover. Not an allow list. Leave it. |
| Custom registry | Not hosted. Do not invent one. |
| `.github/agents/*.agent.md` | Not this unit. |

## Exam line

We can point at the phrases and at the empty leftover file. We cannot point at an allow list we configured. Filling `managed-settings.json` on this personal repo would be a costume.
