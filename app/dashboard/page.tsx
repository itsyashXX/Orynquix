import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function DashboardOverview() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?redirect=/dashboard");

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  const { count: orderCount } = await supabase
    .from("orders")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id);

  return (
    <div>
      <h1 className="font-display text-2xl mb-2">
        Welcome back{profile?.full_name ? `, ${profile.full_name}` : ""}
      </h1>
      <p className="text-wevix-black/60 dark:text-white/60 mb-10">
        {profile?.account_type === "business"
          ? profile?.company_name
          : "Personal Account"}
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
        <div className="border border-black/10 dark:border-white/10 p-6">
          <p className="text-xs uppercase tracking-widest text-wevix-gold mb-2">
            Total Orders
          </p>
          <p className="font-display text-3xl">{orderCount ?? 0}</p>
        </div>
        <div className="border border-black/10 dark:border-white/10 p-6">
          <p className="text-xs uppercase tracking-widest text-wevix-gold mb-2">
            Account Type
          </p>
          <p className="font-display text-3xl capitalize">
            {profile?.account_type ?? "personal"}
          </p>
        </div>
        <div className="border border-black/10 dark:border-white/10 p-6">
          <p className="text-xs uppercase tracking-widest text-wevix-gold mb-2">
            Verified Retailer
          </p>
          <p className="font-display text-3xl">
            {profile?.is_verified_retailer ? "Yes" : "Pending"}
          </p>
        </div>
      </div>

      <div className="mt-10 border border-black/10 dark:border-white/10 p-6">
        <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
          Business Details
        </h2>
        <dl className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
          <div>
            <dt className="text-wevix-black/50 dark:text-white/50">Email</dt>
            <dd>{user.email}</dd>
          </div>
          <div>
            <dt className="text-wevix-black/50 dark:text-white/50">Phone</dt>
            <dd>{profile?.phone ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-wevix-black/50 dark:text-white/50">Country</dt>
            <dd>{profile?.country ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-wevix-black/50 dark:text-white/50">
              Monthly Purchase Volume
            </dt>
            <dd>{profile?.monthly_purchase_volume ?? "—"}</dd>
          </div>
        </dl>
      </div>
    </div>
  );
}
