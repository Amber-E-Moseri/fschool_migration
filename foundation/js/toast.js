(function(){
  const Toast = window.FSToast = window.FSToast || {};
  let root;
  function ensure(){
    if(root) return;
    root = document.createElement('div');
    root.id = 'fs-toast-root';
    root.style.cssText = 'position:fixed;right:14px;top:14px;z-index:1200;display:grid;gap:8px;width:min(360px,calc(100vw - 28px));';
    document.body.appendChild(root);
  }
  Toast.show = function(message, type = 'info', ttl = 3200){
    ensure();
    const el = document.createElement('div');
    el.className = `fs-alert fs-alert-${type}`;
    el.textContent = message;
    root.appendChild(el);
    setTimeout(()=>el.remove(), ttl);
  };
})();
