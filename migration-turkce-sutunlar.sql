-- HazeFix — reviews sütunlarını Türkçe adlara geçir
-- Supabase Dashboard -> SQL Editor -> yapıştır -> Run.
--
-- Idempotent: bir sütun zaten yeni adını almışsa (örn. Table Editor'den elle
-- "Onay" yapılan is_approved) o satır atlanır. Kaç kere çalıştırılırsa
-- çalıştırılsın hata vermez, veri kaybı olmaz.
--
-- ÖNEMLİ: Bunu çalıştırmadan ÖNCE index.html'i güncellemeyin; yeni index.html
-- yalnızca yeni sütun adlarıyla çalışır. Sıra: bu SQL -> sonra index.html.

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('first_name',  'İsim'),
      ('service',     'Hizmet'),
      ('rating',      'Puan'),
      ('review_text', 'Yorum'),
      ('image_path',  'Görsel Konumu'),
      ('is_approved', 'Onay'),
      ('created_at',  'Yorum Tarihi')
    ) as t(eski, yeni)
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name   = 'reviews'
        and column_name  = r.eski
    ) and not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name   = 'reviews'
        and column_name  = r.yeni
    ) then
      execute format('alter table public.reviews rename column %I to %I', r.eski, r.yeni);
      raise notice 'yeniden adlandırıldı: % -> %', r.eski, r.yeni;
    end if;
  end loop;
end $$;

-- Postgres, sütun adı değişince policy/index/constraint ifadelerini kendisi
-- günceller. Yine de policy'leri yeni adla açıkça yeniden kuruyoruz ki
-- şema dosyası ile veritabanı birebir aynı olsun.

alter table public.reviews enable row level security;

drop policy if exists "anon can insert unapproved reviews" on public.reviews;
create policy "anon can insert unapproved reviews"
  on public.reviews for insert to anon
  with check ("Onay" = false);

drop policy if exists "anon can read approved reviews" on public.reviews;
create policy "anon can read approved reviews"
  on public.reviews for select to anon
  using ("Onay" = true);

-- UPDATE / DELETE policy'si bilinçli olarak YOK.

grant usage on schema public to anon;
grant select, insert on public.reviews to anon;

-- PostgREST şema önbelleğini tazele — yeni sütun adları hemen görünsün.
notify pgrst, 'reload schema';
