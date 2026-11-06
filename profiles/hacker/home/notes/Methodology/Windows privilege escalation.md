# Windows privilege escalation

Begin with the current identity and host state.

```powershell
whoami /all
systeminfo
ipconfig /all
net user
net localgroup administrators
sc query
schtasks /query /fo LIST /v
```

Check service paths and permissions, scheduled tasks, saved credentials, application configuration, token privileges, mounted shares, local listeners and patch level. Confirm permissions before changing a service or task.

From this account, Impacket can inspect authorized remote targets:

```bash
secretsdump.py 'DOMAIN/user:password@target'
lookupsid.py 'DOMAIN/user:password@target'
```

Keep dumped credentials under `~/engagements/box-name/loot/`. Record the source account, host and collection command so findings can be reproduced and cleaned up.
