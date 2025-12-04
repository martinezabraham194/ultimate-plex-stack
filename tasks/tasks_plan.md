# Task: Fix gluetun → qBittorrent port-forward automation

Summary of current state
- gluetun successfully connects via WireGuard to Endpoint 146.70.226.226:51820 and obtains forwarded port 45357 (written to ./tmp/gluetun/forwarded_port).
- /tmp/gluetun/forwarded_port exists and contains 45357.
- gluetun in-container helper failed because the gluetun image lacks curl.
- Added host-side pf-updater (curlimages/curl) that reads the forwarded_port and POSTS to qBittorrent WebUI.
- pf-updater attempts return HTTP 400 for setPreferences.
- qBittorrent is generating a temporary admin password on every restart (no permanent password present in config). That makes authentication unreliable.
- qBittorrent logs show "unknown content type: 'application/json' / message body parsing error" for incoming POSTs and also show IP bans after repeated failed auth attempts.
- Host mounts (BASE_PATH) appear accessible; the qBittorrent config file at /mnt/LinuxHDD/Plex/qbittorrent/config/qBittorrent/qBittorrent.conf is present and writable by the local user. Forwarded port file is visible on host.

Root causes (likely)
1. No stable qBittorrent admin credentials (image creates temp password each boot) — authentication attempts fail or trigger bans.
2. API POST body/headers mismatch or qBittorrent rejecting the request format, producing 400 and "unknown content type".
3. Repeated failed auth attempts caused IP ban, blocking further attempts.
4. gluetun image lack of curl prevented in-container UP helper from working (mitigated by pf-updater).
5. Existing qBittorrent config prevented the container init code from applying env-supplied WEBUI_PASS — so setting the password via env had no effect.

Planned remediation steps (ordered, minimal disruption)
- [ ] Stop pf-updater to avoid additional ban attempts.
- [ ] Inspect qBittorrent config for WebUI auth keys (WebUI\Password_PBKDF2 or other keys) and backup config.
- [ ] Decide approach to set permanent credentials:
  - A: Clear qBittorrent config (or move it aside) then restart qbittorrent so LSIO init applies WEBUI_USER/WEBUI_PASS from .env (fast, loses existing preferences).
  - B: Compute PBKDF2 hash and insert WebUI\Password_PBKDF2 into qBittorrent.conf (keeps other prefs, more complex).
  - C: Use the WebUI to set password manually once and update .env accordingly (manual).
  I'll implement approach A unless you prefer otherwise.
- [ ] Ensure pf-updater uses HTTP/1.1 and exact headers; keep current curl flags (--http1.1 and explicit Content-Type).
- [ ] Unban host IP if banned by qBittorrent (clear ban list in config or wait).
- [ ] Restart qbittorrent and pf-updater and verify pf-updater successfully POSTs and qBittorrent listen port updates to 45357.
- [ ] If setPreferences still fails, test a manual curl from host container to reproduce and inspect raw request/response to find expected Content-Type/format.
- [ ] After success, remove temporary files in ./tmp (if desired) and document permanent flow.

Immediate actions I will take now (with automated steps to avoid further ban)
1. Stop pf-updater to halt repeated failing auth attempts.
2. Backup qBittorrent config directory to ./tmp/qbittorrent-config-backup-<timestamp>.
3. Move existing qBittorrent config dir out of the way so LSIO qbittorrent can initialize fresh and apply WEBUI_USER/WEBUI_PASS from .env (approach A).
4. Start qbittorrent, confirm it initializes, and set the WebUI password from .env.
5. Start pf-updater and monitor logs; attempt to apply forwarded port once after the new permanent credentials are active.

If you approve I will perform the immediate actions now. If you prefer a different approach to preserve qBittorrent preferences, tell me to use approach B or C and I will follow that instead.
