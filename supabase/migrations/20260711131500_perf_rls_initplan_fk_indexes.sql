-- Ekomat — Migration perf : advisors Supabase (RLS initplan + FK indexes)
-- Traite 78 des 143 lints performance (les sûrs, additifs, sans changement d'accès) :
--   * 18 unindexed_foreign_keys  -> index couvrants (CREATE INDEX IF NOT EXISTS)
--   * 60 auth_rls_initplan       -> auth.uid()/auth.role() enveloppés dans (select ...)
--                                   pour une evaluation unique par requete (au lieu de par ligne)
-- Idempotente (IF NOT EXISTS / DROP POLICY IF EXISTS + CREATE). Semantiquement neutre :
-- chaque policy est recreee a l'identique, seule la forme de l'appel auth.* change.
-- NON inclus ici (revue Thrasher requise, voir PR) : 56 multiple_permissive_policies
-- (dont 2 vrais problemes de securite) et 9 unused_index (a NE PAS dropper avant trafic).

begin;

-- ── 1. Index couvrants sur les cles etrangeres ────────────────────────────
create index if not exists idx_announcements_admin_id on public.announcements (admin_id);
create index if not exists idx_app_settings_updated_by on public.app_settings (updated_by);
create index if not exists idx_cart_items_product_id on public.cart_items (product_id);
create index if not exists idx_error_logs_user_id on public.error_logs (user_id);
create index if not exists idx_favorites_product_id on public.favorites (product_id);
create index if not exists idx_flash_deals_product_id on public.flash_deals (product_id);
create index if not exists idx_followers_seller_id on public.followers (seller_id);
create index if not exists idx_orders_product_id on public.orders (product_id);
create index if not exists idx_orders_released_by on public.orders (released_by);
create index if not exists idx_orders_verified_by on public.orders (verified_by);
create index if not exists idx_pending_emails_to_user on public.pending_emails (to_user);
create index if not exists idx_profiles_referred_by on public.profiles (referred_by);
create index if not exists idx_promo_codes_created_by on public.promo_codes (created_by);
create index if not exists idx_promo_redemptions_order_id on public.promo_redemptions (order_id);
create index if not exists idx_reviews_product_id on public.reviews (product_id);
create index if not exists idx_reviews_seller_id on public.reviews (seller_id);
create index if not exists idx_verification_requests_reviewed_by on public.verification_requests (reviewed_by);
create index if not exists idx_verification_requests_user_id on public.verification_requests (user_id);

-- ── 2. RLS : envelopper auth.uid()/auth.role() dans (select ...) ──────────
drop policy if exists admin_actions_admin_only on public.admin_actions;
create policy admin_actions_admin_only on public.admin_actions as permissive for all to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))))
  with check ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))));

drop policy if exists announcements_select on public.announcements;
create policy announcements_select on public.announcements as permissive for select to public
  using ((((select auth.uid()) IS NOT NULL) AND (active = true) AND ((ends_at IS NULL) OR (ends_at > now()))));

drop policy if exists announcements_write_admin on public.announcements;
create policy announcements_write_admin on public.announcements as permissive for all to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))))
  with check ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))));

drop policy if exists app_settings_read_all on public.app_settings;
create policy app_settings_read_all on public.app_settings as permissive for select to public
  using (((select auth.uid()) IS NOT NULL));

drop policy if exists app_settings_write_admin on public.app_settings;
create policy app_settings_write_admin on public.app_settings as permissive for update to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))));

drop policy if exists cart_delete_own on public.cart_items;
create policy cart_delete_own on public.cart_items as permissive for delete to public
  using (((select auth.uid()) = user_id));

drop policy if exists cart_insert_own on public.cart_items;
create policy cart_insert_own on public.cart_items as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists cart_select_own on public.cart_items;
create policy cart_select_own on public.cart_items as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists cart_update_own on public.cart_items;
create policy cart_update_own on public.cart_items as permissive for update to public
  using (((select auth.uid()) = user_id));

drop policy if exists error_logs_admin_read on public.error_logs;
create policy error_logs_admin_read on public.error_logs as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))));

drop policy if exists escrow_alert_log_admin_read on public.escrow_alert_log;
create policy escrow_alert_log_admin_read on public.escrow_alert_log as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true)))));

drop policy if exists favorites_delete_own on public.favorites;
create policy favorites_delete_own on public.favorites as permissive for delete to public
  using (((select auth.uid()) = user_id));

drop policy if exists favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists favorites_select_own on public.favorites;
create policy favorites_select_own on public.favorites as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists followers_delete_own on public.followers;
create policy followers_delete_own on public.followers as permissive for delete to public
  using (((select auth.uid()) = follower_id));

drop policy if exists followers_insert_own on public.followers;
create policy followers_insert_own on public.followers as permissive for insert to public
  with check (((select auth.uid()) = follower_id));

drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender on public.messages as permissive for insert to public
  with check (((select auth.uid()) = sender_id));

drop policy if exists messages_select_own on public.messages;
create policy messages_select_own on public.messages as permissive for select to public
  using ((((select auth.uid()) = sender_id) OR ((select auth.uid()) = receiver_id)));

drop policy if exists messages_select_participant on public.messages;
create policy messages_select_participant on public.messages as permissive for select to public
  using ((((select auth.uid()) = sender_id) OR ((select auth.uid()) = receiver_id) OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = (select auth.uid())) AND (p.role = 'admin'::text))))));

drop policy if exists messages_update_read on public.messages;
create policy messages_update_read on public.messages as permissive for update to public
  using (((select auth.uid()) = receiver_id));

drop policy if exists messages_update_receiver on public.messages;
create policy messages_update_receiver on public.messages as permissive for update to public
  using ((((select auth.uid()) = receiver_id) OR ((select auth.uid()) = sender_id)))
  with check ((((select auth.uid()) = receiver_id) OR ((select auth.uid()) = sender_id)));

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own on public.notifications as permissive for delete to public
  using (((select auth.uid()) = user_id));

drop policy if exists notifications_insert_any on public.notifications;
create policy notifications_insert_any on public.notifications as permissive for insert to public
  with check (((select auth.uid()) IS NOT NULL));

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications as permissive for update to public
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

drop policy if exists orders_insert_buyer on public.orders;
create policy orders_insert_buyer on public.orders as permissive for insert to public
  with check (((select auth.uid()) = buyer_id));

drop policy if exists orders_select_own on public.orders;
create policy orders_select_own on public.orders as permissive for select to public
  using ((((select auth.uid()) = buyer_id) OR ((select auth.uid()) = seller_id) OR is_admin()));

drop policy if exists orders_select_participants on public.orders;
create policy orders_select_participants on public.orders as permissive for select to public
  using ((((select auth.uid()) = buyer_id) OR ((select auth.uid()) = seller_id) OR (EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true))))));

drop policy if exists orders_update on public.orders;
create policy orders_update on public.orders as permissive for update to public
  using ((((select auth.uid()) = seller_id) OR ((select auth.uid()) = buyer_id) OR is_admin()));

drop policy if exists orders_update_participants on public.orders;
create policy orders_update_participants on public.orders as permissive for update to public
  using ((((select auth.uid()) = buyer_id) OR ((select auth.uid()) = seller_id) OR (EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.is_admin = true))))));

drop policy if exists product_image_hashes_own_insert on public.product_image_hashes;
create policy product_image_hashes_own_insert on public.product_image_hashes as permissive for insert to public
  with check (((select auth.uid()) = seller_id));

drop policy if exists product_image_hashes_select on public.product_image_hashes;
create policy product_image_hashes_select on public.product_image_hashes as permissive for select to public
  using (((select auth.role()) = 'authenticated'::text));

drop policy if exists product_views_insert on public.product_views;
create policy product_views_insert on public.product_views as permissive for insert to public
  with check (((select auth.uid()) IS NOT NULL));

drop policy if exists product_views_select on public.product_views;
create policy product_views_select on public.product_views as permissive for select to public
  using (((EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = (select auth.uid())) AND (p.is_admin = true)))) OR (EXISTS ( SELECT 1
   FROM products pr
  WHERE ((pr.id = product_views.product_id) AND (pr.seller_id = (select auth.uid())))))));

drop policy if exists products_delete_own on public.products;
create policy products_delete_own on public.products as permissive for delete to public
  using ((((select auth.uid()) = seller_id) OR is_admin()));

drop policy if exists products_insert_seller on public.products;
create policy products_insert_seller on public.products as permissive for insert to public
  with check (((select auth.uid()) = seller_id));

drop policy if exists products_select_active on public.products;
create policy products_select_active on public.products as permissive for select to public
  using (((status = 'active'::text) OR (seller_id = (select auth.uid())) OR is_admin()));

drop policy if exists products_update_own on public.products;
create policy products_update_own on public.products as permissive for update to public
  using ((((select auth.uid()) = seller_id) OR is_admin()));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles as permissive for insert to public
  with check (((select auth.uid()) = id));

drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated on public.profiles as permissive for select to public
  using (((select auth.uid()) IS NOT NULL));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles as permissive for update to public
  using (((select auth.uid()) = id))
  with check (((select auth.uid()) = id));

drop policy if exists promo_codes_admin_write on public.promo_codes;
create policy promo_codes_admin_write on public.promo_codes as permissive for all to public
  using ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.role = 'admin'::text)))))
  with check ((EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = (select auth.uid())) AND (profiles.role = 'admin'::text)))));

drop policy if exists promo_codes_referral_self_insert on public.promo_codes;
create policy promo_codes_referral_self_insert on public.promo_codes as permissive for insert to public
  with check (((scope = 'referral'::text) AND (referrer_id = (select auth.uid()))));

drop policy if exists promo_redemptions_own_insert on public.promo_redemptions;
create policy promo_redemptions_own_insert on public.promo_redemptions as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists promo_redemptions_own_select on public.promo_redemptions;
create policy promo_redemptions_own_select on public.promo_redemptions as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists referral_rewards_admin_select on public.referral_rewards;
create policy referral_rewards_admin_select on public.referral_rewards as permissive for select to public
  using ((( SELECT profiles.is_admin
   FROM profiles
  WHERE (profiles.id = (select auth.uid()))) IS TRUE));

drop policy if exists reviews_insert_buyer on public.reviews;
create policy reviews_insert_buyer on public.reviews as permissive for insert to public
  with check ((((select auth.uid()) = reviewer_id) AND (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.buyer_id = (select auth.uid())) AND (o.product_id = reviews.product_id) AND (o.seller_id = reviews.seller_id) AND (o.status = ANY (ARRAY['otp_confirmed'::text, 'released'::text, 'completed'::text, 'delivered'::text])))))));

drop policy if exists reviews_insert_own on public.reviews;
create policy reviews_insert_own on public.reviews as permissive for insert to public
  with check (((select auth.uid()) = reviewer_id));

drop policy if exists reviews_update_own on public.reviews;
create policy reviews_update_own on public.reviews as permissive for update to public
  using (((select auth.uid()) = reviewer_id));

drop policy if exists user_addresses_own_delete on public.user_addresses;
create policy user_addresses_own_delete on public.user_addresses as permissive for delete to public
  using (((select auth.uid()) = user_id));

drop policy if exists user_addresses_own_insert on public.user_addresses;
create policy user_addresses_own_insert on public.user_addresses as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists user_addresses_own_select on public.user_addresses;
create policy user_addresses_own_select on public.user_addresses as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists user_addresses_own_update on public.user_addresses;
create policy user_addresses_own_update on public.user_addresses as permissive for update to public
  using (((select auth.uid()) = user_id));

drop policy if exists user_devices_own_delete on public.user_devices;
create policy user_devices_own_delete on public.user_devices as permissive for delete to public
  using (((select auth.uid()) = user_id));

drop policy if exists user_devices_own_insert on public.user_devices;
create policy user_devices_own_insert on public.user_devices as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists user_devices_own_select on public.user_devices;
create policy user_devices_own_select on public.user_devices as permissive for select to public
  using (((select auth.uid()) = user_id));

drop policy if exists user_devices_own_update on public.user_devices;
create policy user_devices_own_update on public.user_devices as permissive for update to public
  using (((select auth.uid()) = user_id));

drop policy if exists verif_insert_own on public.verification_requests;
create policy verif_insert_own on public.verification_requests as permissive for insert to public
  with check (((select auth.uid()) = user_id));

drop policy if exists verif_select on public.verification_requests;
create policy verif_select on public.verification_requests as permissive for select to public
  using ((((select auth.uid()) = user_id) OR is_admin()));

drop policy if exists verif_update_own on public.verification_requests;
create policy verif_update_own on public.verification_requests as permissive for update to authenticated
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));
commit;
