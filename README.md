# How to use

```sh
# Spin up KVM (only tested on Linux host for now)
nix run github:jonhermansen/openclaw-vm-flake
# In another session, connect to IRC daemon
nix run nixpkgs#weechat weechat irc://user@localhost:6667/#openclaw
```
