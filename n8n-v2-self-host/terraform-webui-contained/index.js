export const appPackage = {
  key: "terraform-webui-contained",
  name: "Terraform Web UI (Contained)",
  description: "Template app wrapper that loads the exact terraform-webui frontend",
  version: "1.0.0",
  company: "CPaT",
  developerEmail: "orlando.gutierrez1@hp.com",

  render(container, context = {}) {
    const savedBase = localStorage.getItem("tfw_contained_base") || "http://localhost:8080";
    const initialBase = context.backendUrl || savedBase;

    container.innerHTML = `
      <style>
        .tfwc { display: flex; flex-direction: column; gap: 10px; }
        .tfwc-card { background: #fff; border: 1px solid #d1d5db; border-radius: 12px; padding: 10px; }
        .tfwc-head { display: grid; grid-template-columns: 1fr auto auto; gap: 8px; align-items: end; }
        .tfwc-field { display: flex; flex-direction: column; gap: 4px; }
        .tfwc-field label { font-weight: 600; font-size: 0.9rem; }
        .tfwc-input, .tfwc-btn { font: inherit; }
        .tfwc-input { border: 1px solid #c9d2e3; border-radius: 8px; padding: 8px; }
        .tfwc-btn { border: 1px solid #c9d2e3; border-radius: 8px; background: #fff; padding: 8px 10px; cursor: pointer; }
        .tfwc-btn.primary { background: #0b5fff; border-color: #0b5fff; color: #fff; }
        .tfwc-meta { color: #5c6c87; font-size: 0.82rem; }
        .tfwc-frame { width: 100%; min-height: 78vh; border: 1px solid #c9d2e3; border-radius: 12px; background: #fff; }
      </style>

      <section class="tfwc">
        <div class="tfwc-card">
          <div class="tfwc-head">
            <div class="tfwc-field">
              <label for="tfwc-base">terraform-webui URL</label>
              <input id="tfwc-base" class="tfwc-input" placeholder="http://localhost:8080" value="${initialBase}" />
            </div>
            <button id="tfwc-load" class="tfwc-btn primary" type="button">Load</button>
            <button id="tfwc-open" class="tfwc-btn" type="button">Open New Tab</button>
          </div>
          <div id="tfwc-meta" class="tfwc-meta">This wrapper loads the exact existing terraform-webui UI from the URL above.</div>
        </div>

        <iframe id="tfwc-frame" class="tfwc-frame" title="Terraform Web UI"></iframe>
      </section>
    `;

    const baseInput = container.querySelector("#tfwc-base");
    const loadBtn = container.querySelector("#tfwc-load");
    const openBtn = container.querySelector("#tfwc-open");
    const meta = container.querySelector("#tfwc-meta");
    const frame = container.querySelector("#tfwc-frame");

    const normalizeBase = (value) => String(value || "").trim().replace(/\/$/, "");

    const loadFrame = () => {
      const base = normalizeBase(baseInput.value);
      if (!base) {
        meta.textContent = "Please enter a valid terraform-webui URL.";
        return;
      }

      localStorage.setItem("tfw_contained_base", base);
      frame.src = `${base}/?embedded=1&t=${Date.now()}`;
      meta.textContent = `Loaded: ${base}`;
    };

    loadBtn.addEventListener("click", loadFrame);
    openBtn.addEventListener("click", () => {
      const base = normalizeBase(baseInput.value);
      if (!base) {
        meta.textContent = "Please enter a valid terraform-webui URL.";
        return;
      }
      window.open(`${base}/`, "_blank", "noopener,noreferrer");
    });

    baseInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        loadFrame();
      }
    });

    loadFrame();
  },
};

export default appPackage;
