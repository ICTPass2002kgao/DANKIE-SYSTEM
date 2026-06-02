"use client";

import { motion } from "framer-motion";
import { GraduationCap, Music, ShoppingCart, Shield } from "lucide-react";

export default function Services() {
  const container = {
    hidden: { opacity: 0 },
    show: { opacity: 1, transition: { staggerChildren: 0.15 } }
  };

  const item = {
    hidden: { opacity: 0, y: 30 },
    show: { opacity: 1, y: 0, transition: { duration: 0.6 } }
  };

  return (
    <main className="w-full max-w-7xl mx-auto p-6 md:p-16 flex flex-col items-center relative z-10">
      
      <motion.div 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="w-full text-center mb-16"
      >
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight mb-4 text-[var(--theme-text-main)]">
          Platform <span className="text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-primary)] to-[var(--theme-primary-hover)]">Capabilities</span>
        </h1>
        <p className="text-lg text-[var(--theme-text-muted)] font-normal max-w-2xl mx-auto">
          Dankie provides dedicated infrastructure for spiritual growth, education, commerce, and secure administration.
        </p>
      </motion.div>

      <motion.div 
        variants={container}
        initial="hidden"
        animate="show"
        className="w-full grid grid-cols-1 md:grid-cols-2 gap-8"
      >
        {/* TACTSO Service */}
        <motion.div variants={item} className="bg-[var(--theme-card-bg)] border border-gray-200 rounded-3xl p-8 hover:border-[var(--theme-primary)]/50 transition-colors shadow-lg">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)]">
              <GraduationCap className="w-6 h-6" />
            </div>
            <h2 className="text-2xl font-bold text-[var(--theme-text-main)]">TACTSO Student Logistics</h2>
          </div>
          <p className="text-[var(--theme-text-muted)] font-normal leading-relaxed mb-4">
            A dedicated system for matric learners to apply to universities via TACTSO branch committees. Committee members facilitate the application process, maintaining fully encrypted student documentation and generating secure digital attendance registers.
          </p>
        </motion.div>

        {/* Media & Comm Service */}
        <motion.div variants={item} className="bg-[var(--theme-card-bg)] border border-gray-200 rounded-3xl p-8 hover:border-[var(--theme-primary)]/50 transition-colors shadow-lg">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)]">
              <Music className="w-6 h-6" />
            </div>
            <h2 className="text-2xl font-bold text-[var(--theme-text-main)]">Media & Event Tracking</h2>
          </div>
          <p className="text-[var(--theme-text-muted)] font-normal leading-relaxed mb-4">
            Members can locate nearby branches, view upcoming church events, and seamlessly stream, download, and share church music and historical apostle greetings directly from the platform.
          </p>
        </motion.div>

        {/* Marketplace Service */}
        <motion.div variants={item} className="bg-[var(--theme-card-bg)] border border-gray-200 rounded-3xl p-8 hover:border-[var(--theme-primary)]/50 transition-colors shadow-lg">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)]">
              <ShoppingCart className="w-6 h-6" />
            </div>
            <h2 className="text-2xl font-bold text-[var(--theme-text-main)]">Church Marketplace</h2>
          </div>
          <p className="text-[var(--theme-text-muted)] font-normal leading-relaxed mb-4">
            An internal economy empowering church members. Authorized sellers can list products or services, set pricing, and manage deliveries, allowing the congregation to support internal businesses safely.
          </p>
        </motion.div>

        {/* Security & Admin Service */}
        <motion.div variants={item} className="bg-[var(--theme-card-bg)] border border-blue-100 rounded-3xl p-8 hover:border-[var(--theme-primary)]/50 transition-colors shadow-[0_10px_30px_rgba(37,99,235,0.08)]">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)] flex items-center justify-center text-white shadow-md">
              <Shield className="w-6 h-6" />
            </div>
            <h2 className="text-2xl font-bold text-[var(--theme-text-main)]">Secure Administration</h2>
          </div>
          <p className="text-[var(--theme-text-muted)] font-normal leading-relaxed mb-4">
            Overseers and System Admins utilize state-of-the-art facial recognition for secure login. Tools include financial balance sheet generation, local data comparison spreadsheets, and global membership tracking.
          </p>
        </motion.div>
      </motion.div>
    </main>
  );
}