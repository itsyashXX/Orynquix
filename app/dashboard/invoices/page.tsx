import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function InvoicesPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?redirect=/dashboard/invoices");

  const { data: orders } = await supabase
    .from("orders")
    .select("id, total, created_at, payment_method, status")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });

  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Invoices & Payment History</h1>

      {!orders || orders.length === 0 ? (
        <p className="text-wevix-black/60 dark:text-white/60">No invoices yet.</p>
      ) : (
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-widest text-wevix-gold border-b border-black/10 dark:border-white/10">
              <th className="py-3">Invoice</th>
              <th className="py-3">Date</th>
              <th className="py-3">Payment Method</th>
              <th className="py-3">Status</th>
              <th className="py-3 text-right">Amount</th>
              <th className="py-3 text-right">Download</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.id} className="border-b border-black/5 dark:border-white/5">
                <td className="py-3">INV-{o.id.slice(0, 8).toUpperCase()}</td>
                <td className="py-3">{new Date(o.created_at).toLocaleDateString()}</td>
                <td className="py-3 capitalize">{o.payment_method?.replace("_", " ")}</td>
                <td className="py-3 capitalize">{o.status}</td>
                <td className="py-3 text-right">${o.total.toFixed(2)}</td>
                <td className="py-3 text-right">
                  <button className="text-wevix-gold text-xs uppercase tracking-widest">
                    PDF
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <p className="text-xs text-wevix-black/40 dark:text-white/40 mt-6">
        PDF invoice generation requires wiring up a PDF export route — hook this
        button to a serverless function once ready.
      </p>
    </div>
  );
}
