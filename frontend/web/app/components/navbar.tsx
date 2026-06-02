"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

export default function Navbar() {
  const pathname = usePathname();
  const [isOpen, setIsOpen] = useState(false);

  const navLinks = [
    { name: "Home", href: "/" },
    { name: "Contact", href: "/contact-us" },
    { name: "About", href: "/about-us" },
    { name: "Services", href: "/services" },
    { name: "Terms", href: "/terms-and-conditions" },
    { name: "Privacy", href: "/policy-privacy" },
  ];

  return (
    <nav className="fixed top-0 left-0 w-full z-50 p-4 md:p-6 pointer-events-none">
      <div className="max-w-7xl mx-auto pointer-events-auto bg-white/90 backdrop-blur-xl rounded-2xl px-6 py-4 flex justify-between items-center shadow-[0_10px_40px_rgba(0,0,0,0.05)]">
        
        {/* Logo / Brand */}
        <Link href="/" className="flex items-center gap-3 group">
          <div className="w-8 h-8 rounded-full bg-[var(--theme-primary)] flex items-center justify-center text-white text-xs shadow-md group-hover:scale-105 transition-transform">
            T
          </div>
          <span className="text-xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-primary)] to-[var(--theme-primary-hover)] uppercase tracking-widest">
            Dankie
          </span>
        </Link>

        {/* Desktop Navigation */}
        <div className="hidden md:flex items-center gap-6">
          {navLinks.map((link) => {
            const isActive = pathname === link.href;
            return (
              <Link 
                key={link.name} 
                href={link.href}
                className={`text-sm font-bold transition-colors hover:text-[var(--theme-primary)] ${isActive ? "text-[var(--theme-primary)]" : "text-[var(--theme-text-muted)]"}`}
              >
                {link.name}
              </Link>
            );
          })}
        </div>

        {/* Mobile Hamburger Toggle */}
        <button 
          className="md:hidden text-[var(--theme-text-main)] focus:outline-none"
          onClick={() => setIsOpen(!isOpen)}
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {isOpen ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
      </div>

      {/* Mobile Menu Dropdown */}
      <AnimatePresence>
        {isOpen && (
          <motion.div 
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="md:hidden pointer-events-auto mt-2 max-w-7xl mx-auto bg-white/95 backdrop-blur-xl rounded-2xl overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.1)]"
          >
            <div className="flex flex-col py-2">
              {navLinks.map((link) => {
                const isActive = pathname === link.href;
                return (
                  <Link 
                    key={link.name} 
                    href={link.href}
                    onClick={() => setIsOpen(false)}
                    className={`px-6 py-4 text-sm font-bold border-b border-gray-50 last:border-none ${isActive ? "text-[var(--theme-primary)] bg-blue-50/50" : "text-[var(--theme-text-muted)]"}`}
                  >
                    {link.name}
                  </Link>
                );
              })}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}