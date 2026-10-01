# Broadcasting the Bambu Lab P1S Internal Camera

Research notes and implementation plan for streaming the P1S chamber camera to a public web interface.

**Author:** Inigo Dela Vega
**Date:** September 2026

## Goal

Take the live feed from two P1S chamber cameras in the ECST makerspace and make them viewable through a public web interface. The makerspace has authorized us to create accounts and configure WLAN settings on the printers on their behalf.

## Why the P1S Is Harder Than Other Bambu Printers

Bambu printers fall into two camera groups.

| Models | Camera interface | Direct RTSP? |
|--------|-----------------|--------------|
| X1, X1C, X1E, P2S, H2 series | RTSPS on port 322 | Yes |
| A1, A1 Mini, P1P, P1S | Proprietary JPEG frame protocol on port 6000 | No |

Consequences for the P1S:

- No standard RTSP URL exists, so go2rtc, VLC, and OBS cannot connect to it directly.
- The feed is a sequence of JPEG frames, typically around 1 to 2 fps. Expect a slideshow, not smooth video.
- Bambu Studio's "Go Live" OBS feature is not available for the P1 series.
- A translation layer is required: something that speaks the port 6000 protocol and re-serves the frames as MJPEG or RTSP.

## Approaches Others Have Used

### BambuP1Streamer + go2rtc

The most common community approach. BambuP1Streamer (usually run in Docker) uses Bambu's `libBambuSource.so` to pull frames from the printer and hands them to go2rtc, which serves a standard MJPEG stream.

```
streams:
  p1s: "exec:./BambuP1Streamer ./libBambuSource.so ${PRINTER_ADDRESS} ${PRINTER_ACCESS_CODE}"
```

The resulting MJPEG URL:

```
http://<host>:1984/api/stream.mjpeg?src=p1s
```

**Known issue:** chaining a second go2rtc instance to transcode that MJPEG into WebRTC or H.264 (for Frigate or Home Assistant) has been reported as unreliable, with dropped or grey frames. MJPEG out of the first instance was stable.

### Bambuddy

A self-hosted dashboard that provides MJPEG streaming from the built-in printer camera and can also ingest external network cameras. Lowest effort option for browser viewing.

### Python library: `bambu-lab-cloud-api`

Provides a `JPEGFrameStream` class for A1/P1 printers that returns individual JPEG frames given the printer IP and LAN access code. Suitable as the ingest layer for a custom relay.

```python
from bambulab import JPEGFrameStream

with JPEGFrameStream("192.168.1.100", "access_code") as stream:
    frame = stream.get_frame()
```

### LAN Only Mode

Some users report a noticeably faster feed when the printer runs in LAN only mode. Results vary, and LAN only mode disables cloud features such as remote printing through Handy.

### External RTSP Camera

For real broadcasting (Twitch, Discord, smooth remote viewing), many owners mount an inexpensive RTSP camera instead of relying on the internal one. This bypasses the protocol problem entirely and gives higher frame rates.

## Chosen Implementation: BambuP1Streamer + JavaScript Frontend

**Ingest:** [BambuP1Streamer](https://github.com/slynn1324/BambuP1Streamer) pulls frames through Bambu's plugin library (`libBambuSource.so`) and serves them via go2rtc as MJPEG on port 1984.

- Tested upstream only on a P1S, on Debian 12 / amd64. ARM hosts are not supported.
- Pinned dependencies: Bambu plugin `01.04.00.15`, go2rtc `v1.6.2`.
- Licensed AGPL-3.0.
- Open issues report problems with newer firmware and LAN only mode. Record the working firmware version once the stream is up.

```
podman build -t bambu_p1_streamer .
podman run -d --name bambu_p1_streamer --restart unless-stopped \
  -p 1984:1984 --env-file .env localhost/bambu_p1_streamer
```

Stream URL: `http://<host>:1984/api/stream.mjpeg?src=p1s`

**Frontend:** A JavaScript web application that consumes the MJPEG stream and presents a public viewer for both printers.

## Printer Configuration

The makerspace has given us authorization to configure the printers. The following steps will be performed on each P1S:

1. **WLAN setup** -- connect each printer to the makerspace network (in progress)
2. **Enable LAN Only Mode** -- Settings > WLAN > LAN Only Mode > Yes
3. **Enable Developer Mode** -- Settings > scroll down > Developer Mode > read notice > Enable
4. **Record the Access Code** -- shown on the printer's network settings screen
5. **Assign DHCP reservations** -- so the printer IPs do not change

## Network Ports Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 6000 | TCP | Proprietary JPEG frame stream from printer |
| 322 | TCP | RTSPS (not available on P1S) |
| 8883 | TCP | MQTT (LAN mode) |
| 990 | TCP | FTP control (LAN mode) |

## Security Notes

- The printer's LAN access code grants control of the printer, not just the camera. Keep it in environment variables or a secrets file, never in source control.
- MJPEG relays typically have no built-in authentication. Keep the relay on the LAN and expose only the public-facing viewer through a reverse proxy.
- Firmware updates have changed third-party local access before. Test after every update.
- The viewer is view-only. Never add print control to the public interface.

## References

- [Bambuddy camera documentation](https://wiki.bambuddy.cool/features/camera/)
- [go2rtc issue #1359 (P1S MJPEG to WebRTC)](https://github.com/AlexxIT/go2rtc/issues/1359)
- [Bambu Lab Cloud API library](https://github.com/coelacant1/Bambu-Lab-Cloud-API)
- [Bambu forum: H2C RTSP thread](https://forum.bambulab.com/t/h2c-rtsp-for-camera/256148)
- [Bambu forum: P1P camera thread](https://forum.bambulab.com/t/cant-get-camera-to-work/11084)
- [BambuStudio issue #1536 (RTSP request)](https://github.com/bambulab/BambuStudio/issues/1536)
- [BambuP1Streamer](https://github.com/slynn1324/BambuP1Streamer)
- [Bambu Lab Wiki: Printer Network Ports](https://wiki.bambulab.com/en/general/printer-network-ports)
- [Bambu Lab Wiki: Developer Mode](https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode)
