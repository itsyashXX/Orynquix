export default function WishlistPage() {
  return (
    <div>
      <h1 className="font-display text-2xl mb-8">Wishlist</h1>
      <p className="text-wevix-black/60 dark:text-white/60">
        Products you save will appear here. Wire the heart icon on product
        cards to insert into a `wishlist_items` table (same pattern as
        `cart_items` in the schema) to make this live.
      </p>
    </div>
  );
}
