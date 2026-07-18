-- Lot konfyans: avatars/bannières vendeur publics + fix upload photos produit.
-- Idempotente.

-- 1) Colonne bannière publique (avatar_url existe déjà et est lue partout).
alter table public.profiles add column if not exists cover_url text;

-- 2) Bucket "Avatar" (existe déjà, public en lecture) : aucune policy INSERT
--    n'existait → tout upload était rejeté par la RLS de storage.objects.
--    Chemin utilisé par le client: {uid}/avatar.jpg et {uid}/cover.jpg.
drop policy if exists avatar_insert_own on storage.objects;
create policy avatar_insert_own on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'Avatar'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists avatar_update_own on storage.objects;
create policy avatar_update_own on storage.objects
    for update to authenticated
    using (
        bucket_id = 'Avatar'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    )
    with check (
        bucket_id = 'Avatar'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists avatar_delete_own on storage.objects;
create policy avatar_delete_own on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'Avatar'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

-- 3) Bucket "product-images" : même trou — aucune policy INSERT/UPDATE, donc
--    l'upload des photos produit échouait EN SILENCE et le client retombait
--    sur le data URL base64 (vérifié en prod: products.images = base64).
--    Chemin utilisé par le client: products/{uid}/{ts}_{i}.jpg.
drop policy if exists product_images_insert_own on storage.objects;
create policy product_images_insert_own on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'product-images'
        and (storage.foldername(name))[1] = 'products'
        and (storage.foldername(name))[2] = (select auth.uid())::text
    );

drop policy if exists product_images_update_own on storage.objects;
create policy product_images_update_own on storage.objects
    for update to authenticated
    using (
        bucket_id = 'product-images'
        and (storage.foldername(name))[1] = 'products'
        and (storage.foldername(name))[2] = (select auth.uid())::text
    )
    with check (
        bucket_id = 'product-images'
        and (storage.foldername(name))[1] = 'products'
        and (storage.foldername(name))[2] = (select auth.uid())::text
    );
