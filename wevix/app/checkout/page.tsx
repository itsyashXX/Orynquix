"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useCart } from "@/context/CartContext";
import { createClient } from "@/lib/supabase/client";

export default function CheckoutPage() {
  const { items, subtotal, clearCart } = useCart();
  const router = useRouter();
  const [paymentMethod, setPaymentMethod] = useState<
    "online" | "bank_transfer" | "invoice" | "cod"
  >("online");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const shipping = 25;
  const tax = subtotal * 0.08;
  const total = subtotal + shipping + tax;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      setError("Please sign in to complete checkout.");
      setSubmitting(false);
      router.push("/login?redirect=/checkout");
      return;
    }

    const formData = new FormData(e.target as HTMLFormElement);
    const shippingAddress = {
      name: formData.get("name"),
      phone: formData.get("phone"),
      address: formData.get("address"),
      city: formData.get("city"),
      country: formData.get("country"),
      postal_code: formData.get("postal_code"),
    };

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        user_id: user.id,
        status: "pending",
        subtotal,
        tax,
        shipping,
        total,
        payment_method: paymentMethod,
        shipping_address: shippingAddress,
      })
      .select()
      .single();

    if (orderError) {
      setError(orderError.message);
      setSubmitting(false);
      return;
    }

    const orderItems = items.map((i) => ({
      order_id: order.id,
      product_id: i.productId,
      quantity: i.quantity,
      unit_price: i.unitPrice,
      size: i.size,
      color: i.color,
    }));

    const { error: itemsError } = await supabase
      .from("order_items")
      .insert(orderItems);

    if (itemsError) {
      setError(itemsError.message);
      setSubmitting(false);
      return;
    }

    // NOTE: online payment gateway integration goes here.
    // Plug in Razorpay/Stripe checkout session creation before
    // marking the order confirmed if paymentMethod === "online".

    clearCart();
    router.push(`/dashboard/orders?confirmed=${order.id}`);
  };

  if (items.length === 0) {
    return (
      <div className="max-w-2xl mx-auto px-6 pt-32 pb-24 text-center">
        <h1 className="font-display text-3xl mb-4">Nothing To Check Out</h1>
        <p className="text-wevix-black/60 dark:text-white/60">
          Your cart is empty.
        </p>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto px-6 pt-32 pb-24">
      <h1 className="font-display text-3xl mb-10">Checkout</h1>
      <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-2 space-y-10">
          <section>
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Customer Details
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <input name="name" required placeholder="Full Name" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
              <input name="phone" required placeholder="Phone" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
              <input name="company" placeholder="Company Name" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent sm:col-span-2" />
            </div>
          </section>

          <section>
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Shipping Address
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <input name="address" required placeholder="Street Address" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent sm:col-span-2" />
              <input name="city" required placeholder="City" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
              <input name="postal_code" required placeholder="Postal Code" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
              <input name="country" required placeholder="Country" className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent sm:col-span-2" />
            </div>
          </section>

          <section>
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Payment Method
            </h2>
            <div className="space-y-2">
              {[
                { id: "online", label: "Online Payment (Card / UPI)" },
                { id: "bank_transfer", label: "Bank Transfer" },
                { id: "invoice", label: "Invoice Payment (Net 30)" },
                { id: "cod", label: "Cash On Delivery" },
              ].map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-3 px-4 py-3 border border-black/10 dark:border-white/10 cursor-pointer"
                >
                  <input
                    type="radio"
                    name="payment_method"
                    checked={paymentMethod === m.id}
                    onChange={() => setPaymentMethod(m.id as typeof paymentMethod)}
                    className="accent-wevix-gold"
                  />
                  {m.label}
                </label>
              ))}
            </div>
          </section>
        </div>

        {/* SUMMARY */}
        <div className="border border-black/10 dark:border-white/10 p-6 h-fit">
          <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Order Summary
          </h2>
          <div className="space-y-2 text-sm mb-4">
            {items.map((i) => (
              <div key={i.id} className="flex justify-between">
                <span className="truncate pr-2">
                  {i.name} × {i.quantity}
                </span>
                <span>${(i.unitPrice * i.quantity).toFixed(2)}</span>
              </div>
            ))}
          </div>
          <div className="space-y-2 text-sm border-t border-black/10 dark:border-white/10 pt-4">
            <div className="flex justify-between">
              <span>Subtotal</span>
              <span>${subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span>Shipping</span>
              <span>${shipping.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span>Tax</span>
              <span>${tax.toFixed(2)}</span>
            </div>
          </div>
          <div className="flex justify-between mt-4 pt-4 border-t border-black/10 dark:border-white/10 font-display text-xl text-wevix-gold">
            <span>Total</span>
            <span>${total.toFixed(2)}</span>
          </div>

          {error && <p className="text-red-500 text-sm mt-4">{error}</p>}

          <button
            type="submit"
            disabled={submitting}
            className="w-full mt-6 py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest disabled:opacity-50"
          >
            {submitting ? "Placing Order..." : "Place Order"}
          </button>
        </div>
      </form>
    </div>
  );
}
