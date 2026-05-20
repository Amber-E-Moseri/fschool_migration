// Direct-email modal — IIFE global, works in both ES-module and non-module pages.
// API: FSDirectEmail.init({ supabase, senderEmail }), FSDirectEmail.open({ email, name }) or open({ bulk: true })
(function (global) {
  "use strict";

  let _db = null;
  let _senderEmail = "";
  let _root = null;
  let _bulkMode = false;

  const MODAL_ID = "fsDemRoot";
  const STYLE_ID = "fsDemStyle";

  // ── Escape ────────────────────────────────────────────────────────────────────
  function esc(v) {
    return String(v ?? "").replace(/[&<>'"]/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[c])
    );
  }

  // ── Style injection ───────────────────────────────────────────────────────────
  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const s = document.createElement("style");
    s.id = STYLE_ID;
    s.textContent = `
#fsDemRoot{position:fixed;inset:0;z-index:9800;display:none;align-items:center;justify-content:center;padding:16px;background:rgba(15,18,34,.45)}
#fsDemRoot.open{display:flex}
#fsDemDialog{width:min(540px,100%);background:#fff;border-radius:16px;padding:32px;box-sizing:border-box;font-family:'Manrope',system-ui,sans-serif;box-shadow:0 8px 40px rgba(0,0,0,.22);max-height:90vh;overflow-y:auto}
.fsdem-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:20px}
.fsdem-title{margin:0;font-size:18px;font-weight:800;color:#1E1630}
.fsdem-close{background:none;border:none;cursor:pointer;font-size:20px;line-height:1;color:#6f6881;padding:4px}
.fsdem-grid{display:flex;flex-direction:column;gap:14px}
.fsdem-label{display:block;font-size:12px;font-weight:700;color:#4C2A92;margin-bottom:4px;text-transform:uppercase;letter-spacing:.04em}
.fsdem-input,.fsdem-textarea{width:100%;box-sizing:border-box;border:1px solid #e0d9ff;border-radius:8px;padding:10px 12px;font-size:14px;color:#1E1630;outline:none;font-family:inherit;background:#fff}
.fsdem-input:focus,.fsdem-textarea:focus{border-color:#7c3aed;box-shadow:0 0 0 3px rgba(124,58,237,.12)}
.fsdem-input[readonly]{background:#f8f6ff;color:#4C2A92}
.fsdem-textarea{min-height:130px;resize:vertical}
.fsdem-hint{margin:4px 0 0;font-size:12px;color:#9c91b7}
.fsdem-error{display:none;background:#fff1f2;border:1px solid #fecaca;border-radius:8px;padding:10px 12px;color:#991b1b;font-size:13px;font-weight:600}
.fsdem-actions{display:flex;gap:10px;justify-content:flex-end;margin-top:4px}
.fsdem-btn{padding:10px 22px;border-radius:10px;font-weight:700;font-size:14px;cursor:pointer;font-family:inherit;border:none;transition:opacity .15s}
.fsdem-btn:disabled{opacity:.6;cursor:not-allowed}
.fsdem-btn-secondary{background:#fff;border:1px solid #e0d9ff;color:#4C2A92}
.fsdem-btn-primary{background:#4C2A92;color:#fff}
`;
    document.head.appendChild(s);
  }

  // ── DOM bootstrap ─────────────────────────────────────────────────────────────
  function ensureRoot() {
    if (_root) return _root;
    ensureStyle();
    _root = document.createElement("div");
    _root.id = MODAL_ID;
    _root.setAttribute("role", "dialog");
    _root.setAttribute("aria-modal", "true");
    _root.setAttribute("aria-labelledby", "fsDemTitle");
    _root.innerHTML = `
<div id="fsDemDialog">
  <div class="fsdem-head">
    <h2 id="fsDemTitle" class="fsdem-title">Send Email</h2>
    <button class="fsdem-close" id="fsDemClose" aria-label="Close">&#x2715;</button>
  </div>
  <div class="fsdem-grid">
    <div>
      <label class="fsdem-label" for="fsDemTo">To</label>
      <input id="fsDemTo" class="fsdem-input" type="text" autocomplete="off" placeholder="recipient@example.com" />
      <p id="fsDemToHint" class="fsdem-hint" style="display:none">Separate multiple addresses with commas or semicolons.</p>
    </div>
    <div>
      <label class="fsdem-label" for="fsDemSubject">Subject</label>
      <input id="fsDemSubject" class="fsdem-input" type="text" placeholder="Email subject" />
    </div>
    <div>
      <label class="fsdem-label" for="fsDemMessage">Message</label>
      <textarea id="fsDemMessage" class="fsdem-textarea" placeholder="Write your message here (min. 10 characters)…"></textarea>
    </div>
    <div id="fsDemError" class="fsdem-error" role="alert"></div>
    <div class="fsdem-actions">
      <button id="fsDemCancel" class="fsdem-btn fsdem-btn-secondary" type="button">Cancel</button>
      <button id="fsDemSend"   class="fsdem-btn fsdem-btn-primary"   type="button">Send Email</button>
    </div>
  </div>
</div>`;
    document.body.appendChild(_root);

    _root.addEventListener("click", (e) => { if (e.target === _root) close(); });
    document.getElementById("fsDemClose").addEventListener("click", close);
    document.getElementById("fsDemCancel").addEventListener("click", close);
    document.addEventListener("keydown", (e) => { if (e.key === "Escape" && _root.classList.contains("open")) close(); });
    document.getElementById("fsDemSend").addEventListener("click", handleSend);
    return _root;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  function showError(msg) {
    const el = document.getElementById("fsDemError");
    el.textContent = msg;
    el.style.display = "block";
  }

  function clearError() {
    const el = document.getElementById("fsDemError");
    if (el) { el.textContent = ""; el.style.display = "none"; }
  }

  function setSending(on) {
    const btn = document.getElementById("fsDemSend");
    if (!btn) return;
    btn.disabled = on;
    btn.textContent = on ? "Sending…" : "Send Email";
  }

  function showToast(msg) {
    if (global.FSToast?.show) { global.FSToast.show(msg, "success"); return; }
    const t = document.createElement("div");
    t.style.cssText =
      "position:fixed;bottom:24px;right:24px;z-index:99999;background:#1a7f4b;color:#fff;" +
      "padding:12px 20px;border-radius:12px;font-family:Manrope,system-ui,sans-serif;" +
      "font-size:14px;font-weight:700;box-shadow:0 4px 20px rgba(0,0,0,.2);pointer-events:none;";
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), 4000);
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /**
   * Must be called once per page with { supabase, senderEmail }.
   * Safe to call multiple times — subsequent calls update state.
   */
  function init(opts) {
    opts = opts || {};
    if (opts.supabase) _db = opts.supabase;
    if (opts.senderEmail) _senderEmail = String(opts.senderEmail || "").trim();
    ensureRoot();
  }

  /**
   * Open the modal.
   * Single mode:  open({ email, name })
   * Bulk mode:    open({ bulk: true })
   */
  function open(opts) {
    opts = opts || {};
    ensureRoot();
    clearError();

    _bulkMode = !!opts.bulk;

    const toEl   = document.getElementById("fsDemTo");
    const hint   = document.getElementById("fsDemToHint");
    const subjEl = document.getElementById("fsDemSubject");
    const msgEl  = document.getElementById("fsDemMessage");
    const title  = document.getElementById("fsDemTitle");

    if (_bulkMode) {
      toEl.value    = "";
      toEl.readOnly = false;
      hint.style.display = "block";
      title.textContent  = "New Direct Email";
    } else {
      toEl.value    = String(opts.email || "").trim();
      toEl.readOnly = true;
      toEl.dataset.recipientName = String(opts.name || "").trim();
      hint.style.display = "none";
      title.textContent  = "Send Email";
    }

    subjEl.value = "";
    msgEl.value  = "";
    setSending(false);

    _root.classList.add("open");
    document.body.style.overflow = "hidden";
    setTimeout(() => (_bulkMode ? toEl : subjEl).focus(), 60);
  }

  function close() {
    if (!_root) return;
    _root.classList.remove("open");
    document.body.style.overflow = "";
  }

  // ── Send ──────────────────────────────────────────────────────────────────────
  async function handleSend() {
    clearError();

    if (!_db) { showError("Email service not initialized. Please refresh and try again."); return; }

    const toEl    = document.getElementById("fsDemTo");
    const toRaw   = (toEl?.value || "").trim();
    const subject = (document.getElementById("fsDemSubject")?.value || "").trim();
    const message = (document.getElementById("fsDemMessage")?.value || "").trim();

    if (!toRaw)          { showError("Please enter at least one recipient email address."); return; }
    if (!subject)        { showError("Please enter a subject."); return; }
    if (message.length < 10) { showError("Message must be at least 10 characters."); return; }

    const recipientName = _bulkMode ? "" : (toEl.dataset.recipientName || "");
    const emails = toRaw.split(/[,;]+/).map((e) => e.trim().toLowerCase()).filter(Boolean);
    const invalid = emails.filter((e) => !e.includes("@") || !e.includes("."));
    if (invalid.length) { showError(`Invalid email address: ${invalid.join(", ")}`); return; }

    setSending(true);

    const now = new Date().toISOString();
    const rows = emails.map((email, i) => ({
      recipient_email: email,
      recipient_name: _bulkMode ? "" : (i === 0 ? recipientName : ""),
      template_key: "direct_message",
      subject,
      status: "Pending",
      payload: {
        subject,
        message,
        sender_email: _senderEmail,
        sent_at: now,
        recipient_name: _bulkMode ? "" : recipientName,
      },
    }));

    try {
      const { error: queueErr } = await _db.from("email_queue").insert(rows);
      if (queueErr) throw queueErr;

      try {
        await _db.from("audit_logs").insert({
          actor_email: _senderEmail || "unknown",
          action: "DIRECT_EMAIL_SENT",
          entity_type: "email_queue",
          entity_id: emails[0],
          status: "SUCCESS",
          details: { recipients: emails, subject, recipient_count: emails.length },
        });
      } catch { /* best-effort audit */ }

      close();
      const count = emails.length;
      showToast(
        count === 1
          ? "Email queued — will send within 15 minutes."
          : `${count} emails queued — will send within 15 minutes.`
      );
    } catch (err) {
      showError((err && err.message) || "Failed to queue email. Please try again.");
    } finally {
      setSending(false);
    }
  }

  global.FSDirectEmail = { init, open, close };
})(window);
