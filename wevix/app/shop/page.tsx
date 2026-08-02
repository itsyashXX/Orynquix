import ProductCard, { Product } from "@/components/ProductCard";

// TEMP mock data — replace with a Supabase query, e.g.
// const { data } = await supabase.from("products").select("*");
const mockProducts: Product[] = [
  {
    id: "1",
    name: "Oversized Wool Coat",
    image:
      "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?q=80&w=800",
    wholesale_price: 42,
    retail_price: 89,
    moq: 50,
    in_stock: true,
    rating: 4.8,
  },
  {
    id: "2",
    name: "Essential Cotton Tee — Bulk Pack",
    image:
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?q=80&w=800",
    wholesale_price: 6,
    retail_price: 19,
    moq: 100,
    in_stock: true,
    rating: 4.6,
  },
  {
    id: "3",
    name: "Tailored Blazer — Charcoal",
    image:
      "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?q=80&w=800",
    wholesale_price: 38,
    retail_price: 95,
    moq: 30,
    in_stock: false,
    rating: 4.9,
  },
  {
    id: "4",
    name: "Streetwear Cargo Pants",
    image:
      "https://images.unsplash.com/photo-1517438476312-10d79c077509?q=80&w=800",
    wholesale_price: 18,
    retail_price: 49,
    moq: 60,
    in_stock: true,
    rating: 4.5,
  },
];

const filters = [
  "Men's",
  "Women's",
  "Kids",
  "Streetwear",
  "Luxury",
  "Casual",
  "Trending",
];

export default function ShopPage() {
  return (
    <div className="max-w-7xl mx-auto px-6 pt-32 pb-24">
      <div className="mb-10">
        <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-3">
          Marketplace
        </p>
        <h1 className="font-display text-4xl">Shop The Collection</h1>
      </div>

      <div className="flex flex-col md:flex-row gap-10">
        {/* SIDEBAR FILTERS */}
        <aside className="md:w-64 shrink-0 space-y-8">
          <div>
            <input
              type="text"
              placeholder="Search products..."
              className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent text-sm"
            />
          </div>

          <div>
            <h3 className="text-xs uppercase tracking-widest text-wevix-gold mb-3">
              Category
            </h3>
            <div className="space-y-2 text-sm">
              {filters.map((f) => (
                <label key={f} className="flex items-center gap-2">
                  <input type="checkbox" className="accent-wevix-gold" />
                  {f}
                </label>
              ))}
            </div>
          </div>

          <div>
            <h3 className="text-xs uppercase tracking-widest text-wevix-gold mb-3">
              Price Range
            </h3>
            <input type="range" min={0} max={200} className="w-full accent-wevix-gold" />
          </div>

          <div>
            <h3 className="text-xs uppercase tracking-widest text-wevix-gold mb-3">
              MOQ
            </h3>
            <select className="w-full px-3 py-2 border border-black/10 dark:border-white/10 bg-transparent text-sm">
              <option>Any</option>
              <option>Under 50</option>
              <option>50–100</option>
              <option>100+</option>
            </select>
          </div>
        </aside>

        {/* PRODUCT GRID */}
        <div className="flex-1">
          <div className="flex items-center justify-between mb-6">
            <p className="text-sm text-wevix-black/60 dark:text-white/60">
              {mockProducts.length} products
            </p>
            <select className="px-3 py-2 border border-black/10 dark:border-white/10 bg-transparent text-sm">
              <option>Sort: Newest</option>
              <option>Price: Low to High</option>
              <option>Price: High to Low</option>
              <option>Best Rated</option>
            </select>
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-3 gap-6">
            {mockProducts.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
