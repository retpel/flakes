# nullclaw-chat-ui

[nullclaw-chat-ui](https://github.com/nullclaw/nullclaw-chat-ui), the web chat
for NullClaw's `web` channel (WebSocket, PIN pairing, streaming replies, tool
calls, approvals). Upstream releases ship the static SvelteKit build, so this
package just unpacks it: no Node.js at build or run time.

The files end up in `share/nullclaw-chat-ui/` (`index.html`, `_app/`, icons).
Serve that directory with any web server and point the UI at the channel's
WebSocket, e.g. with Caddy on the same origin:

```caddy
root * ${pkgs.retpel.nullclaw-chat-ui}/share/nullclaw-chat-ui
handle /ws {
  reverse_proxy 127.0.0.1:32123
}
handle {
  try_files {path} /index.html
  file_server
}
```

Put authentication in front of it. For a loopback client, which is what a
reverse proxy on the same host looks like, NullClaw's web channel lets pairing
through without a code.

Upstream declares no license (no LICENSE file, `"license": null` in
`package.json`), so the package claims none.
