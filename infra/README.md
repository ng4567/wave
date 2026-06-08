# Wave Foundry Infrastructure

Deploy the Foundry project and Wave model deployments:

```sh
./infra/deploy-foundry-wave-app.sh <resource-group>
```

If Azure CLI is missing, the script prints the install link and stops. If Azure CLI is installed but not authenticated, it prompts to run `az login` before validating and creating the deployment.

To validate without provisioning resources:

```sh
./infra/deploy-foundry-wave-app.sh --validate-only <resource-group>
```

The template creates:

- Azure AI Services / Foundry account with API-key auth enabled
- Foundry project named `wave-app-project`
- `gpt-5.4-mini`, `gpt-5.4`, and `gpt-5.4-nano` deployments for AI Mode
- endpoints for Wave settings
- post-deployment verification that API keys can be retrieved

For the API-key auth policy exemption, set `apiKeyAuthPolicyAssignmentId` to the resource ID of the policy assignment that blocks local auth. The default parameters file uses the assignment found in the earlier Codex session:

```text
/providers/microsoft.management/managementgroups/229b41e3-f095-4314-bced-89e3e73c3adf/providers/microsoft.authorization/policyassignments/mcapsgovdeploypolicies
```

The template also sets `apiKeyAuthPolicyDefinitionReferenceId` to `CognitiveServicesDisableLocalAuth`, matching the initiative member exempted in that session. The exemption is required and is created at resource-group scope before the account is created with `disableLocalAuth: false`.

Because the governance policy can still modify the account during ARM evaluation, the wrapper re-applies `disableLocalAuth=false` after deployment and verifies that API keys can be retrieved. It reports whether keys exist and their lengths, but does not print the secret key values.

`MAI-Transcribe-1.5` does not deploy as a Foundry model deployment. Wave calls it through the Azure Speech endpoint using model `mai-transcribe-1.5`, so the same account endpoint and API key are enough once local auth is allowed.

The newer Foundry STT deployments (`gpt-4o-mini-transcribe`, `gpt-4o-transcribe`, and `gpt-4o-transcribe-diarize`) were not available in the live `eastus` catalog when this template was written. They were visible in `eastus2`; deploy them there in a second Foundry account if you want a Foundry STT fallback.
