# Linux privilege escalation

Start manually so automated output has context.

```bash
id
uname -a
sudo -l
find / -xdev -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
ss -lntup
```

Check scheduled jobs, writable service files, credentials in application configuration, mounted filesystems, unusual groups and locally listening services. Compare kernel or service versions only after finding the exact build and configuration.

## Profile tools

```bash
linpeas -a | tee /tmp/linpeas.txt
pspy
```

Read the output instead of applying suggestions blindly. Save useful evidence under `~/engagements/box-name/loot/`, document the exact path used, and remove temporary files from the target when the lab expects cleanup.
