# Suklu — Architecture Overview

## 1. System Overview

Suklu is an AI-assisted online tutoring platform for Francophone Africa.
The MVP targets Android (primary), with Web admin and future iOS support.

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (Android / Web Admin)                       │
│  • GoRouter + Riverpod                                   │
│  • Firebase Auth (JWT custom claims for roles)           │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS
          ┌────────────▼────────────┐
          │  Firebase Services       │
          │  • Auth (Auth trigger)   │
          │  • Firestore (RBAC rules)│
          │  • Storage               │
          │  • Cloud Functions (TS)  │
          └────────────┬────────────┘
                       │ HTTP (Firebase ID token)
          ┌────────────▼────────────┐
          │  AI Gateway (Cloud Run)  │
          │  • FastAPI               │
          │  • OpenAI / Gemini LLM   │
          │  • Qdrant vector DB      │
          │  • Safety middleware     │
          └─────────────────────────┘
```

## 2. Role Model

| Role            | Description                              |
|-----------------|------------------------------------------|
| `student`       | End user consuming tutoring & AI chat    |
| `parent`        | Books sessions, monitors child progress  |
| `tutor`         | Delivers sessions, generates quizzes     |
| `academic_staff`| Uploads curriculum, manages tutors       |
| `super_admin`   | Full platform access                     |

Roles are stored as:
- **Firebase custom claims** (`token.role`) — read by Firestore Security Rules with zero extra reads
- **Firestore `/users/{uid}.role`** — read by application code

Role escalation is only possible through a `setUserRole` callable function restricted to `super_admin`.

## 3. Data Model

### `/users/{uid}`
```json
{
  "uid": "...",
  "email": "...",
  "displayName": "...",
  "role": "student | parent | tutor | academic_staff | super_admin",
  "isActive": true,
  "parentIds": [],          // student only: parent UIDs
  "linkedStudentIds": [],   // parent only: child UIDs
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `/bookings/{id}`
Created exclusively by `createBooking` Cloud Function. Never by the client directly.

### `/payments/{id}`
Created exclusively by payment webhook Cloud Functions. Immutable after creation.

### `/ai_logs/{id}`
Written by the AI Gateway service account. Read-only for staff in admin panel.

### `/processed_events/{eventId}`
Idempotency ledger for webhook deduplication. No client access.

## 4. Payment Flow

```
Client → [initiate payment Cloud Function] → Get redirect URL
↓
User completes payment on provider (Flutterwave / Orange Money / Wave)
↓
Provider → POST webhook → Cloud Function
↓
Signature verification → Idempotency check → Firestore transaction
↓
payment doc created + booking.status updated to 'confirmed'
```

**Key principle**: The client never handles money. It only reads resulting payment/booking documents from Firestore.

## 5. AI Gateway Flow (RAG Chat)

```
Client → POST /chat (Firebase ID token) → Safety middleware
↓
Firebase token verification → LLM Client
↓
1. Embed user message (OpenAI / Gemini)
2. Vector search in Qdrant (top-5 curriculum chunks)
3. Inject retrieved context into versioned prompt template
4. LLM call → response
5. Log to /ai_logs (fire-and-forget, never blocks response)
↓
JSON response to client
```

## 6. Curriculum Ingestion Flow

```
Staff uploads PDF/DOCX via admin panel → POST /ingest (auth: staff role)
↓
Text extraction (pypdf / python-docx)
↓
Tiktoken chunking (512 tokens, 64 overlap)
↓
Embed each chunk → upsert to Qdrant with metadata {subject, grade_level, country}
↓
Create /rag_documents/{id} record in Firestore
```

## 7. Security Invariants

| Invariant                              | Enforcement point               |
|----------------------------------------|---------------------------------|
| No secrets in client code              | .gitignore, env vars on servers |
| Payment processing server-side only    | Cloud Functions + Firestore rules |
| All Firestore writes idempotent        | processed_events collection     |
| AI responses logged                    | AI Gateway logging_service      |
| Role boundaries enforced               | Firestore Security Rules        |
| Content safety for minors              | SafetyFilterMiddleware          |
| Firebase ID token on every AI call     | SafetyFilterMiddleware          |

## 8. Development Setup

```bash
cd infrastructure/scripts
chmod +x setup_dev.sh deploy.sh
./setup_dev.sh   # installs deps + starts emulators
```

See `setup_dev.sh` for the full setup sequence.

## 9. Deployment

```bash
./infrastructure/scripts/deploy.sh --all
# or selectively:
./infrastructure/scripts/deploy.sh --functions --rules
./infrastructure/scripts/deploy.sh --ai-gateway
```

## 10. Open Business Logic Questions (TODOs)

- **Pricing engine**: how are session rates calculated? (per-minute, flat-rate, tiered by subject?)
- **Tutor onboarding**: what's the approval flow for new tutors? (document upload, background check?)
- **Parent–child linking**: is it self-service or admin-mediated?
- **Daily.co rooms**: should rooms be persistent (same URL) or ephemeral per booking?
- **Supported countries/currencies**: which XOF countries are in MVP scope?
- **Content moderation escalation**: who reviews flagged content?
