# Router edition of nouride (in-process Nougate AI Router). Same release and
# hashes.json as pkgs/nouride; only the artifact differs.
{ nouride }:

nouride.override { edition = "router"; }
