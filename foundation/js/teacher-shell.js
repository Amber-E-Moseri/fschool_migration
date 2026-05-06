(function(){
  const KEY = 'fs_theme';
  const Shell = window.FSTeacherShell = window.FSTeacherShell || {};

  function applyTheme(theme){
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(KEY, theme);
    const t = document.getElementById('fs-theme-toggle');
    if(t) t.textContent = theme === 'dark' ? '☀️' : '🌙';
  }

  function initTheme(){
    const saved = localStorage.getItem(KEY);
    const preferred = saved || (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    applyTheme(preferred);
    if(document.getElementById('fs-theme-toggle')) return;
    const btn = document.createElement('button');
    btn.id = 'fs-theme-toggle';
    btn.className = 'fs-btn';
    btn.style.cssText = 'position:fixed;right:16px;bottom:16px;z-index:1300;padding:8px 10px;min-width:40px;';
    btn.setAttribute('aria-label', 'Toggle theme');
    btn.onclick = function(){
      const cur = document.documentElement.getAttribute('data-theme') || 'light';
      applyTheme(cur === 'dark' ? 'light' : 'dark');
    };
    document.body.appendChild(btn);
    applyTheme(preferred);
  }

  function ensureManrope(){
    if(document.querySelector('link[data-fs-manrope="1"]')) return;
    const l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = 'https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap';
    l.setAttribute('data-fs-manrope', '1');
    document.head.appendChild(l);
  }

  function inferActiveKey(){
    const p = (window.location.pathname || '').toLowerCase();
    if(p.endsWith('/teacherattendanceportal.html') || p.endsWith('teacherattendanceportal.html')) return 'attendance';
    if(p.endsWith('/studentprogressview.html') || p.endsWith('studentprogressview.html')) return 'progress';
    if(p.endsWith('/teacher-schedule.html') || p.endsWith('teacher-schedule.html')) return 'schedule';
    return '';
  }

  Shell.mount = function(opts){
    opts = opts || {};
    const active = opts.active || inferActiveKey();
    const links = [
      { href:'TeacherAttendancePortal.html', icon:'✅', label:'Attendance', key:'attendance' },
      { href:'StudentProgressView.html', icon:'📊', label:'Student Progress', key:'progress' },
      { href:'teacher-schedule.html', icon:'📅', label:'My Schedule', key:'schedule' }
    ];
    if(!document.querySelector('.fs-shell-nav')){
      ensureManrope();
      const nav = document.createElement('nav');
      nav.className = 'fs-shell-nav';
      nav.innerHTML = `<div class="fs-shell-inner"><div class="fs-shell-brand">RS</div>${links.map(l => `<a class="fs-shell-link ${l.key===active?'active':''}" href="${l.href}">${l.icon} <span>${l.label}</span></a>`).join('')}</div>`;
      document.body.prepend(nav);
    }
    initTheme();
  };
})();
