(function(){
  const Modal = window.FSModal = window.FSModal || {};
  Modal.open = function(el){ if(el) el.classList.add('open'); };
  Modal.close = function(el){ if(el) el.classList.remove('open'); };
  Modal.bindBackdropClose = function(el){
    if(!el) return;
    el.addEventListener('click', function(e){ if(e.target === el) Modal.close(el); });
  };
})();
