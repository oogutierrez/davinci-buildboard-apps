# Standard App Template

Use `apps/_template/index.js` as the starting point for all new apps.

## Required fields
- `name`
- `description`
- `version`
- `render(container, context?)`

## Recommended fields
- `key`
- `company`
- `developerEmail`

## Optional lifecycle hooks
- `onDeregister()`

## Optional cleanup metadata
- `artifacts: string[]`

## Create a new app from template
1. Copy `apps/_template` to `apps/<your-app-slug>`
2. Edit metadata and UI
3. Register with source path: `./apps/<your-app-slug>/index.js`

## Run App Standalone
- Open `./apps/<your-app-slug>/standalone.html`
- This renders the app directly without loading the main Buildboard shell.
