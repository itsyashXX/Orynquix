import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function AdminOrders() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login?redirect=/admin/orders");

  const { data: orders } = await supabase
    .from("orders")
    .select("*")
    .order("created_at", { ascending: false });

  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Orders</h1>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-xs uppercase tracking-widest text-wevix-gold border-b border-white/10">
            <th className="py-3">Order</th>
            <th className="py-3">Date</th>
            <th className="py-3">Total</th>
            <th className="py-3">Payment</th>
            <th className="py-3">Status</th>
            <th className="py-3 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {(orders ?? []).map((o) => (
            <tr key={o.id} className="border-b border-white/5">
              <td className="py-3">#{o.id.slice(0, 8)}</td>
              <td className="py-3">{new Date(o.created_at).toLocaleDateString()}</td>
              <td className="py-3">${Number(o.total).toFixed(2)}</td>
              <td className="py-3 capitalize">{o.payment_method?.replace("_", " ")}</td>
              <td className="py-3">
                <select
                  defaultValue={o.status}
                  className="bg-transparent border border-white/20 px-2 py-1 text-xs"
                >
                  <option value="pending">Pending</option>
                  <option value="confirmed">Confirmed</option>
                  <option value="shipped">Shipped</option>
                  <option value="delivered">Delivered</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </td>
              <td className="py-3 text-right">
                <button className="text-wevix-gold text-xs uppercase tracking-widest">
                  Generate Invoice
                </button>
              </td>
            </tr>
          ))}
          {(!orders || orders.length === 0) && (
            <tr>
              <td colSpan={6} className="py-8 text-center text-white/40">
                No orders yet.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
