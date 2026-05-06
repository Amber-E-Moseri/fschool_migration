(function(){
  const NS = window.FSUtils = window.FSUtils || {};
  NS.esc = function esc(s){
    return String(s || '').replace(/[&<>"']/g, function(m){
      return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[m];
    });
  };
  NS.debounce = function debounce(fn, ms){
    let t = null;
    return function(){
      const args = arguments;
      clearTimeout(t);
      t = setTimeout(function(){ fn.apply(null, args); }, ms);
    };
  };
})();
