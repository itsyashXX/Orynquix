import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function AdminProducts() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login?redirect=/admin/products");

  const { data: products } = await supabase
    .from("products")
    .select("*")
    .order("created_at", { ascending: false });

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <h1 className="font-display text-2xl">Products</h1>
        <div className="flex gap-3">
          <button className="px-4 py-2 border border-white/20 text-xs uppercase tracking-widest">
            Bulk Upload CSV
          </button>
          <button className="px-4 py-2 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
            + Add Product
          </button>
        </div>
      </div>

      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-xs uppercase tracking-widest text-wevix-gold border-b border-white/10">
            <th className="py-3">Name</th>
            <th className="py-3">Category</th>
            <th className="py-3">Retail Price</th>
            <th className="py-3">MOQ</th>
            <th className="py-3">Stock</th>
            <th className="py-3 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {(products ?? []).map((p) => (
            <tr key={p.id} className="border-b border-white/5">
              <td className="py-3">{p.name}</td>
              <td className="py-3">{p.category ?? "—"}</td>
              <td className="py-3">${Number(p.retail_price).toFixed(2)}</td>
              <td className="py-3">{p.moq}</td>
              <td className="py-3">
                {p.in_stock ? p.stock_quantity : "Out of stock"}
              </td>
              <td className="py-3 text-right space-x-3">
                <button className="text-wevix-gold text-xs uppercase tracking-widest">
                  Edit
                </button>
                <button className="text-red-400 text-xs uppercase tracking-widest">
                  Delete
                </button>
              </td>
            </tr>
          ))}
          {(!products || products.length === 0) && (
            <tr>
              <td colSpan={6} className="py-8 text-center text-white/40">
                No products yet. Add your first product or run a bulk upload.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
