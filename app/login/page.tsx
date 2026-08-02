"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginForm() {
  const [mode, setMode] = useState<"password" | "otp">("password");
  const [otpSent, setOtpSent] = useState(false);
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const router = useRouter();
  const params = useSearchParams();
  const redirect = params.get("redirect") || "/dashboard";

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    const formData = new FormData(e.target as HTMLFormElement);
    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: formData.get("email") as string,
      password: formData.get("password") as string,
    });
    if (signInError) {
      setError(signInError.message);
      setLoading(false);
      return;
    }
    router.push(redirect);
  };

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    const supabase = createClient();
    const { error: otpError } = await supabase.auth.signInWithOtp({ email });
    if (otpError) {
      setError(otpError.message);
      setLoading(false);
      return;
    }
    setOtpSent(true);
    setLoading(false);
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    const formData = new FormData(e.target as HTMLFormElement);
    const supabase = createClient();
    const { error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token: formData.get("otp") as string,
      type: "email",
    });
    if (verifyError) {
      setError(verifyError.message);
      setLoading(false);
      return;
    }
    router.push(redirect);
  };

  const handleGoogleLogin = async () => {
    const supabase = createClient();
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}${redirect}` },
    });
  };

  return (
    <>
      <div className="flex mb-8 border border-black/10 dark:border-white/10">
        {(["password", "otp"] as const).map((m) => (
          <button
            key={m}
            onClick={() => {
              setMode(m);
              setOtpSent(false);
              setError("");
            }}
            className={`flex-1 py-3 text-xs uppercase tracking-widest ${
              mode === m
                ? "bg-wevix-gold text-wevix-black"
                : "text-wevix-black/60 dark:text-white/60"
            }`}
          >
            {m === "password" ? "Password" : "Email OTP"}
          </button>
        ))}
      </div>

      {mode === "password" && (
        <form onSubmit={handlePasswordLogin} className="space-y-4">
          <input name="email" type="email" required placeholder="Email" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
          <input name="password" type="password" required placeholder="Password" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest disabled:opacity-50"
          >
            {loading ? "Logging in..." : "Log In"}
          </button>
        </form>
      )}

      {mode === "otp" && !otpSent && (
        <form onSubmit={handleSendOtp} className="space-y-4">
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent"
          />
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest disabled:opacity-50"
          >
            {loading ? "Sending Code..." : "Send Login Code"}
          </button>
        </form>
      )}

      {mode === "otp" && otpSent && (
        <form onSubmit={handleVerifyOtp} className="space-y-4">
          <input name="otp" required placeholder="6-digit code" className="w-full px-4 py-3 border border-black/10 dark:border-white/10 bg-transparent" />
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-wevix-gold text-wevix-black text-xs uppercase tracking-widest disabled:opacity-50"
          >
            {loading ? "Verifying..." : "Verify & Log In"}
          </button>
        </form>
      )}

      <div className="flex items-center gap-4 my-6">
        <div className="flex-1 h-px bg-black/10 dark:bg-white/10" />
        <span className="text-xs text-wevix-black/40 dark:text-white/40">OR</span>
        <div className="flex-1 h-px bg-black/10 dark:bg-white/10" />
      </div>

      <button
        onClick={handleGoogleLogin}
        className="w-full py-3 border border-black/20 dark:border-white/20 text-xs uppercase tracking-widest"
      >
        Continue With Google
      </button>

      <p className="text-center text-sm mt-8 text-wevix-black/60 dark:text-white/60">
        Don&apos;t have an account?{" "}
        <Link href="/signup" className="text-wevix-gold">
          Sign up
        </Link>
      </p>
    </>
  );
}
