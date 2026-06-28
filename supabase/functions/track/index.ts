import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://igxpwxfruasfpvfagbaw.supabase.co";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const SHOP_NAME = "LAIDANI REPAIR";
const SHOP_PHONE = "0550000000";
const SHOP_MAPS = "https://maps.google.com";

function frDate(iso: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  return d.toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function frDateShort(iso: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  return d.toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric" });
}

const EVENT_LABELS: Record<string, string> = {
  status_change: "Changement de statut",
  quote_generated: "Devis généré",
  quote_sent: "Devis envoyé",
  qc_result: "Contrôle qualité",
  part_added: "Pièce ajoutée",
  handover_confirmed: "Remise confirmée",
  warranty_claim_opened: "Réclamation garantie",
  warranty_claim_status: "Statut réclamation",
  refund_processed: "Remboursement",
  refund_partial: "Remboursement partiel",
};

function eventLabel(type: string): string {
  return EVENT_LABELS[type] ?? type;
}

function html(parts: TemplateStringsArray, ...vals: any[]): string {
  return String.raw({ raw: parts }, ...vals.map(v => v == null ? "" : String(v)));
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const qr = url.searchParams.get("qr");
  if (!qr) {
    return new Response(page("QR manquant", '<p style="color:#f85149;text-align:center">Paramètre QR requis dans l\'URL.</p>'), { headers: { "Content-Type": "text/html" } });
  }

  try {
    const ticketResp = await fetch(
      `${SUPABASE_URL}/rest/v1/repair_tickets?qr_code_hash=eq.${encodeURIComponent(qr)}&select=*,customers(full_name,phone_number),profiles!repair_tickets_worker_id_fkey(full_name),repair_parts(charged_price,shop_cost_price,quantity,part_status,products(product_name)),repair_ticket_events(event_type,old_value,new_value,notes,created_at)&repair_ticket_events.order=created_at.asc`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    );

    if (!ticketResp.ok) {
      return new Response(page("Erreur", `<p style="color:#f85149;text-align:center">Erreur serveur: ${ticketResp.status}</p>`), { headers: { "Content-Type": "text/html" } });
    }

    const tickets = await ticketResp.json();
    if (!tickets || tickets.length === 0) {
      return new Response(page("Ticket introuvable", '<p style="color:#f85149;text-align:center">Aucun ticket trouvé avec ce code QR.</p>'), { headers: { "Content-Type": "text/html" } });
    }

    const t = tickets[0];
    const enabled = t.is_public_page_enabled === true;

    // Increment view counter
    if (enabled) {
      await fetch(
        `${SUPABASE_URL}/rest/v1/repair_tickets?id=eq.${t.id}`,
        {
          method: "PATCH",
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({ public_page_views: (t.public_page_views ?? 0) + 1 }),
        }
      );
    }

    if (!enabled) {
      return new Response(page("Page non disponible", '<div style="text-align:center;padding:60px 20px"><div style="font-size:48px;margin-bottom:16px">🔒</div><p style="color:#8b949e">La page de suivi pour ce ticket n\'est pas encore activée.</p><p style="color:#8b949e;font-size:13px">Le magasin activera le suivi prochainement.</p></div>'), { headers: { "Content-Type": "text/html" } });
    }

    const customer = t.customers;
    const tech = t.profiles;
    const parts = t.repair_parts ?? [];
    const events = t.repair_ticket_events ?? [];
    const status = t.status ?? "En attente";
    const showPrices = t.show_prices_on_public === true;
    const warrantyDays = t.warranty_days ?? 0;
    const views = t.public_page_views ?? 0;

    const statusStep = status === "Livré" ? 4 : status === "Terminé" ? 3 : status === "Annulé" ? -1 : 1;
    const statusColor = status === "Livré" ? "#3fb950" : status === "Terminé" ? "#00bcd4" : status === "Annulé" ? "#f85149" : "#d29922";
    const statusLabel = status === "Livré" ? "Livré ✓" : status === "Terminé" ? "Prêt à récupérer ✓" : status === "Annulé" ? "Annulé ✗" : "En attente";
    const deviceName = [t.device_brand, t.device_name].filter(Boolean).join(" ") || "Non spécifié";

    const body = html`
      <div class="container">
        <!-- Header -->
        <div class="header">
          <div class="header-logo">🛠️</div>
          <h1>${SHOP_NAME}</h1>
          <p class="header-sub">Suivi de réparation</p>
        </div>

        ${status === "Annulé" ? html`
          <div class="banner danger">
            <span>⚠️ Cette réparation a été annulée</span>
          </div>
        ` : html`
        <!-- Progress Bar -->
        <div class="progress-bar">
          ${["Reçu","En réparation","Terminé","Livré"].map((label, i) => {
            const step = i + 1;
            const done = step <= statusStep;
            const active = step === statusStep;
            return html`
              <div class="step ${done ? "done" : ""} ${active ? "active" : ""}">
                <div class="step-icon">${done ? "✓" : step}</div>
                <div class="step-label">${label}</div>
              </div>
            `;
          }).join("")}
        </div>
        `}

        <!-- Status Badge -->
        <div class="status-badge" style="background:${statusColor}20;border-color:${statusColor}40;color:${statusColor}">
          ${statusLabel}
        </div>

        <!-- Customer + Device Card -->
        <div class="card">
          <h2 class="card-title">👤 Client</h2>
          <div class="info-row"><span class="info-label">Nom</span><span>${customer?.full_name ?? t.client_name_temp ?? "Inconnu"}</span></div>
          <div class="info-row"><span class="info-label">Téléphone</span><span>${customer?.phone_number ?? t.client_phone_temp ?? ""}</span></div>
          <h2 class="card-title" style="margin-top:16px">📱 Appareil</h2>
          <div class="info-row"><span class="info-label">Modèle</span><span>${deviceName}</span></div>
          <div class="info-row"><span class="info-label">Problème</span><span>${t.issue_description ?? t.pre_diagnostic ?? "Non spécifié"}</span></div>
          <div class="info-row"><span class="info-label">Technicien</span><span>${tech?.full_name ?? "En cours d'assignation"}</span></div>
          <div class="info-row"><span class="info-label">Déposé le</span><span>${frDateShort(t.created_at)}</span></div>
          ${t.estimated_completion_date ? html`<div class="info-row"><span class="info-label">Livraison prévue</span><span>${frDateShort(t.estimated_completion_date)}</span></div>` : ""}
        </div>

        <!-- Events Timeline -->
        ${events.length > 0 ? html`
        <div class="card">
          <h2 class="card-title">📋 Historique</h2>
          <div class="timeline">
            ${events.map((e: any) => html`
              <div class="timeline-item">
                <div class="timeline-dot"></div>
                <div class="timeline-content">
                  <div class="timeline-title">${eventLabel(e.event_type)}</div>
                  <div class="timeline-date">${frDate(e.created_at)}</div>
                  ${e.notes ? html`<div class="timeline-notes">${e.notes}</div>` : ""}
                </div>
              </div>
            `).join("")}
          </div>
        </div>
        ` : ""}

        <!-- Parts -->
        ${parts.filter((p: any) => p.part_status === "Utilisé").length > 0 ? html`
        <div class="card">
          <h2 class="card-title">🔧 Pièces remplacées</h2>
          ${parts.filter((p: any) => p.part_status === "Utilisé").map((p: any) => html`
            <div class="info-row">
              <span>${p.products?.product_name ?? "Pièce"} ×${p.quantity ?? 1}</span>
              ${showPrices ? html`<span style="color:#00bcd4">${(p.charged_price ?? 0)} DA</span>` : ""}
            </div>
          `).join("")}
        </div>
        ` : ""}

        <!-- Warranty Card -->
        ${status === "Livré" && warrantyDays > 0 ? html`
        <div class="card" style="border-left:3px solid #3fb950">
          <h2 class="card-title" style="color:#3fb950">🛡️ Garantie</h2>
          <p style="color:#3fb950;font-weight:bold;font-size:18px">${warrantyDays} jours</p>
          ${t.warranty_expires_at ? html`<p style="color:#8b949e;font-size:13px">Expire le ${frDateShort(t.warranty_expires_at)}</p>` : ""}
          <p style="color:#8b949e;font-size:12px;margin-top:8px">Couverture pièces et main d'œuvre. Exclut dommages physiques et oxydation.</p>
        </div>
        ` : ""}

        <!-- Rating -->
        ${status === "Livré" ? html`
        <div class="card" id="rating-section">
          <h2 class="card-title">⭐ Votre avis</h2>
          <div id="stars" style="margin:12px 0">
            ${[1,2,3,4,5].map(n => html`<button class="star-btn" data-star="${n}" onclick="setRating(${n})">☆</button>`).join("")}
          </div>
          <textarea id="comment" placeholder="Votre commentaire (optionnel)..." rows="3" style="width:100%;background:#0d1117;color:#e6edf3;border:1px solid #30363d;border-radius:8px;padding:10px;font-family:inherit;resize:vertical"></textarea>
          <button class="btn primary" onclick="submitFeedback()" style="margin-top:12px">Envoyer mon avis</button>
          <div id="feedback-msg" style="margin-top:8px;font-size:13px"></div>
        </div>
        ` : ""}

        <!-- Action Buttons -->
        <div class="actions">
          <a href="tel:${SHOP_PHONE}" class="btn action">📞 Appeler</a>
          <a href="https://wa.me/${SHOP_PHONE}" target="_blank" class="btn action">💬 WhatsApp</a>
          <a href="${SHOP_MAPS}" target="_blank" class="btn action">📍 Carte</a>
          <button class="btn action" onclick="sharePage()">🔗 Partager</button>
        </div>

        <!-- Footer -->
        <div class="footer">
          <p>${SHOP_NAME}</p>
          <p style="font-size:11px;color:#8b949e">Propulsé par Laidani Repair System</p>
          <p style="font-size:10px;color:#8b949e">Vues: ${views + 1}</p>
        </div>
      </div>
    `;

    return new Response(page("Suivi - " + (customer?.full_name ?? deviceName), body, t.id), { headers: { "Content-Type": "text/html" } });
  } catch (err) {
    return new Response(page("Erreur", `<p style="color:#f85149;text-align:center">${err}</p>`), { headers: { "Content-Type": "text/html" } });
  }
});

function page(title: string, body: string, ticketId?: string): string {
  return html`<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title}</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,-apple-system,sans-serif;background:#0d1117;color:#e6edf3;min-height:100vh}
.container{max-width:600px;margin:0 auto;padding:20px}
.header{text-align:center;padding:30px 20px 20px;background:linear-gradient(135deg,#0d1117,#161b22);border-bottom:2px solid #00bcd4}
.header-logo{font-size:48px;margin-bottom:8px}
.header h1{font-size:22px;font-weight:800;letter-spacing:1px;color:#00bcd4}
.header-sub{font-size:13px;color:#8b949e;margin-top:2px}
.banner{padding:14px 20px;border-radius:10px;text-align:center;margin:16px 0;font-weight:600;font-size:14px}
.banner.danger{background:#f8514920;border:1px solid #f8514940;color:#f85149}
.progress-bar{display:flex;justify-content:space-between;margin:24px 0;position:relative}
.progress-bar::before{content:"";position:absolute;top:14px;left:10%;right:10%;height:2px;background:#30363d;z-index:0}
.step{display:flex;flex-direction:column;align-items:center;z-index:1;flex:1}
.step-icon{width:30px;height:30px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:bold;background:#21262d;color:#8b949e;border:2px solid #30363d}
.step.done .step-icon{background:#3fb950;color:#fff;border-color:#3fb950}
.step.active .step-icon{background:#00bcd4;color:#0d1117;border-color:#00bcd4;box-shadow:0 0 12px #00bcd460}
.step-label{font-size:10px;color:#8b949e;margin-top:6px;text-align:center;max-width:60px}
.step.done .step-label{color:#3fb950}
.step.active .step-label{color:#00bcd4;font-weight:600}
.status-badge{text-align:center;padding:10px 20px;border-radius:20px;font-weight:bold;font-size:15px;margin:8px auto 16px;display:inline-block;width:100%}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:20px;margin-bottom:16px}
.card-title{font-size:15px;font-weight:600;color:#00bcd4;margin-bottom:12px}
.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #30363d40;font-size:14px}
.info-row:last-child{border-bottom:none}
.info-label{color:#8b949e;font-size:13px}
.timeline{padding-left:8px}
.timeline-item{display:flex;gap:12px;padding-bottom:16px;position:relative}
.timeline-item::before{content:"";position:absolute;left:7px;top:28px;bottom:0;width:2px;background:#30363d}
.timeline-item:last-child::before{display:none}
.timeline-dot{width:16px;height:16px;border-radius:50%;background:#00bcd4;flex-shrink:0;margin-top:3px}
.timeline-content{flex:1}
.timeline-title{font-weight:600;font-size:14px;color:#e6edf3}
.timeline-date{font-size:11px;color:#8b949e;margin-top:2px}
.timeline-notes{font-size:12px;color:#8b949e;margin-top:4px;background:#0d1117;padding:6px 10px;border-radius:6px}
.actions{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:24px}
@media(min-width:400px){.actions{grid-template-columns:repeat(4,1fr)}}
.btn{display:block;text-align:center;padding:12px 8px;border-radius:10px;font-size:13px;font-weight:600;text-decoration:none;cursor:pointer;border:none;font-family:inherit;color:#e6edf3}
.btn.action{background:#161b22;border:1px solid #30363d}
.btn.action:hover{background:#21262d}
.btn.primary{background:#00bcd4;color:#0d1117;font-weight:700;width:100%}
.btn.primary:hover{background:#00acc1}
.star-btn{background:none;border:none;font-size:32px;cursor:pointer;color:#30363d;padding:0 4px;transition:color .15s}
.star-btn.active,.star-btn:hover{color:#d29922}
textarea:focus{outline:none;border-color:#00bcd4}
.footer{text-align:center;padding:24px;color:#8b949e;font-size:13px;border-top:1px solid #00bcd440;margin-top:24px}
</style>
</head>
<body>
${body}
<script type="module">
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
const supabase = createClient("${SUPABASE_URL}", "${SUPABASE_ANON_KEY}");
const ticketId = "${ticketId ?? ""}";

// Realtime subscription
if (ticketId) {
  supabase
    .channel("ticket-updates")
    .on("postgres_changes", { event: "UPDATE", schema: "public", table: "repair_tickets", filter: \`id=eq.\${ticketId}\` }, () => {
      location.reload();
    })
    .subscribe();
}

// Star rating
window.setRating = function(n) {
  window._rating = n;
  document.querySelectorAll(".star-btn").forEach((b, i) => {
    b.textContent = i < n ? "★" : "☆";
    b.classList.toggle("active", i < n);
  });
};

// Submit feedback
window.submitFeedback = async function() {
  const rating = window._rating;
  const comment = document.getElementById("comment")?.value ?? "";
  const msg = document.getElementById("feedback-msg");
  if (!rating) { msg.innerHTML = '<span style="color:#f85149">Veuillez sélectionner une note</span>'; return; }
  msg.innerHTML = '<span style="color:#8b949e">Envoi...</span>';
  const ticketQr = new URLSearchParams(location.search).get("qr");
  try {
    const resp = await fetch("${SUPABASE_URL}/rest/v1/customer_feedback", {
      method: "POST",
      headers: { apikey: "${SUPABASE_ANON_KEY}", Authorization: "Bearer ${SUPABASE_ANON_KEY}", "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ ticket_id: ticketId, rating, comment })
    });
    if (resp.ok) {
      msg.innerHTML = '<span style="color:#3fb950">Merci pour votre avis ! ★'.repeat(rating) + '</span>';
      document.getElementById("rating-section").innerHTML = '<div style="text-align:center;padding:20px"><span style="color:#3fb950;font-size:24px">✅</span><p style="color:#3fb950;margin-top:8px;font-weight:600">Avis envoyé, merci !</p></div>';
    } else {
      const err = await resp.text();
      msg.innerHTML = '<span style="color:#f85149">Erreur: ${err}</span>';
    }
  } catch(e) {
    msg.innerHTML = '<span style="color:#f85149">Erreur réseau</span>';
  }
};

// Share
window.sharePage = function() {
  if (navigator.share) {
    navigator.share({ title: "Suivi de réparation", url: location.href });
  } else {
    navigator.clipboard.writeText(location.href).then(() => alert("Lien copié !"));
  }
};
</script>
</body>
</html>`;
}
