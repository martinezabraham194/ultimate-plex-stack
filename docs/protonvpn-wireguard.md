# ProtonVPN WireGuard Setup

This guide explains how to set up ProtonVPN using WireGuard on the host system to secure qBittorrent traffic.

## Prerequisites
- `wireguard-tools` installed (`sudo apt install wireguard-tools` on Debian/Ubuntu).
- ProtonVPN account.

## Steps

### 1. Generate WireGuard Config
1.  Log in to your ProtonVPN account.
2.  Go to **Downloads** > **WireGuard**.
3.  Create a new configuration:
    - **Name**: `wg0` (or similar).
    - **Platform**: Linux.
    - **VPN Options**: Select your desired server/options.
4.  Download the configuration file (e.g., `wg0.conf`).

### 2. Install Configuration
1.  Move the config file to `/etc/wireguard/`:
    ```bash
    sudo cp /path/to/downloaded/wg0.conf /etc/wireguard/wg0.conf
    ```
2.  Set permissions:
    ```bash
    sudo chmod 600 /etc/wireguard/wg0.conf
    ```

### 3. Start the VPN
1.  Bring up the interface:
    ```bash
    sudo wg-quick up wg0
    ```
2.  Verify the interface is up:
    ```bash
    sudo wg show
    ip addr show wg0
    ```
3.  Enable auto-start (optional):
    ```bash
    sudo systemctl enable wg-quick@wg0
    ```

### 4. Verify Connectivity
Check if your IP is changed and traffic is routing through the VPN:
```bash
curl --interface wg0 https://ipinfo.io/ip
```
You should see an IP address belonging to ProtonVPN.

## qBittorrent Configuration
The `docker-compose.yaml` is configured to use `network_mode: host` for qBittorrent.
You should configure qBittorrent to bind to the `wg0` interface:
1.  Open qBittorrent Web UI.
2.  Go to **Tools** > **Options** > **Advanced**.
3.  **Network Interface**: Select `wg0` (or the name of your WireGuard interface).
4.  **Optional IP Address to bind to**: Select the IP address of the `wg0` interface.
5.  Save and restart qBittorrent if needed.

## Port Forwarding (Optional)
If your ProtonVPN plan supports port forwarding:
1.  Enable port forwarding in your ProtonVPN dashboard/config.
2.  Note the forwarded port.
3.  Update `QB_TORRENT_PORT` in your `.env` file with this port.
4.  Update qBittorrent settings to listen on this port.
