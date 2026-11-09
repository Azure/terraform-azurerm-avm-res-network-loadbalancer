# Terraform 1.16.5 on Windows embeds tests\unit in the alternative-module cache
# key but does not create its intermediate directory. Prepare only that cache
# parent before managed init; no providers/configuration/state are modified.
$ErrorActionPreference = 'Stop'
if ($IsWindows) {
  $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  New-Item -ItemType Directory -Force (Join-Path $root '.terraform/modules/test.tests/unit') | Out-Null
}
