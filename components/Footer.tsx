export default function Footer() {
  return (
    <footer className="bg-wevix-black text-wevix-white mt-32 border-t border-wevix-charcoal">
      <div className="max-w-7xl mx-auto px-6 py-16 grid grid-cols-1 md:grid-cols-4 gap-10">
        <div>
          <h3 className="font-display text-xl tracking-widest mb-4">WEVIX</h3>
          <p className="text-sm text-wevix-beige/70">
            The future of wholesale fashion. Premium apparel supply for
            businesses around the world.
          </p>
        </div>
        <div>
          <h4 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Shop
          </h4>
          <ul className="space-y-2 text-sm text-wevix-beige/70">
            <li>New Arrivals</li>
            <li>Best Sellers</li>
            <li>Trending Collections</li>
            <li>Seasonal Drops</li>
          </ul>
        </div>
        <div>
          <h4 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Business
          </h4>
          <ul className="space-y-2 text-sm text-wevix-beige/70">
            <li>Wholesale Partnership</li>
            <li>Custom Manufacturing</li>
            <li>Bulk Pricing</li>
            <li>Retailer Verification</li>
          </ul>
        </div>
        <div>
          <h4 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Company
          </h4>
          <ul className="space-y-2 text-sm text-wevix-beige/70">
            <li>About Us</li>
            <li>Supply Chain</li>
            <li>Contact</li>
            <li>Support</li>
          </ul>
        </div>
      </div>
      <div className="border-t border-wevix-charcoal py-6 text-center text-xs text-wevix-beige/50">
        © {new Date().getFullYear()} Wevix. All rights reserved.
      </div>
    </footer>
  );
}
