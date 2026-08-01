"use client";

import Image from "next/image";
import Link from "next/link";
import { useCart } from "@/context/CartContext";
import { Trash2 } from "lucide-react";

export default function CartPage() {
  const { items, updateQuantity, removeItem, subtotal } = useCart();
  const shipping = items.length > 0 ? 25 : 0;
  const tax = subtotal * 0.08;
  const total = subtotal + shipping + tax;

  if (items.length === 0) {
    return (
      <div className="max-w-3xl mx-auto px-6 pt-32 pb-24 text-center">
        <h1 className="font-display text-3xl mb-4">Your Cart Is Empty</h1>
        <p className="text-wevix-black/60 dark:text-white/60 mb-8">
          Browse the marketplace to start building your wholesale order.
        </p>
        <Link
          href="/shop"
          className="inline-block px-8 py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest"
        >
          Explore Collection
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-6 pt-32 pb-24">
      <h1 className="font-display text-3xl mb-10">Your Cart</h1>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-2 space-y-6">
          {items.map((item) => (
            <div
              key={item.id}
              className="flex gap-4 border-b border-black/10 dark:border-white/10 pb-6"
            >
              <div className="relative w-24 h-32 bg-wevix-beige/30 shrink-0">
                <Image src={item.image} alt={item.name} fill className="object-cover" />
              </div>
              <div className="flex-1">
                <h3 className="font-medium">{item.name}</h3>
                <p className="text-xs text-wevix-black/50 dark:text-white/50">
                  {item.size} {item.color && `· ${item.color}`}
                </p>
                <p className="text-wevix-gold mt-1">${item.unitPrice.toFixed(2)} / pc</p>
                <div className="flex items-center gap-3 mt-3">
                  <input
                    type="number"
                    min={1}
                    value={item.quantity}
                    onChange={(e) => updateQuantity(item.id, Number(e.target.value))}
                    className="w-20 px-2 py-1 border border-black/10 dark:border-white/10 bg-transparent text-sm"
                  />
                  <button
                    onClick={() => removeItem(item.id)}
                    className="text-wevix-black/40 dark:text-white/40 hover:text-red-500 transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              <div className="text-right font-medium">
                ${(item.unitPrice * item.quantity).toFixed(2)}
              </div>
            </div>
          ))}
        </div>

        {/* SUMMARY */}
        <div className="border border-black/10 dark:border-white/10 p-6 h-fit">
          <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Order Summary
          </h2>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span>Subtotal</span>
              <span>${subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span>Shipping</span>
              <span>${shipping.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span>Tax (est.)</span>
              <span>${tax.toFixed(2)}</span>
            </div>
          </div>
          <div className="flex justify-between mt-4 pt-4 border-t border-black/10 dark:border-white/10 font-display text-xl text-wevix-gold">
            <span>Total</span>
            <span>${total.toFixed(2)}</span>
          </div>

          <div className="mt-6">
            <input
              type="text"
              placeholder="Coupon code"
              className="w-full px-4 py-2 border border-black/10 dark:border-white/10 bg-transparent text-sm mb-3"
            />
            <Link
              href="/checkout"
              className="block text-center py-3 bg-wevix-black text-white dark:bg-white dark:text-wevix-black text-xs uppercase tracking-widest"
            >
              Proceed To Checkout
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
