-- Ekomat — Retire le défaut 'buyer' sur profiles.role
-- Objectif : à l'inscription, le profil n'a plus de rôle imposé, donc l'app
-- affiche l'écran de choix « Ki wòl ou sou Ekomat? » (achtè / vandè). Avant,
-- le défaut 'buyer' + le trigger handle_new_user donnaient role='buyer' à tout
-- nouveau compte, et l'écran de rôle était sauté.
-- Appliqué en prod via MCP le 2026-07-11 (pipeline db-migrate bloqué : secret
-- SUPABASE_DB_PASSWORD périmé). Idempotent, réversible.
-- Comptes existants inchangés ; supabaseSaveRole() écrit le rôle au choix.
alter table public.profiles alter column role drop default;
