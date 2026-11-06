# VPN files

Import a provider configuration with:

```bash
lab vpn import ~/Downloads/lab.ovpn
lab vpn up
lab status
```

The helper copies the source file into this folder with private permissions, imports it into NetworkManager for this user, and disables automatic connection. Use `lab vpn down` when the lab is finished. Do not commit VPN files or credentials to notes or project repositories.
