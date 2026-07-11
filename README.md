# homelab-info-scripts

Snapshot tooling for a small homelab. A Windows PowerShell orchestrator SSHes
into QNAP NAS hosts and a Pi-hole, runs shell scripts that already live on those
hosts, and saves their output to a timestamped folder under `Documents\Homelab\`.

## Setup

1. Copy `.env.example` to `.env` and fill in your hosts:
   ```powershell
   Copy-Item .env.example .env
   ```
2. Make sure SSH key-based auth works to every host listed in `.env` — the
   orchestrator does not prompt for or pass passwords.
3. Deploy the per-host scripts manually:
   - QNAP hosts: copy `qnap/sysinfo-qnap.sh` and `qnap/dockerinfo-qnap.sh` to
     `HOMELAB_QNAP_SCRIPT_PATH` (default `/share/homes/<user>`).
   - Pi-hole host: copy `rpi-pihole/sysinfo-rpi.sh` to `HOMELAB_PIHOLE_SCRIPT_PATH`
     (default `/home/<user>`).

## Run

```powershell
.\collect-homelab-snapshots.ps1
```

Each QNAP host is collected in parallel via `Start-Job`; Pi-hole runs after the
QNAP jobs finish. Output filenames are `{SystemName}{Suffix}.txt` for QNAP tasks
(suffix from `HOMELAB_QNAP_TASKS`) and `pihole.txt` for Pi-hole. After the QNAP
jobs finish the orchestrator also writes `_ROLE-MAP.txt`, a cross-host map of
running containers (name / image / published ports) built from the collected
`*-docker.txt` files. Remote stdout and stderr are both captured, so SSH or
script errors appear inside the `.txt` files rather than failing the run.

## Disk SMART on QNAP (optional, needs scoped sudo)

Real SMART attributes (reallocated sectors, power-on-hours, temperature) come
from `/sbin/get_hd_smartinfo`, which opens the raw block device and therefore
requires root. The collector runs `sysinfo-qnap.sh` as the login user
**non-interactively**, and the QNAPs have **no passwordless sudo by default**, so
without extra config the SMART section falls back to `qcli_storage` model/size
info and prints a note.

To enable full SMART, add a scoped `NOPASSWD` sudoers entry on each QNAP for that
one binary — the same pattern already used for the Pi-hole script. Use the safety
sequence (back up first): `sudo -i`, then
`echo 'josh ALL=(root) NOPASSWD: /sbin/get_hd_smartinfo' > /etc/config/sudoers.d/smartinfo`
(QNAP persists `/etc/config`, not `/etc`), verify with `visudo -c`, then re-run
the collector. `sysinfo-qnap.sh` auto-detects the entry (`sudo -n get_hd_smartinfo`)
and emits per-disk SMART when present.

## Layout

- `collect-homelab-snapshots.ps1` — orchestrator and `.env` loader.
- `qnap/` — shell scripts that run on QNAP hosts.
- `rpi-pihole/` — shell script that runs on the Pi-hole host.
- `.env.example` — every config variable, documented inline.

## License

MIT. See `LICENSE.md`.
