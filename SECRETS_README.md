# SECRETS_README.md

This file describes the Docker secrets required by `docker-stack.yml` and exact commands to create them. Create these secrets on the Swarm manager node before deploying the stack.

Secrets referenced by docker-stack.yml:
- proton_user       -> ProtonVPN username
- proton_pass       -> ProtonVPN password
- plex_claim        -> Plex claim token (optional)
- sonarr_api_key    -> Sonarr API key
- radarr_api_key    -> Radarr API key
- membarr_token     -> Membarr token (if used)

1) Recommended: create secrets from environment variables (secure, reproducible)
Export the secret values in your shell (do NOT commit these to git). Then create secrets:

Bash example:
```bash
# Export values in your shell (do NOT store these in a committed file)
export PROTONVPN_USER="your-proton-user"
export PROTONVPN_PASS="your-proton-pass"
export PLEX_CLAIM="claim-xxxx"
export SONARR_KEY="sonarr-api-key"
export RADARR_KEY="radarr-api-key"
export MEMBARR_TOKEN="membarr-token"

# Create Docker secrets from env values
echo -n "$PROTONVPN_USER" | docker secret create proton_user -
echo -n "$PROTONVPN_PASS" | docker secret create proton_pass -
echo -n "$PLEX_CLAIM" | docker secret create plex_claim -
echo -n "$SONARR_KEY" | docker secret create sonarr_api_key -
echo -n "$RADARR_KEY" | docker secret create radarr_api_key -
echo -n "$MEMBARR_TOKEN" | docker secret create membarr_token -
```

2) Create secrets from files
Create a file containing the secret (one file per secret) and run:
```bash
docker secret create proton_user ./secrets/proton_user.txt
docker secret create proton_pass ./secrets/proton_pass.txt
docker secret create plex_claim ./secrets/plex_claim.txt
```

3) Interactive creation (prompt)
```bash
read -rsp "ProtonVPN user: " _u; echo -n "$_u" | docker secret create proton_user -
read -rsp "ProtonVPN pass: " _p; echo -n "$_p" | docker secret create proton_pass -
```

4) Verify secrets
```bash
docker secret ls
docker secret inspect proton_user
```

5) Update / Remove secrets
- To remove: `docker secret rm proton_user`
- To update: remove and recreate the secret (secrets are immutable).

Notes / Caveats
- Secrets are only available to services attached to the Swarm and are mounted as files under `/run/secrets/<name>` inside containers. The stack file expects some services to read secret files (see `docker-stack.yml`).
- Keep secrets confined to your Swarm manager nodes — do not put values in git or in `.env` commits.
- If you have multiple Swarm managers, ensure secrets exist on the Swarm (they are stored in Swarm Raft).
