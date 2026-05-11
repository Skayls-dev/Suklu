Les 4 comptes sont créés dans Firebase. Voici le récap :

Rôle	Email	Mot de passe
Étudiant	student@suklu.test	Test1234!
Tuteur	tutor@suklu.test	Test1234!
Parent	parent@suklu.test	Test1234!
Super Admin	admin@suklu.test	Test1234!
Connecte-toi avec n'importe lequel dans Chrome — chaque rôle sera redirigé vers son dashboard correspondant.

✅ AI Gateway en cours d'exécution via Docker!

API: http://localhost:8000
Health: http://localhost:8000/health
LLM Provider: OpenAI (GPT-4o-mini)
Project Firebase: suklu-prod
Docker Compose: depuis la racine du repo, lance `docker compose up -d qdrant ai-gateway`
Ingestion batch fixtures RAG: `cd scripts && npm run ingest:rag-fixtures`
Pour arrêter le container: docker stop suklu-ai-gateway
Pour le relancer: docker start suklu-ai-gateway