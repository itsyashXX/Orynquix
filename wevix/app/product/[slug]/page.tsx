import Image from "next/image";
import TierPriceCalculator from "@/components/TierPriceCalculator";
import ProductCard from "@/components/ProductCard";

// TEMP mock lookup — replace with:
// const { data: product } = await supabase.from("products").select("*, pricing_tiers(*)").eq("slug", params.slug).single();
function getMockProduct(slug: string) {
  return {
    id: "1",
    slug,
    name: "Oversized Wool Coat",
    description:
      "A tailored oversized wool coat built for retail floors that demand quality at scale. Structured shoulders, deep pockets, and a drape that photographs well online and in-store.",
    fabric: "80% Wool, 20% Polyester blend",
    manufacturing: "Cut and sewn in-house, OEKO-TEX certified facility",
    care: "Dry clean only. Store on padded hangers.",
    images: [
      "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?q=80&w=1200",
      "https://images.unsplash.com/photo-1520975954732-35dd22299614?q=80&w=1200",
      "https://images.unsplash.com/photo-1544022613-e87ca75a784a?q=80&w=1200",
    ],
    retail_price: 89,
    moq: 50,
    sizes: ["XS", "S", "M", "L", "XL"],
    colors: ["Charcoal", "Camel", "Black"],
    tiers: [
      { minQty: 1, maxQty: 50, price: 48 },
      { minQty: 50, maxQty: 200, price: 42 },
      { minQty: 200, maxQty: null, price: 36 },
    ],
    rating: 4.8,
  };
}

const similar = [
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

export default function ProductDetailPage({
  params,
}: {
  params: { slug: string };
}) {
  const product = getMockProduct(params.slug);

  return (
    <div className="max-w-7xl mx-auto px-6 pt-32 pb-24">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
        {/* GALLERY */}
        <div className="space-y-4">
          <div className="relative aspect-[3/4] bg-wevix-beige/30 overflow-hidden">
            <Image
              src={product.images[0]}
              alt={product.name}
              fill
              className="object-cover"
            />
          </div>
          <div className="grid grid-cols-3 gap-4">
            {product.images.map((img, i) => (
              <div
                key={i}
                className="relative aspect-square bg-wevix-beige/30 overflow-hidden cursor-pointer"
              >
                <Image src={img} alt="" fill className="object-cover" />
              </div>
            ))}
          </div>
        </div>

        {/* INFO + PRICING */}
        <div>
          <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-3">
            Wholesale Product
          </p>
          <h1 className="font-display text-3xl md:text-4xl mb-3">
            {product.name}
          </h1>
          <p className="text-sm text-wevix-black/60 dark:text-white/60 mb-6">
            Rating {product.rating} / 5 · Suggested retail ${product.retail_price}
          </p>
          <p className="text-wevix-black/70 dark:text-white/70 leading-relaxed mb-8">
            {product.description}
          </p>

          <TierPriceCalculator
            productId={product.id}
            name={product.name}
            image={product.images[0]}
            moq={product.moq}
            tiers={product.tiers}
            sizes={product.sizes}
            colors={product.colors}
          />

          <div className="mt-8 space-y-3 text-sm">
            <div className="flex gap-2">
              <span className="text-wevix-gold uppercase tracking-widest text-xs w-32 shrink-0">
                Fabric
              </span>
              <span className="text-wevix-black/70 dark:text-white/70">
                {product.fabric}
              </span>
            </div>
            <div className="flex gap-2">
              <span className="text-wevix-gold uppercase tracking-widest text-xs w-32 shrink-0">
                Manufacturing
              </span>
              <span className="text-wevix-black/70 dark:text-white/70">
                {product.manufacturing}
              </span>
            </div>
            <div className="flex gap-2">
              <span className="text-wevix-gold uppercase tracking-widest text-xs w-32 shrink-0">
                Care
              </span>
              <span className="text-wevix-black/70 dark:text-white/70">
                {product.care}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* SIMILAR PRODUCTS */}
      <div className="mt-24">
        <h2 className="font-display text-2xl mb-8">Similar Products</h2>
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-6">
          {similar.map((p) => (
            <ProductCard key={p.id} product={p} />
          ))}
        </div>
      </div>
    </div>
  );
}
