# Web

## Baseline

```bash
whatweb "http://$TARGET"
curl -i "http://$TARGET/"
```

Record redirects, cookies, headers, frameworks and candidate host names. Add a discovered lab name with:

```bash
target hosts app.htb
```

## Content discovery

```bash
BOX=box-name
feroxbuster -u "http://$TARGET" -w "$WORDLISTS/dirbuster/directory-list-2.3-medium.txt" -o "$HOME/engagements/$BOX/www/ferox.txt"
ffuf -u "http://$TARGET/FUZZ" -w "$WORDLISTS/dirb/common.txt" -of json -o "$HOME/engagements/$BOX/www/ffuf.json"
```

Tune status, size and word filters after looking at a known missing path. Do not treat every different response as a finding.

## Proxy workflow

1. Start Burp Suite.
2. Run `burp-ca` after Burp is listening.
3. Open **Firefox (Burp proxy)**.
4. Keep the normal Firefox profile for browsing that should not use the proxy.

## Test from evidence

Map inputs, authentication boundaries, roles, state changes and file handling before using automated checks. Keep one clean request and response for each finding. Use `sqlmap`, `wpscan`, `nikto` or Burp scanning only when the lab scope permits it.
