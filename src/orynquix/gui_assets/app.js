"use strict";

const ui = {
  currentPage: "home",
  sessionState: "stopped",
  activeJob: null,
  activity: [],
  toastTimer: null,
  pendingConfirmation: null,
};

const ACTION_COPY = {
  doctor: {
    working: "Checking this phone",
    detail: "Inspecting Android, architecture, storage, Termux, and runtime prerequisites…",
    success: "Phone check complete",
  },
  setup: {
    working: "Building your workspace",
    detail: "Installing the persistent Debian and XFCE environment in resumable steps…",
    success: "Workstation setup complete",
  },
  start: {
    working: "Starting workspace",
    detail: "Bringing up the display, optional audio, guest services, and XFCE in order…",
    success: "Workspace is ready",
  },
  stop: {
    working: "Stopping workspace",
    detail: "Closing identity-verified Orynquix processes in reverse order…",
    success: "Workspace stopped cleanly",
  },
  repair: {
    working: "Repairing workspace",
    detail: "Archiving invalid state and cleaning up only verified Orynquix processes…",
    success: "Workspace repaired",
  },
  "phone-proof": {
    working: "Running phone proof",
    detail: "Completing five graphical start / stop cycles and recording real-device evidence…",
    success: "Phone proof finished",
  },
};

const CONFIRM_COPY = {
  setup: {
    title: "Set up this phone?",
    copy: "This installs the Debian root filesystem, XFCE desktop, and required host packages. Your projects stay in a separate preserved folder.",
    button: "Begin setup",
  },
  "phone-proof": {
    title: "Run the five-cycle proof?",
    copy: "The graphical workspace will start and stop five times. Keep Termux open and the phone awake until the evidence report is saved.",
    button: "Run proof",
  },
  repair: {
    title: "Repair workspace state?",
    copy: "Orynquix will archive invalid state and stop only processes whose recorded identity still matches.",
    button: "Repair safely",
  },
};

function byId(id) {
  return document.getElementById(id);
}

function titleCase(value) {
  return String(value || "unknown")
    .replaceAll("-", " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function showPage(pageName) {
  const page = document.querySelector(`[data-page="${pageName}"]`);
  if (!page) return;
  document.querySelectorAll("[data-page]").forEach((candidate) => {
    const active = candidate === page;
    candidate.classList.toggle("active", active);
    candidate.hidden = !active;
  });
  document.querySelectorAll(".rail-item[data-page-target]").forEach((item) => {
    item.classList.toggle("active", item.dataset.pageTarget === pageName);
  });
  ui.currentPage = pageName;
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function serviceByName(status, name) {
  return Array.isArray(status.services)
    ? status.services.find((service) => service.name === name)
    : undefined;
}

function serviceLabel(service, waiting = "Waiting") {
  if (!service) return waiting;
  if (service.health === "pass") return "Ready";
  if (service.health === "warn") return "Degraded";
  if (service.health === "fail") return "Failed";
  return "Not enabled";
}

function renderStatus(status) {
  const state = String(status.state || "stopped");
  ui.sessionState = state;
  const capsule = byId("status-capsule");
  capsule.className = `status-capsule status-${state}`;
  const capsuleLabels = {
    stopped: "Offline",
    starting: "Starting",
    running: "Workspace ready",
    degraded: "Degraded",
    failed: "Needs repair",
    repairing: "Repairing",
    stopping: "Stopping",
  };
  byId("status-capsule-label").textContent = capsuleLabels[state] || titleCase(state);
  byId("session-metric").textContent = titleCase(state);

  const detailLabels = {
    stopped: "Ready when you are",
    running: "All required services healthy",
    degraded: "Usable with a limitation",
    failed: status.diagnostic_id || "Open Activity for details",
  };
  byId("session-detail").textContent = detailLabels[state] || "Lifecycle operation in progress";

  const display = serviceByName(status, "display");
  const desktop = serviceByName(status, "desktop");
  byId("display-metric").textContent = serviceLabel(display, state === "stopped" ? "Waiting" : "Checking");
  byId("desktop-metric").textContent = serviceLabel(desktop, state === "stopped" ? "Waiting" : "Checking");

  const primary = byId("primary-session-action");
  const label = byId("primary-session-label");
  if (state === "running" || state === "degraded") {
    primary.dataset.action = "stop";
    label.textContent = "Stop workspace";
  } else if (state === "failed") {
    primary.dataset.action = "repair";
    label.textContent = "Repair workspace";
  } else {
    primary.dataset.action = "start";
    label.textContent = "Start workspace";
  }
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    credentials: "same-origin",
    cache: "no-store",
    ...options,
  });
  let body;
  try {
    body = await response.json();
  } catch {
    body = { ok: false, message: `Unexpected server response (${response.status})` };
  }
  if (!response.ok) {
    const error = new Error(body.message || `Request failed (${response.status})`);
    error.body = body;
    throw error;
  }
  return body;
}

async function refreshStatus({ quiet = true } = {}) {
  if (ui.activeJob) return;
  try {
    renderStatus(await api("/api/status"));
  } catch (error) {
    if (!quiet) showToast("Status unavailable", error.message, true);
  }
}

function setBusy(action, busy) {
  const overlay = byId("operation-overlay");
  overlay.hidden = !busy;
  document.querySelectorAll("button[data-action], button[data-confirm-action]").forEach((button) => {
    button.disabled = busy;
  });
  if (busy) {
    const copy = ACTION_COPY[action] || { working: "Working", detail: "Completing the selected operation…" };
    byId("operation-title").textContent = copy.working;
    byId("operation-detail").textContent = copy.detail;
  }
}

function sleep(milliseconds) {
  return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
}

async function pollJob(jobId) {
  for (;;) {
    const job = await api(`/api/jobs/${encodeURIComponent(jobId)}`);
    if (job.state === "succeeded" || job.state === "failed") return job;
    await sleep(850);
  }
}

async function runAction(action) {
  if (ui.activeJob) return;
  setBusy(action, true);
  try {
    const accepted = await api("/api/jobs", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Orynquix-Request": "gui-v1",
      },
      body: JSON.stringify({
        action,
        payload: action === "phone-proof" ? { cycles: 5 } : {},
      }),
    });
    ui.activeJob = accepted.job_id;
    const job = await pollJob(accepted.job_id);
    if (job.state === "failed") {
      const error = new Error(job.error?.message || "Operation failed");
      error.body = job.error || {};
      throw error;
    }
    addActivity(action, "succeeded", job.result || {});
    showToast(ACTION_COPY[action]?.success || "Operation complete", summarize(action, job.result || {}));
    if (action === "phone-proof" || action === "doctor") showPage("activity");
  } catch (error) {
    const details = error.body || { message: error.message };
    addActivity(action, "failed", details);
    showToast(
      "Action needs attention",
      details.diagnostic_id ? `${details.message} • ${details.diagnostic_id}` : details.message || error.message,
      true,
    );
    showPage("activity");
  } finally {
    ui.activeJob = null;
    setBusy(action, false);
    await refreshStatus({ quiet: true });
  }
}

function summarize(action, result) {
  if (action === "doctor") {
    const count = Array.isArray(result.checks) ? result.checks.length : 0;
    return result.supported ? `${count} checks completed; this phone is supported.` : `${count} checks completed; review the failed requirements.`;
  }
  if (action === "setup") {
    const changed = Array.isArray(result.changed_steps) ? result.changed_steps.length : 0;
    return changed ? `${changed} setup steps completed.` : "The workstation was already set up.";
  }
  if (action === "phone-proof") {
    const report = result.report || {};
    const done = report.completed_cycles ?? 0;
    return result.ok ? `${done} cycles passed and the evidence report was saved.` : `${done} cycles completed; review the evidence.`;
  }
  if (action === "start") return `Session is ${result.state || "running"}.`;
  if (action === "stop") return "The graphical session closed cleanly.";
  if (action === "repair") return "Lifecycle state is ready for another launch.";
  return "Finished successfully.";
}

function addActivity(action, state, details) {
  const item = {
    id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
    action,
    state,
    details,
    at: new Date(),
  };
  ui.activity.unshift(item);
  ui.activity = ui.activity.slice(0, 25);
  renderActivity();
  byId("activity-badge").hidden = ui.currentPage === "activity";
}

function renderActivity() {
  const list = byId("activity-list");
  list.replaceChildren();
  byId("empty-activity").hidden = ui.activity.length > 0;
  for (const item of ui.activity) {
    const article = document.createElement("article");
    article.className = `activity-item ${item.state}`;

    const head = document.createElement("div");
    head.className = "activity-head";
    const state = document.createElement("span");
    state.className = "activity-state";
    state.textContent = item.state === "succeeded" ? "✓" : "!";
    const copy = document.createElement("div");
    const title = document.createElement("strong");
    title.textContent = ACTION_COPY[item.action]?.success || titleCase(item.action);
    const time = document.createElement("small");
    time.textContent = `${item.at.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })} • ${item.state}`;
    copy.append(title, time);
    head.append(state, copy);

    const details = document.createElement("details");
    const summary = document.createElement("summary");
    summary.textContent = "View technical details";
    const pre = document.createElement("pre");
    pre.textContent = JSON.stringify(item.details, null, 2);
    details.append(summary, pre);
    article.append(head, details);
    list.append(article);
  }
}

function showToast(title, copy, error = false) {
  const toast = byId("toast");
  toast.classList.toggle("error", error);
  byId("toast-icon").textContent = error ? "!" : "✓";
  byId("toast-title").textContent = title;
  byId("toast-copy").textContent = copy || "";
  toast.hidden = false;
  if (ui.toastTimer) window.clearTimeout(ui.toastTimer);
  ui.toastTimer = window.setTimeout(() => { toast.hidden = true; }, 5200);
}

function requestConfirmation(action) {
  const copy = CONFIRM_COPY[action];
  if (!copy) {
    runAction(action);
    return;
  }
  ui.pendingConfirmation = action;
  byId("confirm-title").textContent = copy.title;
  byId("confirm-copy").textContent = copy.copy;
  byId("confirm-submit").textContent = copy.button;
  byId("confirm-dialog").showModal();
}

document.addEventListener("click", (event) => {
  const pageButton = event.target.closest("[data-page-target]");
  if (pageButton) {
    showPage(pageButton.dataset.pageTarget);
    if (pageButton.dataset.pageTarget === "activity") byId("activity-badge").hidden = true;
    return;
  }
  const confirmButton = event.target.closest("[data-confirm-action]");
  if (confirmButton) {
    requestConfirmation(confirmButton.dataset.confirmAction);
    return;
  }
  const actionButton = event.target.closest("[data-action]");
  if (actionButton) {
    const action = actionButton.dataset.action;
    if (action === "repair") requestConfirmation(action);
    else runAction(action);
    return;
  }
  if (event.target.closest("[data-refresh-status]")) refreshStatus({ quiet: false });
});

byId("confirm-dialog").addEventListener("close", () => {
  if (byId("confirm-dialog").returnValue === "confirm" && ui.pendingConfirmation) {
    const action = ui.pendingConfirmation;
    ui.pendingConfirmation = null;
    runAction(action);
  } else {
    ui.pendingConfirmation = null;
  }
});

window.addEventListener("online", () => refreshStatus({ quiet: true }));
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) refreshStatus({ quiet: true });
});

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js").catch(() => {});
}

refreshStatus({ quiet: false });
window.setInterval(() => refreshStatus({ quiet: true }), 6000);
