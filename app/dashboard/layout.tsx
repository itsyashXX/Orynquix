import Link from "next/link";

const links = [
  { href: "/dashboard", label: "Overview" },
  { href: "/dashboard/orders", label: "Orders" },
  { href: "/dashboard/invoices", label: "Invoices" },
  { href: "/dashboard/wishlist", label: "Wishlist" },
  { href: "/dashboard/support", label: "Support" },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="max-w-7xl mx-auto px-6 pt-32 pb-24">
      <div className="flex flex-col md:flex-row gap-10">
        <aside className="md:w-56 shrink-0">
          <h2 className="font-display text-xl mb-6">My Account</h2>
          <nav className="flex md:flex-col gap-1 overflow-x-auto">
            {links.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                className="px-4 py-2 text-sm hover:bg-wevix-beige/40 dark:hover:bg-wevix-charcoal whitespace-nowrap"
              >
                {l.label}
              </Link>
            ))}
          </nav>
        </aside>
        <div className="flex-1">{children}</div>
      </div>
    </div>
  );
}
