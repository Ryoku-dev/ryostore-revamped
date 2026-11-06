# Enumeration

Work only inside the assigned lab scope. Save every scan under the engagement folder.

## Set up

```bash
box new box-name 10.10.10.10
target hosts box-name.htb
cd "$(box path box-name)"
```

## Discover ports

```bash
rustscan -a "$TARGET" -- -Pn -oA nmap/rustscan
nmap -Pn -p- --min-rate 1000 -oA nmap/all-ports "$TARGET"
```

## Identify services

Replace the port list with open ports from the first scan.

```bash
nmap -Pn -sC -sV -p 22,80,443 -oA nmap/services "$TARGET"
```

Use UDP only when the room or evidence calls for it because it is slow.

```bash
nmap -Pn -sU --top-ports 100 -oA nmap/udp-top100 "$TARGET"
```

## Follow each service

- HTTP: record titles, redirects, server headers, host names and technologies.
- DNS: query discovered names with `dig` and try an authorized zone transfer.
- SMB: list shares with `smbclient -L "//$TARGET" -N`.
- TLS: inspect names in the certificate.
- Unknown: set `PORT=8080`, then run `nc.openbsd -nv "$TARGET" "$PORT"` and capture the banner.

Keep commands and results in the box note as you go.
