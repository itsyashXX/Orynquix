import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

const statusColor: Record<string, string> = {
  pending: "text-yellow-600",
  confirmed: "text-blue-600",
  shipped: "text-purple-600",
  delivered: "text-green-600",
  cancelled: "text-red-600",
};

export default async function OrdersPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?redirect=/dashboard/orders");

  const { data: orders } = await supabase
    .from("orders")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });

  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Your Orders</h1>

      {!orders || orders.length === 0 ? (
        <p className="text-wevix-black/60 dark:text-white/60">
          You haven&apos;t placed any orders yet.
        </p>
      ) : (
        <div className="space-y-4">
          {orders.map((o) => (
            <div
              key={o.id}
              className="border border-black/10 dark:border-white/10 p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <div>
                <p className="text-sm text-wevix-black/50 dark:text-white/50">
                  Order #{o.id.slice(0, 8)}
                </p>
                <p className="text-xs text-wevix-black/40 dark:text-white/40">
                  {new Date(o.created_at).toLocaleDateString()}
                </p>
              </div>
              <div className={`text-sm uppercase tracking-widest ${statusColor[o.status]}`}>
                {o.status}
              </div>
              <div className="font-display text-lg">${o.total.toFixed(2)}</div>
              {o.tracking_number && (
                <div className="text-xs text-wevix-black/50 dark:text-white/50">
                  Tracking: {o.tracking_number}
                </div>
              )}
              {o.status !== "delivered" && o.status !== "cancelled" && (
                <button className="text-xs uppercase tracking-widest text-red-500 border border-red-500 px-3 py-1.5">
                  Cancel Order
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
