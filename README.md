# Wevix — Full Build

Premium B2B wholesale fashion marketplace, built on Next.js 14 (App Router), TypeScript, Tailwind, and Supabase.

## What's fully wired (real logic, no external keys needed)

- **Design system** — colors, fonts, animations (`tailwind.config.ts`, `globals.css`)
- **Homepage** — hero, animated stats, collections, testimonials, newsletter
- **Shop/marketplace** — filters, product grid (mock data — swap for a Supabase query)
- **Product detail page** — image gallery, tier pricing calculator (live quantity → price → total), size/color selection, add to cart
- **Cart** — persisted client-side (localStorage), editable quantities, shipping/tax estimate
- **Checkout** — writes real orders + order_items to Supabase, payment method selector
- **Auth** — signup (personal/business account types), login (password, email OTP, Google OAuth) via Supabase
- **Customer dashboard** — overview, orders (live from Supabase), invoices, wishlist (schema ready), support ticket form
- **Admin dashboard** — analytics (revenue/orders/customers from real queries), product management, order management with status updates, customer management + wholesale application approval, marketing (coupons/banners/campaigns UI)
- **Database schema** (`supabase/schema.sql`) — profiles, products, pricing_tiers, cart_items, wishlist_items, orders, order_items, partner_applications, coupons, full RLS policies

## What needs your own API keys/credentials to go fully live

These can't be functionally activated without you creating accounts and getting keys — I've left clear TODO comments at each spot:

| Feature | Where | What you need |
|---|---|---|
| Online payment (card/UPI) | `app/checkout/page.tsx` | Razorpay or Stripe account + keys |
| Live chat | `app/dashboard/support/page.tsx` | Intercom/Crisp account, or build on Socket.IO |
| WhatsApp notifications | not yet scaffolded | WhatsApp Business API / Twilio |
| Email campaigns | `app/admin/marketing/page.tsx` | Resend API (you already use this for Himluxe) |
| AI product recommendations / chatbot | not yet scaffolded | Anthropic or OpenAI API key |
| PDF invoice generation | `app/dashboard/invoices/page.tsx` | A PDF library (e.g. `@react-pdf/renderer`) wired to a route handler |
| Push notifications | not yet scaffolded | Web Push / Firebase Cloud Messaging |
| SMS/phone OTP verification | not yet scaffolded | Twilio Verify (Supabase email OTP is already live) |

Send me the key names once you have them (never the key values in chat) and I'll wire the integration code.

## Setup on Termux (phone-only workflow)

```bash
cd ~/storage/downloads
unzip wevix.zip
cd wevix

npm install

cp .env.example .env.local
nano .env.local   # add your Supabase URL + anon key

npm run dev
```

## Supabase setup

1. Create a project at supabase.com
2. SQL editor → run `supabase/schema.sql`
3. Copy Project URL + anon key into `.env.local`
4. To make yourself an admin: after signing up, run in the SQL editor:
   ```sql
   update public.profiles set is_admin = true where id = 'your-user-id';
   ```
   (find your user id in Authentication → Users)
5. Enable Google OAuth: Authentication → Providers → Google, add your OAuth client ID/secret

## Deploying

```bash
git init
git add .
git commit -m "Wevix full build"
git remote add origin https://github.com/itsyashXX/wevix.git
git push -u origin main
```

Import into Vercel, add the two env vars in project settings, deploy.

## Route map

- `/` — homepage
- `/shop` — marketplace
- `/product/[slug]` — product detail
- `/cart`, `/checkout` — purchase flow
- `/login`, `/signup` — auth
- `/dashboard`, `/dashboard/orders`, `/dashboard/invoices`, `/dashboard/wishlist`, `/dashboard/support` — customer area
- `/admin`, `/admin/products`, `/admin/orders`, `/admin/customers`, `/admin/marketing` — admin area (requires `is_admin = true`)
- `/about`, `/wholesale` — marketing pages
