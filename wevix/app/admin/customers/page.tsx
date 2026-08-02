import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function AdminCustomers() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login?redirect=/admin/customers");

  const { data: customers } = await supabase
    .from("profiles")
    .select("*")
    .order("created_at", { ascending: false });

  const { data: applications } = await supabase
    .from("partner_applications")
    .select("*")
    .eq("status", "pending")
    .order("created_at", { ascending: false });

  return (
    <div className="space-y-12">
      <div>
        <h1 className="font-display text-2xl mb-8">Customers</h1>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-widest text-wevix-gold border-b border-white/10">
              <th className="py-3">Name</th>
              <th className="py-3">Type</th>
              <th className="py-3">Company</th>
              <th className="py-3">Verified</th>
              <th className="py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {(customers ?? []).map((c) => (
              <tr key={c.id} className="border-b border-white/5">
                <td className="py-3">{c.full_name}</td>
                <td className="py-3 capitalize">{c.account_type}</td>
                <td className="py-3">{c.company_name ?? "—"}</td>
                <td className="py-3">{c.is_verified_retailer ? "Yes" : "No"}</td>
                <td className="py-3 text-right">
                  <button className="text-wevix-gold text-xs uppercase tracking-widest">
                    {c.is_verified_retailer ? "Revoke" : "Verify"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div>
        <h2 className="font-display text-xl mb-6">
          Pending Wholesale Applications
        </h2>
        <div className="space-y-3">
          {(applications ?? []).map((a) => (
            <div
              key={a.id}
              className="border border-white/10 p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <div>
                <p className="font-medium">{a.company_name}</p>
                <p className="text-xs text-white/50">
                  {a.full_name} · {a.email} · {a.country}
                </p>
              </div>
              <div className="flex gap-2">
                <button className="px-3 py-1.5 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
                  Approve
                </button>
                <button className="px-3 py-1.5 border border-white/20 text-xs uppercase tracking-widest">
                  Reject
                </button>
              </div>
            </div>
          ))}
          {(!applications || applications.length === 0) && (
            <p className="text-white/40 text-sm">No pending applications.</p>
          )}
        </div>
      </div>
    </div>
  );
}
