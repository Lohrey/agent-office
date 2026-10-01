# Run it on a server for your team

Any Ubuntu or Debian server, with one line, or set up by hand behind Caddy or nginx. Back to the [README](../README.md).

Run this on any Ubuntu or Debian server, as root or as a user with sudo:

```bash
curl -fsSL https://raw.githubusercontent.com/AgentSystemLabs/agent-office/main/deploy/provision.sh | bash
```

Or run it from your computer without logging in first: `ssh root@203.0.113.7 'curl -fsSL https://raw.githubusercontent.com/AgentSystemLabs/agent-office/main/deploy/provision.sh | bash'`.

It takes a few minutes the first time:

1. Installs Node.js 22, git, the GitHub CLI and **Claude Code**. Run as root, it creates an `agentoffice` user and runs the office as that user, so workers never run as root.
2. Clones agent-office into `/opt/agent-office` and runs it under systemd. `Restart=always` brings it back after a crash or a reboot, and `KillMode=process` keeps workers running through a restart. It listens on `127.0.0.1:4600` only. The office keeps its data in `~/agent-office` and clones projects into `~/workspace/<owner>/<repo>`.
3. Sets up **👥 Invite teammates**. Teammates' SSH keys log in as a separate `office` user that can only forward to the office port: no shell, no other ports.
4. Offers to sign the GitHub CLI in, if it's running in a terminal.
5. Prints how to get in:

```
  On your computer, open a tunnel and leave it running:

    ssh -N -L 4600:localhost:4600 root@203.0.113.7

  then open http://localhost:4600/claim?t=…
  It shows the office password once: write it down.
```

Everything goes through SSH, so there are no certificates to manage, and `localhost` counts as a secure origin, so voice and screen sharing work. Claude signs in from the office: the first worker asks you to type `/login` in its terminal. If GitHub isn't signed in yet, run `gh auth login` from a shell at any desk (**B**). Do both while you're in on the office password: those are the machine's own sign-ins. Teammates you give [accounts](../README.md#add-users) sign in to their own Claude and GitHub in **☰ → 🔐 Your sign-ins**, and their workers run on their own plan. To update, run the same line again, or use **⬆️ Upgrade the office** in the **☰** menu. Options go after `bash -s --`: `--project owner/repo` clones a first floor, and `--help` lists the rest.

**On your own domain.** Point a DNS record at the server, open ports 80 and 443, and add `--domain`:

```bash
curl -fsSL https://raw.githubusercontent.com/AgentSystemLabs/agent-office/main/deploy/provision.sh | bash -s -- --domain office.example.com
```

It installs [Caddy](https://caddyserver.com), which gets a certificate from Let's Encrypt by itself and serves the office on https://office.example.com. The claim link is then `https://office.example.com/claim?t=…`. Give teammates an invite link each from **🔑 Accounts**.

**On a Docker host with Traefik.** A server that already runs Traefik for its other apps, on the host's network (Hostinger's "Ubuntu with Docker and Traefik" VPS, for one) takes the office as one more Compose project, [`deploy/container/compose.yaml`](../deploy/container/compose.yaml). Point a DNS record at the server, then, next to the file:

```bash
printf 'AGENT_OFFICE_DOMAIN=office.example.com\nAGENT_OFFICE_PASSWORD=%s\n' "$(openssl rand -base64 18)" >.env
chmod 600 .env; cat .env     # the office password: write it down
docker compose -f compose.yaml up -d
```

Compose reads `.env` from that folder on every run, so the domain and the password stay the same when you update. On Hostinger, paste the file into the VPS's **Docker Manager** instead (or send it to the API's "create project"), with those two lines as the project's environment. Nothing is built ahead of time, so it works where Compose can't build images: the container starts from the stock `node:22-bookworm`, clones the repository, and [`deploy/container/bootstrap.sh`](../deploy/container/bootstrap.sh) installs what [`deploy/container/Dockerfile`](../deploy/container/Dockerfile) would, builds the office and starts it. That takes a few minutes the first time; until then Traefik answers with a 404 or a 502. `AGENT_OFFICE_REPO` and `AGENT_OFFICE_REF` pick another repository or branch. `AGENT_OFFICE_BEHIND_PROXY=1` has the office listen on the container's network and trust Traefik's `X-Forwarded-*`. sshd still runs in the container, but its port isn't published, so everyone signs in on the domain and teammates join by an invite link from **🔑 Accounts** rather than **👥 Invite teammates**. The labels assume Traefik's Docker provider and Hostinger's names, `websecure`, `web` and `letsencrypt`; set `TRAEFIK_ENTRYPOINT`, `TRAEFIK_HTTP_ENTRYPOINT` or `TRAEFIK_CERTRESOLVER` for others. Everything the office keeps is on the `office-data` volume, laid out as in the [Dokploy reference](dokploy.md), and Claude signs in with `/login` in the first worker's terminal (or pass `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`). There's no SSH in to run `gh auth login` before the first floor, so add `AGENT_OFFICE_GITHUB_TOKEN`, a GitHub token with the `repo`, `read:org` and `workflow` scopes ([make one](https://github.com/settings/tokens/new?scopes=repo,read:org,workflow&description=agent-office)): each start signs the office's GitHub CLI in with it, and gives git the token's name and noreply email unless it has some. Voice between people on networks that block direct calls (mobile and office networks, mostly) needs a TURN relay, or they see each other talk and hear nothing. Add `COMPOSE_PROFILES=turn` and `TURN_PASSWORD=` with `openssl rand -hex 16` to the environment and Compose also runs [coturn](https://github.com/coturn/coturn) on the server, which the office hands to everyone's browser. It listens on the host's network, so open UDP and TCP `3478` and UDP `49160-49200` in the server's firewall (Hostinger's is under the VPS's **Security → Firewall**), and it reaches the server by the office's domain, so that record can't be behind a proxy like Cloudflare's orange cloud. It refuses to relay into private addresses, so it can't be used to reach the containers next to it. A TURN server you already have goes in `AGENT_OFFICE_TURN` instead. A restart keeps the build; to update, recreate the container (`docker compose -f compose.yaml up -d --force-recreate` next to the `.env`, or create the project again in the Docker Manager with the same environment), and it clones and builds the branch's latest commit.

**On your Tailscale network.** No domain, and no ports to open: add `--tailscale`, and the server joins your tailnet and serves the office on `https://agent-office.<your-tailnet>.ts.net` with [Tailscale Serve](https://tailscale.com/kb/1312/serve), which brings its own certificate:

```bash
curl -fsSL https://raw.githubusercontent.com/AgentSystemLabs/agent-office/main/deploy/provision.sh | bash -s -- --tailscale
```

It prints a link to add the machine to your tailnet (or pass `--tailscale-auth-key tskey-auth-…`), and the first time, one that turns on MagicDNS and HTTPS Certificates for the tailnet. It waits for each. `--tailscale-hostname` names the machine (`agent-office` by default). Then anyone on your tailnet opens the link, and workers' web servers get links of their own, `https://agent-office.<your-tailnet>.ts.net:<port>`, still behind the office sign-in. For someone outside your tailnet, share the machine with them from Tailscale's Machines page. Re-running the script keeps it on the tailnet. Turn off key expiry for the machine on that page, or it drops off after 180 days. The details, and what else the tailnet can reach on the machine, are in the [AWS reference](aws.md#tailscale), since `deploy/aws.sh up --tailscale` does the same thing.

**Setting it up by hand** (another distribution, or your own proxy): run `agent-office`, which listens on `127.0.0.1` only, and reach it through `ssh -L 4600:localhost:4600 you@server`. Or put it behind HTTPS on a domain, which voice and screen sharing need, with Caddy:

```caddy
# /etc/caddy/Caddyfile
office.example.com {
    reverse_proxy 127.0.0.1:4600
}
```

```bash
agent-office setup --projects ~/workspace --project owner/repo   # once; or pick projects in the office
agent-office --host 127.0.0.1 --trust-proxy --password "$(openssl rand -base64 18)"
```

Caddy proxies WebSockets out of the box. With nginx, forward the Host and Upgrade headers:

```nginx
location / {
    proxy_pass http://127.0.0.1:4600;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 1d;
}
```

To keep the office running, use a systemd unit:

```ini
# /etc/systemd/system/agent-office.service
[Unit]
Description=Agent Office
After=network.target

[Service]
User=dev
WorkingDirectory=/home/dev
# generate with: openssl rand -base64 24
Environment=AGENT_OFFICE_PASSWORD=<a long random password>
ExecStart=/usr/bin/env agent-office --host 127.0.0.1 --trust-proxy
Restart=on-failure
# Restarting the office leaves the workers' terminals running for the next one to pick up.
KillMode=process

[Install]
WantedBy=multi-user.target
```

If you don't have a domain, `--self-signed` serves HTTPS directly. Browsers will warn once per person.

**Voice across strict NATs.** Peers connect directly using public STUN. If some teammates can't hear each other (common on corporate networks), run a TURN server such as coturn and pass `--turn turn:user:pass@turn.example.com:3478` (or set `AGENT_OFFICE_TURN`, several separated by spaces). The office warns in a toast when a call can't connect.
