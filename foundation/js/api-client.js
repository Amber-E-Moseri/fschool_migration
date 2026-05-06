(function(){
  const API = window.FSApi = window.FSApi || {};
  function resolveUrl(metaNames){
    for (const n of metaNames) {
      const v = (document.querySelector(`meta[name="${n}"]`)?.content || '').trim();
      if (v && !v.startsWith('__')) return v;
    }
    return '';
  }
  function resolveToken(metaNames){
    for (const n of metaNames) {
      const v = (document.querySelector(`meta[name="${n}"]`)?.content || '').trim();
      if (v && !v.startsWith('__')) return v;
    }
    return '';
  }
  API.config = {
    baseUrl: resolveUrl(['api-url','teacher-availability-api-url']),
    token: resolveToken(['api-token','teacher-availability-api-token']),
    backendMode: 'apps-script'
  };
  API.setConfig = function(cfg){ API.config = Object.assign({}, API.config, cfg || {}); };

  API.getBackendMode = function(){
    return API.config.backendMode || 'apps-script';
  };

  API.appsScriptGet = async function(action, params){
    if(!API.config.baseUrl) throw new Error('API URL is not configured.');
    const u = new URL(API.config.baseUrl);
    u.searchParams.set('action', action);
    Object.entries(params || {}).forEach(([k,v]) => u.searchParams.set(k, v));
    if(API.config.token) u.searchParams.set('token', API.config.token);
    const r = await fetch(u);
    const j = await r.json();
    if(!r.ok || j.ok === false) throw new Error(j.error || 'Request failed');
    return j;
  };

  API.appsScriptPost = async function(action, body){
    if(!API.config.baseUrl) throw new Error('API URL is not configured.');
    const u = new URL(API.config.baseUrl);
    u.searchParams.set('action', action);
    if(API.config.token) u.searchParams.set('token', API.config.token);
    const r = await fetch(u, {
      method: 'POST',
      headers: { 'Content-Type':'text/plain;charset=utf-8' },
      body: JSON.stringify(Object.assign({}, body || {}, API.config.token ? { token: API.config.token } : {}))
    });
    const t = await r.text();
    let j;
    try { j = JSON.parse(t); } catch (_) { throw new Error('Invalid JSON response from Apps Script.'); }
    if(!r.ok || j.ok === false) throw new Error(j.error || 'Request failed');
    return j;
  };

  API.get = API.appsScriptGet;
  API.post = API.appsScriptPost;

  API._requireSupabase = function(){
    if(!window.supabase || typeof window.supabase.from !== 'function'){
      throw new Error('Supabase client is not initialized on window.supabase.');
    }
    return window.supabase;
  };

  API.supabaseSelect = async function(table, queryBuilder){
    const client = API._requireSupabase();
    let q = client.from(table).select('*');
    if(typeof queryBuilder === 'function'){
      q = queryBuilder(q) || q;
    }
    const { data, error } = await q;
    if(error) throw error;
    return data;
  };

  API.supabaseInsert = async function(table, payload){
    const client = API._requireSupabase();
    const { data, error } = await client.from(table).insert(payload).select();
    if(error) throw error;
    return data;
  };

  API.supabaseUpdate = async function(table, payload, match){
    const client = API._requireSupabase();
    let q = client.from(table).update(payload);
    Object.entries(match || {}).forEach(([k, v]) => {
      q = q.eq(k, v);
    });
    const { data, error } = await q.select();
    if(error) throw error;
    return data;
  };
})();
