"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

export default function CookieConsent() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Check if the user has already made a choice
    const consent = localStorage.getItem("dankie_cookie_consent");
    if (!consent) {
      // Small delay so it doesn't instantly flash on page load
      const timer = setTimeout(() => setIsVisible(true), 1000);
      return () => clearTimeout(timer);
    }
  }, []);

  const handleAccept = () => {
    localStorage.setItem("dankie_cookie_consent", "accepted");
    setIsVisible(false);
    // TODO: Initialize your tracking scripts (e.g., Google Analytics) here
  };

  const handleDecline = () => {
    localStorage.setItem("dankie_cookie_consent", "declined");
    setIsVisible(false);
    // TODO: Ensure tracking scripts remain disabled
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 50, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 20, scale: 0.95 }}
          transition={{ type: "spring", stiffness: 100, damping: 20 }}
          className="fixed bottom-6 left-6 right-6 md:left-auto md:right-6 md:max-w-sm z-[100] bg-white/80 backdrop-blur-xl border border-white/80 rounded-2xl p-6 shadow-[0_8px_32px_rgba(37,99,235,0.15)]"
        >
          <div className="flex items-start gap-4 mb-4">
            <div className="w-10 h-10 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)] shrink-0 shadow-sm border border-gray-100">
              <i className="fa-solid fa-cookie-bite text-xl"></i>
            </div>
            <div>
              <h3 className="font-bold text-[var(--theme-text-main)] text-lg leading-tight mb-1">
                We value your privacy
              </h3>
              <p className="text-sm text-[var(--theme-text-muted)] font-medium leading-relaxed">
                We use cookies to enhance your browsing experience and analyze our traffic. Read our{" "}
                <Link href="/policy-privacy" className="text-[var(--theme-primary)] hover:underline">
                  Privacy Policy
                </Link>{" "}
                for more details.
              </p>
            </div>
          </div>

          <div className="flex gap-3 mt-5">
            <button
              onClick={handleDecline}
              className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 bg-gray-50 text-[var(--theme-text-main)] text-sm font-bold hover:bg-gray-100 transition-colors shadow-sm"
            >
              Decline
            </button>
            <button
              onClick={handleAccept}
              className="flex-1 px-4 py-2.5 rounded-xl border border-[var(--theme-primary)] bg-[var(--theme-primary)] text-white text-sm font-bold hover:bg-[var(--theme-primary-hover)] transition-colors shadow-md"
            >
              Accept All
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}