#!/bin/sh
# Test-only: this sandbox can't set a negative oom_score_adj, which Kubernetes always asks for.
b=""; prev=""
for a in "$@"; do
  [ "$prev" = "--bundle" ] && b="$a"
  case "$a" in --bundle=*) b="${a#--bundle=}" ;; esac
  prev="$a"
done
if [ -n "$b" ] && [ -f "$b/config.json" ]; then
  sed -i -e 's/"oomScoreAdj":-[0-9]*,//' -e 's/,"oomScoreAdj":-[0-9]*//' "$b/config.json"
fi
exec /bin/runc.real "$@"
