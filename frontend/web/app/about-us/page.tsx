"use client";

import { motion } from "framer-motion";

export default function AboutUs() {
  return (
    <main className="w-full max-w-7xl mx-auto p-6 md:p-16 flex flex-col items-center relative z-10">
      
      <motion.div 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="w-full text-center mb-16"
      >
        <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight mb-4 text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-white">
          Our Legacy & Vision
        </h1>
        <p className="text-lg text-gray-300 font-light max-w-3xl mx-auto">
          Bridging centuries of faith with modern digital infrastructure for The Twelve Apostles Church in Trinity.
        </p>
      </motion.div>

      <div className="w-full grid grid-cols-1 md:grid-cols-2 gap-12 mb-16">
        <motion.div 
          initial={{ opacity: 0, x: -50 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 md:p-12 shadow-2xl"
        >
          <div className="w-16 h-16 bg-blue-900/50 rounded-full flex items-center justify-center text-blue-400 text-3xl mb-6 border border-blue-500/30">📜</div>
          <h2 className="text-2xl font-bold text-white mb-4">A History Since 1770</h2>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            The Twelve Apostles Church in Trinity (TACT) holds a rich, unbroken lineage of spiritual leadership. The Dankie app preserves this legacy by offering members direct access to the historical archives, including the sacred greetings and teachings of apostles dating back to 1770.
          </p>
          <p className="text-gray-300 font-light leading-relaxed">
            We are not just moving forward; we are bringing our entire history with us into the digital age, ensuring that every generation remains connected to our roots.
          </p>
        </motion.div>

        <motion.div 
          initial={{ opacity: 0, x: 50 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 md:p-12 shadow-2xl"
        >
          <div className="w-16 h-16 bg-blue-900/50 rounded-full flex items-center justify-center text-blue-400 text-3xl mb-6 border border-blue-500/30">🌐</div>
          <h2 className="text-2xl font-bold text-white mb-4">The Dankie Ecosystem</h2>
          <p className="text-gray-300 font-light leading-relaxed mb-4">
            Dankie was built to serve as the central nervous system for our community. It is a secure, multifaceted platform designed to empower every member of the church.
          </p>
          <ul className="space-y-4 text-gray-300 font-light">
            <li className="flex items-center gap-3"><span className="text-blue-400">✓</span> Empowering student education through TACTSO.</li>
            <li className="flex items-center gap-3"><span className="text-blue-400">✓</span> Fostering economic growth via our internal Marketplace.</li>
            <li className="flex items-center gap-3"><span className="text-blue-400">✓</span> Equipping Overseers and Admins with powerful, secure tools.</li>
            <li className="flex items-center gap-3"><span className="text-blue-400">✓</span> Connecting branches and members globally.</li>
          </ul>
        </motion.div>
      </div>
    </main>
  );
}