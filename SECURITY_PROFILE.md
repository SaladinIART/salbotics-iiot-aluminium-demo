---
project_name: "salbotics iiot stack"
owner: "Solehuddin"
visibility_intent: "planned_public"
security_mode: "public"
secret_storage_location: "Use the central solehuddin-security-safe repo only"
rotation_policy: "public_secret"
notes: "Update this profile before repo visibility changes."
---

# Security Profile

This repo is protected by Solehuddin Security Safe.

## Operating rules

- Do not commit raw secrets.
- Use the central security-safe repo for secret generation and tracking.
- Keep `visibility_intent` current if the repo moves from private to public.
- Treat hook blocks as real security feedback.

