export default function SupportPage() {
  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Support</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div>
          <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Open A Ticket
          </h2>
          <form className="space-y-4">
            <input placeholder="Subject" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
            <textarea placeholder="Describe your issue" rows={5} className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
            <button type="submit" className="px-6 py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest">
              Submit Ticket
            </button>
          </form>
        </div>
        <div>
          <h2 className="text-xs uppercase tracking-widest text-wevix-gold mb-4">
            Live Chat
          </h2>
          <p className="text-wevix-black/60 dark:text-white/60 text-sm">
            Live chat requires a provider (Intercom, Crisp, or a custom
            Socket.IO widget). Drop the provider&apos;s embed script into
            `app/layout.tsx` once you have an account.
          </p>
        </div>
      </div>
    </div>
  );
}
