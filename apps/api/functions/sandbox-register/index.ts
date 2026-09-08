const URL_BASE=Deno.env.get('SUPABASE_URL')!;
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PUBLIC_KEY='sb_publishable_OVscrF59zW2zqnM7w11P_g_ksfdc8N7';
const ORIGIN='https://lions-games-preview.marealtahostelbc.chatgpt.site';
Deno.serve(async(req:Request)=>{
 const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':ORIGIN,'Access-Control-Allow-Headers':'apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Cache-Control':'no-store','Vary':'Origin'};
 const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply({error:'METHOD_NOT_ALLOWED'},405);
 if(req.headers.get('apikey')!==PUBLIC_KEY)return reply({error:'INVALID_API_KEY'},401);
 if(req.headers.get('origin')&&req.headers.get('origin')!==ORIGIN)return reply({error:'ORIGIN_NOT_ALLOWED'},403);
 try{
 const raw=await req.text();if(raw.length>2048)return reply({error:'INVALID_REQUEST'},400);
 const {username,password}=JSON.parse(raw);
 if(typeof username!=='string'||!/^[a-z][a-z0-9_]{3,23}$/.test(username)||typeof password!=='string'||password.length<12||password.length>128)return reply({error:'Use usuário com 4 a 24 letras/números e senha de 12 a 128 caracteres.'},400);
 const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim()||'unknown';
 const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(ip+SERVICE));
 const bucket=Array.from(new Uint8Array(hash)).map(b=>b.toString(16).padStart(2,'0')).join('');
 const gate=await fetch(URL_BASE+'/rest/v1/rpc/lions_registration_gate',{method:'POST',headers:{apikey:SERVICE,Authorization:'Bearer '+SERVICE,'Content-Type':'application/json'},body:JSON.stringify({p_bucket:bucket})});
 if(!gate.ok||await gate.json()!==true)return reply({error:'Limite temporário de cadastros. Tente novamente mais tarde.'},429);
 const res=await fetch(URL_BASE+'/auth/v1/admin/users',{method:'POST',headers:{apikey:SERVICE,Authorization:'Bearer '+SERVICE,'Content-Type':'application/json'},body:JSON.stringify({email:username+'@lions-sandbox.invalid',password,email_confirm:true,app_metadata:{sandbox:true},user_metadata:{sandbox_username:username}})});
 if(!res.ok)return reply({error:'Não foi possível criar esse usuário. Escolha outro nome ou tente mais tarde.'},400);
 const user=await res.json();return reply({id:user.id,username,mode:'sandbox'},201);
 }catch{return reply({error:'Não foi possível concluir o cadastro.'},500)}
});
