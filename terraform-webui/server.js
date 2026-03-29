const express = require("express");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const app = express();
const PORT = process.env.PORT || 8080;
const TERRAFORM_DIR = path.resolve(__dirname, "..", "terraform");
const VARIABLES_FILE = path.join(TERRAFORM_DIR, "variables.tf");
const REQUIRED_OVERRIDES = new Set(["environment", "costmanagement", "owner", "category"]);
const TAG_SCHEMAS = {
  costmanagement: {
    fields: [
      { name: "CostCenter", required: true },
      { name: "MRU", required: false },
      { name: "LocationCode", required: false },
      { name: "ExpirationDate", required: false },
    ],
  },
  owner: {
    fields: [
      { name: "EPRID", required: true },
      { name: "Name", required: true },
      { name: "Contact", required: true },
    ],
  },
  category: {
    fields: [
      { name: "Environment", required: true },
      { name: "Criticality", required: true },
      { name: "Role", required: true },
    ],
  },
};

app.use(express.json({ limit: "2mb" }));
app.use(express.static(path.join(__dirname, "public")));

function parseVariableBlocks(content) {
  const blocks = [];
  const startRegex = /variable\s+"([^"]+)"\s*\{/g;
  let match;

  while ((match = startRegex.exec(content)) !== null) {
    const name = match[1];
    const blockStart = content.indexOf("{", match.index);
    let depth = 0;
    let inString = false;
    let escaped = false;
    let endIndex = -1;

    for (let i = blockStart; i < content.length; i++) {
      const char = content[i];

      if (inString) {
        if (!escaped && char === "\\") {
          escaped = true;
          continue;
        }
        if (!escaped && char === '"') {
          inString = false;
        }
        escaped = false;
        continue;
      }

      if (char === '"') {
        inString = true;
        continue;
      }

      if (char === "{") {
        depth += 1;
      } else if (char === "}") {
        depth -= 1;
        if (depth === 0) {
          endIndex = i;
          break;
        }
      }
    }

    if (endIndex === -1) {
      continue;
    }

    const body = content.slice(blockStart + 1, endIndex);
    blocks.push({ name, body });
    startRegex.lastIndex = endIndex + 1;
  }

  return blocks;
}

function parseVariableMetadata(body) {
  const description = body.match(/description\s*=\s*"([\s\S]*?)"/);
  const type = body.match(/type\s*=\s*([^\n\r]+)/);
  const defaultMatch = body.match(/default\s*=\s*([^\n\r]+)/);
  const sensitiveMatch = body.match(/sensitive\s*=\s*(true|false)/);

  let defaultValue;
  if (defaultMatch) {
    const raw = defaultMatch[1].trim();
    if (raw === "true" || raw === "false") {
      defaultValue = raw === "true";
    } else if (/^-?\d+(\.\d+)?$/.test(raw)) {
      defaultValue = Number(raw);
    } else if (raw.startsWith('"') && raw.endsWith('"')) {
      defaultValue = raw.slice(1, -1);
    } else {
      defaultValue = raw;
    }
  }

  return {
    description: description ? description[1] : "",
    type: type ? type[1].trim() : "string",
    required: !defaultMatch,
    sensitive: sensitiveMatch ? sensitiveMatch[1] === "true" : false,
    defaultValue,
  };
}

function loadVariables() {
  if (!fs.existsSync(VARIABLES_FILE)) {
    throw new Error(`Could not find variables file: ${VARIABLES_FILE}`);
  }

  const content = fs.readFileSync(VARIABLES_FILE, "utf8");
  const blocks = parseVariableBlocks(content);

  return blocks.map((block) => {
    const parsed = parseVariableMetadata(block.body);
    return {
      name: block.name,
      ...parsed,
      required: parsed.required || REQUIRED_OVERRIDES.has(block.name),
    };
  });
}

function normalizeEnvironmentValue(raw) {
  const value = String(raw || "").trim().toLowerCase();
  const mapping = {
    dev: "development",
    development: "development",
    stg: "staging",
    staging: "staging",
    qa: "qa",
    pro: "production",
    prod: "production",
    production: "production",
  };

  const normalized = mapping[value];
  if (!normalized) {
    throw new Error("Invalid environment. Allowed values are DEV, STG, QA, PRO.");
  }
  return normalized;
}

function toTfvarsValue(value, type) {
  const normalizedType = (type || "string").trim().toLowerCase();

  if (normalizedType.startsWith("bool")) {
    if (typeof value === "boolean") return value ? "true" : "false";
    if (typeof value === "string") {
      const v = value.trim().toLowerCase();
      if (v === "true" || v === "false") return v;
    }
    throw new Error(`Expected boolean for type '${type}'`);
  }

  if (normalizedType.startsWith("number")) {
    const n = typeof value === "number" ? value : Number(value);
    if (Number.isNaN(n)) {
      throw new Error(`Expected number for type '${type}'`);
    }
    return String(n);
  }

  if (
    normalizedType.startsWith("list") ||
    normalizedType.startsWith("set") ||
    normalizedType.startsWith("map") ||
    normalizedType.startsWith("object") ||
    normalizedType.startsWith("tuple")
  ) {
    let parsed = value;
    if (typeof value === "string") {
      const raw = value.trim();
      if (!raw) {
        throw new Error(`Expected non-empty value for type '${type}'`);
      }

      // Accept either JSON or raw HCL expression from uploaded tfvars content.
      try {
        parsed = JSON.parse(raw);
      } catch {
        return raw;
      }
    }
    return JSON.stringify(parsed, null, 2);
  }

  const stringValue = value == null ? "" : String(value);
  return JSON.stringify(stringValue);
}

function normalizeAndValidateTagValue(variableName, rawValue) {
  const schema = TAG_SCHEMAS[variableName];
  if (!schema) {
    return rawValue;
  }

  const raw = String(rawValue == null ? "" : rawValue).trim();
  const parsed = {};
  for (const field of schema.fields) {
    parsed[field.name] = "";
  }

  if (raw) {
    raw
      .split("+")
      .map((part) => part.trim())
      .filter(Boolean)
      .forEach((part) => {
        const idx = part.indexOf(":");
        if (idx < 0) return;
        const key = part.slice(0, idx).trim();
        const value = part.slice(idx + 1);
        if (Object.prototype.hasOwnProperty.call(parsed, key)) {
          parsed[key] = value;
        }
      });
  }

  for (const field of schema.fields) {
    if (field.required && !String(parsed[field.name] || "").trim()) {
      throw new Error(`Missing required ${variableName} field: ${field.name}`);
    }
  }

  return schema.fields.map((field) => `${field.name}:${parsed[field.name] || ""}`).join("+");
}

function buildTfvarsContent(variables, values) {
  const lines = [
    "# Generated by terraform-webui",
    `# ${new Date().toISOString()}`,
    "",
  ];

  for (const variable of variables) {
    let raw = values[variable.name];
    const isEmptyString = typeof raw === "string" && raw.trim() === "";
    const isMissing = raw === undefined || raw === null || isEmptyString;

    if (isMissing) {
      if (variable.required) {
        throw new Error(`Missing required variable: ${variable.name}`);
      }
      continue;
    }

    if (variable.name === "environment") {
      raw = normalizeEnvironmentValue(raw);
    }
    if (TAG_SCHEMAS[variable.name]) {
      raw = normalizeAndValidateTagValue(variable.name, raw);
    }

    const rendered = toTfvarsValue(raw, variable.type);

    if (rendered.includes("\n")) {
      lines.push(`${variable.name} = ${rendered}`);
    } else {
      lines.push(`${variable.name} = ${rendered}`);
    }
  }

  lines.push("");
  return lines.join("\n");
}

function runCommand(command, args, cwd) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      shell: true,
      env: process.env,
    });

    let output = "";
    let settled = false;

    // Prevent commands from waiting on stdin.
    if (child.stdin) {
      child.stdin.end();
    }

    child.stdout.on("data", (data) => {
      output += data.toString();
    });

    child.stderr.on("data", (data) => {
      output += data.toString();
    });

    child.on("error", (error) => {
      if (settled) return;
      settled = true;
      resolve({ code: 1, output: `${output}\n${error.message}`.trim() });
    });

    child.on("close", (code) => {
      if (settled) return;
      settled = true;
      resolve({ code, output });
    });
  });
}

function runCommandStreaming(command, args, cwd, onData) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      shell: true,
      env: process.env,
    });

    let output = "";
    let settled = false;

    if (child.stdin) {
      child.stdin.end();
    }

    child.stdout.on("data", (data) => {
      const text = data.toString();
      output += text;
      onData(text, "stdout");
    });

    child.stderr.on("data", (data) => {
      const text = data.toString();
      output += text;
      onData(text, "stderr");
    });

    child.on("error", (error) => {
      if (settled) return;
      settled = true;
      resolve({ code: 1, output: `${output}\n${error.message}`.trim() });
    });

    child.on("close", (code) => {
      if (settled) return;
      settled = true;
      resolve({ code, output });
    });
  });
}

function writeStreamEvent(res, payload) {
  res.write(`${JSON.stringify(payload)}\n`);
}

function parseWorkspacesFromOutput(output) {
  return String(output || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .map((line) => line.replace(/^\*\s*/, "").trim())
    .filter((line) => /^[a-zA-Z0-9._-]+$/.test(line));
}

function trimOutput(text, max = 2000) {
  const value = String(text || "");
  if (value.length <= max) return value;
  return `${value.slice(0, max)}\n... [truncated]`;
}

function findTopLevelEqualsIndex(statement) {
  let inString = false;
  let escaped = false;
  let brace = 0;
  let bracket = 0;
  let paren = 0;

  for (let i = 0; i < statement.length; i++) {
    const ch = statement[i];
    if (inString) {
      if (!escaped && ch === "\\") {
        escaped = true;
        continue;
      }
      if (!escaped && ch === '"') {
        inString = false;
      }
      escaped = false;
      continue;
    }

    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "{") brace += 1;
    else if (ch === "}") brace -= 1;
    else if (ch === "[") bracket += 1;
    else if (ch === "]") bracket -= 1;
    else if (ch === "(") paren += 1;
    else if (ch === ")") paren -= 1;
    else if (ch === "=" && brace === 0 && bracket === 0 && paren === 0) return i;
  }
  return -1;
}

function splitTfvarsStatements(content) {
  const normalized = String(content || "").replace(/\r\n/g, "\n");
  const statements = [];
  let current = "";
  let inString = false;
  let escaped = false;
  let brace = 0;
  let bracket = 0;
  let paren = 0;
  let inLineComment = false;
  let inBlockComment = false;

  for (let i = 0; i < normalized.length; i++) {
    const ch = normalized[i];
    const next = normalized[i + 1];

    if (inLineComment) {
      if (ch === "\n") {
        inLineComment = false;
        if (!inString && brace === 0 && bracket === 0 && paren === 0) {
          if (current.trim()) statements.push(current.trim());
          current = "";
        } else {
          current += ch;
        }
      }
      continue;
    }

    if (inBlockComment) {
      if (ch === "*" && next === "/") {
        inBlockComment = false;
        i += 1;
      }
      continue;
    }

    if (!inString && ch === "/" && next === "/") {
      inLineComment = true;
      i += 1;
      continue;
    }
    if (!inString && ch === "#") {
      inLineComment = true;
      continue;
    }
    if (!inString && ch === "/" && next === "*") {
      inBlockComment = true;
      i += 1;
      continue;
    }

    current += ch;

    if (inString) {
      if (!escaped && ch === "\\") {
        escaped = true;
        continue;
      }
      if (!escaped && ch === '"') {
        inString = false;
      }
      escaped = false;
      continue;
    }

    if (ch === '"') inString = true;
    else if (ch === "{") brace += 1;
    else if (ch === "}") brace -= 1;
    else if (ch === "[") bracket += 1;
    else if (ch === "]") bracket -= 1;
    else if (ch === "(") paren += 1;
    else if (ch === ")") paren -= 1;

    if (ch === "\n" && brace === 0 && bracket === 0 && paren === 0) {
      if (current.trim()) statements.push(current.trim());
      current = "";
    }
  }

  if (current.trim()) statements.push(current.trim());
  return statements;
}

function parseTfvarsValue(rawValue) {
  const value = String(rawValue || "").trim();
  if (!value) return "";
  if (value === "true") return true;
  if (value === "false") return false;
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value);
  if (value.startsWith('"') && value.endsWith('"')) {
    try {
      return JSON.parse(value);
    } catch {
      return value.slice(1, -1);
    }
  }
  // For complex HCL expressions (maps/lists/objects), keep raw text.
  return value;
}

function parseTfvarsContent(content) {
  const result = {};
  const statements = splitTfvarsStatements(content);
  for (const statement of statements) {
    const eqIndex = findTopLevelEqualsIndex(statement);
    if (eqIndex < 1) continue;
    const key = statement.slice(0, eqIndex).trim();
    const valueRaw = statement.slice(eqIndex + 1).trim();
    if (!key) continue;
    result[key] = parseTfvarsValue(valueRaw);
  }
  return result;
}

function findWorkspaceTfvarsFile(workspace) {
  const safeWorkspace = String(workspace || "").trim();
  if (!safeWorkspace) return null;

  const candidates = [
    `${safeWorkspace}.tfvars`,
    `${safeWorkspace}.auto.tfvars`,
    `${safeWorkspace}.auto.tfvars.json`,
  ];

  for (const file of candidates) {
    const fullPath = path.join(TERRAFORM_DIR, file);
    if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
      return fullPath;
    }
  }

  return null;
}

app.get("/api/variables", (req, res) => {
  try {
    const variables = loadVariables();
    res.json({
      terraformDir: TERRAFORM_DIR,
      variables,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/workspaces", async (req, res) => {
  try {
    // Fast path: if already initialized, this returns quickly.
    let listResult = await runCommand("terraform", ["workspace", "list"], TERRAFORM_DIR);

    // Fallback: initialize backend, then retry workspace list.
    if (listResult.code !== 0) {
      const initResult = await runCommand("terraform", ["init", "-input=false"], TERRAFORM_DIR);
      if (initResult.code !== 0) {
        return res.status(500).json({
          error: "Terraform init failed while loading workspaces.",
          details: trimOutput(initResult.output),
        });
      }

      listResult = await runCommand("terraform", ["workspace", "list"], TERRAFORM_DIR);
      if (listResult.code !== 0) {
        return res.status(500).json({
          error: "Failed to load workspaces from backend state.",
          details: trimOutput(listResult.output),
        });
      }
    }

    const workspaces = parseWorkspacesFromOutput(listResult.output);
    res.json({ terraformDir: TERRAFORM_DIR, workspaces });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/workspace-values", (req, res) => {
  try {
    const workspace = String(req.query.workspace || "").trim();
    if (!workspace) {
      return res.status(400).json({ error: "workspace query parameter is required." });
    }
    if (!/^[a-zA-Z0-9._-]+$/.test(workspace)) {
      return res.status(400).json({ error: "Invalid workspace name." });
    }

    const tfvarsPath = findWorkspaceTfvarsFile(workspace);
    if (!tfvarsPath) {
      return res.json({
        workspace,
        terraformDir: TERRAFORM_DIR,
        tfvarsPath: null,
        values: {},
      });
    }

    const content = fs.readFileSync(tfvarsPath, "utf8");
    const values = parseTfvarsContent(content);
    res.json({
      workspace,
      terraformDir: TERRAFORM_DIR,
      tfvarsPath,
      tfvarsFilename: path.basename(tfvarsPath),
      values,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/run", async (req, res) => {
  try {
    const { action, values, tfvarsFilename, workspace, destroyConfirmation } = req.body;
    if (!["plan", "apply", "destroy"].includes(action)) {
      return res.status(400).json({ error: "Action must be 'plan', 'apply', or 'destroy'." });
    }

    if (action === "destroy" && destroyConfirmation !== "DESTROY") {
      return res.status(400).json({
        error: "Destroy requires confirmation phrase: DESTROY",
      });
    }

    const variables = loadVariables();
    const tfvarsContent = buildTfvarsContent(variables, values || {});
    const safeFilename = (tfvarsFilename || "webui.auto.tfvars").replace(/[^a-zA-Z0-9._-]/g, "_");
    const tfvarsPath = path.join(TERRAFORM_DIR, safeFilename);

    fs.writeFileSync(tfvarsPath, tfvarsContent, "utf8");

    const steps = [];

    const initResult = await runCommand("terraform", ["init", "-input=false"], TERRAFORM_DIR);
    steps.push({ command: "terraform init -input=false", ...initResult });

    if (initResult.code !== 0) {
      return res.status(500).json({
        error: "Terraform init failed",
        tfvarsPath,
        steps,
      });
    }

    const workspaceName = String(workspace || "").trim();
    if (workspaceName) {
      const selectResult = await runCommand("terraform", ["workspace", "select", workspaceName], TERRAFORM_DIR);
      steps.push({ command: `terraform workspace select ${workspaceName}`, ...selectResult });
      if (selectResult.code !== 0) {
        return res.status(500).json({
          error: `Failed to select workspace: ${workspaceName}`,
          tfvarsPath,
          steps,
        });
      }
    }

    if (action === "destroy") {
      const stateListResult = await runCommand("terraform", ["state", "list"], TERRAFORM_DIR);
      steps.push({ command: "terraform state list", ...stateListResult });
      if (stateListResult.code !== 0) {
        return res.status(500).json({
          error: "Unable to read state before destroy.",
          tfvarsPath,
          steps,
        });
      }

      const resources = String(stateListResult.output || "")
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean);
      if (resources.length === 0) {
        return res.status(400).json({
          error: "Selected workspace has no resources in state. Nothing to destroy.",
          tfvarsPath,
          steps,
        });
      }
    }

    const terraformArgs = [action, "-input=false", "-no-color", "-var-file", safeFilename];
    if (action === "apply" || action === "destroy") {
      terraformArgs.splice(1, 0, "-auto-approve");
    }

    const actionResult = await runCommand("terraform", terraformArgs, TERRAFORM_DIR);
    steps.push({ command: `terraform ${terraformArgs.join(" ")}`, ...actionResult });

    const ok = actionResult.code === 0;
    res.status(ok ? 200 : 500).json({
      ok,
      tfvarsPath,
      steps,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/run-stream", async (req, res) => {
  res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("Connection", "keep-alive");

  const send = (event) => writeStreamEvent(res, event);
  const sendStatus = (message) => send({ type: "status", message, at: new Date().toISOString() });

  try {
    const { action, values, tfvarsFilename, workspace, destroyConfirmation } = req.body || {};
    if (!["plan", "apply", "destroy"].includes(action)) {
      send({ type: "error", error: "Action must be 'plan', 'apply', or 'destroy'." });
      return res.end();
    }

    if (action === "destroy" && destroyConfirmation !== "DESTROY") {
      send({ type: "error", error: "Destroy requires confirmation phrase: DESTROY" });
      return res.end();
    }

    const variables = loadVariables();
    const tfvarsContent = buildTfvarsContent(variables, values || {});
    const safeFilename = (tfvarsFilename || "webui.auto.tfvars").replace(/[^a-zA-Z0-9._-]/g, "_");
    const tfvarsPath = path.join(TERRAFORM_DIR, safeFilename);
    fs.writeFileSync(tfvarsPath, tfvarsContent, "utf8");
    send({ type: "tfvars", tfvarsPath, tfvarsFilename: safeFilename });

    const runStep = async (command, args, label) => {
      const commandText = `${command} ${args.join(" ")}`;
      send({ type: "step_start", label, command: commandText });
      const result = await runCommandStreaming(command, args, TERRAFORM_DIR, (chunk) => {
        send({ type: "log", label, chunk });
      });
      send({ type: "step_end", label, command: commandText, code: result.code });
      return result;
    };

    sendStatus("Initializing Terraform...");
    const initResult = await runStep("terraform", ["init", "-input=false"], "init");
    if (initResult.code !== 0) {
      send({ type: "error", error: "Terraform init failed", code: initResult.code });
      return res.end();
    }

    const workspaceName = String(workspace || "").trim();
    if (workspaceName) {
      sendStatus(`Selecting workspace '${workspaceName}'...`);
      const selectResult = await runStep(
        "terraform",
        ["workspace", "select", workspaceName],
        "workspace-select"
      );
      if (selectResult.code !== 0) {
        send({ type: "error", error: `Failed to select workspace: ${workspaceName}` });
        return res.end();
      }
    }

    if (action === "destroy") {
      sendStatus("Checking state before destroy...");
      const stateListResult = await runStep("terraform", ["state", "list"], "state-list");
      if (stateListResult.code !== 0) {
        send({ type: "error", error: "Unable to read state before destroy." });
        return res.end();
      }
      const resources = String(stateListResult.output || "")
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean);
      if (resources.length === 0) {
        send({ type: "error", error: "Selected workspace has no resources in state. Nothing to destroy." });
        return res.end();
      }
    }

    const terraformArgs = [action, "-input=false", "-no-color", "-var-file", safeFilename];
    if (action === "apply" || action === "destroy") {
      terraformArgs.splice(1, 0, "-auto-approve");
    }

    sendStatus(`Running terraform ${action}...`);
    const actionResult = await runStep("terraform", terraformArgs, action);
    const ok = actionResult.code === 0;
    send({ type: "done", ok, tfvarsPath, action, code: actionResult.code });
    return res.end();
  } catch (error) {
    send({ type: "error", error: error.message || "Unexpected error." });
    return res.end();
  }
});

app.listen(PORT, () => {
  console.log(`terraform-webui running on http://localhost:${PORT}`);
  console.log(`Terraform directory: ${TERRAFORM_DIR}`);
});


