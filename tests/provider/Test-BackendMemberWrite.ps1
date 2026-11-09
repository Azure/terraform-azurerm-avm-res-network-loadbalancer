# Offline provider-boundary regression, separate from mocked Terraform tests.
# Uses ONLY AzAPI v2.13.0's existing Go dependency graph (-mod=readonly).
# Prerequisites: git and Go compatible with that pinned provider's go.mod.
# No Azure authentication, provider binary override or network transport is used.
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string] $Workspace
)

$ErrorActionPreference = 'Stop'
$providerCommit = 'cf3ecee858fa48c0aca95d0b995a8bfd4950c8ec'
if (Test-Path $Workspace) {
  throw 'Use a NEW protected external workspace; existing artifacts are never overwritten.'
}
New-Item -ItemType Directory -Path $Workspace | Out-Null
$source = Join-Path $Workspace 'provider'
& git clone --quiet --depth 1 --branch v2.13.0 https://github.com/Azure/terraform-provider-azapi.git $source
if ($LASTEXITCODE -ne 0) { throw 'Pinned provider clone failed.' }
$actual = & git -C $source rev-parse HEAD
if ($actual -ne $providerCommit) { throw "Pinned provider tag moved: $actual" }
Copy-Item (Join-Path $PSScriptRoot 'member_write_test.go') (Join-Path $source 'internal/services/avm_member_write_test.go')
Push-Location $source
try {
  & go test -mod=readonly ./internal/services -run '^TestAVMMemberWrite' -count=1 -v
  if ($LASTEXITCODE -ne 0) { throw 'Provider-boundary regression failed.' }
  & git diff --exit-code -- go.mod go.sum
  if ($LASTEXITCODE -ne 0) { throw 'Pinned dependency manifests changed.' }
} finally {
  Pop-Location
}
