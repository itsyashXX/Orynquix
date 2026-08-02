-- ============================================================
-- WEVIX — Phase 1 Database Schema
-- Run this in the Supabase SQL editor
-- ============================================================

-- Extend the default auth.users with business profile info
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  full_name text,
  account_type text check (account_type in ('personal', 'business')) default 'personal',
  company_name text,
  business_type text,
  phone text,
  country text,
  monthly_purchase_volume text,
  is_verified_retailer boolean default false,
  is_admin boolean default false,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- ============================================================
-- PRODUCTS
-- ============================================================
create table if not exists public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  slug text unique not null,
  description text,
  category text,
  fabric text,
  images text[] default '{}',
  retail_price numeric(10,2) not null,
  moq integer not null default 1,
  in_stock boolean default true,
  stock_quantity integer default 0,
  sizes text[] default '{}',
  colors text[] default '{}',
  rating numeric(2,1) default 0,
  created_at timestamptz default now()
);

alter table public.products enable row level security;

create policy "Products are publicly viewable"
  on public.products for select
  using (true);

-- ============================================================
-- WHOLESALE PRICING TIERS (per product, quantity-based)
-- Example: 1-50 = Price A, 50-200 = Price B, 200+ = Price C
-- ============================================================
create table if not exists public.pricing_tiers (
  id uuid default gen_random_uuid() primary key,
  product_id uuid references public.products(id) on delete cascade not null,
  min_qty integer not null,
  max_qty integer, -- null = no upper bound
  price numeric(10,2) not null
);

alter table public.pricing_tiers enable row level security;

create policy "Pricing tiers are publicly viewable"
  on public.pricing_tiers for select
  using (true);

-- ============================================================
-- CART
-- ============================================================
create table if not exists public.cart_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  product_id uuid references public.products(id) on delete cascade not null,
  quantity integer not null default 1,
  size text,
  color text,
  created_at timestamptz default now()
);

alter table public.cart_items enable row level security;

create policy "Users manage own cart"
  on public.cart_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- WISHLIST
-- ============================================================
create table if not exists public.wishlist_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  product_id uuid references public.products(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique (user_id, product_id)
);

alter table public.wishlist_items enable row level security;

create policy "Users manage own wishlist"
  on public.wishlist_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- ORDERS
-- ============================================================
create table if not exists public.orders (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  status text check (status in ('pending','confirmed','shipped','delivered','cancelled')) default 'pending',
  subtotal numeric(10,2) not null,
  tax numeric(10,2) default 0,
  shipping numeric(10,2) default 0,
  total numeric(10,2) not null,
  payment_method text check (payment_method in ('online','bank_transfer','invoice','cod')),
  shipping_address jsonb,
  tracking_number text,
  created_at timestamptz default now()
);

alter table public.orders enable row level security;

create policy "Users view own orders"
  on public.orders for select
  using (auth.uid() = user_id);

create policy "Users create own orders"
  on public.orders for insert
  with check (auth.uid() = user_id);

create table if not exists public.order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  product_id uuid references public.products(id) not null,
  quantity integer not null,
  unit_price numeric(10,2) not null,
  size text,
  color text
);

alter table public.order_items enable row level security;

create policy "Users view own order items"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
      and orders.user_id = auth.uid()
    )
  );

-- ============================================================
-- WHOLESALE PARTNER APPLICATIONS
-- ============================================================
create table if not exists public.partner_applications (
  id uuid default gen_random_uuid() primary key,
  full_name text not null,
  company_name text not null,
  business_type text,
  phone text,
  email text not null,
  country text,
  monthly_purchase_volume text,
  product_interest text,
  status text check (status in ('pending','approved','rejected')) default 'pending',
  created_at timestamptz default now()
);

alter table public.partner_applications enable row level security;

create policy "Anyone can submit a partner application"
  on public.partner_applications for insert
  with check (true);

-- ============================================================
-- COUPONS
-- ============================================================
create table if not exists public.coupons (
  id uuid default gen_random_uuid() primary key,
  code text unique not null,
  discount_type text check (discount_type in ('percent','fixed')) default 'percent',
  discount_value numeric(10,2) not null,
  active boolean default true,
  expires_at timestamptz,
  created_at timestamptz default now()
);

alter table public.coupons enable row level security;

create policy "Active coupons are publicly viewable"
  on public.coupons for select
  using (active = true);

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_products_category on public.products(category);
create index if not exists idx_pricing_tiers_product on public.pricing_tiers(product_id);
create index if not exists idx_orders_user on public.orders(user_id);
create index if not exists idx_cart_items_user on public.cart_items(user_id);
