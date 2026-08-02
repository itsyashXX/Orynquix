export default function AdminMarketing() {
  return (
    <div className="space-y-12">
      <div>
        <h1 className="font-display text-2xl mb-8">Marketing</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <section className="border border-white/10 p-6">
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Coupons & Discounts
            </h2>
            <form className="space-y-3">
              <input placeholder="Coupon Code" className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <input placeholder="Discount % or Amount" className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <button type="submit" className="px-4 py-2 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
                Create Coupon
              </button>
            </form>
          </section>

          <section className="border border-white/10 p-6">
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Banner Management
            </h2>
            <form className="space-y-3">
              <input placeholder="Banner Title" className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <input placeholder="Image URL" className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <button type="submit" className="px-4 py-2 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
                Publish Banner
              </button>
            </form>
          </section>

          <section className="border border-white/10 p-6 md:col-span-2">
            <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
              Email Campaigns
            </h2>
            <p className="text-sm text-white/50 mb-4">
              Requires an email provider (Resend, which you&apos;re already
              using for transactional email in Himluxe, works well here too).
              Wire this form to a serverless function that calls the Resend
              broadcast API.
            </p>
            <form className="space-y-3">
              <input placeholder="Campaign Subject" className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <textarea placeholder="Campaign Body" rows={4} className="w-full px-3 py-2 bg-transparent border border-white/20 text-sm" />
              <button type="submit" className="px-4 py-2 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
                Send Campaign
              </button>
            </form>
          </section>
        </div>
      </div>
    </div>
  );
}
