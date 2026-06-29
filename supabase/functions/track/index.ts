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
  status_change: "Changement de statut", quote_generated: "Devis généré", quote_sent: "Devis envoyé",
  qc_result: "Contrôle qualité", part_added: "Pièce ajoutée", handover_confirmed: "Remise confirmée",
  warranty_claim_opened: "Réclamation garantie", warranty_claim_status: "Statut réclamation",
  refund_processed: "Remboursement", refund_partial: "Remboursement partiel",
};

const CSS = `*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}body{font-family:system-ui,-apple-system,sans-serif;background:#0d1117;color:#e6edf3;min-height:100vh}.container{max-width:600px;margin:0 auto;padding:20px}.header{text-align:center;padding:30px 20px 20px;background:linear-gradient(135deg,#0d1117,#161b22);border-bottom:2px solid #00bcd4}.header-logo{font-size:48px;margin-bottom:8px}.header h1{font-size:22px;font-weight:800;letter-spacing:1px;color:#00bcd4}.header-sub{font-size:13px;color:#8b949e;margin-top:2px}.banner{padding:14px 20px;border-radius:10px;text-align:center;margin:16px 0;font-weight:600;font-size:14px}.banner.danger{background:#f8514920;border:1px solid #f8514940;color:#f85149}.progress-bar{display:flex;justify-content:space-between;margin:24px 0;position:relative}.progress-bar::before{content:"";position:absolute;top:14px;left:10%;right:10%;height:2px;background:#30363d;z-index:0}.step{display:flex;flex-direction:column;align-items:center;z-index:1;flex:1}.step-icon{width:30px;height:30px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:bold;background:#21262d;color:#8b949e;border:2px solid #30363d}.step.done .step-icon{background:#3fb950;color:#fff;border-color:#3fb950}.step.active .step-icon{background:#00bcd4;color:#0d1117;border-color:#00bcd4;box-shadow:0 0 12px #00bcd460}.step-label{font-size:10px;color:#8b949e;margin-top:6px;text-align:center;max-width:60px}.step.done .step-label{color:#3fb950}.step.active .step-label{color:#00bcd4;font-weight:600}.status-badge{text-align:center;padding:10px 20px;border-radius:20px;font-weight:bold;font-size:15px;margin:8px auto 16px;display:inline-block;width:100%}.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:20px;margin-bottom:16px}.card-title{font-size:15px;font-weight:600;color:#00bcd4;margin-bottom:12px}.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #30363d40;font-size:14px}.info-row:last-child{border-bottom:none}.info-label{color:#8b949e;font-size:13px}.timeline{padding-left:8px}.timeline-item{display:flex;gap:12px;padding-bottom:16px;position:relative}.timeline-item::before{content:"";position:absolute;left:7px;top:28px;bottom:0;width:2px;background:#30363d}.timeline-item:last-child::before{display:none}.timeline-dot{width:16px;height:16px;border-radius:50%;background:#00bcd4;flex-shrink:0;margin-top:3px}.timeline-content{flex:1}.timeline-title{font-weight:600;font-size:14px;color:#e6edf3}.timeline-date{font-size:11px;color:#8b949e;margin-top:2px}.timeline-notes{font-size:12px;color:#8b949e;margin-top:4px;background:#0d1117;padding:6px 10px;border-radius:6px}.actions{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:24px}@media(min-width:400px){.actions{grid-template-columns:repeat(4,1fr)}}.btn{display:block;text-align:center;padding:12px 8px;border-radius:10px;font-size:13px;font-weight:600;text-decoration:none;cursor:pointer;border:none;font-family:inherit;color:#e6edf3}.btn.action{background:#161b22;border:1px solid #30363d}.btn.action:hover{background:#21262d}.btn.primary{background:#00bcd4;color:#0d1117;font-weight:700;width:100%}.btn.primary:hover{background:#00acc1}.star-btn{background:none;border:none;font-size:32px;cursor:pointer;color:#30363d;padding:0 4px;transition:color .15s}.star-btn.active,.star-btn:hover{color:#d29922}textarea:focus{outline:none;border-color:#00bcd4}.footer{text-align:center;padding:24px;color:#8b949e;font-size:13px;border-top:1px solid #00bcd440;margin-top:24px}`;

function buildHtml(t: any, anonKey: string): string {
  const customer = t.customers;
  const tech = t.profiles;
  const parts = t.repair_parts ?? [];
  const events = t.repair_ticket_events ?? [];
  const status = t.status ?? "En attente";
  const showPrices = t.show_prices_on_public === true;
  const wd = t.warranty_days ?? 0;
  const views = (t.public_page_views ?? 0) + 1;
  const step = status === "Livré" ? 4 : status === "Terminé" ? 3 : status === "Annulé" ? -1 : 1;
  const sc = status === "Livré" ? "#3fb950" : status === "Terminé" ? "#00bcd4" : status === "Annulé" ? "#f85149" : "#d29922";
  const sl = status === "Livré" ? "Livré ✓" : status === "Terminé" ? "Prêt à récupérer ✓" : status === "Annulé" ? "Annulé ✗" : "En attente";
  const dev = [t.device_brand, t.device_name].filter(Boolean).join(" ") || "Non spécifié";

  const progressBar = status === "Annulé"
    ? '<div class="banner danger"><span>⚠️ Cette réparation a été annulée</span></div>'
    : ["Reçu","En réparation","Terminé","Livré"].map((l, i) => {
        const done = i + 1 <= step; const active = i + 1 === step;
        return `<div class="step${done?" done":""}${active?" active":""}"><div class="step-icon">${done?"✓":i+1}</div><div class="step-label">${l}</div></div>`;
      }).join("");

  const eventsHtml = events.length > 0 ? `<div class="card"><h2 class="card-title">📋 Historique</h2><div class="timeline">${(events as any[]).map((e: any) => `<div class="timeline-item"><div class="timeline-dot"></div><div class="timeline-content"><div class="timeline-title">${EVENTS[e.event_type]??e.event_type}</div><div class="timeline-date">${frDate(e.created_at)}</div>${e.notes?`<div class="timeline-notes">${e.notes}</div>`:""}</div></div>`).join("")}</div></div>` : "";

  const usedParts = (parts as any[]).filter((p: any) => p.part_status === "Utilisé");
  const partsHtml = usedParts.length > 0 ? `<div class="card"><h2 class="card-title">🔧 Pièces remplacées</h2>${usedParts.map((p: any) => `<div class="info-row"><span>${p.products?.product_name??"Pièce"} ×${p.quantity??1}</span>${showPrices?`<span style="color:#00bcd4">${p.charged_price??0} DA</span>`:""}</div>`).join("")}</div>` : "";

  const warrantyHtml = status === "Livré" && wd > 0 ? `<div class="card" style="border-left:3px solid #3fb950"><h2 class="card-title" style="color:#3fb950">🛡️ Garantie</h2><p style="color:#3fb950;font-weight:bold;font-size:18px">${wd} jours</p>${t.warranty_expires_at?`<p style="color:#8b949e;font-size:13px">Expire le ${frDateShort(t.warranty_expires_at)}</p>`:""}</div>` : "";

  const ratingHtml = status === "Livré" ? `<div class="card" id="rating-section"><h2 class="card-title">⭐ Votre avis</h2><div id="stars" style="margin:12px 0">${[1,2,3,4,5].map(n => `<button class="star-btn" onclick="setRating(${n})">☆</button>`).join("")}</div><textarea id="comment" placeholder="Votre commentaire..." rows="3" style="width:100%;background:#0d1117;color:#e6edf3;border:1px solid #30363d;border-radius:8px;padding:10px;font-family:inherit;resize:vertical"></textarea><button class="btn primary" onclick="submitFeedback()" style="margin-top:12px">Envoyer</button><div id="feedback-msg" style="margin-top:8px;font-size:13px"></div></div>` : "";

  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Suivi - ${customer?.full_name??dev}</title><style>${CSS}</style></head><body><div class="container"><div class="header"><div class="header-logo">🛠️</div><h1>${SHOP_NAME}</h1><p class="header-sub">Suivi de réparation</p></div><div class="progress-bar">${progressBar}</div><div class="status-badge" style="background:${sc}20;border-color:${sc}40;color:${sc}">${sl}</div><div class="card"><h2 class="card-title">👤 Client</h2><div class="info-row"><span class="info-label">Nom</span><span>${customer?.full_name??t.client_name_temp??"Inconnu"}</span></div><div class="info-row"><span class="info-label">Téléphone</span><span>${customer?.phone_number??t.client_phone_temp??""}</span></div><h2 class="card-title" style="margin-top:16px">📱 Appareil</h2><div class="info-row"><span class="info-label">Modèle</span><span>${dev}</span></div><div class="info-row"><span class="info-label">Problème</span><span>${t.issue_description??t.pre_diagnostic??"Non spécifié"}</span></div><div class="info-row"><span class="info-label">Technicien</span><span>${tech?.full_name??"En cours d'assignation"}</span></div><div class="info-row"><span class="info-label">Déposé le</span><span>${frDateShort(t.created_at)}</span></div>${t.estimated_completion_date?`<div class="info-row"><span class="info-label">Livraison prévue</span><span>${frDateShort(t.estimated_completion_date)}</span></div>`:""}</div>${eventsHtml}${partsHtml}${warrantyHtml}${ratingHtml}<div class="actions"><a href="tel:${SHOP_PHONE}" class="btn action">📞 Appeler</a><a href="https://wa.me/${SHOP_PHONE}" target="_blank" class="btn action">💬 WhatsApp</a><a href="${SHOP_MAPS}" target="_blank" class="btn action">📍 Carte</a><button class="btn action" onclick="sharePage()">🔗 Partager</button></div><div class="footer"><p>${SHOP_NAME}</p><p style="font-size:11px;color:#8b949e">Propulsé par Laidani Repair System</p><p style="font-size:10px;color:#8b949e">Vues: ${views}</p></div></div><script>window.SUPABASE_URL="${SUPABASE_URL}";window.ANON_KEY="${anonKey}";window.TICKET_ID="${t.id}";let _rating=0;window.setRating=n=>{_rating=n;document.querySelectorAll(".star-btn").forEach((b,i)=>b.textContent=i<n?"★":"☆")};window.submitFeedback=async()=>{const c=document.getElementById("comment")?.value??"";const m=document.getElementById("feedback-msg");if(!_rating){m.innerHTML='<span style="color:#f85149">Sélectionnez une note</span>';return}m.innerHTML='<span style="color:#8b949e">Envoi...</span>';try{const r=await fetch(window.SUPABASE_URL+"/rest/v1/customer_feedback",{method:"POST",headers:{apikey:window.ANON_KEY,Authorization:"Bearer "+window.ANON_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({ticket_id:window.TICKET_ID,rating:_rating,comment:c})});if(r.ok){document.getElementById("rating-section").innerHTML='<div style="text-align:center;padding:20px">✅<p style="color:#3fb950;margin-top:8px">Avis envoyé, merci !</p></div>'}else m.innerHTML='<span style="color:#f85149">Erreur</span>'}catch(e){m.innerHTML='<span style="color:#f85149">Erreur réseau</span>'}};window.sharePage=()=>{navigator.share?navigator.share({title:"Suivi de réparation",url:location.href}):navigator.clipboard.writeText(location.href).then(()=>alert("Lien copié !"))};\n// Realtime\nimport("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm").then(m=>{const s=m.createClient(window.SUPABASE_URL,window.ANON_KEY);s.channel("updates").on("postgres_changes",{event:"UPDATE",schema:"public",table:"repair_tickets",filter:"id=eq."+window.TICKET_ID},()=>location.reload()).subscribe()});<\/script></body></html>`;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const qr = url.searchParams.get("qr");
  if (!qr) {
    return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>QR manquant</title><style>${CSS}</style></head><body style="background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui"><p style="color:#f85149">Paramètre QR requis dans l'URL.</p></body></html>`)}`, 302);
  }

  try {
    const resp = await fetch(
      `${SUPABASE_URL}/rest/v1/repair_tickets?qr_code_hash=eq.${encodeURIComponent(qr)}&select=*,customers(full_name,phone_number),profiles!repair_tickets_worker_id_fkey(full_name),repair_parts(charged_price,shop_cost_price,quantity,part_status,products(product_name)),repair_ticket_events(event_type,old_value,new_value,notes,created_at)&repair_ticket_events.order=created_at.asc`,
      { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } }
    );

    if (!resp.ok) {
      return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Erreur</title><style>${CSS}</style></head><body style="background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui"><p style="color:#f85149">Erreur serveur: ${resp.status}</p></body></html>`)}`, 302);
    }

    const tickets = await resp.json();
    if (!tickets || tickets.length === 0) {
      return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Introuvable</title><style>${CSS}</style></head><body style="background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui"><p style="color:#f85149">Aucun ticket trouvé avec ce code QR.</p></body></html>`)}`, 302);
    }

    const t = tickets[0];
    const enabled = t.is_public_page_enabled === true;

    if (enabled) {
      await fetch(`${SUPABASE_URL}/rest/v1/repair_tickets?id=eq.${t.id}`, {
        method: "PATCH",
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify({ public_page_views: (t.public_page_views ?? 0) + 1 }),
      });
    }

    if (!enabled) {
      return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Non disponible</title><style>${CSS}</style></head><body style="background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui;text-align:center"><div style="font-size:48px;margin-bottom:16px">🔒</div><p style="color:#8b949e">La page de suivi pour ce ticket n'est pas encore activée.</p><p style="color:#8b949e;font-size:13px">Le magasin activera le suivi prochainement.</p></body></html>`)}`, 302);
    }

    const anonKey = Deno.env.get("ANON_KEY") ?? "";
    const html = buildHtml(t, anonKey);
    return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`, 302);
  } catch (err) {
    return Response.redirect(`data:text/html;charset=utf-8,${encodeURIComponent(`<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Erreur</title><style>${CSS}</style></head><body style="background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui"><p style="color:#f85149">${err}</p></body></html>`)}`, 302);
  }
});
