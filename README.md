# 🔧 LaidaniRepair — ERP de Réparation Téléphonique

**Système ERP/POS complet pour ateliers de réparation de téléphones et vente d'accessoires — multi-utilisateur, temps réel, cloud.**

[![Flutter](https://img.shields.io/badge/Flutter-3.3%2B-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-2.x-3ECF8E?logo=supabase)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-5C4EE5)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-Private-red)](#license)

---

## ✨ Features

### 🛒 Point de Vente (POS)
Une caisse enregistreuse complète avec catalogue produits, catégories et recherche par nom ou code-barres. Supporte les ventes au comptant ou à crédit, avec sélection du client, modification du prix unitaire, remise par article, et remise globale. Validez la vente et imprimez un ticket thermique (PDF) automatiquement. Les codes promo (pourcentage ou montant fixe) sont validés en temps réel au checkout.

### 🛠️ Gestion des Réparations
Cycle de vie complet d'un ticket de réparation : création avec diagnostic, photos, IMEI, mot de passe, accessoires. Attribution aux techniciens avec date de fin estimée (SLA). Workflow de devis (envoi WhatsApp/SMS/Email, approbation client). Contrôle qualité avant livraison avec notes et test de l'appareil. Génération de facture PDF au moment de la remise. Garantie pièces et main-d'œuvre configurable. QR code unique par ticket permettant un suivi public.

### 📊 Tableau de Bord
Vue d'ensemble de l'activité quotidienne : réparations actives, livraisons du jour, chiffre d'affaires, dépenses, revenu net. Alertes visuelles : réparations en retard (SLA dépassé) surlignées en rouge, ruptures de stock en bannière persistante, réclamations garantie en attente. Graphique des pannes les plus fréquentes (par problème, marque, type d'appareil).

### 👥 Clients & Dettes
Fiche client détaillée avec trois onglets : historique des achats (factures POS), historique des réparations (tickets), et historique des paiements. Total dépensé et dette globale affichés. Paiement partiel possible au POS avec enregistrement automatique de la dette. Recherche par nom ou numéro de téléphone.

### 📦 Stock & Achats
Inventaire complet avec catégories, codes-barres, prix d'achat et de vente. Seuil de réapprovisionnement (`min_stock`) avec alerte visuelle. Gestion des fournisseurs avec achats, retours fournisseur, et suivi des paiements. Chaque mouvement de stock est tracé (vente, achat, réparation, manuel, retour).

### 👨‍🔧 Employés & Pointage
Gestion des comptes employés (création, activation/suspension, attribution de rôle). Pointage quotidien avec bouton check-in/check-out. Le propriétaire voit l'historique de tous les employés ; chaque employé voit uniquement ses propres pointages.

### 🏷️ Promotions
Codes promo personnalisables : choix entre réduction en pourcentage ou montant fixe, achat minimum requis, limite d'utilisation totale, date d'expiration. Validation automatique lors du checkout POS.

### 🔍 Suivi Public (QR Code)
Chaque ticket de réparation génère un QR code unique. En scannant ce code, le client accède à une page publique (sans authentification) affichant le statut de la réparation, l'appareil, le technicien assigné, la date estimée de fin, et le solde restant à payer.

### 🤖 IA Groq (Llama3)
Assistant intelligent intégré via l'API Groq : diagnostic automatique des pannes, estimation des prix de réparation, suggestion de pièces détachées avec correspondance en stock, analyse de réapprovisionnement, et scoring client (valeur, risque de churn, offres personnalisées).

### 🏢 Multi-Succursales
Gestion de plusieurs boutiques : création de branches avec adresse et téléphone, association des employés à une succursale via `profiles.branch_id`.

### 📡 Mode Hors-Ligne
Détection de connectivité automatique (`dart:io`), cache local en fichiers JSON dans le répertoire temporaire, bannière visuelle "hors-ligne" et indicateur de synchronisation dans l'en-tête.

### 🏥 SLA & Escalade
Chaque ticket de réparation est coloré par statut SLA : vert (dans les temps), jaune (échéance dans 24h), rouge (dépassé). Filtres SLA dédiés dans la liste des réparations.

### 🖨️ Impression Étiquettes
Génération et impression d'étiquettes code-barres pour les produits avec nom, code-barres, prix et nom du magasin via le package `printing`.

### 📊 Analytiques Avancées
Graphiques d'inventaire (top 10 produits, produits à faible rotation, KPIs) et graphiques de dépenses (évolution sur 6 mois, budget par catégorie avec barres de progression) utilisant `fl_chart`.

### 📥 Import CSV
Import de fichiers CSV pour les produits et clients avec validation des colonnes, prévisualisation des données, surlignage des erreurs et insertion groupée dans Supabase.

### 🔔 Centre de Notifications
Cloche de notifications avec badge de compteur dans l'en-tête, listant : stocks bas, réparations en retard, rappels de maintenance. Navigation directe vers l'écran concerné.

### 🧮 Opérations Groupées
Mode sélection multiple avec cases à cocher dans les listes de réparations et d'inventaire. Actions groupées : changement de statut, assignation de technicien, export CSV des éléments sélectionnés.

### 📈 Rapports & Export
Rapports de ventes avec filtres (période prédéfinie ou personnalisée, employé, client). Rapports de réparations avec analyse des pannes fréquentes. Export CSV disponible pour : ventes, réparations, inventaire, et clients.

### 🔐 Audit & Sécurité
Journal d'audit complet traçant chaque opération CRUD (création, modification, suppression) avec l'identifiant de l'employé, la table concernée, les anciennes et nouvelles valeurs. Row Level Security (RLS) activée sur toutes les tables Supabase.

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
└── reports.png
```

*Les captures d'écran seront ajoutées prochainement.*

---

## 🗃️ Schéma de la Base de Données

### Auth & Utilisateurs
| Table | Description |
|---|---|
| `auth.users` | Utilisateurs Supabase Auth (géré par Supabase) |
| `roles` | Rôles (`owner`, `worker`) |
| `profiles` | Profils utilisateurs (nom, téléphone, rôle, statut actif) |

### Point de Vente (POS)
| Table | Description |
|---|---|
| `categories` | Catégories de produits |
| `products` | Produits (nom, code-barres, prix, stock, seuil min) |
| `sales_invoices` | Factures de vente (total, remise, montant final, client, employé) |
| `sales_items` | Lignes de facture (produit, quantité, prix de vente) |
| `promotions` | Codes promo (type, valeur, utilisation, expiration) |
| `customer_payments` | Paiements clients (montant, date, employé) |

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
| Génération PDF | pdf | `^3.11.1` |
| Impression | printing | `^5.13.4` |
| Date/Heure | intl | `^0.20.2` |
| Polices | google_fonts | `^6.2.1` |
| Fenêtrage | window_manager | `^0.5.1` |
| Images | image_picker | `^1.0.7` |

---

## 🚀 Installation

### Prérequis
- Flutter SDK `>=3.3.0`
- Compte Supabase (gratuit)
- Git

### Étapes

```bash
# 1. Cloner le dépôt
git clone <url-du-depot>
cd laidani_repair

# 2. Installer les dépendances
flutter pub get

# 3. Configurer Supabase
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
```

```bash
# 4. Lancer l'application
flutter run
```

---

## 👥 Contrôle d'Accès par Rôle

| Fonctionnalité | Propriétaire (Owner) | Employé (Worker) |
|---|---|---|
| Tableau de bord | ✅ | ✅ |
| Point de Vente (POS) | ✅ | ✅ |
| Réparations | ✅ | ✅ |
| Mon Atelier (technicien) | ✅ | ✅ |
| Pointage | ✅ | ✅ |
| Clients & Dettes | ✅ | ✅ |
| **Employés** | ✅ | ❌ |
| **Inventaire** | ✅ | ❌ |
| **Achats & Fournisseurs** | ✅ | ❌ |
| **Dépenses** | ✅ | ❌ |
| **Journal d'audit** | ✅ | ❌ |
| **Rapports** | ✅ | ❌ |
| **Promotions** | ✅ | ❌ |
| Suivi public (QR code) | ✅ (public, sans auth) | ✅ |

---

## 📁 Structure du Projet

```
lib/
├── core/                          # Couche transversale
│   ├── constants/                 # Constantes (URLs, routes, rôles)
│   ├── providers/                 # Providers globaux (Supabase client)
│   ├── router/                    # Configuration go_router
│   ├── services/                  # Services (Groq IA, Offline, TOTP, API fournisseurs)
│   ├── theme/                     # Thème sombre (couleurs, styles)
│   └── utils/                     # Utilitaires (PDF, CSV export)
│
├── features/                      # Modules fonctionnels
│   ├── attendance/                # Pointage employés
│   ├── audit/                     # Journal d'audit
│   ├── auth/                      # Connexion, inscription, profil
│   ├── branches/                  # Gestion multi-succursales (owner)
│   ├── checkin/                   # Borne libre-service client (QR)
│   ├── clients/                   # Fiche client détaillée +Analyse IA
│   ├── dashboard/                 # Tableau de bord avec KPIs
│   ├── employees/                 # Gestion des employés (owner)
│   ├── expenses/                  # Gestion des dépenses +Budgets +Analytiques
│   ├── import/                    # Import CSV (produits, clients)
│   ├── notifications/             # Centre de notifications intégré
│   ├── pos/                       # Point de vente (caisse)
│   │   ├── data/                  # Modèles, repositories
│   │   ├── presentation/
│   │       ├── providers/         # Providers Riverpod (panier, checkout)
│   │       ├── screens/           # Écran POS
│   │       └── widgets/           # Composants (panier, produit, ticket)
│   ├── promotions/                # Codes promo (owner)
│   ├── repairs/                   # Réparations (création, suivi, QC, duplication, IA)
│   ├── reports/                   # Rapports (ventes, réparations)
│   ├── settings/                  # Paramètres, Sauvegarde
│   ├── shell/                     # App shell (navigation latérale, recherche)
│   ├── stock/                     # Inventaire, achats, fournisseurs +Analytiques
│   ├── sync/                      # Mode hors-ligne (bannière, statut sync)
│   ├── tracking/                  # Suivi public QR code
│   └── website/                   # Site vitrine
│
├── main.dart                      # Point d'entrée
└── app.dart                       # Widget racine
```

---

## 🗺️ Roadmap

### ✅ Terminé
- ✅ POS avec caisse, panier, remises, crédit client
- ✅ Gestion des réparations (création, diagnostic, photos, devis)
- ✅ Workflow complet : En attente → En cours → QC → Terminé → Livré
- ✅ Attribution aux techniciens avec SLA (date estimée)
- ✅ QR code unique par ticket
- ✅ Page publique de suivi (`/track/:hash`)
- ✅ Contrôle qualité avant livraison
- ✅ Gestion des garanties (pièces, main-d'œuvre)
- ✅ Notifications client (WhatsApp, SMS, appel, email)
- ✅ Validation de devis par le client
- ✅ Génération facture PDF après remise
- ✅ Tableau de bord technicien (Mon Atelier)
- ✅ Tableau de bord propriétaire (KPIs, alertes, graphiques)
- ✅ Rapports de ventes et réparations avec filtres
- ✅ Export CSV (ventes, réparations, inventaire, clients)
- ✅ Gestion des employés et pointage
- ✅ Codes promo personnalisables
- ✅ Scanner code-barres intégré (caméra)
- ✅ Impression thermique réelle (PDF + printing)
- ✅ Recherche globale dans l'application
- ✅ Journal d'audit complet
- ✅ Authentification et contrôle d'accès par rôle
- ✅ Mode hors-ligne avec cache JSON local et auto-sync
- ✅ Thème clair/sombre (bascule utilisateur)
- ✅ Support multilingue (Arabe / Français / Anglais)
- ✅ Gestion multi-succursales (branches)
- ✅ Assistant diagnostic IA (Groq - Llama3)
- ✅ Estimateur de prix IA (Groq)
- ✅ Suggestion de pièces IA (Groq)
- ✅ Suggestions de réapprovisionnement IA (Groq)
- ✅ Analyse client IA (score, risque, offres) (Groq)
- ✅ Intégration API fournisseurs (placeholder + UI flow)
- ✅ Paramètres avancés (apparence, sécurité, à propos)
- ✅ Escalade SLA (vert/jaune/rouge)
- ✅ Accueil client libre-service (borne QR)
- ✅ Onglet d'analytiques inventaire (graphiques)
- ✅ Budgets et analytiques dépenses (graphiques)
- ✅ Recherche floue et historique de recherche
- ✅ Centre de notifications intégré (cloche + badge)
- ✅ Duplication de ticket de réparation
- ✅ Opérations groupées (réparations et inventaire)
- ✅ Impression d'étiquettes code-barres
- ✅ Import CSV (produits et clients via file_picker)

### 🚧 En cours
- 🚧 Tests automatisés (unitaires et d'intégration)

### 🔮 Planifié
- 🔮 Application mobile client
- 🔮 Sauvegarde automatique Google Drive
- 🔮 Notifications push mobile
- 🔮 Devis envoyé par email avec signature électronique
- 🔮 Paiement en ligne (Intégration CIB / Dahabia)
- 🔮 Module E-commerce (site vitrine + vente en ligne)
- 🔮 Intégration API fournisseurs réelles

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
