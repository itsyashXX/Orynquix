import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function AdminAnalytics() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?redirect=/admin");

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();

  if (!profile?.is_admin) redirect("/dashboard");

  const { data: orders } = await supabase.from("orders").select("total, status, created_at");
  const { count: customerCount } = await supabase
    .from("profiles")
    .select("id", { count: "exact", head: true });
  const { count: productCount } = await supabase
    .from("products")
    .select("id", { count: "exact", head: true });

  const revenue = orders?.reduce((sum, o) => sum + Number(o.total), 0) ?? 0;
  const orderCount = orders?.length ?? 0;

  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Analytics Overview</h1>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-6 mb-12">
        <StatBox label="Revenue" value={`$${revenue.toFixed(2)}`} />
        <StatBox label="Orders" value={orderCount} />
        <StatBox label="Customers" value={customerCount ?? 0} />
        <StatBox label="Products" value={productCount ?? 0} />
      </div>

      <div className="border border-white/10 p-6">
        <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
          Order Status Breakdown
        </h2>
        <div className="space-y-2 text-sm">
          {["pending", "confirmed", "shipped", "delivered", "cancelled"].map(
            (status) => {
              const count = orders?.filter((o) => o.status === status).length ?? 0;
              return (
                <div key={status} className="flex justify-between capitalize">
                  <span>{status}</span>
                  <span>{count}</span>
                </div>
              );
            }
          )}
        </div>
      </div>

      <p className="text-xs text-white/40 mt-6">
        Wire a charting library (Recharts) here for revenue-over-time and
        product-performance charts once you have enough order volume to plot.
      </p>
    </div>
  );
}

function StatBox({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="border border-white/10 p-6">
      <p className="text-xs uppercase tracking-widest text-wevix-gold mb-2">
        {label}
      </p>
      <p className="font-display text-3xl">{value}</p>
    </div>
  );
}
