import Link from "next/link";
import Image from "next/image";
import StatCounter from "@/components/StatCounter";

export default function HomePage() {
  return (
    <div>
      {/* HERO */}
      <section className="relative h-screen w-full flex items-center justify-center overflow-hidden bg-wevix-black">
        <Image
          src="https://images.unsplash.com/photo-1445205170230-053b83016050?q=80&w=2000"
          alt="Wevix wholesale fashion"
          fill
          priority
          className="object-cover opacity-50"
        />
        <div className="relative z-10 text-center px-6 animate-fade-in-up">
          <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-6">
            Wholesale Fashion, Redefined
          </p>
          <h1 className="font-display text-white text-5xl md:text-7xl leading-tight max-w-4xl mx-auto">
            Wevix — The Future Of Wholesale Fashion
          </h1>
          <p className="text-wevix-beige/80 mt-6 max-w-xl mx-auto text-lg">
            Premium Apparel Supply For Businesses Around The World
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mt-10">
            <Link
              href="/shop"
              className="px-8 py-4 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest hover:bg-wevix-gold-light transition-colors"
            >
              Explore Collection
            </Link>
            <Link
              href="/wholesale"
              className="px-8 py-4 border border-white text-white text-xs uppercase tracking-widest hover:bg-white hover:text-wevix-black transition-colors"
            >
              Start Wholesale Partnership
            </Link>
          </div>
        </div>
      </section>

      {/* STATS */}
      <section className="bg-wevix-black text-white py-20">
        <div className="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-10 px-6">
          <StatCounter value={12400} suffix="+" label="Products Available" />
          <StatCounter value={3200} suffix="+" label="Happy Retail Partners" />
          <StatCounter value={48} label="Countries Served" />
          <StatCounter value={98000} suffix="+" label="Orders Delivered" />
        </div>
      </section>

      {/* FEATURED CATEGORIES */}
      <section className="max-w-7xl mx-auto px-6 py-24">
        <div className="text-center mb-14">
          <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-3">
            Curated For Business
          </p>
          <h2 className="font-display text-3xl md:text-4xl">
            Trending Collections
          </h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {[
            {
              title: "Streetwear",
              img: "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?q=80&w=1200",
            },
            {
              title: "Luxury Essentials",
              img: "https://images.unsplash.com/photo-1490114538077-0a7f8cb49891?q=80&w=1200",
            },
            {
              title: "Seasonal Drops",
              img: "https://images.unsplash.com/photo-1552346154-21d32810aba3?q=80&w=1200",
            },
          ].map((c) => (
            <div
              key={c.title}
              className="relative h-96 overflow-hidden group cursor-pointer"
            >
              <Image
                src={c.img}
                alt={c.title}
                fill
                className="object-cover transition-transform duration-700 group-hover:scale-110"
              />
              <div className="absolute inset-0 bg-black/30 flex items-end p-6">
                <h3 className="text-white font-display text-2xl">
                  {c.title}
                </h3>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* TESTIMONIALS */}
      <section className="bg-wevix-beige/40 dark:bg-wevix-charcoal py-24">
        <div className="max-w-5xl mx-auto px-6 text-center">
          <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-3">
            Trusted By Retailers Worldwide
          </p>
          <h2 className="font-display text-3xl md:text-4xl mb-14">
            What Our Partners Say
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                quote:
                  "Wevix transformed how we source inventory. Tier pricing alone cut our costs significantly.",
                name: "Aria Boutique, Dubai",
              },
              {
                quote:
                  "Reliable, premium quality, and fast fulfillment. Our go-to wholesale partner.",
                name: "Nova Retail Group, Singapore",
              },
              {
                quote:
                  "The onboarding was seamless and their support team understands B2B needs.",
                name: "Maison Corp, Paris",
              },
            ].map((t) => (
              <div
                key={t.name}
                className="bg-white dark:bg-wevix-black p-8 shadow-sm"
              >
                <p className="text-sm italic mb-4">&ldquo;{t.quote}&rdquo;</p>
                <p className="text-xs uppercase tracking-widest text-wevix-gold">
                  {t.name}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* NEWSLETTER */}
      <section className="max-w-3xl mx-auto px-6 py-24 text-center">
        <h2 className="font-display text-3xl mb-4">
          Get Exclusive Wholesale Updates
        </h2>
        <p className="text-wevix-black/60 dark:text-white/60 mb-8">
          Be the first to know about new collections, pricing tiers, and
          partner-only drops.
        </p>
        <form className="flex flex-col sm:flex-row gap-4 justify-center">
          <input
            type="email"
            placeholder="Your business email"
            className="px-5 py-3 border border-black/20 dark:border-white/20 bg-transparent flex-1 max-w-sm"
          />
          <button
            type="submit"
            className="px-8 py-3 bg-wevix-black text-white dark:bg-white dark:text-wevix-black text-xs uppercase tracking-widest"
          >
            Subscribe
          </button>
        </form>
      </section>
    </div>
  );
}
