Use your PC as a **LAN server**, then open it from the phone by the PC’s local IP.

## Best way

### 1. Start server on your PC
From `C:\Git\zTmpProjects`:

```powershell
python -m http.server 8000 --bind 0.0.0.0
```

`0.0.0.0` makes it reachable from other devices on your Wi-Fi.

---

### 2. Find your PC local IP
Run:

```powershell
ipconfig
```

Look for something like:

```text
IPv4 Address . . . . . . . . . . : 192.168.1.23
```

---

### 3. Connect phone to the same Wi‑Fi
Your phone and PC must be on the **same local network**.

---

### 4. Open from phone browser
On the phone, open:

```text
http://192.168.1.23:8000/eye_scroll2.html
```

Replace `192.168.1.23` with your real PC IP.

---

## Important camera note
Many mobile browsers allow camera more reliably on:

- `https://...`
- or `http://localhost`

But your phone opening `http://192.168.x.x:8000` is **not localhost**.

So possible outcomes:

- page opens fine
- camera may work
- or camera may be blocked because it is not secure HTTPS

---

## If camera does not work on phone

### Option A — use a tunnel with HTTPS
Use something like:

- Cloudflare Tunnel
- ngrok

Example idea:
- serve locally on PC
- expose it as an `https://...` URL
- open that HTTPS URL on the phone

That usually helps camera permissions.

---

### Option B — host it on a real HTTPS site
Upload `eye_scroll2.html` to any HTTPS host, for example:
- GitHub Pages
- Netlify
- Vercel
- any static HTTPS hosting

Then open that HTTPS URL on your phone.

---

## If page opens but camera still fails
Check:

1. same Wi-Fi
2. Windows firewall allows Python/server
3. use Chrome/Safari
4. phone browser camera permission is allowed
5. try HTTPS, not plain HTTP LAN URL

---

## Quick summary
For phone testing:

- **same Wi-Fi**
- run server with `--bind 0.0.0.0`
- open `http://<PC-IP>:8000/eye_scroll2.html`

If camera permission fails:
- use **HTTPS** via tunnel or hosting

If you want, I can generate a tiny **one-click PowerShell script** that:
- finds your local IP
- starts the server
- prints the exact mobile URL to open.