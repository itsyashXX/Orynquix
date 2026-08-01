"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Search, Heart, ShoppingBag, Menu, X } from "lucide-react";
import { useCart } from "@/context/CartContext";

const links = [
  { href: "/shop", label: "Shop" },
  { href: "/wholesale", label: "Wholesale" },
  { href: "/about", label: "About" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const { items } = useCart();
  const cartCount = items.reduce((n, i) => n + i.quantity, 0);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
        scrolled
          ? "bg-wevix-white/90 dark:bg-wevix-black/90 backdrop-blur-md shadow-sm"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-7xl mx-auto flex items-center justify-between px-6 py-5">
        <Link
          href="/"
          className="font-display text-2xl tracking-widest animate-logo-reveal"
        >
          WEVIX
        </Link>

        <nav className="hidden md:flex items-center gap-10 text-sm uppercase tracking-wide">
          {links.map((l) => (
            <Link key={l.href} href={l.href} className="gold-underline">
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden md:flex items-center gap-6">
          <Search className="w-5 h-5 cursor-pointer hover:text-wevix-gold transition-colors" />
          <Link href="/dashboard/wishlist">
            <Heart className="w-5 h-5 cursor-pointer hover:text-wevix-gold transition-colors" />
          </Link>
          <Link href="/cart" className="relative">
            <ShoppingBag className="w-5 h-5 cursor-pointer hover:text-wevix-gold transition-colors" />
            {cartCount > 0 && (
              <span className="absolute -top-2 -right-2 w-4 h-4 rounded-full bg-wevix-gold text-[10px] text-wevix-black flex items-center justify-center">
                {cartCount}
              </span>
            )}
          </Link>
          <Link
            href="/wholesale"
            className="ml-2 px-5 py-2 text-xs uppercase tracking-widest border border-wevix-gold text-wevix-gold hover:bg-wevix-gold hover:text-wevix-black transition-all"
          >
            Partner With Us
          </Link>
        </div>

        <button className="md:hidden" onClick={() => setOpen(!open)}>
          {open ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {open && (
        <div className="md:hidden bg-wevix-white dark:bg-wevix-black px-6 pb-6 flex flex-col gap-4">
          {links.map((l) => (
            <Link key={l.href} href={l.href} onClick={() => setOpen(false)}>
              {l.label}
            </Link>
          ))}
        </div>
      )}
    </header>
  );
}
