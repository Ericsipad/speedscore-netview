# Speedscore Netview for Linux

Speedscore Netview links an Ubuntu server of yours to your Speedscore account. Once it is linked, the server pings
the addresses you monitor (also the ones inside your own network), keeps the results itself, reads your SNMP devices,
manages your TR-069 routers, runs the WireGuard tunnels you add, can be a speed test point for your own tests and, if you choose, for visitors, and
keeps itself up to date.

**All services on this server are managed in your Speedscore web dashboard.** The server has only a small page for
setup and status.

## For ISPs and network managers

- **Register your own ASN and IP ranges.** A network manager or an ISP registers its own AS number and IP ranges on
  speedscore.net. Users who visit from that network then automatically test against the most appropriate server, the
  one the ISP chooses and operates, which ensures the most accurate results.
- **Full visibility.** You see the metrics of the tests run from your own network.
- **Routers managed together.** Users can view and manage their own routers along with the ISP's technicians, with
  SNMP and TR-069 management options.
- **Price.** 10 devices can connect for free, and unlimited devices can connect for $10 a month on speedscore.net.
- **Free ISP account.** If an ISP is registered and users on its own ASN and IP ranges subscribe to the 180-day
  history and Personal VPN plan, the ISP's account is free once 10 such users have accumulated.
- **Home users.** Users can access their own home server if they install the Speedscore tool and the Personal
  WireGuard VPN host on a Windows or Mac PC in their home.

Read more at <https://speedscore.net/linux-server>. To register your ASN and IP ranges, sign in and open
<https://speedscore.net/my-account#isp-ranges>.

## What you need

- Ubuntu 24.04 LTS or newer, on x86_64 or arm64 (a small virtual machine is fine).
- Recommended: at least 1 CPU and 2 GB RAM for up to 500 IPs, and 2 CPUs for 500+ devices.
- A Speedscore account. Linking a server is free. 10 devices can connect for free (IP addresses, web checks, SNMP
  devices and TR-069 routers together); unlimited devices can connect for $10 a month on speedscore.net.

## Install

On the server, run this one line:

```
curl -fsSL https://raw.githubusercontent.com/Ericsipad/speedscore-netview/main/install.sh | sudo bash
```

It downloads the program for your machine from this repository's `bin` folder, checks it, installs the service and
starts it. If the ufw firewall is on, it opens port 8443 for the setup page. At the end it prints the page's address.

## Set up

1. Open the setup page in your browser: `https://<your server's IP>:8443`. The browser warns about the certificate the
   first time (it is the server's own); continue to the page.
2. Sign in with user **admin** and password **speedscore**.
3. Choose your own password (at least 10 characters). It stays on the server.
4. The page shows the server's public IP and a link key. On speedscore.net, signed in, open
   **My Account → Connected devices → Add a server** and type the key, a name for the server, its public IP and the
   city it is in.
5. The page then shows **Connected to Speedscore** and **Linked to an account**. That is all: everything else is set on
   speedscore.net.

The page also shows the server's CPU, memory, disk and the ports it uses for speed tests.

## Ports

- 8443 (TCP): the setup page. You can close it again in your firewall once the server is linked.
- Speed test ports: the ones you choose on your account. Open them (TCP and UDP) in your router or firewall; the
  server only listens on them while a test runs, only for the visitor who started it.

## Uninstall

```
curl -fsSL https://raw.githubusercontent.com/Ericsipad/speedscore-netview/main/uninstall.sh | sudo bash
```

The results stay in `/var/lib/speedscore-netview`; add `-s -- --purge` after `bash` to delete them too. Also remove
the server on your account.

## What this repository holds

Only the install and uninstall scripts, these instructions, the license and, in `bin`, the ready-built program
(`speedscore-netview-x86_64`, `speedscore-netview-aarch64`, each with its `.sha256`, and `release.json`, which names
the current version so linked servers update themselves). There is no source code here.

## License

Speedscore Netview is proprietary. It is free to install and use, also commercially, by a single company to connect
its own networks with Speedscore network management. It may not be resold, redistributed or edited. See `LICENSE`.
