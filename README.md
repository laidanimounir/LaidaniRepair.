# LaidaniRepair — ERP de Réparation Téléphonique

Système ERP/POS complet pour atelier de réparation de téléphones et vente d'accessoires.

## Fonctionnalités

### Point de Vente (POS)
- Caisse avec scan de produits (clavier et code-barres via caméra)
- Panier avec modification des prix/remises par article
- Paiement comptant ou crédit client
- Impression de ticket thermique (PDF + impression réelle)
- Codes promo (pourcentage ou montant fixe)
- Sélection rapide du client avec historique

### Gestion des Réparations
- Création de tickets de réparation avec diagnostic, photos, IMEI
- Attribution aux techniciens avec SLA (date estimation)
- Suivi QR code — page publique de suivi (`/track/:hash`)
- Contrôle qualité (QC) avant livraison
- Garantie pièces et main-d'œuvre
- Notifications client (WhatsApp, SMS, appel)
- Validation devis par le client
- Génération facture PDF après remise
- Tableau de bord technicien (Mon Atelier)

### Stock & Achats
- Inventaire produits avec catégories et codes-barres
- Alerte rupture de stock (seuil `min_stock`)
- Gestion fournisseurs et achats (avec retour fournisseur)
- Mouvements de stock tracés

### Dashboard
- Résumé quotidien : ventes, nouvelles réparations, livrées, dépenses, revenu net
- Graphique des pannes fréquentes
- Rupture de stock en surbrillance rouge
- Nombre de réparations en retard (SLA dépassé)

### Rapports
- Rapports de ventes avec filtres (période, employé, client)
- Rapports de réparations avec analyse des pannes
- Export CSV de toutes les données (ventes, réparations, inventaire, clients)

### Clients
- Fiche client détaillée avec onglets : Achats / Réparations / Paiements
- Gestion des dettes (total dû, historique des versements)

### Employés & Pointage
- Gestion des employés (owner seulement)
- Pointage check-in/check-out — historique filtré par rôle

### Promotions
- Codes promo personnalisables (% ou montant fixe)
- Limite d'utilisation et date d'expiration
- Validation automatique au checkout

### Audit & Sécurité
- Journal d'audit complet (CRUD tracé)
- RLS (Row Level Security) sur toutes les tables
- Authentification Supabase

## Stack Technique

| Couche | Technologie |
|--------|-------------|
| Frontend | Flutter 3.3+ / Dart |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| État | Riverpod |
| Routing | go_router |
| QR Code | qr_flutter |
| Scanner | mobile_scanner |
| PDF | pdf + printing |
| Polices | Google Fonts |

## Installation

```bash
# Cloner le dépôt
git clone <url>
cd laidani_repair

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

## Variables d'environnement

Les identifiants Supabase sont dans `lib/core/constants/app_constants.dart` :
- `supabaseUrl` — URL du projet Supabase
- `supabaseAnonKey` — Clé anon publique

## Structure du projet

```
lib/
├── core/                 # Constantes, providers, thème, utilitaires
│   ├── constants/
│   ├── providers/
│   ├── router/
│   ├── theme/
│   └── utils/
├── features/             # Modules fonctionnels
│   ├── attendance/       # Pointage employés
│   ├── audit/            # Journal d'audit
│   ├── auth/             # Authentification
│   ├── clients/          # Clients & dettes
│   ├── dashboard/        # Tableau de bord
│   ├── employees/        # Gestion employés
│   ├── expenses/         # Dépenses
│   ├── pos/              # Point de vente
│   ├── promotions/       # Codes promo
│   ├── repairs/          # Réparations
│   ├── reports/          # Rapports
│   ├── shell/            # App shell & navigation
│   ├── stock/            # Inventaire & achats
│   └── tracking/         # Suivi public QR code
└── main.dart
```

## Base de données

Le projet utilise Supabase PostgreSQL avec les tables principales :
- `profiles`, `customers`, `products`, `categories`, `suppliers`
- `sales_invoices`, `sales_items`
- `purchase_invoices`, `purchase_items`
- `repair_tickets`, `repair_parts`, `repair_photos`, `repair_payments`
- `promotions`, `attendance`, `expenses`, `audit_logs`
- `stock_movements`, `customer_payments`, `supplier_payments`

## Licences

Projet privé — LaidaniRepair © 2026
