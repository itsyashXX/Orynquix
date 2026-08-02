import Link from "next/link";

const links = [
  { href: "/admin", label: "Analytics" },
  { href: "/admin/products", label: "Products" },
  { href: "/admin/orders", label: "Orders" },
  { href: "/admin/customers", label: "Customers" },
  { href: "/admin/marketing", label: "Marketing" },
];

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-wevix-black text-white">
      <div className="max-w-7xl mx-auto px-6 pt-32 pb-24">
        <div className="flex flex-col md:flex-row gap-10">
          <aside className="md:w-56 shrink-0">
            <h2 className="font-display text-xl mb-6 text-wevix-gold">
              Admin Panel
            </h2>
            <nav className="flex md:flex-col gap-1 overflow-x-auto">
              {links.map((l) => (
                <Link
                  key={l.href}
                  href={l.href}
                  className="px-4 py-2 text-sm hover:bg-wevix-charcoal whitespace-nowrap"
                >
                  {l.label}
                </Link>
              ))}
            </nav>
          </aside>
          <div className="flex-1">{children}</div>
        </div>
      </div>
    </div>
  );
}
