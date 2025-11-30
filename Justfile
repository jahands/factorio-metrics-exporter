set shell := ["bash", "-c"]

[private]
@help:
  just --list

alias i := install

# Install dependencies
install:
  bun install

# Symlink the mod into Factorio's mods directory for development
link:
  ln -sfn "$(pwd)/src" "$HOME/Library/Application Support/factorio/mods/metrics-exporter"
