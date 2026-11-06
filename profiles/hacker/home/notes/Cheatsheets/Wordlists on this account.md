# Wordlists on this account

`$WORDLISTS` is `/usr/share/wordlists` and `$SECLISTS` is `/usr/share/seclists`.

| Path | Contents |
| --- | --- |
| `$WORDLISTS/rockyou.txt` | Extracted RockYou password list |
| `$WORDLISTS/seclists` | Link to the full SecLists tree |
| `$WORDLISTS/dirb` | Link to DIRB wordlists |
| `$WORDLISTS/dirbuster` | Familiar names linked to current SecLists DirBuster lists |
| `$SECLISTS/Discovery/Web-Content` | Web path and file lists |
| `$SECLISTS/Usernames` | Username lists |
| `$SECLISTS/Passwords` | Password and credential lists |
| `$SECLISTS/Fuzzing` | Fuzzing payloads |

Examples:

```bash
ffuf -u 'http://target/FUZZ' -w "$WORDLISTS/dirbuster/directory-list-2.3-medium.txt"
hydra -L "$SECLISTS/Usernames/top-usernames-shortlist.txt" -P "$WORDLISTS/rockyou.txt" ssh://target
```

Choose the smallest list that matches what you know. Record the list and filters used so results can be reproduced.
