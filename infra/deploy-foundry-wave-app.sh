#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_file="$script_dir/foundry-wave-app.bicep"
parameters_file="$script_dir/foundry-wave-app.parameters.json"
resource_group="${AZURE_RESOURCE_GROUP:-standard-rg}"
validate_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate-only)
      validate_only=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--validate-only] [resource-group]"
      exit 0
      ;;
    *)
      resource_group="$1"
      shift
      ;;
  esac
done

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed."
  echo "Install it from https://learn.microsoft.com/cli/azure/install-azure-cli, then run this script again."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed."
  echo "Install jq, then run this script again:"
  echo "  macOS: brew install jq"
  echo "  Linux: use your distro package manager, for example apt install jq or dnf install jq"
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is installed, but you are not signed in."
  read -r -p "Run 'az login' now? [Y/n] " login_choice

  case "$login_choice" in
    n|N|no|NO)
      echo "Run 'az login' when ready, then rerun this script."
      exit 1
      ;;
    *)
      az login
      ;;
  esac
fi

subscription_name="$(az account show --query name -o tsv)"
subscription_id="$(az account show --query id -o tsv)"
echo "Using Azure subscription: $subscription_name"
echo "Using resource group: $resource_group"

az deployment group validate \
  --resource-group "$resource_group" \
  --template-file "$template_file" \
  --parameters "@$parameters_file" \
  --validation-level Template \
  --output table

if [[ "$validate_only" == true ]]; then
  echo "Validation succeeded. Skipping deployment because --validate-only was set."
  exit 0
fi

az deployment group create \
  --resource-group "$resource_group" \
  --template-file "$template_file" \
  --parameters "@$parameters_file" \
  --output table

foundry_account_name="$(jq -r '.parameters.foundryAccountName.value' "$parameters_file")"
foundry_account_id="/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.CognitiveServices/accounts/$foundry_account_name"

echo "Ensuring API-key auth is enabled after policy evaluation..."
az resource update \
  --ids "$foundry_account_id" \
  --api-version 2025-06-01 \
  --set properties.disableLocalAuth=false \
  --output none

echo "Verifying endpoints and API credentials..."
az cognitiveservices account show \
  --resource-group "$resource_group" \
  --name "$foundry_account_name" \
  --output json |
  jq '{
    name,
    location,
    provisioningState: .properties.provisioningState,
    disableLocalAuth: .properties.disableLocalAuth,
    endpoint: .properties.endpoint,
    foundryEndpoint: .properties.endpoints["AI Foundry API"],
    openAIEndpoint: .properties.endpoints["Azure OpenAI Legacy API - Latest moniker"],
    maiEndpoint: .properties.endpoints["Azure MAI Model Inference API"],
    speechEndpoint: .properties.endpoints["Speech Services Speech to Text 2025-10-15"]
  }'

az cognitiveservices account keys list \
  --resource-group "$resource_group" \
  --name "$foundry_account_name" \
  --query "{hasKey1:key1 != '',hasKey2:key2 != '',key1Length:length(key1),key2Length:length(key2)}" \
  --output json
