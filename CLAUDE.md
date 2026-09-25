# P1S Camera Relay

Project owner: Inigo Dela Vega

## Goal

Stream the Bambu Lab P1S chamber camera as standard MJPEG so it can be viewed in a browser, VLC, OBS, or Home Assistant, including remotely over a VPN.

## Chosen implementation

Use BambuP1Streamer: https://github.com/slynn1324/BambuP1Streamer

- Wraps Bambu's proprietary plugin library (`libBambuSource.so`) to pull frames from the printer, and uses go2rtc to serve them as MJPEG on port 1984.
- Upstream is tested only on a P1S, on Debian 12 / amd64.
- Pinned upstream dependencies: Bambu plugin `01.04.00.15`, go2rtc `v1.6.2`. Do not bump either without a reason and a test.
- License: AGPL-3.0. Any modified version we distribute or expose as a network service must publish its source.
- Do not write a replacement ingest layer unless BambuP1Streamer is confirmed broken on our firmware.

## Hardware and environment

- Printer: Bambu Lab P1S with AMS, on the home LAN.
- Relay host: a Linux amd64 machine on the same LAN (planned: refurbished ThinkPad). ARM hosts such as a Raspberry Pi are not supported upstream (open issue #8).
- Do not target the gaming desktop or the MacBook. One machine, one job.
- Container runtime: Podman preferred, Docker acceptable.
- Remote access: Tailscale or similar VPN. Never port forward port 1984.

## Build and run

Quickstart build:

```
git clone https://github.com/slynn1324/BambuP1Streamer.git
cd BambuP1Streamer
podman build -t bambu_p1_streamer .
```

Run with secrets from an env file, not inline `-e` flags (inline values leak into shell history and process listings):

```
podman run -d --name bambu_p1_streamer --restart unless-stopped \
  -p 1984:1984 --env-file .env localhost/bambu_p1_streamer
```

`.env` contains:

```
PRINTER_ADDRESS=<printer LAN IP>
PRINTER_ACCESS_CODE=<8 digit LAN access code>
```

Give the printer a DHCP reservation so `PRINTER_ADDRESS` does not change.

## Endpoints

- MJPEG stream: `http://<host>:1984/api/stream.mjpeg?src=p1s`
- Index page (only MJPEG parts work): `http://<host>:1984/links.html?src=p1s`
- MJPEG over WebSocket: `ws://<host>:1984/api/ws?src=p1s` (connect, send `mjpeg`, receive `mjpeg`, then binary JPEG frames). Candidate for a custom low latency viewer later.

## Troubleshooting

- `Bambu_Open failed: 0xffffff9b`: printer address unreachable. Check IP, subnet, and that the printer is on.
- `[BambuTunnel::read_sample] error [1]`: wrong access code. Re-read it from the printer's screen; it can change.
- A few errors before the stream starts on the stream page are normal. Wait several seconds.

## Known risks

- Upstream is lightly maintained. Open issues report failures on newer printer firmware (#9) and uncertainty in LAN only mode (#10), plus container build errors (#12). Check these before debugging from scratch.
- Firmware updates can break local access. Note the working printer firmware version once the stream works, and re-test after every update.
- Frame rate is roughly 1 to 2 fps. Do not design for smooth video.
- Transcoding this MJPEG to WebRTC/H.264 with a second go2rtc has been reported as flaky. Stay on MJPEG unless a consumer strictly needs otherwise.

## Milestones

1. Build the container on the relay host.
2. Run it and see frames at the MJPEG URL on the LAN.
3. Record the working firmware version and container image ID.
4. Make it survive reboots (`--restart unless-stopped` or a systemd unit via `podman generate systemd`).
5. Add the stream to OBS (browser or media source) and/or Home Assistant.
6. Remote viewing over the VPN.

## Security rules

- The LAN access code controls the printer, not just the camera. Keep it only in `.env`.
- `.env` must be in `.gitignore`. Never print, log, or commit the access code.
- go2rtc has no auth configured here. Bind to the LAN or VPN only.
- The relay is view only. Never add print control.

## Code conventions

- Upstream source is C++. Any C++ changes: no comments.
- All other new code files (scripts, systemd units, compose files): include a brief comment crediting Inigo Dela Vega.
- Prose in docs and READMEs: no em dashes.
- Keep upstream changes minimal so they stay easy to rebase.

## References

- BambuP1Streamer: https://github.com/slynn1324/BambuP1Streamer
- go2rtc: https://github.com/AlexxIT/go2rtc
- go2rtc issue #1359 (P1S MJPEG to WebRTC): https://github.com/AlexxIT/go2rtc/issues/1359
