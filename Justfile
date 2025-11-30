set shell := ["bash", "-c"]

[private]
@help:
  just --list

alias i := install

# Install dependencies
install:
  bun install
