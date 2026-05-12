# 🚀 Commandes de lancement - Suklu

Guide complet pour lancer les différents modules et services de Suklu.

---

## 📋 Table des matières

1. [Installation initiale](#installation-initiale)
2. [Modules individuels](#modules-individuels)
3. [Démarrage complet](#démarrage-complet)
4. [Docker & AI Gateway](#docker--ai-gateway)
5. [Ports et URLs](#ports-et-urls)
6. [Comptes de test](#comptes-de-test)

---

## ✅ Installation initiale

À exécuter une seule fois pour installer toutes les dépendances :

```bash
setup.bat
```

**Étapes du setup :**
- Vérification de Node.js, Flutter, Python, Firebase CLI
- Installation des dépendances npm (Cloud Functions)
- Installation des packages Flutter (mobile & admin)
- Configuration de l'environnement Python (venv)
- Création du fichier `.env` pour l'AI Gateway

---

## 🚀 Modules individuels

### 1️⃣ Panel Admin (Flutter Web)

```bash
start-admin.bat
```

**Détails :**
- URL: `http://localhost:8081`
- Port: `8081`
- Commande équivalente :
  ```bash
  cd apps/admin
  flutter run -d chrome --web-port 8081
  ```

---

### 2️⃣ App Mobile (Flutter Web)

```bash
start-mobile.bat
```

**Détails :**
- URL: `http://localhost:8082` (première instance)
- Demande l'appareil cible (laisse vide pour le défaut Chrome)
- Fonctionne sur Chrome, Android, iOS
- Commande équivalente :
  ```bash
  cd apps/mobile
  flutter run -d chrome --web-port 8082
  ```

**Lancer plusieurs instances :**
```bash
# Terminal 1 - Tutor (port 8082)
cd apps/mobile
flutter run -d chrome --web-port 8082

# Terminal 2 - Student (port 8084)
cd apps/mobile
flutter run -d chrome --web-port 8084
```

---

### 3️⃣ AI Gateway (FastAPI - Python)

```bash
start-ai-gateway.bat
```

**Détails :**
- API: `http://localhost:8000`
- Documentation interactive: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`
- LLM Provider: OpenAI (GPT-4o-mini)
- Commande équivalente :
  ```bash
  cd backend/ai-gateway
  .venv\Scripts\activate
  python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
  ```

---

### 4️⃣ Emulateurs Firebase

```bash
start-emulators.bat
```

**Détails :**
- Auth: `http://localhost:9099`
- Firestore: `http://localhost:8080`
- Functions: `http://localhost:5001`
- Storage: `http://localhost:9199`
- Hosting: `http://localhost:5000`
- UI: `http://localhost:4000`
- Commande équivalente :
  ```bash
  cd infrastructure/firebase
  firebase emulators:start --import=emulator-data --export-on-exit=emulator-data
  ```

⚠️ **Note :** Les emulateurs sont optionnels. L'app utilise `suklu-prod` (Firebase cloud) par défaut.

---

## 🎯 Démarrage complet

Lance les 3 services principaux dans des fenêtres séparées :

```bash
start-all.bat
```

**Services lancés :**
1. Emulateurs Firebase (optionnel)
2. AI Gateway (FastAPI)
3. Panel Admin (Flutter Web)

**L'app mobile se lance séparément :**
```bash
start-mobile.bat
```

---

## 🐳 Docker & AI Gateway

### Avec Docker Compose

Depuis la racine du repo :

```bash
docker compose up -d qdrant ai-gateway
```

**Services lancés :**
- **Qdrant** : Base de données vectorielle (RAG)
- **AI Gateway** : API FastAPI (port 8000)

### Arrêter les containers

```bash
docker stop suklu-ai-gateway suklu-qdrant
```

### Relancer les containers

```bash
docker start suklu-ai-gateway suklu-qdrant
```

### Ingestion des données RAG

```bash
cd scripts
npm run ingest:rag-fixtures
```

---

## 📍 Ports et URLs

| Service | Port | URL |
|---------|------|-----|
| **Admin Panel** | 8081 | http://localhost:8081 |
| **Mobile (Tutor)** | 8082 | http://localhost:8082 |
| **Mobile (Student)** | 8084 | http://localhost:8084 |
| **AI Gateway** | 8000 | http://localhost:8000 |
| **AI Gateway Docs** | 8000 | http://localhost:8000/docs |
| **Firebase Emulator UI** | 4000 | http://localhost:4000 |
| **Firebase Auth** | 9099 | http://localhost:9099 |
| **Firebase Firestore** | 8080 | interne |
| **Firebase Functions** | 5001 | interne |
| **Firebase Storage** | 9199 | interne |

---

## 👥 Comptes de test

Tous les comptes sont créés dans Firebase (`suklu-prod`).

| Rôle | Email | Mot de passe |
|------|-------|------------|
| 👨‍🎓 Étudiant | `student@suklu.test` | `Test1234!` |
| 👨‍🏫 Tuteur | `tutor@suklu.test` | `Test1234!` |
| 👨‍👩‍👧 Parent | `parent@suklu.test` | `Test1234!` |
| 🔐 Super Admin | `admin@suklu.test` | `Test1234!` |

**Connexion :**
Chaque rôle est automatiquement redirigé vers son dashboard correspondant après authentification.

---

## 🔧 Commandes utiles

### Flutter

```bash
# Analyser le code
flutter analyze

# Formater le code
flutter format lib/

# Nettoyer le projet
flutter clean

# Récupérer les dépendances
flutter pub get
```

### Firebase

```bash
# Déployer les Cloud Functions
firebase deploy --only functions --project suklu-prod

# Déployer les règles Firestore
firebase deploy --only firestore:rules --project suklu-prod

# Consulter les logs des functions
firebase functions:log --project suklu-prod
```

### Git

```bash
# Ajouter et commiter les changements
git add .
git commit -m "message du commit"
git push

# Voir l'historique
git log --oneline
```

---

## 📚 Structure du projet

```
suklu/
├── apps/
│   ├── admin/          # Panel administrateur (Flutter Web)
│   └── mobile/         # App mobile (Flutter - Android/iOS/Web)
├── backend/
│   ├── ai-gateway/     # API IA (FastAPI)
│   └── functions/      # Cloud Functions (TypeScript)
├── infrastructure/
│   └── firebase/       # Configuration Firebase
├── scripts/            # Scripts utilitaires
├── docs/              # Documentation
├── docker-compose.yml # Configuration Docker
└── setup.bat          # Script d'installation
```

---

## 🐛 Troubleshooting

### Flutter n'est pas trouvé
```bash
# Télécharge Flutter : https://flutter.dev/docs/get-started/install/windows
# Ajoute le chemin de Flutter à ton PATH système
```

### Python venv non trouvé
```bash
# Relance le setup.bat pour recréer le venv
setup.bat
```

### Port déjà utilisé
```bash
# Utilise un port différent
cd apps/mobile
flutter run -d chrome --web-port 8085
```

### Docker container ne démarre pas
```bash
# Vérifie que Docker est lancé
# Consulte les logs
docker logs suklu-ai-gateway
```

---

## 📞 Support

Pour plus d'informations :
- 📖 [Documentation Firebase](https://firebase.google.com/docs)
- 🎯 [Documentation Flutter](https://flutter.dev/docs)
- 🐍 [Documentation FastAPI](https://fastapi.tiangolo.com/)
- 🐳 [Documentation Docker](https://docs.docker.com/)
