export default function WholesalePage() {
  return (
    <div className="max-w-3xl mx-auto px-6 pt-32 pb-24">
      <p className="text-wevix-gold uppercase tracking-[0.3em] text-xs mb-3">
        Become A Partner
      </p>
      <h1 className="font-display text-4xl mb-4">Wholesale Partnership</h1>
      <p className="text-wevix-black/70 dark:text-white/70 mb-10">
        Get exclusive pricing, priority support, early access to new
        collections, and custom manufacturing options.
      </p>

      <form className="grid grid-cols-1 md:grid-cols-2 gap-5">
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Full Name"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Company Name"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Business Type"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Phone"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Email"
          type="email"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          placeholder="Country"
        />
        <input
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent md:col-span-2"
          placeholder="Monthly Purchase Volume"
        />
        <textarea
          className="px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent md:col-span-2"
          placeholder="Product Interest"
          rows={4}
        />
        <button
          type="submit"
          className="md:col-span-2 py-4 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest hover:bg-wevix-gold-light transition-colors"
        >
          Submit Application
        </button>
      </form>
    </div>
  );
}
