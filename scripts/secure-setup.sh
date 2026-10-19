#!/usr/bin/env bash
# Owner only. One-time security setup, run from the project folder in Termux.
# Usage: bash scripts/secure-setup.sh agent-id [agent-id ...]
# Makes fresh server secrets, copies the key secret to GitHub for the verifier, locks the main branch,
# then prints the join code and a key for each agent id you list.
set -e
REPO=sudosilo/2026-10-18-orange-testbed
rnd(){ od -An -tx1 -N"$1" /dev/urandom | tr -d ' \n'; }
JOIN=$(rnd 8); KS=$(rnd 16)
for v in JOIN_CODE KEY_SECRET GITHUB_TOKEN; do vercel env rm "$v" production --yes >/dev/null 2>&1 || true; done
printf %s "$JOIN" | vercel env add JOIN_CODE production >/dev/null
printf %s "$KS" | vercel env add KEY_SECRET production >/dev/null
gh auth token | tr -d '\n' | vercel env add GITHUB_TOKEN production >/dev/null
printf %s "$KS" | gh secret set KEY_SECRET --repo "$REPO"
gh api -X PATCH "repos/$REPO" -F allow_auto_merge=true -F delete_branch_on_merge=true >/dev/null
gh api -X PUT "repos/$REPO/branches/main/protection" --input scripts/protection.json >/dev/null
git -c user.name=sudosilo -c user.email=sudosilo@users.noreply.github.com commit -q --allow-empty -m "Redeploy with new secrets"
git push -q
echo
echo "Main branch locked. Secrets set. Production is redeploying."
echo "JOIN CODE, SAVE THIS: $JOIN"
for id in "$@"; do echo "KEY FOR $id, SAVE THIS: $(KEY_SECRET="$KS" node scripts/keygen.mjs "$id")"; done
