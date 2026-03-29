# Terraform Web UI

Small local web app that:
- reads Terraform variable definitions from `../terraform/variables.tf`
- asks the user for tfvars values
- generates a tfvars file
- runs `terraform init` and then `terraform plan` or `terraform apply`

## Run

```bash
cd terraform-webui
npm install
npm start
```

Open: `http://localhost:8080`

## Notes

- Terraform root is fixed to `../terraform` (relative to `terraform-webui`).

- Actions supported in UI: `plan`, `apply`.
- Actions supported in UI: `plan`, `apply`, `destroy`.
- Backend workspaces are loaded from Terraform backend state and can be selected before running.
- `destroy` requires typing `DESTROY` in the confirmation field.
- Terraform output is streamed live in the UI while commands run.
- When a workspace is selected, the form auto-refreshes from a matching tfvars file in Terraform root:
  - `<workspace>.tfvars`
  - `<workspace>.auto.tfvars`
  - `<workspace>.auto.tfvars.json`
- Generated tfvars file defaults to `webui.auto.tfvars` in the Terraform root.
- `apply` and `destroy` use `-auto-approve`.

## Safety

This app executes Terraform commands on the host machine. Use it only in trusted/local environments.
