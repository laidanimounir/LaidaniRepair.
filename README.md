# 🔧 LaidaniRepair — ERP de Réparation Téléphonique

**Système ERP/POS complet pour ateliers de réparation de téléphones et vente d'accessoires — multi-utilisateur, temps réel, cloud.**

[![Flutter](https://img.shields.io/badge/Flutter-3.3%2B-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-2.x-3ECF8E?logo=supabase)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-5C4EE5)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-Private-red)](#license)

---

## ✨ Features

### 🛒 Point de Vente (POS)
Caisse enregistreuse complète avec catalogue produits, catégories et recherche par nom ou code-barres. Supporte les ventes au comptant ou à crédit, avec sélection du client, modification du prix unitaire, remise par article, et remise globale. Validation de la vente avec impression de ticket thermique (PDF). Codes promo (pourcentage ou montant fixe) validés en temps réel au checkout. **Points de fidélité** : cumul de 1 point par 100 DA d'achat, rachat possible (100 pts = 100 DA). **Mode kiosque** : Ctrl+K active un affichage plein écran pour le client avec panier en grand format.

### 🛠️ Gestion des Réparations
Cycle de vie complet : création avec diagnostic, photos, IMEI, mot de passe, accessoires. Attribution aux techniciens avec date de fin estimée (SLA). Workflow devis (envoi WhatsApp/SMS/Email, approbation client). Contrôle qualité avant livraison avec notes et test de l'appareil. Génération de **devis PDF** et **certificat de garantie PDF**. QR code unique par ticket pour suivi public. **Duplication de ticket** en un clic. **Opérations groupées** : sélection multi-tickets avec changement de statut, assignation technicien, export CSV. **Marge bénéficiaire réelle** calculée automatiquement (coût pièces + main-d'œuvre vs prix facturé). **Rappels de maintenance automatiques** (6 mois après remise). **Chronologie visuelle** en 7 étapes (Reçu → Diagnostic → Devis → En réparation → QC → Prêt → Livré).

### 📊 Tableau de Bord
Vue d'ensemble de l'activité quotidienne : réparations actives, livraisons du jour, chiffre d'affaires, dépenses, revenu net. **Graphique des pannes les plus fréquentes** (top 10, fl_chart). **Prévisions de ventes sur 7 jours** basées sur la moyenne des 30 derniers jours. **Widgets personnalisables** : afficher/masquer chaque carte selon les préférences (sauvegardé). Alertes visuelles SLA : réparations en retard surlignées en rouge, stocks bas en bannière, réclamations garantie en attente.

### 👥 Clients & Dettes
Fiche client détaillée avec trois onglets : historique des achats (factures POS), historique des réparations (tickets), et historique des paiements. Total dépensé et dette globale affichés. **Solde de points de fidélité** visible dans la fiche. **Analyse client IA (Groq)** : score de valeur, risque de churn, offre personnalisée suggérée. Paiement partiel au POS avec enregistrement automatique de la dette. Recherche par nom ou téléphone (recherche floue).

### 📦 Stock & Achats
Inventaire complet avec catégories, codes-barres, prix d'achat et de vente. Seuil de réapprovisionnement (`min_stock`) avec alerte visuelle. Gestion des fournisseurs avec achats, retours et suivi des paiements. Chaque mouvement de stock est tracé. **Analytiques inventaire** : top 10 meilleures ventes, produits à faible rotation, taux de rotation (fl_chart). **Impression étiquettes code-barres** avec nom, prix, code-barres. **Opérations groupées** : changement de catégorie, export CSV des produits sélectionnés. **Suggestions de réapprovisionnement IA (Groq)** basées sur l'historique des ventes et le stock actuel.

### 👨‍🔧 Employés & Pointage
Gestion des comptes employés (création, activation/suspension, attribution de rôle). **Permissions granulaires par technicien** : 4 droits configurables (voir clients, modifier inventaire, accéder rapports, gérer réparations). Pointage quotidien avec bouton check-in/check-out. Le propriétaire voit l'historique de tous les employés ; chaque employé voit uniquement ses propres pointages.

### 🏷️ Promotions
Codes promo personnalisables : choix entre réduction en pourcentage ou montant fixe, achat minimum requis, limite d'utilisation totale, date d'expiration. Validation automatique lors du checkout POS.

### 🔍 Suivi Public (QR Code)
Chaque ticket de réparation génère un QR code unique. En scannant ce code, le client accède à une page publique (sans authentification) affichant une **chronologie visuelle** du statut, l'appareil, le technicien assigné, la date estimée de fin, et le solde restant.

### 🤖 IA Groq (Llama3)
Assistant intelligent intégré via l'API Groq (modèle `llama3-70b-8192`) :
- **Diagnostic automatique** des pannes (cause probable, étapes, difficulté, pièces suggérées)
- **Estimation des prix** de réparation (min/max, temps estimé, confiance)
- **Suggestion de pièces détachées** avec correspondance en stock
- **Analyse de réapprovisionnement** par produit (urgence, quantité suggérée)
- **Scoring client** (valeur, risque de churn, offre personnalisée, meilleur moment de contact)

### 🏢 Multi-Succursales
Gestion de plusieurs boutiques : création de branches avec adresse et téléphone, association des employés à une succursale via `profiles.branch_id`.

### 📡 Mode Hors-Ligne
Détection de connectivité automatique (`dart:io` via `connectivity_plus`), cache local en fichiers JSON dans le répertoire temporaire, bannière visuelle "hors-ligne" et indicateur de synchronisation dans l'en-tête. File d'attente de synchronisation automatique au retour en ligne.

### 🏥 SLA & Escalade
Chaque ticket de réparation est coloré par statut SLA : vert (dans les temps), jaune (échéance dans 24h), rouge (dépassé). Filtres SLA dédiés dans la liste des réparations.

### 🖨️ Impression Étiquettes
Génération et impression d'étiquettes code-barres pour les produits avec nom, code-barres, prix et nom du magasin via le package `printing`.

### 📊 Analytiques Avancées
Graphiques d'inventaire (top 10 produits, produits à faible rotation, KPIs) et graphiques de dépenses (évolution sur 6 mois, budget par catégorie avec barres de progression) utilisant `fl_chart`.

### 📥 Import CSV
Import de fichiers CSV pour les produits et clients via `file_picker`. Validation des colonnes, prévisualisation des données avec surlignage des erreurs, insertion groupée dans Supabase.

### 🔔 Centre de Notifications
Cloche de notifications avec badge de compteur dans l'en-tête, listant : stocks bas, réparations en retard, rappels de maintenance. Navigation directe vers l'écran concerné.

### ⌨️ Raccourcis Clavier
Raccourcis globaux : Ctrl+1-8 navigation, Ctrl+N nouvelle réparation, Ctrl+P POS, Ctrl+F recherche, Ctrl+K mode kiosque, F1 aide. Superposé à toute l'application via `ShortcutsWidget`.

### 🔐 Authentification & Sécurité
Connexion par email/mot de passe. Contrôle d'accès par rôles (Owner/Worker/Technician). **Authentification à deux facteurs (2FA TOTP)** avec code à 6 chiffres renouvelé toutes les 30 secondes. **Journal d'audit** complet traçant chaque opération CRUD avec anciennes et nouvelles valeurs (affichage diff coloré), filtres par utilisateur/table/action, et export CSV. Row Level Security (RLS) activée sur toutes les tables Supabase.

### 🌐 Site Vitrine
Page publique à l'URL racine (`/`) présentant la boutique : Hero, Services, Comment ça marche, Suivi de réparation (saisie de numéro), Contact et Horaires. Responsive via `LayoutBuilder`.

### 📲 Notifications WhatsApp
Boutons "Envoyer WhatsApp" par statut de réparation avec message pré-formaté (template par étape). Liens profonds `wa.me` avec numéro et texte encodé. Historique des envois dans `repair_notifications`.

### 📄 Génération PDF
- **Devis PDF** : en-tête LaidaniRepair, coordonnées client, appareil, panne, coûts détaillés (pièces, main-d'œuvre, total), validité 15 jours, conditions générales
- **Certificat de Garantie PDF** : numéro de ticket, QR code, appareil, date de remise, durée garantie, date d'expiration, signature
- **Facture PDF** : après remise de l'appareil, avec total et détails

### 🌍 Multilingue (AR/FR/EN)
Support complet de l'arabe (RTL), du français et de l'anglais. Bascule par icône dans l'en-tête. Persistance du choix via `SharedPreferences`. `GlobalMaterialLoc alizations` + `GlobalWidgetsLocalizations` configurés.

---

## 📸 Captures d'écran

```
assets/screenshots/
├── dashboard.png
├── pos.png
├── repairs_list.png
├── ticket_details.png
├── inventory.png
├── clients.png
├── promotions.png
├── attendance.png
├── employees.png
├── tracking_public.png
├── reports.png
├── settings.png
├── kiosk_mode.png
├── website.png
├── notifications.png
└── 2fa_setup.png
```

*Les captures d'écran seront ajoutées prochainement.*

---

## 🗃️ Schéma de la Base de Données

### Auth & Utilisateurs
| Table | Description |
|---|---|
| `auth.users` | Utilisateurs Supabase Auth (géré par Supabase) |
| `roles` | Rôles (`owner`, `worker`, `technician`) |
| `profiles` | Profils utilisateurs (nom, téléphone, rôle, statut actif, `branch_id`, `permissions` JSONB, `totp_secret`, `totp_enabled`) |
| `branches` | Succursales (nom, adresse, téléphone) |

### Point de Vente (POS)
| Table | Description |
|---|---|
| `categories` | Catégories de produits |
| `products` | Produits (nom, code-barres, prix, stock, seuil min) |
| `sales_invoices` | Factures de vente (total, remise, montant final, client, employé) |
| `sales_items` | Lignes de facture (produit, quantité, prix de vente) |
| `promotions` | Codes promo (type, valeur, utilisation, expiration) |
| `customer_payments` | Paiements clients (montant, date, employé) |
| `loyalty_transactions` | Transactions de points de fidélité (client, points, type, référence) |

### Réparations
| Table | Description |
|---|---|
| `repair_tickets` | Tickets de réparation (appareil, problème, statut, coût, technicien, QR code, garantie) |
| `repair_parts` | Pièces utilisées (produit, quantité, prix facturé, garantie) |
| `repair_photos` | Photos (diagnostic, réparation, remise) |
| `repair_payments` | Paiements sur réparation (montant, méthode, notes) |
| `repair_ticket_events` | Historique des événements (changement de statut, affectation, etc.) |
| `repair_notifications` | Notifications envoyées au client (méthode, statut, notes) |
| `warranty_claims` | Réclamations garantie (motif, statut, résolution) |
| `customer_feedback` | Avis clients (note /5, commentaire) |
| `maintenance_reminders` | Rappels de maintenance automatiques (ticket, date rappel, envoyé) |

### Stock & Achats
| Table | Description |
|---|---|
| `suppliers` | Fournisseurs (nom, téléphone, total dû) |
| `purchase_invoices` | Factures d'achat (fournisseur, total, payé, employé) |
| `purchase_items` | Lignes d'achat (produit, quantité, prix d'achat, retour) |
| `supplier_payments` | Paiements fournisseurs |
| `stock_movements` | Mouvements de stock tracés (motif, référence) |

### Ressources Humaines
| Table | Description |
|---|---|
| `attendance` | Pointages (check-in, check-out, notes) |

### Finances
| Table | Description |
|---|---|
| `expenses` | Dépenses (type, montant, notes, employé) |

### Audit
| Table | Description |
|---|---|
| `audit_logs` | Journal d'audit (action, table, enregistrement, anciennes/nouvelles valeurs) |

---

## 🧰 Stack Technique

| Couche | Technologie | Version |
|---|---|---|
| Langage | Dart | `>=3.3.0 <4.0.0` |
| Framework UI | Flutter | `3.3+` |
| Backend / BDD | Supabase (PostgreSQL) | `2.x` |
| State Management | Riverpod | `^2.5.1` |
| Routing | go_router | `^13.2.4` |
| QR Code | qr_flutter | `^4.1.0` |
| Scanner code-barres | mobile_scanner | `^6.0.2` |
| Graphiques | fl_chart | `^0.69.2` |
| Génération PDF | pdf | `^3.11.1` |
| Impression | printing | `^5.13.4` |
| Date/Heure | intl | `^0.20.2` |
| Polices | google_fonts | `^6.2.1` |
| Fenêtrage | window_manager | `^0.5.1` |
| Images | image_picker | `^1.0.7` |
| Google Drive | google_sign_in | (backup) |
| Crypto (2FA) | crypto | (SHA1/HMAC TOTP) |

---

## 🚀 Installation

### Prérequis
- Flutter SDK `>=3.3.0`
- Compte Supabase (gratuit)
- Compte Groq (gratuit) — pour les fonctionnalités IA
- Git

### Étapes

```bash
# 1. Cloner le dépôt
git clone <url-du-depot>
cd laidani_repair

# 2. Installer les dépendances
flutter pub get
```

### Configuration Supabase

1. Créez un projet sur [supabase.com](https://supabase.com)
2. Dans l'éditeur SQL, exécutez les migrations situées dans le dossier `supabase/migrations/` (si présent)
3. Activez l'authentification par email/password dans **Authentication → Providers**
4. Activez **Row Level Security** sur toutes les tables
5. Copiez l'URL et la clé `anon` depuis **Project Settings → API**
6. Mettez à jour `lib/core/constants/app_constants.dart` :

```dart
static const String supabaseUrl = 'https://votre-projet.supabase.co';
static const String supabaseAnonKey = 'votre-cle-anon';
static const String groqApiKey = 'votre-cle-groq'; // Optionnel, placeholder par défaut
```

```bash
# 3. Lancer l'application
flutter run
```

---

## 👥 Contrôle d'Accès par Rôle

| Fonctionnalité | Propriétaire (Owner) | Employé (Worker) | Technicien |
|---|---|---|---|
| Tableau de bord | ✅ | ✅ | ✅ |
| Point de Vente (POS) | ✅ | ✅ | ✅ |
| Réparations (toutes) | ✅ | ✅ | ✅ (ses tickets) |
| Mon Atelier (technicien) | ✅ | ✅ | ✅ |
| Pointage | ✅ | ✅ | ✅ |
| Clients & Dettes | ✅ | ✅ | ✅* |
| **Employés** | ✅ | ❌ | ❌ |
| **Inventaire** | ✅ | ❌ | ❌ |
| **Achats & Fournisseurs** | ✅ | ❌ | ❌ |
| **Dépenses** | ✅ | ❌ | ❌ |
| **Journal d'audit** | ✅ | ❌ | ❌ |
| **Rapports** | ✅ | ❌ | ❌ |
| **Promotions** | ✅ | ❌ | ❌ |
| **Paramètres** | ✅ | ❌ | ❌ |
| **Multi-succursales** | ✅ | ❌ | ❌ |
| Suivi public (QR code) | ✅ (public, sans auth) | ✅ |
| Import CSV | ✅ | ❌ | ❌ |
| Opérations groupées | ✅ | ❌ | ❌ |

*\*Permissions granulaires configurables par le propriétaire dans la fiche employé.*

---

## 📁 Structure du Projet

```
lib/
├── core/                          # Couche transversale
│   ├── constants/                 # Constantes (URLs, routes, rôles)
│   ├── localization/              # Support multilingue (délégation AppLocalizations)
│   ├── providers/                 # Providers globaux (Supabase client, thème, locale)
│   ├── router/                    # Configuration go_router
│   ├── services/                  # Services (Groq IA, Offline, TOTP 2FA, API fournisseurs)
│   ├── theme/                     # Thèmes clair et sombre (couleurs, styles)
│   └── utils/                     # Utilitaires (PDF quote/warranty, CSV export)
│
├── features/                      # Modules fonctionnels
│   ├── attendance/                # Pointage employés
│   ├── audit/                     # Journal d'audit avec diff viewer + CSV export
│   ├── auth/                      # Connexion, inscription, profil, 2FA OTP
│   ├── branches/                  # Gestion multi-succursales (owner)
│   ├── checkin/                   # Borne libre-service client (QR)
│   ├── clients/                   # Fiche client détaillée + Analyse IA + Points fidélité
│   ├── dashboard/                 # Tableau de bord avec KPIs, widgets custom, forecast
│   ├── employees/                 # Gestion des employés + permissions granulaires
│   ├── expenses/                  # Gestion des dépenses + Budgets + Analytiques
│   ├── import/                    # Import CSV (produits, clients)
│   ├── maintenance/               # Rappels de maintenance automatiques
│   ├── notifications/             # Centre de notifications intégré
│   ├── pos/                       # Point de vente (caisse + kiosque)
│   │   ├── data/                  # Modèles, repositories
│   │   ├── presentation/
│   │       ├── providers/         # Providers Riverpod (panier, checkout)
│   │       ├── screens/           # Écran POS + mode kiosque
│   │       └── widgets/           # Composants (panier, produit, ticket)
│   ├── promotions/                # Codes promo (owner)
│   ├── repairs/                   # Réparations (création, suivi, QC, duplication, IA)
│   ├── reports/                   # Rapports (ventes, réparations, techniciens, pannes)
│   ├── settings/                  # Paramètres avancés, sauvegarde Google Drive, à propos
│   ├── shell/                     # App shell (navigation latérale, recherche globale)
│   ├── stock/                     # Inventaire, achats, fournisseurs + Analytiques
│   ├── sync/                      # Mode hors-ligne (bannière, statut sync)
│   ├── tracking/                  # Suivi public QR code
│   └── website/                   # Site vitrine public
│
├── l10n/                          # Fichiers de traduction (ar.json, fr.json, en.json)
├── main.dart                      # Point d'entrée (locale, MaterialApp config)
└── app.dart                       # Widget racine
```

---

## 🗺️ Roadmap

### ✅ Terminé
- ✅ POS avec caisse, panier, remises, crédit client, codes promo
- ✅ Gestion des réparations (création, diagnostic, photos, devis, duplication)
- ✅ Workflow complet : En attente → En cours → QC → Terminé → Livré
- ✅ Attribution aux techniciens avec SLA (date estimée, escalade vert/jaune/rouge)
- ✅ QR code unique par ticket + page publique de suivi (`/track/:hash`)
- ✅ Contrôle qualité avant livraison
- ✅ Gestion des garanties (pièces, main-d'œuvre) + certificat PDF
- ✅ Notifications client (WhatsApp template par statut)
- ✅ Validation de devis par le client + génération devis PDF
- ✅ Facture PDF après remise
- ✅ Tableau de bord propriétaire (KPIs, alertes, graphiques, forecast)
- ✅ Graphique des pannes les plus fréquentes (fl_chart, top 10)
- ✅ Widgets personnalisables (afficher/masquer les cartes du tableau de bord)
- ✅ Rapport de performance des techniciens
- ✅ Rapports de ventes et réparations avec filtres
- ✅ Export CSV (ventes, réparations, inventaire, clients, audit)
- ✅ Gestion des employés avec permissions granulaires (4 droits)
- ✅ Pointage quotidien (check-in/check-out)
- ✅ Scanner code-barres intégré (caméra)
- ✅ Impression thermique (PDF + printing) + étiquettes code-barres
- ✅ Recherche globale floue avec historique
- ✅ Journal d'audit complet avec diff viewer coloré + filtres
- ✅ Authentification et contrôle d'accès par rôle (Owner/Worker/Technician)
- ✅ Authentification à deux facteurs (2FA TOTP)
- ✅ Mode hors-ligne avec cache JSON local et file d'attente de sync
- ✅ Thème clair/sombre (bascule utilisateur persistante)
- ✅ Support multilingue (Arabe / Français / Anglais) avec RTL
- ✅ Raccourcis clavier globaux (Ctrl+1-8, Ctrl+N/P/F/K, F1)
- ✅ Gestion multi-succursales (branches)
- ✅ Assistant diagnostic IA (Groq - Llama3)
- ✅ Estimateur de prix IA (Groq)
- ✅ Suggestion de pièces IA (Groq)
- ✅ Suggestions de réapprovisionnement IA (Groq)
- ✅ Analyse client IA (score, risque, offres) (Groq)
- ✅ Intégration API fournisseurs (UI complète avec catalogue mocké)
- ✅ Paramètres avancés (apparence, sécurité 2FA, sauvegarde GDrive, à propos)
- ✅ Accueil client libre-service (borne QR /check-in)
- ✅ Points de fidélité (cumul 1pt/100DA, rachat 100pts=100DA)
- ✅ Rappels de maintenance automatiques (6 mois après remise)
- ✅ Chronologie visuelle 7 étapes (page tracking publique)
- ✅ Site vitrine public (/)
- ✅ Mode kiosque (Ctrl+K, affichage grand format)
- ✅ Marge bénéficiaire réelle par réparation
- ✅ Prévisions de ventes sur 7 jours
- ✅ Centre de notifications (cloche + badge)
- ✅ Opérations groupées (réparations et inventaire)
- ✅ Import CSV (produits et clients)
- ✅ Sauvegarde Google Drive (écran de configuration)

### 🚧 En cours
- 🚧 Tests automatisés (unitaires et d'intégration)

### 🔮 Planifié — Feuille de Route Complète

#### 🔴 Qualité & Performance
- 🔮 Tests unitaires, d'intégration et de widgets (couverture complète)
- 🔮 CI/CD via GitHub Actions (lint + test + build automatique)
- 🔮 Error tracking via Sentry
- 🔮 Optimisation des requêtes Supabase + indexes
- 🔮 Rapport de couverture de code
- 🔮 flutter_lints strict (règles de code unifiées)
- 🔮 Audit des dépendances (packages obsolètes ou vulnérables)
- 🔮 Pagination sur toutes les listes longues
- 🔮 Cache des images (photos de réparation)
- 🔮 Lazy loading des écrans lourds

#### 🛡️ Sécurité
- 🔮 Rate limiting (anti-spam sur les requêtes)
- 🔮 Session timeout automatique après inactivité
- 🔮 Chiffrement local des clés API (Groq, etc.)
- 🔮 Audit complet des politiques RLS Supabase

#### 📱 Expérience Utilisateur
- 🔮 Écran d'onboarding pour les nouveaux utilisateurs
- 🔮 États vides illustrés (listes vides, pas de résultats)
- 🔮 Squelettes de chargement (loading skeletons)
- 🔮 Annulation des dernières actions (Undo)
- 🔮 Retour haptique sur mobile

#### 📊 Monitoring
- 🔮 Tableau de bord analytique (écrans les plus utilisés, utilisateurs actifs)
- 🔮 Rapports de crash automatiques
- 🔮 Monitoring des performances par écran

#### 💰 Finance
- 🔮 Caisse par succursale (solde d'ouverture, dépôt, retrait)
- 🔮 Rapport Z de fin de journée par caisse
- 🔮 Rapprochement caisse (espèces réelles vs système)
- 🔮 Retours et remboursements de ventes
- 🔮 Clôture journalière par succursale
- 🔮 Rapports P&L centralisés (toutes succursales confondues)

#### 📦 Stock Inter-Succursales
- 🔮 Visibilité du stock de toutes les succursales en temps réel
- 🔮 Demandes de transfert de stock entre succursales
- 🔮 Entrepôt central (Warehouse) distribuant vers les succursales

#### 👥 Ressources Humaines
- 🔮 Transfert d'employé entre succursales (temporaire ou permanent)
- 🔮 Gestion des salaires et commissions (ventes + réparations)
- 🔮 Demandes de congé avec validation par le propriétaire
- 🔮 Suivi du temps de réparation par technicien
- 🔮 Calcul du coût réel de la main-d'œuvre (coût horaire × temps)

#### 🔧 Réparations Avancées
- 🔮 Checklist d'accueil standardisée (points de contrôle visuels)
- 🔮 Workflow spécifique PC/Laptop (différent du smartphone)
- 🔮 Transfert de ticket entre succursales
- 🔮 Tarification différente par succursale

#### 📲 Communication
- 🔮 SMS automatique via API (Twilio ou équivalent)
- 🔮 Envoi de facture/garantie par email
- 🔮 Lien d'avis Google Maps après remise de l'appareil

#### 🛒 Point de Vente Avancé
- 🔮 Pré-commande pour produit hors stock
- 🔮 Tarification en gros (prix spécial par quantité)
- 🔮 Ventes groupées / bundles (ex: téléphone + coque + verre = prix réduit)

#### 🚀 Expansion
- 🔮 Application mobile client (suivi, historique, notifications push)
- 🔮 API WhatsApp/SMS automatique (envoi sans intervention manuelle)
- 🔮 Business Intelligence avancée (tendances, prédictions, rapports visuels)
- 🔮 Intégration API fournisseurs réelle (catalogue temps réel, commande EDI)
- 🔮 Impression cloud (envoi vers imprimante réseau distante)
- 🔮 Mode hors-ligne complet avec Isar (sync conflits, fusion intelligente)
- 🔮 Notifications push mobiles
- 🔮 Module E-commerce complet (site vitrine + vente en ligne)

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Veuillez suivre le processus standard :

1. Forkez le projet
2. Créez une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Committez vos changements (`git commit -m 'feat: ajout de ma-fonctionnalite'`)
4. Poussez la branche (`git push origin feature/ma-fonctionnalite`)
5. Ouvrez une Pull Request

### Conventions de code
- Suivez le style Dart officiel (`flutter analyze` doit passer sans erreur)
- Commits en anglais, format `type: description` (ex: `feat:`, `fix:`, `docs:`)
- Testez avant chaque commit

---

## 📄 Licence

Projet privé — Tous droits réservés © LaidaniRepair 2026.

Ce logiciel est la propriété exclusive de LaidaniRepair. Toute reproduction, distribution ou modification sans autorisation écrite préalable est interdite.
