-- HazeFix — Supabase şeması
-- Bu dosya veritabanının GERÇEK hâlini yansıtır (2026-09-02 itibarıyla doğrulandı).
-- Tamamen idempotent: kaç kere çalıştırılırsa çalıştırılsın hata vermez, çift
-- policy/constraint üretmez.
--
-- Çalıştırmak için:  psql service=hazefix -f supabase-schema.sql
--
-- Sütun adları Türkçe olduğu için her yerde çift tırnak zorunlu: "İsim",
-- "Görsel Konumu" vb. Tırnaksız yazılırsa Postgres küçük harfe indirger ve
-- sütunu bulamaz. JS tarafındaki insert() anahtarları da birebir aynı olmalı.

-- ---------------------------------------------------------------
-- 1. reviews tablosu
-- ---------------------------------------------------------------

create table if not exists public.reviews (
  id                uuid        primary key default gen_random_uuid(),
  "İsim"            text        not null,
  "Puan"            smallint    not null,
  "Yorum"           text        not null,
  "Görsel Konumu"   text,
  "Onay"            boolean     not null default false,
  "Yorum Tarihi"    timestamptz not null default now(),
  "Hizmet"          text
);

-- Kontroller. Adlar veritabanındakiyle birebir aynı tutuluyor ki
-- drop/create çifti gerçekten eskisini bulup değiştirsin.
alter table public.reviews drop constraint if exists reviews_rating_check;
alter table public.reviews add  constraint reviews_rating_check
  check ("Puan" >= 1 and "Puan" <= 5);

alter table public.reviews drop constraint if exists reviews_first_name_check;
alter table public.reviews add  constraint reviews_first_name_check
  check (char_length("İsim") >= 1 and char_length("İsim") <= 80);

alter table public.reviews drop constraint if exists reviews_review_text_check;
alter table public.reviews add  constraint reviews_review_text_check
  check (char_length("Yorum") >= 1 and char_length("Yorum") <= 2000);

-- Onaylı yorumları tarihe göre listelemek için kısmi index.
create index if not exists reviews_onayli_tarih_idx
  on public.reviews ("Yorum Tarihi" desc)
  where "Onay";

-- ---------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------

alter table public.reviews enable row level security;

-- Eski adlarla kurulmuş policy'ler (ilk kurulumdan kalma) — temizlenir ki
-- aynı davranışa sahip iki permissive policy yan yana durmasın.
drop policy if exists "public can insert reviews"        on public.reviews;
drop policy if exists "public can read approved reviews" on public.reviews;

-- anon SADECE onaylanmamış satır ekleyebilir (kendi yorumunu onaylayamaz)
drop policy if exists "anon can insert unapproved reviews" on public.reviews;
create policy "anon can insert unapproved reviews"
  on public.reviews for insert to anon
  with check ("Onay" = false);

-- anon SADECE onaylanmış satırları okuyabilir
drop policy if exists "anon can read approved reviews" on public.reviews;
create policy "anon can read approved reviews"
  on public.reviews for select to anon
  using ("Onay" = true);

-- UPDATE / DELETE policy'si bilinçli olarak YOK — anon güncelleyemez, silemez.
-- Onaylama işlemi Table Editor'den (service_role ile) yapılır.

-- Data API'de "Automatically expose new tables" kapalı olduğu için grant elle gerekli.
grant usage on schema public to anon;
grant select, insert on public.reviews to anon;

-- ---------------------------------------------------------------
-- 3. Storage: review-images bucket
-- ---------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'review-images',
  'review-images',
  true,
  5242880,                                                     -- 5 MB
  array['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- İlk kurulumdan kalma eski adlar
drop policy if exists "public can upload review images" on storage.objects;
drop policy if exists "public can view review images"   on storage.objects;

drop policy if exists "anon can upload review images" on storage.objects;
create policy "anon can upload review images"
  on storage.objects for insert to anon
  with check (bucket_id = 'review-images');

drop policy if exists "public can read review images" on storage.objects;
create policy "public can read review images"
  on storage.objects for select to public
  using (bucket_id = 'review-images');

notify pgrst, 'reload schema';
