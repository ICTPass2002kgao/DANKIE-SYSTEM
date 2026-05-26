"use client";

import { motion } from "framer-motion";

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
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight mb-4 text-white">
          Platform <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-blue-200">Capabilities</span>
        </h1>
        <p className="text-lg text-gray-400 font-light max-w-2xl mx-auto">
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
        <motion.div variants={item} className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 hover:bg-white/10 transition-colors">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-blue-600/20 flex items-center justify-center text-blue-400 text-xl border border-blue-500/30">🎓</div>
            <h2 className="text-2xl font-bold text-white">TACTSO Student Logistics</h2>
          </div>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            A dedicated system for matric learners to apply to universities via TACTSO branch committees. Committee members facilitate the application process, maintaining fully encrypted student documentation and generating secure digital attendance registers.
          </p>
        </motion.div>

        {/* Media & Comm Service */}
        <motion.div variants={item} className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 hover:bg-white/10 transition-colors">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-blue-600/20 flex items-center justify-center text-blue-400 text-xl border border-blue-500/30">🎵</div>
            <h2 className="text-2xl font-bold text-white">Media & Event Tracking</h2>
          </div>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            Members can locate nearby branches, view upcoming church events, and seamlessly stream, download, and share church music and historical apostle greetings directly from the platform.
          </p>
        </motion.div>

        {/* Marketplace Service */}
        <motion.div variants={item} className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 hover:bg-white/10 transition-colors">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-blue-600/20 flex items-center justify-center text-blue-400 text-xl border border-blue-500/30">🛒</div>
            <h2 className="text-2xl font-bold text-white">Church Marketplace</h2>
          </div>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            An internal economy empowering church members. Authorized sellers can list products or services, set pricing, and manage deliveries, allowing the congregation to support internal businesses safely.
          </p>
        </motion.div>

        {/* Security & Admin Service */}
        <motion.div variants={item} className="bg-white/5 backdrop-blur-xl border border-blue-500/20 rounded-3xl p-8 hover:bg-white/10 transition-colors shadow-[0_0_30px_rgba(37,99,235,0.1)]">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-full bg-blue-600 flex items-center justify-center text-white text-xl shadow-lg">🛡️</div>
            <h2 className="text-2xl font-bold text-white">Secure Administration</h2>
          </div>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            Overseers and System Admins utilize state-of-the-art facial recognition for secure login. Tools include financial balance sheet generation, local data comparison spreadsheets, and global membership tracking.
          </p>
        </motion.div>
      </motion.div>
    </main>
  );
}