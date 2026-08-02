"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { Heart, Eye } from "lucide-react";

export type Product = {
  id: string;
  name: string;
  image: string;
  wholesale_price: number;
  retail_price: number;
  moq: number;
  in_stock: boolean;
  rating: number;
};

export default function ProductCard({ product }: { product: Product }) {
  return (
    <motion.div
      whileHover={{ y: -6 }}
      transition={{ duration: 0.3 }}
      className="group relative bg-white dark:bg-wevix-charcoal border border-black/5 dark:border-white/5"
    >
      <div className="relative aspect-[3/4] overflow-hidden bg-wevix-beige/30">
        <Image
          src={product.image}
          alt={product.name}
          fill
          className="object-cover transition-transform duration-700 group-hover:scale-110"
        />
        {!product.in_stock && (
          <span className="absolute top-3 left-3 bg-wevix-black text-white text-[10px] uppercase tracking-widest px-2 py-1">
            Out of Stock
          </span>
        )}
        <div className="absolute top-3 right-3 flex flex-col gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button className="w-8 h-8 rounded-full bg-white/90 flex items-center justify-center hover:bg-wevix-gold hover:text-white transition-colors">
            <Heart className="w-4 h-4" />
          </button>
          <button className="w-8 h-8 rounded-full bg-white/90 flex items-center justify-center hover:bg-wevix-gold hover:text-white transition-colors">
            <Eye className="w-4 h-4" />
          </button>
        </div>
      </div>

      <div className="p-4">
        <h3 className="text-sm font-medium truncate">{product.name}</h3>
        <div className="flex items-baseline gap-2 mt-1">
          <span className="text-wevix-gold font-semibold">
            ${product.wholesale_price.toFixed(2)}
          </span>
          <span className="text-xs text-wevix-black/40 dark:text-white/40 line-through">
            ${product.retail_price.toFixed(2)}
          </span>
        </div>
        <p className="text-[11px] uppercase tracking-wide text-wevix-black/50 dark:text-white/50 mt-1">
          MOQ: {product.moq} pcs
        </p>
        <button className="mt-3 w-full py-2 text-xs uppercase tracking-widest border border-wevix-black dark:border-white hover:bg-wevix-black hover:text-white dark:hover:bg-white dark:hover:text-wevix-black transition-all">
          Add to Cart
        </button>
      </div>
    </motion.div>
  );
}
