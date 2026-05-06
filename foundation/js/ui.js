(function(){
  const UI = window.FSUI = window.FSUI || {};
  UI.loading = {
    ensure(){
      let el = document.getElementById('fs-loading');
      if(el) return el;
      el = document.createElement('div');
      el.id = 'fs-loading';
      el.style.cssText = 'position:fixed;inset:0;background:rgba(18,14,30,.35);display:none;align-items:center;justify-content:center;z-index:1250;';
      el.innerHTML = '<div style="background:var(--surface);border:1px solid var(--border);padding:12px 16px;border-radius:12px">Loading...</div>';
      document.body.appendChild(el);
      return el;
    },
    show(){ UI.loading.ensure().style.display = 'flex'; },
    hide(){ UI.loading.ensure().style.display = 'none'; }
  };
})();
