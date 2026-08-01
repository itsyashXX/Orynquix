"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const [accountType, setAccountType] = useState<"personal" | "business">("personal");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const formData = new FormData(e.target as HTMLFormElement);
    const email = formData.get("email") as string;
    const password = formData.get("password") as string;
    const fullName = formData.get("full_name") as string;
    const companyName = formData.get("company_name") as string;

    const supabase = createClient();
    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/dashboard`,
        data: { full_name: fullName, account_type: accountType },
      },
    });

    if (signUpError) {
      setError(signUpError.message);
      setLoading(false);
      return;
    }

    if (data.user) {
      await supabase.from("profiles").insert({
        id: data.user.id,
        full_name: fullName,
        account_type: accountType,
        company_name: accountType === "business" ? companyName : null,
      });
    }

    setSuccess(true);
    setLoading(false);
  };

  const handleGoogleSignup = async () => {
    const supabase = createClient();
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/dashboard` },
    });
  };

  if (success) {
    return (
      <div className="max-w-md mx-auto px-6 pt-40 pb-24 text-center">
        <h1 className="font-display text-2xl mb-4">Check Your Email</h1>
        <p className="text-wevix-black/60 dark:text-white/60">
          We&apos;ve sent a verification link to confirm your account. Verify
          your phone number from your dashboard once logged in.
        </p>
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto px-6 pt-32 pb-24">
      <h1 className="font-display text-3xl mb-2">Create Your Account</h1>
      <p className="text-wevix-black/60 dark:text-white/60 mb-8">
        Join Wevix as a retailer or business partner.
      </p>

      <div className="flex mb-8 border border-black/10 dark:border-white/10">
        {(["personal", "business"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setAccountType(t)}
            className={`flex-1 py-3 text-xs uppercase tracking-widest capitalize ${
              accountType === t
                ? "bg-wevix-gold text-wevix-black"
                : "text-wevix-black/60 dark:text-white/60"
            }`}
          >
            {t} Account
          </button>
        ))}
      </div>

      <form onSubmit={handleSignup} className="space-y-4">
        <input name="full_name" required placeholder="Full Name" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
        {accountType === "business" && (
          <input name="company_name" required placeholder="Company Name" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
        )}
        <input name="email" type="email" required placeholder="Email" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
        <input name="password" type="password" required minLength={8} placeholder="Password (min 8 characters)" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />

        {error && <p className="text-red-500 text-sm">{error}</p>}

        <button
          type="submit"
          disabled={loading}
          className="w-full py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest disabled:opacity-50"
        >
          {loading ? "Creating Account..." : "Create Account"}
        </button>
      </form>

      <div className="flex items-center gap-4 my-6">
        <div className="flex-1 h-px bg-black/10 dark:bg-white/10" />
        <span className="text-xs text-wevix-black/40 dark:text-white/40">OR</span>
        <div className="flex-1 h-px bg-black/10 dark:bg-white/10" />
      </div>

      <button
        onClick={handleGoogleSignup}
        className="w-full py-3 border border-black/20 dark:border-white/20 text-xs uppercase tracking-widest"
      >
        Continue With Google
      </button>

      <p className="text-center text-sm mt-8 text-wevix-black/60 dark:text-white/60">
        Already have an account?{" "}
        <Link href="/login" className="text-wevix-gold">
          Log in
        </Link>
      </p>
    </div>
  );
}
