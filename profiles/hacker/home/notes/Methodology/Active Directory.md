# Active Directory

## Record the environment

Keep the domain, domain controller, DNS name, target IP, credentials and time skew in the box note. Add lab names through the managed hosts helper:

```bash
target hosts dc01.htb
```

## Anonymous and guest checks

```bash
smbclient -L "//$TARGET" -N
rpcclient -U '' -N "$TARGET"
enum4linux-ng -A "$TARGET"
```

## Credentials

Use the domain explicitly and start with low-impact enumeration.

```bash
nxc smb "$TARGET" -d DOMAIN -u user -p 'password' --shares
GetUserSPNs.py 'DOMAIN/user:password' -dc-ip "$TARGET" -request
GetNPUsers.py 'DOMAIN/' -usersfile users.txt -dc-ip "$TARGET" -no-pass
```

## Certificates and relationships

```bash
certipy find -u 'user@domain' -p 'password' -dc-ip "$TARGET" -stdout
bloodhound-python -u user -p 'password' -d domain -ns "$TARGET" -c All
```

Treat captured hashes and tickets as sensitive loot. Keep them under the engagement folder, not in reusable templates.
