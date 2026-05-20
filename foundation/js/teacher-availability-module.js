import { submitAvailability } from "./availabilityApi.js";
import { supabase, getSessionOrNull, getCurrentProfile } from "../auth/auth-client.js";

const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const SLOTS = [
  "6:00 AM", "7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM", "11:00 AM", "12:00 PM",
  "1:00 PM", "2:00 PM", "3:00 PM", "4:00 PM", "5:00 PM", "6:00 PM", "7:00 PM", "8:00 PM", "9:00 PM", "10:00 PM",
];
const TZ_OPTIONS = [
  "America/Toronto",
  "America/Vancouver",
  "America/Edmonton",
  "America/Winnipeg",
  "America/Halifax",
  "America/St_Johns",
  "America/Regina",
  "UTC",
];
const SUBGROUP_LABELS = {
  CESGA: "Prairies (MB / SK)",
  CESGB: "Atlantic Canada",
  CSGA: "GTA, Ottawa & Quebec",
  CSGB: "Waterloo & West GTA",
  WSGA: "Alberta & BC",
  WSGB: "Southern Alberta",
};

function esc(v) {
  return String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function slotKey(day, time) { return `${day}__${time}`; }
function splitKey(key) { const [day, time] = String(key || "").split("__"); return { day, time }; }

function monthOptions(n = 6) {
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(new Date().getFullYear(), new Date().getMonth() + i, 1);
    return {
      key: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`,
      label: d.toLocaleDateString("en-US", { month: "long", year: "numeric" }),
      month: d.toLocaleDateString("en-US", { month: "long" }),
      year: d.getFullYear(),
      monthIndex: d.getMonth() + 1,
    };
  });
}
function selectedMonth(state, months) {
  return months.find((m) => m.key === state.monthKey) || months[0];
}

function parseTime12h(v) {
  const m = String(v).trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (!m) return null;
  let h = Number(m[1]);
  const mi = Number(m[2]);
  const ap = m[3].toUpperCase();
  if (ap === "PM" && h < 12) h += 12;
  if (ap === "AM" && h === 12) h = 0;
  return { h, mi };
}
function to24h(v) {
  const t = parseTime12h(v);
  if (!t) return null;
  return `${String(t.h).padStart(2, "0")}:${String(t.mi).padStart(2, "0")}:00`;
}
function dayIdx(day) { return DAYS.indexOf(day); }
function weekdayDateInMonth(year, monthIndex, weekdayName) {
  const first = new Date(year, monthIndex - 1, 1);
  const firstIdx = (first.getDay() + 6) % 7;
  const target = dayIdx(weekdayName);
  const delta = (target - firstIdx + 7) % 7;
  return 1 + delta;
}
function getTzOffsetMs(instant, timeZone) {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const p = Object.fromEntries(dtf.formatToParts(instant).map((x) => [x.type, x.value]));
  const asUtc = Date.UTC(Number(p.year), Number(p.month) - 1, Number(p.day), Number(p.hour), Number(p.minute), Number(p.second));
  return asUtc - instant.getTime();
}
function wallClockToInstant(year, monthIndex, dayOfMonth, hour, minute, timeZone) {
  const naive = Date.UTC(year, monthIndex - 1, dayOfMonth, hour, minute, 0);
  const off1 = getTzOffsetMs(new Date(naive), timeZone);
  const adj = naive - off1;
  const off2 = getTzOffsetMs(new Date(adj), timeZone);
  return new Date(off1 === off2 ? adj : adj - off2 + off1);
}
// Preserve conversion logic from teacher-schedule.html
function convertTeacherSlotToCampus(slot, teacherTz, campusTz, month) {
  const t = parseTime12h(slot.time);
  if (!t) return { campusDay: slot.day, campusTime: slot.time };
  const dom = weekdayDateInMonth(month.year, month.monthIndex, slot.day);
  const instant = wallClockToInstant(month.year, month.monthIndex, dom, t.h, t.mi, teacherTz);
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: campusTz, weekday: "long", hour: "numeric", minute: "2-digit", hour12: true }).formatToParts(instant);
  const campusDay = (parts.find((p) => p.type === "weekday") || {}).value || slot.day;
  const hr = (parts.find((p) => p.type === "hour") || {}).value || "";
  const mi = (parts.find((p) => p.type === "minute") || {}).value || "00";
  const dp = ((parts.find((p) => p.type === "dayPeriod") || {}).value || "").toUpperCase();
  return { campusDay, campusTime: `${hr}:${mi} ${dp}` };
}

export async function mountTeacherAvailability(containerId) {
  const root = document.getElementById(containerId);
  if (!root) throw new Error(`Container not found: ${containerId}`);

  const months = monthOptions(6);
  const state = {
    profile: null,
    teacherRecord: null,
    teacherOptions: [],
    selectedTeacherRecord: null,
    submitForAnother: false,
    campuses: [],
    selectedCampusCodes: new Set(),
    activeCampusCode: "",
    slotSet: new Set(),
    search: "",
    teacherTimezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "America/Toronto",
    monthKey: months[0].key,
    submitting: false,
  };

  const session = await getSessionOrNull();
  if (!session) {
    window.location.href = "../auth/login.html";
    return;
  }
  const profile = await getCurrentProfile();
  if (!profile?.email) {
    window.location.href = "../auth/login.html";
    return;
  }
  state.profile = profile;

  const teacherEmail = String(profile.email || "").trim().toLowerCase();
  const { data: teacherRow } = await supabase
    .from("teachers")
    .select("teacher_id,full_name,email,subgroup_id")
    .ilike("email", teacherEmail)
    .is("deleted_at", null)
    .limit(1)
    .maybeSingle();
  state.teacherRecord = teacherRow || null;
  state.selectedTeacherRecord = state.teacherRecord || null;

  const { data: teacherOptionsRaw } = await supabase
    .from("teachers")
    .select("teacher_id,full_name,email,subgroup_id,deleted_at,active")
    .eq("active", true)
    .is("deleted_at", null)
    .order("full_name");
  state.teacherOptions = (teacherOptionsRaw || []).map((r) => ({
    teacher_id: String(r.teacher_id || "").trim(),
    full_name: String(r.full_name || "").trim(),
    email: String(r.email || "").trim(),
    subgroup_id: String(r.subgroup_id || "").trim(),
  })).filter((r) => r.teacher_id && r.email);

  const { data: campusesRaw, error: campusesErr } = await supabase
    .from("fellowship_map")
    .select("fellowship_code,campus_name,group_id,subgroup_id,timezone,active")
    .eq("active", true)
    .order("campus_name");
  if (campusesErr) throw campusesErr;

  state.campuses = (campusesRaw || []).map((r) => ({
    code: String(r.fellowship_code || "").trim(),
    campusName: String(r.campus_name || "").trim(),
    groupID: String(r.group_id || "").trim(),
    subgroupID: String(r.subgroup_id || "").trim(),
    timezone: String(r.timezone || "").trim() || "America/Toronto",
  })).filter((r) => r.code);

  if (state.teacherRecord?.subgroup_id) {
    const preferred = state.campuses.find((c) => c.subgroupID === state.teacherRecord.subgroup_id);
    if (preferred) state.teacherTimezone = preferred.timezone || state.teacherTimezone;
  }

  root.innerHTML = `
    <style>
      .ta-layout { display:grid; grid-template-columns: minmax(0,1fr) 320px; gap:12px; }
      .ta-left-grid { display:grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap:10px; }
      .ta-pill-wrap { display:flex; flex-wrap:wrap; gap:6px; }
      .ta-pill { border-radius:999px; }
      .ta-pill.active { background:var(--color-primary,#6d28d9); color:#fff; border-color:var(--color-primary,#6d28d9); }
      .ta-badge { margin-left:6px; border-radius:999px; padding:1px 7px; font-size:11px; font-weight:700; background:rgba(0,0,0,.08); }
      .ta-pill.active .ta-badge { background:rgba(255,255,255,.2); color:#fff; }
      .ta-days { display:grid; grid-template-columns:80px repeat(7,1fr); background:var(--color-bg,#faf8ff); border-bottom:1px solid var(--color-border,#e6dcff); }
      .ta-days div { padding:7px; text-align:center; font-size:11px; font-weight:700; border-left:1px solid var(--color-border,#e6dcff); }
      .ta-days div:first-child { border-left:0; text-align:left; color:var(--color-text-secondary,#6b7280); }
      .ta-slot { display:grid; grid-template-columns:80px repeat(7,1fr); border-bottom:1px solid var(--color-border,#e6dcff); }
      .ta-time { padding:8px; background:var(--color-bg,#faf8ff); font-size:11px; color:var(--color-text-secondary,#6b7280); font-weight:600; }
      .ta-cell { min-height:38px; border-left:1px solid var(--color-border,#e6dcff); display:flex; align-items:center; justify-content:center; cursor:pointer; user-select:none; font-size:12px; }
      .ta-cell:hover { background:var(--soft-lavender,#f3ecff); }
      .ta-cell.on { background:#f3e8ff; color:#5b21b6; font-weight:700; }
      .ta-bottom { display:flex; justify-content:space-between; align-items:center; }
      @media (max-width: 1080px){ .ta-layout{grid-template-columns:1fr;} }
      @media (max-width: 760px){ .ta-left-grid{grid-template-columns:1fr;} }
    </style>
    <section class="fs-card" style="margin-bottom:12px;">
      <div class="ta-layout">
        <div>
          <div class="ta-left-grid">
            <div><label class="fs-label">Teacher</label><input class="fs-input" id="taTeacher" disabled /></div>
            <div><label class="fs-label">Email</label><input class="fs-input" id="taEmail" disabled /></div>
            <div><label class="fs-label">Month</label><select id="taMonth" class="fs-select"></select></div>
            <div><label class="fs-label">Timezone</label><select id="taTimezone" class="fs-select"></select></div>
          </div>
          <div style="margin-top:8px;">
            <label style="display:flex;align-items:center;gap:8px;">
              <input type="checkbox" id="taOtherTeacherToggle" />
              <span class="fs-muted">Create availability for another teacher</span>
            </label>
            <div id="taOtherTeacherWrap" style="margin-top:8px;display:none;">
              <label class="fs-label">Select Teacher</label>
              <select id="taOtherTeacherSelect" class="fs-select"></select>
            </div>
          </div>
          <div style="margin-top:10px;">
            <label class="fs-label">Search Campus</label>
            <input id="taCampusSearch" class="fs-input" placeholder="Search campus name or code..." />
          </div>
          <div style="margin-top:8px;display:flex;justify-content:space-between;align-items:center;">
            <strong>Campuses</strong><span id="taCampusMeta" class="fs-muted"></span>
          </div>
          <div id="taCampusGroups" style="margin-top:8px;"></div>
          <div class="fs-muted" style="margin-top:8px;">You are selecting availability in your own timezone. Selected times are converted per campus timezone.</div>
        </div>
        <aside class="fs-card" style="padding:10px;">
          <div style="display:flex;justify-content:space-between;align-items:center;"><strong>Summary</strong><span id="taSumTotal" class="fs-muted"></span></div>
          <div id="taSummary" class="fs-muted" style="margin-top:8px;"></div>
        </aside>
      </div>
    </section>

    <section class="fs-card" style="margin-bottom:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
        <strong id="taGridTitle">Weekly Grid</strong><span id="taGridTz" class="fs-muted"></span>
      </div>
      <div id="taGridWrap"></div>
    </section>

    <section class="fs-card ta-bottom">
      <span id="taSelStats" class="fs-muted">0 slots selected</span>
      <button id="taReview" class="fs-btn fs-btn-primary" disabled>Review &amp; Submit</button>
    </section>

    <dialog id="taModal" class="fs-card" style="max-width:680px;width:92%;">
      <h3 class="fs-h3" style="margin:0 0 6px 0;">Review &amp; Submit</h3>
      <p class="fs-muted" style="margin:0 0 8px 0;">Confirm converted campus times before submitting.</p>
      <div id="taReviewBody" style="max-height:50vh;overflow:auto;"></div>
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-top:10px;">
        <span id="taSubmitState" class="fs-muted"></span>
        <div class="fs-row" style="gap:8px;">
          <button id="taClose" class="fs-btn fs-btn-secondary" type="button">Close</button>
          <button id="taSubmit" class="fs-btn fs-btn-primary" type="button">Confirm Submit</button>
        </div>
      </div>
    </dialog>

    <div id="taMsg" class="fs-muted" style="margin-top:10px;"></div>
  `;

  const teacherDisplay = root.querySelector("#taTeacher");
  const emailDisplay = root.querySelector("#taEmail");
  const monthSel = root.querySelector("#taMonth");
  const tzSel = root.querySelector("#taTimezone");
  const campusSearch = root.querySelector("#taCampusSearch");
  const otherTeacherToggle = root.querySelector("#taOtherTeacherToggle");
  const otherTeacherWrap = root.querySelector("#taOtherTeacherWrap");
  const otherTeacherSelect = root.querySelector("#taOtherTeacherSelect");
  const campusMeta = root.querySelector("#taCampusMeta");
  const campusGroups = root.querySelector("#taCampusGroups");
  const gridTitle = root.querySelector("#taGridTitle");
  const gridTz = root.querySelector("#taGridTz");
  const gridWrap = root.querySelector("#taGridWrap");
  const sumTotal = root.querySelector("#taSumTotal");
  const summary = root.querySelector("#taSummary");
  const selStats = root.querySelector("#taSelStats");
  const reviewBtn = root.querySelector("#taReview");
  const modal = root.querySelector("#taModal");
  const reviewBody = root.querySelector("#taReviewBody");
  const submitState = root.querySelector("#taSubmitState");
  const submitBtn = root.querySelector("#taSubmit");
  const closeBtn = root.querySelector("#taClose");
  const msg = root.querySelector("#taMsg");

  teacherDisplay.value = String(state.teacherRecord?.full_name || profile.full_name || "Teacher");
  emailDisplay.value = String(profile.email || "");

  otherTeacherSelect.innerHTML =
    `<option value="">Select a teacher...</option>` +
    state.teacherOptions
      .map((t) => `<option value="${esc(t.teacher_id)}">${esc(t.full_name || t.email)} - ${esc(t.email)}</option>`)
      .join("");

  months.forEach((m) => {
    const opt = document.createElement("option");
    opt.value = m.key;
    opt.textContent = m.label;
    monthSel.appendChild(opt);
  });
  monthSel.value = state.monthKey;

  TZ_OPTIONS.forEach((tz) => {
    const opt = document.createElement("option");
    opt.value = tz;
    opt.textContent = tz;
    tzSel.appendChild(opt);
  });
  if (!TZ_OPTIONS.includes(state.teacherTimezone)) {
    const opt = document.createElement("option");
    opt.value = state.teacherTimezone;
    opt.textContent = state.teacherTimezone;
    tzSel.appendChild(opt);
  }
  tzSel.value = state.teacherTimezone;

  if (state.campuses[0]) {
    state.selectedCampusCodes.add(state.campuses[0].code);
    state.activeCampusCode = state.campuses[0].code;
  }

  function groupedCampuses() {
    const q = state.search.toLowerCase();
    const filtered = state.campuses.filter((c) => !q || c.campusName.toLowerCase().includes(q) || c.code.toLowerCase().includes(q));
    const grouped = new Map();
    const groupOrder = ["CE", "CS", "WS", "Other"];

    filtered.forEach((c) => {
      const isOther = !c.groupID || c.code.toUpperCase() === "REGIONAL";
      const g = isOther ? "Other" : c.groupID;
      const sg = c.subgroupID || "Other";
      if (!grouped.has(g)) grouped.set(g, new Map());
      const sub = grouped.get(g);
      if (!sub.has(sg)) sub.set(sg, []);
      sub.get(sg).push(c);
    });

    const ordered = [];
    groupOrder.forEach((g) => { if (grouped.has(g)) ordered.push([g, grouped.get(g)]); });
    [...grouped.entries()].forEach(([g, sub]) => { if (!groupOrder.includes(g)) ordered.push([g, sub]); });
    return { filteredCount: filtered.length, ordered };
  }

  function campusSlotCount(code) {
    if (!state.selectedCampusCodes.has(code)) return 0;
    return state.slotSet.size;
  }

  function renderCampusGroups() {
    const { filteredCount, ordered } = groupedCampuses();
    campusGroups.innerHTML = ordered.map(([groupKey, subMap]) => {
      const subEntries = [...subMap.entries()].sort((a, b) => a[0].localeCompare(b[0]));
      return `
        <div style="margin-bottom:10px;">
          <div class="fs-muted" style="font-weight:700;">${esc(groupKey)}</div>
          ${subEntries.map(([sg, campuses]) => `
            <div style="margin-top:6px;">
              <div class="fs-muted" style="font-size:12px;">${esc(sg)}${SUBGROUP_LABELS[sg] ? ` - ${esc(SUBGROUP_LABELS[sg])}` : ""}</div>
              <div class="ta-pill-wrap" style="margin-top:6px;">
                ${campuses.map((c) => {
                  const active = state.selectedCampusCodes.has(c.code);
                  return `<button type="button" class="fs-btn fs-btn-secondary fs-btn-sm ta-pill ${active ? "active" : ""}" data-campus="${esc(c.code)}">${esc(c.code)}<span class="ta-badge">${campusSlotCount(c.code)}</span></button>`;
                }).join("")}
              </div>
            </div>
          `).join("")}
        </div>
      `;
    }).join("") || `<div class="fs-muted">No campuses match your search.</div>`;

    campusMeta.textContent = `${state.selectedCampusCodes.size} selected - Showing ${filteredCount} active fellowships`;

    campusGroups.querySelectorAll("[data-campus]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const code = btn.getAttribute("data-campus");
        if (!code) return;
        if (state.selectedCampusCodes.has(code)) {
          state.selectedCampusCodes.delete(code);
          if (state.activeCampusCode === code) state.activeCampusCode = [...state.selectedCampusCodes][0] || "";
        } else {
          state.selectedCampusCodes.add(code);
          state.activeCampusCode = code;
        }
        renderAll();
      });
    });
  }

  function selectedCampusLabel() {
    const selected = state.campuses.filter((c) => state.selectedCampusCodes.has(c.code));
    if (!selected.length) return "Weekly Grid";
    if (selected.length === 1) return `${selected[0].code} - ${selected[0].campusName}`;
    return `${selected.length} campuses selected`;
  }

  function renderGrid() {
    gridTitle.textContent = selectedCampusLabel();
    gridTz.textContent = `Grid shown in teacher timezone: ${state.teacherTimezone || "(select timezone)"}`;

    if (!state.activeCampusCode) {
      gridWrap.innerHTML = `<div class="fs-muted" style="padding:8px;">Select at least one campus.</div>`;
      return;
    }

    let html = `<div class="ta-days"><div>Time</div>${DAYS.map((d) => `<div>${esc(d.slice(0, 3))}</div>`).join("")}</div>`;
    SLOTS.forEach((time) => {
      html += `<div class="ta-slot"><div class="ta-time">${esc(time)}</div>`;
      DAYS.forEach((day) => {
        const key = slotKey(day, time);
        const on = state.slotSet.has(key);
        html += `<div class="ta-cell ${on ? "on" : ""}" data-day="${esc(day)}" data-time="${esc(time)}">${on ? "Selected" : ""}</div>`;
      });
      html += `</div>`;
    });
    gridWrap.innerHTML = html;

    gridWrap.querySelectorAll(".ta-cell").forEach((cell) => {
      cell.addEventListener("click", () => {
        const day = cell.getAttribute("data-day");
        const time = cell.getAttribute("data-time");
        const key = slotKey(day, time);
        if (state.slotSet.has(key)) state.slotSet.delete(key); else state.slotSet.add(key);
        renderAll();
      });
    });
  }

  function convertedCampusSlots(campus) {
    const month = selectedMonth(state, months);
    return [...state.slotSet].map((k) => {
      const s = splitKey(k);
      const conv = convertTeacherSlotToCampus({ day: s.day, time: s.time }, state.teacherTimezone, campus.timezone, month);
      return { teacherDay: s.day, teacherTime: s.time, campusDay: conv.campusDay, campusTime: conv.campusTime };
    });
  }

  function renderSummary() {
    const selected = state.campuses.filter((c) => state.selectedCampusCodes.has(c.code));
    sumTotal.textContent = `${state.slotSet.size} teacher-time slots`;
    summary.innerHTML = `<div class="fs-muted" style="margin-bottom:8px;"><strong>Teacher Timezone:</strong> ${esc(state.teacherTimezone)}</div>` +
      (selected.map((c) => {
        const items = convertedCampusSlots(c);
        return `<div style="margin-bottom:8px;"><strong>${esc(c.code)}</strong> <span class="fs-muted">${esc(c.campusName)} - ${esc(c.timezone)}</span><div style="margin-top:4px;">${items.map((it) => `<span class="fs-btn fs-btn-secondary fs-btn-sm" style="padding:2px 8px;font-size:11px;">${esc(it.campusDay.slice(0, 3))} ${esc(it.campusTime)}</span>`).join(" ") || `<span class="fs-muted">No slots</span>`}</div></div>`;
      }).join("")) || `<span class="fs-muted">No campuses selected.</span>`;
  }

  function buildPayload() {
    const m = selectedMonth(state, months);
    const slots = [...state.slotSet].map((k) => {
      const s = splitKey(k);
      return {
        teacherDay: s.day,
        teacherTime: s.time,
        selectedCampusCodes: [...state.selectedCampusCodes],
      };
    });

    const activeTeacher = state.submitForAnother
      ? state.selectedTeacherRecord
      : (state.teacherRecord || {
        teacher_id: "",
        full_name: String(state.profile?.full_name || ""),
        email: String(state.profile?.email || ""),
      });

    return slots.map((s) => ({
      teacherID: String(activeTeacher?.teacher_id || ""),
      teacherName: String(activeTeacher?.full_name || state.profile?.full_name || ""),
      teacherEmail: String(activeTeacher?.email || state.profile?.email || ""),
      teacherTimezone: state.teacherTimezone,
      selectedCampusCodes: s.selectedCampusCodes,
      teacherDay: s.teacherDay,
      teacherTime: s.teacherTime,
      dbTimeSlot: to24h(s.teacherTime),
      month: m.month,
      year: m.year,
    }));
  }

  function renderReview() {
    const activeTeacher = state.submitForAnother
      ? state.selectedTeacherRecord
      : (state.teacherRecord || { full_name: state.profile?.full_name, email: state.profile?.email });
    const byCampus = {};
    const payload = buildPayload();
    payload.forEach((p) => {
      (p.selectedCampusCodes || []).forEach((code) => {
        const campus = state.campuses.find((c) => c.code === code);
        if (!campus) return;
        const month = selectedMonth(state, months);
        const conv = convertTeacherSlotToCampus({ day: p.teacherDay, time: p.teacherTime }, state.teacherTimezone, campus.timezone, month);
        if (!byCampus[code]) byCampus[code] = { campusName: campus.campusName, timezone: campus.timezone, items: [] };
        byCampus[code].items.push(`${conv.campusDay.slice(0, 3)} ${conv.campusTime}`);
      });
    });

    reviewBody.innerHTML = `<div class="fs-muted" style="margin-bottom:8px;"><strong>Name:</strong> ${esc(activeTeacher?.full_name || "-")}<br><strong>Email:</strong> ${esc(activeTeacher?.email || "-")}<br><strong>Teacher Timezone:</strong> ${esc(state.teacherTimezone)}</div>` +
      Object.keys(byCampus).map((code) => {
        const d = byCampus[code];
        return `<div style="margin-bottom:8px;"><strong>${esc(code)} - ${esc(d.campusName)}</strong> <span class="fs-muted">(${esc(d.timezone)})</span><div style="margin-top:4px;">${d.items.map((i) => `<span class="fs-btn fs-btn-secondary fs-btn-sm" style="padding:2px 8px;font-size:11px;">${esc(i)}</span>`).join(" ")}</div></div>`;
      }).join("");
  }

  function setMsg(text, kind) {
    msg.className = kind ? `fs-banner fs-banner-${kind}` : "fs-muted";
    msg.textContent = text || "";
  }

  async function submitNow() {
    const payload = buildPayload();
    if (!payload.length) return;
    state.submitting = true;
    submitBtn.disabled = true;
    submitState.textContent = "Submitting...";
    try {
      const res = await submitAvailability(payload);
      setMsg(`Availability submitted. ${JSON.stringify(res)}`, "success");
      modal.close();
    } catch (e) {
      setMsg(`Submission failed: ${String(e?.message || e)}`, "danger");
    } finally {
      state.submitting = false;
      submitBtn.disabled = false;
      submitState.textContent = "";
    }
  }

  function renderFooter() {
    selStats.textContent = `${state.slotSet.size} slots selected in teacher timezone`;
    const hasTeacher = state.submitForAnother ? !!state.selectedTeacherRecord?.teacher_id : true;
    reviewBtn.disabled = !(hasTeacher && state.teacherTimezone && state.slotSet.size > 0 && state.selectedCampusCodes.size > 0);
  }

  function renderAll() {
    renderCampusGroups();
    renderGrid();
    renderSummary();
    renderFooter();
  }

  campusSearch.addEventListener("input", (e) => {
    state.search = String(e.target.value || "");
    renderCampusGroups();
  });
  monthSel.addEventListener("change", () => {
    state.monthKey = monthSel.value;
    renderSummary();
  });
  tzSel.addEventListener("change", () => {
    state.teacherTimezone = tzSel.value;
    renderAll();
  });
  otherTeacherToggle.addEventListener("change", () => {
    state.submitForAnother = !!otherTeacherToggle.checked;
    otherTeacherWrap.style.display = state.submitForAnother ? "" : "none";
    if (!state.submitForAnother) {
      state.selectedTeacherRecord = state.teacherRecord || null;
      teacherDisplay.value = String(state.teacherRecord?.full_name || state.profile?.full_name || "Teacher");
      emailDisplay.value = String(state.profile?.email || "");
    }
    renderFooter();
  });
  otherTeacherSelect.addEventListener("change", () => {
    const tid = String(otherTeacherSelect.value || "").trim();
    state.selectedTeacherRecord = state.teacherOptions.find((t) => t.teacher_id === tid) || null;
    if (state.selectedTeacherRecord) {
      teacherDisplay.value = String(state.selectedTeacherRecord.full_name || "Teacher");
      emailDisplay.value = String(state.selectedTeacherRecord.email || "");
      if (state.selectedTeacherRecord.subgroup_id) {
        const preferred = state.campuses.find((c) => c.subgroupID === state.selectedTeacherRecord.subgroup_id);
        if (preferred) {
          state.teacherTimezone = preferred.timezone || state.teacherTimezone;
          tzSel.value = state.teacherTimezone;
        }
      }
    }
    renderAll();
  });

  reviewBtn.addEventListener("click", () => {
    if (reviewBtn.disabled) return;
    renderReview();
    modal.showModal();
  });
  closeBtn.addEventListener("click", () => modal.close());
  submitBtn.addEventListener("click", submitNow);

  renderAll();
}
