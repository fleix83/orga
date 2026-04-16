# Orga-Tool — Design-Spezifikation

Massgeschneidertes Organisationstool fuer die Selbstaendigkeit von Felix Weissheimer.

## Stack

- **Frontend:** Vue 3 (Composition API) + Vue Router, gebaut mit Vite
- **Backend:** Plain PHP REST-API (kein Framework), PDO fuer DB-Zugriffe
- **Datenbank:** MariaDB (bestehende `luftgaessli`-DB auf XAMPP, erweitert)
- **Auth:** PHP-Sessions, bcrypt-Passwort
- **Deployment:** GitHub → Server. `dist/` (Vue Build) + `api/` (PHP) werden deployed.

## Projektstruktur

```
/htdocs/orga/
├── api/
│   ├── config.php          # DB-Verbindung, Auth-Check
│   ├── auth.php            # Login/Logout/Session
│   ├── customers.php       # CRUD Kunden
│   ├── orders.php          # CRUD Auftraege
│   ├── services.php        # CRUD Dienstleistungen
│   ├── inventory.php       # CRUD Inventar
│   ├── expenses.php        # CRUD Aufwaende
│   ├── categories.php      # CRUD Zuordnungen
│   ├── appointments.php    # Termine lesen (aus luftgaessli events/bookings)
│   ├── reports.php         # Geschaeftszahlen + Export
│   └── export.php          # CSV/PDF-Generierung
├── frontend/               # Vue 3 Quellcode (nur Entwicklung)
│   ├── src/
│   ├── package.json
│   └── vite.config.js
├── dist/                   # Vue Build-Output (wird deployed)
│   ├── index.html
│   └── assets/
└── migration.sql           # DB-Migration fuer neue Tabellen
```

## Datenbank-Design

### Bestehende Tabelle `customers` — erweitert

Neue Felder zu den bestehenden (id, customer_number, first_name, last_name, email, phone, notes, created_at, updated_at):

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| salutation | VARCHAR(20) | Anrede (Herr, Frau, etc.) |
| street | VARCHAR(200) | Strasse |
| zip | VARCHAR(10) | PLZ |
| city | VARCHAR(100) | Ort |
| nationality | VARCHAR(100) | Nationalitaet |

Berechnete Felder (nicht in DB, per Query):
- **Total**: Summe aller Auftraege des Kunden
- **Anzahl Termine**: Anzahl Auftraege/Events des Kunden

### Bestehende Tabelle `services` — unveraendert

Bereits vorhanden: id, name, duration_slots, price, description, active, sort_order, created_at.

### Neue Tabelle `categories` (Zuordnungen)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| name | VARCHAR(100) NOT NULL | z.B. "Bewerbungen & Mehr", "Studio LUMINELLI", "Araceli" |
| active | TINYINT(1) DEFAULT 1 | |
| sort_order | INT DEFAULT 0 | |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |

Initiale Daten: "Bewerbungen & Mehr", "Studio LUMINELLI", "Araceli"

### Neue Tabelle `orders` (Auftraege)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| order_date | DATE NOT NULL | Datum des Termins |
| customer_id | INT FK → customers | |
| category_id | INT FK → categories | Zuordnung |
| location_type | ENUM('vor_ort', 'remote') | Vor Ort oder Remote |
| amount | DECIMAL(10,2) NOT NULL | Gesamtbetrag |
| notes | TEXT | Anmerkungen |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

### Neue Tabelle `order_services` (Dienstleistungen pro Auftrag)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| order_id | INT FK → orders | |
| service_id | INT FK → services, NULL wenn custom | |
| custom_name | VARCHAR(200) | Fuer Custom-Dienstleistungen |
| price | DECIMAL(10,2) NOT NULL | Preis zum Zeitpunkt der Buchung |

### Neue Tabelle `inventory` (Inventar)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| name | VARCHAR(200) NOT NULL | Bezeichnung |
| value | DECIMAL(10,2) NOT NULL | Wert in CHF |
| purchase_date | DATE | Kaufdatum |
| owner | ENUM('felix', 'araceli') NOT NULL | Zuordnung |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |

### Neue Tabelle `expenses` (Aufwaende)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| expense_date | DATE NOT NULL | |
| description | VARCHAR(300) NOT NULL | Bezeichnung |
| amount | DECIMAL(10,2) NOT NULL | Betrag in CHF |
| category_id | INT FK → categories | Zuordnung (Standard: Bewerbungen & Mehr) |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |

### Neue Tabelle `app_users` (Auth)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| id | INT AUTO_INCREMENT PK | |
| username | VARCHAR(50) NOT NULL UNIQUE | |
| password_hash | VARCHAR(255) NOT NULL | bcrypt |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |

### Bestehende Tabellen (unveraendert, read-only)

`events`, `bookings`, `services`, `event_types`, `blocked_dates`, `free_slots`, `availability_settings`, `users` — werden fuer den Termine-Screen gelesen, aber nicht veraendert (ausser Status/Notizen bei events).

## API-Endpunkte

Alle unter `/orga/api/`. Jeder Request (ausser Login) prueft PHP-Session.

| Endpunkt | Methode | Funktion |
|----------|---------|----------|
| auth.php | POST | Login |
| auth.php?action=logout | POST | Logout |
| auth.php?action=check | GET | Session pruefen |
| customers.php | GET | Alle Kunden (mit Total + Anz. Termine) |
| customers.php?id=X | GET | Einzelner Kunde |
| customers.php | POST | Kunde anlegen |
| customers.php?id=X | PUT | Kunde bearbeiten |
| customers.php?id=X | DELETE | Kunde loeschen |
| orders.php | GET | Alle Auftraege (neueste zuerst, mit Kunde + Services) |
| orders.php | POST | Auftrag anlegen (inkl. order_services) |
| orders.php?id=X | PUT | Auftrag bearbeiten |
| orders.php?id=X | DELETE | Auftrag loeschen |
| services.php | GET/POST/PUT/DELETE | CRUD Dienstleistungen |
| categories.php | GET/POST/PUT/DELETE | CRUD Zuordnungen |
| inventory.php | GET/POST/PUT/DELETE | CRUD Inventar |
| expenses.php | GET/POST/PUT/DELETE | CRUD Aufwaende |
| appointments.php | GET | Termine aus events/bookings |
| appointments.php?id=X | PUT | Termin-Status/Notizen bearbeiten |
| reports.php?month=X&year=Y | GET | Monatliche Geschaeftszahlen |
| reports.php?year=Y | GET | Jaehrliche Geschaeftszahlen |
| export.php?type=csv&... | GET | CSV-Export |
| export.php?type=pdf&... | GET | PDF-Export |

## Frontend — Screens

### Sidebar (fix links)

1. Kunden
2. Auftraege
3. Dienstleistungen
4. Inventar
5. Aufwand
6. Geschaeftszahlen
7. Termine

### Kunden-Screen

- Tabelle: Nummer, Anrede, Name, Vorname, Ort, Telefon, Email, Total (berechnet), Anz. Termine (berechnet)
- Inline-Editing: Klick auf Feld → editierbar, Enter/Tab speichert, Escape bricht ab
- Zeile aufklappen fuer Details (Strasse, PLZ, Nationalitaet, Anmerkung)
- "Neuer Kunde" Button → leere Zeile
- Loeschen via Icon am Zeilenende (mit Bestaetigung)
- Suchfeld oben zum Filtern

### Auftraege-Screen

- Liste aller Auftraege, neueste zuoberst
- Pro Zeile: Datum, Kunde (Name), Dienstleistung(en), Betrag, Zuordnung
- "Neuer Auftrag" Button → Erfassungsformular (Modal):
  - Datum + Vor Ort/Remote Toggle
  - Kunde auswaehlen (Dropdown mit Suche) oder neu anlegen
  - Dienstleistungen auswaehlen (Checkboxen) + Custom-Textfeld
  - Betrag (berechnet aus Services, manuell ueberschreibbar)
  - Anmerkungen
  - Zuordnung (Dropdown aus categories)
- Bestehende Auftraege per Klick editierbar

### Dienstleistungen-Screen

- Tabelle: Name, Preis (CHF), Beschreibung, Aktiv (Toggle)
- Inline-Editing, Sortierung per sort_order
- Hinzufuegen / Loeschen

### Inventar-Screen

- Tabelle: Bezeichnung, Wert CHF, Kaufdatum, Zuordnung (Felix/Araceli)
- Inline-Editing, Hinzufuegen / Loeschen
- Total unten: Gesamtwert, aufgeteilt nach Zuordnung

### Aufwand-Screen

- Tabelle: Datum, Bezeichnung, Betrag CHF, Zuordnung
- Inline-Editing, Hinzufuegen / Loeschen
- Total unten

### Geschaeftszahlen-Screen

- Monat/Jahr-Umschalter oben
- Monatsansicht: Alle Auftraege (Datum, Kunde, Dienstleistung, Betrag) + alle Aufwaende. Total Einnahmen, Total Aufwaende, Differenz
- Jahresansicht: Aggregiert pro Monat, aufklappbar
- Export-Buttons: CSV, Excel, PDF
- PDF: "Felix Weissheimer" im Kopf, Zeitraum, tabellarische Auflistung

### Termine-Screen

- Liste der Termine aus events/bookings
- Anzeige: Datum, Uhrzeit, Kunde, Dienstleistungen, Status
- Editierbar: Status aendern, Notizen bearbeiten
- Datum/Zeit read-only (wird ueber bestehenden Terminmanager gesteuert)

## Design-Stil

- Weisser Hintergrund (#FFFFFF)
- Feine Borders (1px solid #E5E7EB), leicht gerundet (border-radius: 6px)
- System-Font-Stack
- Akzentfarbe: #2563EB (Buttons, Links)
- Kein Schatten, keine Animationen
- Schlichte inline SVG-Icons wo noetig

## Authentifizierung

- PHP-Session-basiert
- Login-Formular → auth.php (POST)
- Passwort: password_hash() / password_verify() (bcrypt)
- Jeder API-Call prueft $_SESSION['user_id']
- Vue prueft beim App-Start via auth.php?action=check → Redirect auf Login falls keine Session
- Kein "Passwort vergessen" — manueller Reset via DB oder CLI-Script
- Einzelner User (Felix)

## PDF-Export

- Bibliothek: TCPDF oder FPDF
- Kopf: "Felix Weissheimer", Zeitraum
- Inhalt: Tabellarische Auflistung der Auftraege und Aufwaende
- Fuss: Totale (Einnahmen, Aufwaende, Differenz)
- Zweck: Beleg fuer Schweizer Steuererklaerung
