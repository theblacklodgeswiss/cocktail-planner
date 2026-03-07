# Firebase CI/CD Setup - GCP Service Account Berechtigungen

## Problem
Der GitHub Actions Workflow schlägt fehl mit:
```
Error: Request to https://serviceusage.googleapis.com/v1/projects/.../services/firestore.googleapis.com had HTTP Error: 403
Caller does not have required permission to use project. Grant the caller the roles/serviceusage.serviceUsageConsumer role
```

## Ursache
Der Service Account in `FIREBASE_SERVICE_ACCOUNT` (GitHub Secret) hat nicht die nötigen GCP-Berechtigungen für Firestore-Deployment.

## Lösung: Service Account Berechtigungen setzen

### Option 1: Über GCP Console (empfohlen)

1. **GCP Console öffnen**:
   - Gehe zu https://console.cloud.google.com/
   - Wähle das Projekt aus (siehe `FIREBASE_PROJECT_ID` in GitHub Secrets)

2. **IAM & Admin öffnen**:
   - Navigiere zu **IAM & Admin** → **IAM**
   - Finde den Service Account (Email endet mit `@<project-id>.iam.gserviceaccount.com`)

3. **Berechtigungen hinzufügen** (Stift-Icon klicken beim Service Account):
   
   Folgende **Rollen** müssen zugewiesen sein:
   
   - ✅ **Firebase Admin** (`roles/firebase.admin`)
     - Für Firebase Hosting & Firestore Rules Deployment
   
   - ✅ **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`)
     - Für API-Aktivierung (Firestore API)
   
   - ✅ **Firebase Rules Admin** (`roles/firebaserules.admin`)
     - Für Firestore Security Rules
   
   - ✅ **Cloud Datastore User** (`roles/datastore.user`)
     - Für Firestore-Zugriff (optional, nur wenn Daten geschrieben werden)

4. **Speichern** und warten (Propagation dauert ~60 Sekunden)

### Option 2: Über gcloud CLI

```bash
# Service Account Email setzen
SA_EMAIL="<service-account>@<project-id>.iam.gserviceaccount.com"
PROJECT_ID="<your-firebase-project-id>"

# Rollen zuweisen
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/firebase.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/serviceusage.serviceUsageConsumer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/firebaserules.admin"
```

### Service Account finden

Wenn du nicht weißt, welcher Service Account verwendet wird:

1. GitHub Repository → **Settings** → **Secrets and variables** → **Actions**
2. Finde `FIREBASE_SERVICE_ACCOUNT` (Wert ist ein JSON)
3. Im JSON siehst du die `client_email` - das ist der Service Account

Beispiel:
```json
{
  "type": "service_account",
  "project_id": "your-project",
  "client_email": "github-actions@your-project.iam.gserviceaccount.com",
  ...
}
```

## Verification

Nach dem Setzen der Berechtigungen:

1. **Warte 60-120 Sekunden** (Permission propagation)

2. **Teste das Deployment**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   
   Oder manuell triggern: GitHub → **Actions** → **Deploy to Firebase Hosting** → **Run workflow**

3. **Prüfe die GitHub Actions Logs**:
   - Bei Erfolg sollte `=== Deploying to '...'` ohne Fehler durchlaufen

## Minimale Berechtigungen (Production-Best-Practice)

Für **Hosting + Firestore Rules only** (kein Cloud Functions, Firestore Data):

```
roles/firebase.hostingAdmin
roles/firebaserules.admin
roles/serviceusage.serviceUsageConsumer
```

Für **Full Firebase Deployment** (inkl. Cloud Functions):

```
roles/firebase.admin
roles/serviceusage.serviceUsageConsumer
```

## Troubleshooting

### Fehler bleibt nach 2 Minuten

→ Lösche den GitHub Actions Cache:
```bash
# In GitHub Repository
Settings → Actions → Management → Delete all caches
```

### "Service account does not exist"

→ Service Account muss neu erstellt werden:
1. GCP Console → **IAM & Admin** → **Service Accounts**
2. **Create Service Account**
3. **Key** als JSON erstellen
4. JSON-Inhalt in `FIREBASE_SERVICE_ACCOUNT` (GitHub Secret) einfügen

### "Permission denied on storage bucket"

→ Zusätzlich benötigt:
```
roles/storage.admin
```

## Weitere Informationen

- [Firebase CLI Deploy Berechtigungen](https://firebase.google.com/docs/cli#administrative_commands)
- [GCP IAM Rollen](https://cloud.google.com/iam/docs/understanding-roles)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
