export const appPackage = {
  // Optional stable key for internal identification.
  key: "your-app-key",

  // Required metadata.
  name: "Your App Name",
  description: "Short description of what this app does",
  version: "1.0.0",

  // Recommended metadata.
  company: "Your Company",
  developerEmail: "dev@company.example",

  // Optional artifact list used by deregistration cleanup flows.
  artifacts: [
    // "./path/to/generated/file-or-folder",
  ],

  // Optional cleanup hook called before deregistration.
  async onDeregister() {
    // Return a human-readable cleanup message.
    // Throw an Error to block deregistration.
    return "No cleanup required.";
  },

  // Required render function.
  render(container, context = {}) {
    const app = context.app || {};

    container.innerHTML = `
      <section class="panel app-view">
        <header class="panel-header">
          <h2>${appPackage.name}</h2>
          <p>${appPackage.description}</p>
        </header>

        <div class="placeholder-card">
          <h3>Starter Template</h3>
          <p><strong>Version:</strong> ${appPackage.version}</p>
          <p><strong>Company:</strong> ${appPackage.company}</p>
          <p><strong>Developer Email:</strong> ${appPackage.developerEmail}</p>
          <p>App ID: ${app.id || "(not registered yet)"}</p>

          <label style="display:flex;flex-direction:column;gap:0.3rem;margin-top:0.75rem;">
            Enter a value
            <input id="template-input" type="text" placeholder="Type here" />
          </label>
          <button id="template-action" class="action-btn" type="button" style="margin-top:0.75rem;">Run Action</button>
          <p id="template-output" style="margin-top:0.75rem;font-weight:600;">Output: -</p>
        </div>
      </section>
    `;

    const input = container.querySelector("#template-input");
    const actionBtn = container.querySelector("#template-action");
    const output = container.querySelector("#template-output");

    actionBtn.addEventListener("click", () => {
      const value = (input.value || "").trim();
      output.textContent = value ? `Output: ${value}` : "Output: Please enter a value.";
    });
  },
};

export default appPackage;
