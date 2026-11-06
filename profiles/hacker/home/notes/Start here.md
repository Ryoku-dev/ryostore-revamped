# Start here

This account is ready for Hack The Box, TryHackMe and OverTheWire-style labs.

## First lab

1. Import the provider's OpenVPN file:

   ```bash
   lab vpn import ~/Downloads/lab.ovpn
   lab vpn up
   lab ip
   ```

2. Create a workspace and set the target:

   ```bash
   box new first-box 10.10.10.10
   target show
   ```

3. Add a lab hostname when the room gives one:

   ```bash
   target hosts first-box.htb
   ```

4. Start with the checklist in [[Methodology/Enumeration]]. Scan results belong in `~/engagements/first-box/nmap/`; notes are in `~/notes/Boxes/first-box.md`.

## Burp and Firefox

Start Burp Suite, wait for it to listen on `127.0.0.1:8080`, then run:

```bash
burp-ca
```

Open **Firefox (Burp proxy)** for traffic that should pass through Burp. Use normal Firefox for other browsing.

## Checkpoints

Before a risky lab step, open Ryoku Hub, go to Users, select this profile account and save a checkpoint. Log out of the Hacker account before reverting a checkpoint. Checkpoints cover this account's home on supported btrfs installations; they do not snapshot the target or system packages.

## Separation, not a sandbox

A profile is a separate account, not a sandbox. Its menus, dock and default apps show only its own tools, but programs installed for the whole computer can still be started from its terminal. Apps it installs also appear in the other accounts on this computer. Files in other accounts stay private: each home folder is readable only by its owner.

Keep work inside `~/engagements`, `~/notes` and `~/vpn`. Resetting the profile restores managed defaults but keeps those folders. Only test systems that the lab or owner has authorized.
