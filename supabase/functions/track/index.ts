import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://igxpwxfruasfpvfagbaw.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SHOP_NAME = "LAIDANI REPAIR";
const SHOP_PHONE = "0550000000";
const SHOP_MAPS = "https://maps.google.com";

function frDate(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit" });
}
function frDateShort(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric" });
}

const EVENTS: Record<string, string> = {
  status_change: "Changement de statut", quote_generated: "Devis g\u00e9n\u00e9r\u00e9", quote_sent: "Devis envoy\u00e9",
  qc_result: "Contr\u00f4le qualit\u00e9", part_added: "Pi\u00e8ce ajout\u00e9e", handover_confirmed: "Remise confirm\u00e9e",
  warranty_claim_opened: "R\u00e9clamation garantie", warranty_claim_status: "Statut r\u00e9clamation",
  refund_processed: "Remboursement", refund_partial: "Remboursement partiel",
};

const CSS = `*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}body{font-family:system-ui,-apple-system,sans-serif;background:#0d1117;color:#e6edf3;min-height:100vh}.container{max-width:600px;margin:0 auto;padding:20px}.header{text-align:center;padding:30px 20px 20px;background:linear-gradient(135deg,#0d1117,#161b22);border-bottom:2px solid #00bcd4}.header-logo{font-size:48px;margin-bottom:8px}.header h1{font-size:22px;font-weight:800;letter-spacing:1px;color:#00bcd4}.header-sub{font-size:13px;color:#8b949e;margin-top:2px}.banner{padding:14px 20px;border-radius:10px;text-align:center;margin:16px 0;font-weight:600;font-size:14px}.banner.danger{background:#f8514920;border:1px solid #f8514940;color:#f85149}.progress-bar{display:flex;justify-content:space-between;margin:24px 0;position:relative}.progress-bar:before{content:'';position:absolute;top:14px;left:10%;right:10%;height:2px;background:#30363d;z-index:0}.step{display:flex;flex-direction:column;align-items:center;z-index:1;flex:1}.step-icon{width:30px;height:30px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:bold;background:#21262d;color:#8b949e;border:2px solid #30363d}.step.done .step-icon{background:#3fb950;color:#fff;border-color:#3fb950}.step.active .step-icon{background:#00bcd4;color:#0d1117;border-color:#00bcd4;box-shadow:0 0 12px #00bcd460}.step-label{font-size:10px;color:#8b949e;margin-top:6px;text-align:center;max-width:60px}.step.done .step-label{color:#3fb950}.step.active .step-label{color:#00bcd4;font-weight:600}.status-badge{text-align:center;padding:10px 20px;border-radius:20px;font-weight:bold;font-size:15px;margin:8px auto 16px;display:inline-block;width:100%}.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:20px;margin-bottom:16px}.card-title{font-size:15px;font-weight:600;color:#00bcd4;margin-bottom:12px}.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #30363d40;font-size:14px}.info-row:last-child{border-bottom:none}.info-label{color:#8b949e;font-size:13px}.timeline{padding-left:8px}.timeline-item{display:flex;gap:12px;padding-bottom:16px;position:relative}.timeline-item:before{content:'';position:absolute;left:7px;top:28px;bottom:0;width:2px;background:#30363d}.timeline-item:last-child:before{display:none}.timeline-dot{width:16px;height:16px;border-radius:50%;background:#00bcd4;flex-shrink:0;margin-top:3px}.timeline-content{flex:1}.timeline-title{font-weight:600;font-size:14px;color:#e6edf3}.timeline-date{font-size:11px;color:#8b949e;margin-top:2px}.timeline-notes{font-size:12px;color:#8b949e;margin-top:4px;background:#0d1117;padding:6px 10px;border-radius:6px}.actions{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:24px}@media(min-width:400px){.actions{grid-template-columns:repeat(4,1fr)}}.btn{display:block;text-align:center;padding:12px 8px;border-radius:10px;font-size:13px;font-weight:600;text-decoration:none;cursor:pointer;border:none;font-family:inherit;color:#e6edf3}.btn.action{background:#161b22;border:1px solid #30363d}.btn.action:hover{background:#21262d}.btn.primary{background:#00bcd4;color:#0d1117;font-weight:700;width:100%}.btn.primary:hover{background:#00acc1}.star-btn{background:none;border:none;font-size:32px;cursor:pointer;color:#30363d;padding:0 4px;transition:color .15s}.star-btn.active,.star-btn:hover{color:#d29922}textarea:focus{outline:none;border-color:#00bcd4}.footer{text-align:center;padding:24px;color:#8b949e;font-size:13px;border-top:1px solid #00bcd440;margin-top:24px}`;

function encodeEntities(s: string): string {
  return s.replace(/[\\u00e0-\\u00ff]/g, (c) => `&#${c.charCodeAt(0)};`).replace(/[\\u0152\\u0153]/g, (c) => `&#${c.charCodeAt(0)};`);
}

function buildHtml(t: any, anonKey: string, ticketId: string): string {
  const customer = t.customers;
  const tech = t.profiles;
  const parts = t.repair_parts ?? [];
  const events = t.repair_ticket_events ?? [];
  const status = t.status ?? "En attente";
  const showPrices = t.show_prices_on_public === true;
  const wd = t.warranty_days ?? 0;
  const views = (t.public_page_views ?? 0) + 1;
  const step = status === "Livr\u00e9" ? 4 : status === "Termin\u00e9" ? 3 : status === "Annul\u00e9" ? -1 : 1;
  const sc = status === "Livr\u00e9" ? "#3fb950" : status === "Termin\u00e9" ? "#00bcd4" : status === "Annul\u00e9" ? "#f85149" : "#d29922";
  const sl = status === "Livr\u00e9" ? "Livr\u00e9 \u2713" : status === "Termin\u00e9" ? "Pr\u00eat \u00e0 r\u00e9cup\u00e9rer \u2713" : status === "Annul\u00e9" ? "Annul\u00e9 \u2717" : "En attente"; const dev = [t.device_brand, t.device_name].filter(Boolean).join(" ") || "Non sp\u00e9cifi\u00e9";

  const progressBar = status === "Annul\u00e9"
    ? '<div class="banner danger"><span>\u26a0\ufe0f Cette r\u00e9paration a \u00e9t\u00e9 annul\u00e9e</span></div>'
    : ["Re\u00e7u","En r\u00e9paration","Termin\u00e9","Livr\u00e9"].map((l, i) => {
        const done = i + 1 <= step; const active = i + 1 === step;
        return `<div class="step${done?" done":""}${active?" active":""}"><div class="step-icon">${done?"\u2713":i+1}</div><div class="step-label">${l}</div></div>`;
      }).join("");

  const eventsHtml = events.length > 0 ? `<div class="card"><h2 class="card-title">\u{1F4CB} Historique</h2><div class="timeline">${(events as any[]).map((e: any) => `<div class="timeline-item"><div class="timeline-dot"></div><div class="timeline-content"><div class="timeline-title">${EVENTS[e.event_type]??e.event_type}</div><div class="timeline-date">${frDate(e.created_at)}</div>${e.notes?`<div class="timeline-notes">${e.notes}</div>`:""}</div></div>`).join("")}</div></div>` : "";

  const usedParts = (parts as any[]).filter((p: any) => p.part_status === "Utilis\u00e9");
  const partsHtml = usedParts.length > 0 ? `<div class="card"><h2 class="card-title">\u{1F527} Pi\u00e8ces remplac\u00e9es</h2>${usedParts.map((p: any) => `<div class="info-row"><span>${p.products?.product_name??"Pi\u00e8ce"} \u00d7${p.quantity??1}</span>${showPrices?`<span style="color:#00bcd4">${p.charged_price??0} DA</span>`:""}</div>`).join("")}</div>` : "";

  const warrantyHtml = status === "Livr\u00e9" && wd > 0 ? `<div class="card" style="border-left:3px solid #3fb950"><h2 class="card-title" style="color:#3fb950">\u{1F6E1}\ufe0f Garantie</h2><p style="color:#3fb950;font-weight:bold;font-size:18px">${wd} jours</p>${t.warranty_expires_at?`<p style="color:#8b949e;font-size:13px">Expire le ${frDateShort(t.warranty_expires_at)}</p>`:""}</div>` : "";

  const ratingHtml = status === "Livr\u00e9" ? `<div class="card" id="rating-section"><h2 class="card-title">\u2b50 Votre avis</h2><div id="stars" style="margin:12px 0">${[1,2,3,4,5].map(n => `<button class="star-btn" onclick="setRating(${n})">\u2606</button>`).join("")}</div><textarea id="comment" placeholder="Votre commentaire..." rows="3" style="width:100%;background:#0d1117;color:#e6edf3;border:1px solid #30363d;border-radius:8px;padding:10px;font-family:inherit;resize:vertical"></textarea><button class="btn primary" onclick="submitFeedback()" style="margin-top:12px">Envoyer</button><div id="feedback-msg" style="margin-top:8px;font-size:13px"></div></div>` : "";

  const body = `<div class="container"><div class="header"><div class="header-logo">\u{1F6E0}\ufe0f</div><h1>${SHOP_NAME}</h1><p class="header-sub">Suivi de r\u00e9paration</p></div><div class="progress-bar">${progressBar}</div><div class="status-badge" style="background:${sc}20;border-color:${sc}40;color:${sc}">${sl}</div><div class="card"><h2 class="card-title">\u{1F464} Client</h2><div class="info-row"><span class="info-label">Nom</span><span>${customer?.full_name??t.client_name_temp??"Inconnu"}</span></div><div class="info-row"><span class="info-label">T\u00e9l\u00e9phone</span><span>${customer?.phone_number??t.client_phone_temp??""}</span></div><h2 class="card-title" style="margin-top:16px">\u{1F4F1} Appareil</h2><div class="info-row"><span class="info-label">Mod\u00e8le</span><span>${dev}</span></div><div class="info-row"><span class="info-label">Probl\u00e8me</span><span>${t.issue_description??t.pre_diagnostic??"Non sp\u00e9cifi\u00e9"}</span></div><div class="info-row"><span class="info-label">Technicien</span><span>${tech?.full_name??"En cours d\u2019assignation"}</span></div><div class="info-row"><span class="info-label">D\u00e9pos\u00e9 le</span><span>${frDateShort(t.created_at)}</span></div>${t.estimated_completion_date?`<div class="info-row"><span class="info-label">Livraison pr\u00e9vue</span><span>${frDateShort(t.estimated_completion_date)}</span></div>`:""}</div>${eventsHtml}${partsHtml}${warrantyHtml}${ratingHtml}<div class="actions"><a href="tel:${SHOP_PHONE}" class="btn action">\u{1F4DE} Appeler</a><a href="https://wa.me/${SHOP_PHONE}" target="_blank" class="btn action">\u{1F4AC} WhatsApp</a><a href="${SHOP_MAPS}" target="_blank" class="btn action">\u{1F4CD} Carte</a><button class="btn action" onclick="sharePage()">\u{1F517} Partager</button></div><div class="footer"><p>${SHOP_NAME}</p><p style="font-size:11px;color:#8b949e">Propuls\u00e9 par Laidani Repair System</p><p style="font-size:10px;color:#8b949e">Vues: ${views}</p></div></div>`;

  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Suivi</title><style>${CSS}</style></head><body>${body}<script>window.SUPABASE_URL="${SUPABASE_URL}";window.ANON_KEY="${anonKey}";window.TICKET_ID="${ticketId}";var _rating=0;window.setRating=function(n){_rating=n;document.querySelectorAll(".star-btn").forEach(function(b,i){b.textContent=i<n?"\u2605":"\u2606"})};window.submitFeedback=async function(){var c=document.getElementById("comment");var m=document.getElementById("feedback-msg");var comment=c?c.value:"";if(!_rating){m.innerHTML='S\u00e9lectionnez une note';return}m.innerHTML='Envoi...';try{var r=await fetch(window.SUPABASE_URL+"/rest/v1/customer_feedback",{method:"POST",headers:{apikey:window.ANON_KEY,Authorization:"Bearer "+window.ANON_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({ticket_id:window.TICKET_ID,rating:_rating,comment:comment})});if(r.ok){var s=document.getElementById("rating-section");if(s)s.innerHTML='<div style="text-align:center;padding:20px">\u2705<p style="color:#3fb950;margin-top:8px">Avis envoy\u00e9, merci !</p></div>'}else m.innerHTML="Erreur"}catch(e){m.innerHTML="Erreur r\u00e9seau"}};window.sharePage=function(){if(navigator.share){navigator.share({title:"Suivi de r\u00e9paration",url:location.href})}else{navigator.clipboard.writeText(location.href).then(function(){alert("Lien copi\u00e9 !")})}};</script></body></html>`;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const qr = url.searchParams.get("qr");
  const anonKey = Deno.env.get("ANON_KEY") ?? "";

  if (!qr) {
    const html = `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>QR manquant</title><style>body{background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui}</style></head><body><p style="color:#f85149">Param\u00e8tre QR requis</p></body></html>`;
    return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(html)}` } });
  }

  try {
    const resp = await fetch(
      `${SUPABASE_URL}/rest/v1/repair_tickets?qr_code_hash=eq.${encodeURIComponent(qr)}&select=*,customers(full_name,phone_number),profiles!repair_tickets_worker_id_fkey(full_name),repair_parts(charged_price,quantity,part_status,products(product_name)),repair_ticket_events(event_type,notes,created_at)&repair_ticket_events.order=created_at.asc`,
      { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } }
    );

    if (!resp.ok) { const e=`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Erreur</title><style>body{background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui}</style></head><body><p style="color:#f85149">Erreur serveur: ${resp.status}</p></body></html>`; return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(e)}` } }); }

    const tickets = await resp.json();
    if (!tickets || tickets.length === 0) { const e='<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Introuvable</title><style>body{background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui}</style></head><body><p style="color:#f85149">Aucun ticket trouv\u00e9</p></body></html>'; return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(e)}` } }); }

    const t = tickets[0];
    const enabled = t.is_public_page_enabled === true;

    if (enabled) {
      await fetch(`${SUPABASE_URL}/rest/v1/repair_tickets?id=eq.${t.id}`, {
        method: "PATCH", headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify({ public_page_views: (t.public_page_views ?? 0) + 1 }),
      });
    }

    if (!enabled) { const e=`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Non disponible</title><style>body{background:#0d1117;color:#e6edf3;font-family:system-ui;text-align:center;padding:60px}</style></head><body><div style="font-size:48px">\u{1F512}</div><p style="color:#8b949e">Page non activ\u00e9e</p><p style="color:#8b949e;font-size:13px">Le magasin activera le suivi prochainement.</p></body></html>`; return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(e)}` } }); }

    const html = buildHtml(t, anonKey, t.id);
    return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(html)}` } });

  } catch (err) { const e=`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Erreur</title><style>body{background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui}</style></head><body><p style="color:#f85149">${err}</p></body></html>`; return new Response(null, { status: 302, headers: { Location: `data:text/html;charset=utf-8,${encodeURIComponent(e)}` } }); }
});
