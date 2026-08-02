"use client";

import { useMemo, useState } from "react";
import { useCart } from "@/context/CartContext";

export type PricingTier = { minQty: number; maxQty: number | null; price: number };

export default function TierPriceCalculator({
  productId,
  name,
  image,
  moq,
  tiers,
  sizes,
  colors,
}: {
  productId: string;
  name: string;
  image: string;
  moq: number;
  tiers: PricingTier[];
  sizes: string[];
  colors: string[];
}) {
  const [quantity, setQuantity] = useState(moq);
  const [size, setSize] = useState(sizes[0] ?? "");
  const [color, setColor] = useState(colors[0] ?? "");
  const { addItem } = useCart();
  const [added, setAdded] = useState(false);

  const activeTier = useMemo(() => {
    return (
      tiers.find(
        (t) => quantity >= t.minQty && (t.maxQty === null || quantity <= t.maxQty)
      ) ?? tiers[tiers.length - 1]
    );
  }, [quantity, tiers]);

  const total = activeTier.price * quantity;

  const handleAdd = () => {
    addItem({
      id: `${productId}-${size}-${color}-${Date.now()}`,
      productId,
      name,
      image,
      unitPrice: activeTier.price,
      quantity,
      size,
      color,
    });
    setAdded(true);
    setTimeout(() => setAdded(false), 2000);
  };

  return (
    <div className="border border-black/10 dark:border-white/10 p-6 space-y-6">
      {/* Tier table */}
      <div>
        <h3 className="text-xs uppercase tracking-widest text-wevix-gold mb-3">
          Wholesale Pricing Tiers
        </h3>
        <table className="w-full text-sm">
          <tbody>
            {tiers.map((t, idx) => (
              <tr
                key={idx}
                className={`border-t border-black/5 dark:border-white/5 ${
                  t === activeTier ? "text-wevix-gold font-medium" : ""
                }`}
              >
                <td className="py-2">
                  {t.minQty}
                  {t.maxQty ? `–${t.maxQty}` : "+"} pieces
                </td>
                <td className="py-2 text-right">${t.price.toFixed(2)} / pc</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Size / color */}
      {sizes.length > 0 && (
        <div>
          <label className="text-xs uppercase tracking-widest text-wevix-gold mb-2 block">
            Size
          </label>
          <div className="flex gap-2 flex-wrap">
            {sizes.map((s) => (
              <button
                key={s}
                onClick={() => setSize(s)}
                className={`px-3 py-1.5 text-sm border ${
                  size === s
                    ? "border-wevix-gold bg-wevix-gold text-wevix-black"
                    : "border-black/20 dark:border-white/20"
                }`}
              >
                {s}
              </button>
            ))}
          </div>
        </div>
      )}

      {colors.length > 0 && (
        <div>
          <label className="text-xs uppercase tracking-widest text-wevix-gold mb-2 block">
            Color
          </label>
          <div className="flex gap-2 flex-wrap">
            {colors.map((c) => (
              <button
                key={c}
                onClick={() => setColor(c)}
                className={`px-3 py-1.5 text-sm border ${
                  color === c
                    ? "border-wevix-gold bg-wevix-gold text-wevix-black"
                    : "border-black/20 dark:border-white/20"
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Quantity */}
      <div>
        <label className="text-xs uppercase tracking-widest text-wevix-gold mb-2 block">
          Quantity (MOQ {moq})
        </label>
        <input
          type="number"
          min={moq}
          value={quantity}
          onChange={(e) => setQuantity(Math.max(moq, Number(e.target.value)))}
          className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
        />
      </div>

      {/* Total */}
      <div className="flex items-center justify-between pt-4 border-t border-black/10 dark:border-white/10">
        <span className="text-sm text-wevix-black/60 dark:text-white/60">
          Estimated Total
        </span>
        <span className="font-display text-2xl text-wevix-gold">
          ${total.toFixed(2)}
        </span>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <button
          onClick={handleAdd}
          className="py-3 bg-wevix-black text-white dark:bg-white dark:text-wevix-black text-xs uppercase tracking-widest hover:opacity-90 transition-opacity"
        >
          {added ? "Added ✓" : "Add To Cart"}
        </button>
        <button className="py-3 border border-wevix-gold text-wevix-gold text-xs uppercase tracking-widest hover:bg-wevix-gold hover:text-wevix-black transition-colors">
          Request Quotation
        </button>
      </div>
    </div>
  );
}
