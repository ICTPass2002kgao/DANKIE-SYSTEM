"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import Image from "next/image";

// Replace with your actual logo URL when ready
const IMG_LOGO = "https://res.cloudinary.com/dajihjqkc/image/upload/v1779755909/dankie_logo_htz2re.png"; 

export default function Home() {
  // Staggered animation configurations
  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: { staggerChildren: 0.15 }
    }
  };

  const item = {
    hidden: { opacity: 0, y: 40 },
    show: { 
      opacity: 1, 
      y: 0, 
      transition: { type: "spring" as const, stiffness: 100, damping: 20 } 
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-[var(--theme-bg-start)] via-[var(--theme-bg-mid)] to-[var(--theme-bg-end)] text-white flex flex-col items-center relative overflow-hidden">
      
      {/* Animated Ambient Glow Effects */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none z-0">
        <motion.div 
          animate={{ scale: [1, 1.2, 1], opacity: [0.3, 0.5, 0.3] }}
          transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[-10%] left-[-10%] w-[60vw] h-[60vw] bg-[var(--theme-primary)]/10 rounded-full blur-[120px]"
        />
        <motion.div 
          animate={{ scale: [1, 1.3, 1], opacity: [0.2, 0.4, 0.2] }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut", delay: 1 }}
          className="absolute bottom-[-10%] right-[-10%] w-[50vw] h-[50vw] bg-[var(--theme-accent)]/10 rounded-full blur-[100px]"
        />
      </div>

      <div className="w-full max-w-7xl relative z-10 px-6 md:px-16 pt-12 pb-24">
        
        {/* Hero Section */}
        <motion.section 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, ease: "easeOut" }}
          className="w-full flex flex-col items-center text-center py-20 mb-16"
        >
          {/* Animated White Logo Container */}
          <motion.div 
            animate={{ y: [0, -10, 0] }}
            transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
            className="relative w-28 h-28 md:w-32 md:h-32 rounded-full bg-white flex items-center justify-center mb-8 shadow-[0_0_40px_rgba(255,255,255,0.2)] border-4 border-white/20 overflow-hidden"
          >
            {IMG_LOGO ? (
              <Image src={IMG_LOGO} alt="Dankie Logo" fill className="object-contain p-2" />
            ) : (
              <span className="text-[var(--theme-primary)] font-black text-xs tracking-widest uppercase">LOGO</span>
            )}
          </motion.div>

          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight mb-6 text-white leading-tight">
            The Twelve Apostles <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-accent)] to-[var(--theme-accent-light)]">
              Church in Trinity
            </span>
          </h1>
          <p className="text-lg md:text-xl text-gray-300 font-light max-w-3xl mx-auto mb-10 leading-relaxed">
            A spiritual home bridging centuries of legacy with modern community connection. Welcome to Dankie—our official digital ecosystem for faith, education, and growth.
          </p>
          
          {/* App Download Buttons */}
          <div className="flex flex-wrap gap-6 items-center justify-center">
            
            {/* iOS App */}
            <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
              <Link href="/" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white text-black transition-all shadow-[0_0_20px_rgba(255,255,255,0.2)] hover:shadow-[0_0_30px_rgba(255,255,255,0.4)]">
                <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.19 2.31-.88 3.5-.8 1.49.07 2.65.65 3.39 1.76-2.9 1.76-2.43 5.48.51 6.69-.69 1.79-1.57 3.39-2.48 4.52zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.35-1.92 4.31-3.74 4.25z"/>
                </svg>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-600">Download on the</span>
                  <span className="text-xl font-bold leading-tight">App Store</span>
                </div>
              </Link>
            </motion.div>

            {/* Android App */}
            <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
              <Link href="https://play.google.com/store/apps/details?id=com.thetact.ttact" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white text-black transition-all shadow-[0_0_20px_rgba(255,255,255,0.2)] hover:shadow-[0_0_30px_rgba(255,255,255,0.4)]">
                <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M3.195 21.053c-.15-.128-.242-.319-.242-.533V3.48c0-.214.092-.405.242-.533l10.364 9.053-10.364 9.053zm11.233-9.807l3.663-3.195-2.887-1.657-3.664 3.195 2.888 1.657zm.776.677l-2.888 1.658 3.664 3.195 2.887-1.657-3.663-3.196zm4.841-3.473l-3.327-1.91 1.758-1.536 3.018 1.734c.484.278.484.729 0 1.008l-3.018 1.733-1.758-1.536 3.327-1.91z" fill="#000"/>
                  <path d="M17.523 15.341l-4.624-4.624 4.624-4.624 5.345 3.072c1.134.652 1.134 1.708 0 2.36l-5.345 3.072zM2.879 2.584C2.33 3.084 2 3.861 2 4.815v14.37c0 .954.33 1.731.879 2.231l.11.1 8.272-8.271v-.219L3.003 2.47c-.042.036-.084.075-.124.114z" />
                </svg>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-600">GET IT ON</span>
                  <span className="text-xl font-bold leading-tight">Google Play</span>
                </div>
              </Link>
            </motion.div>

            {/* Huawei AppGallery */}
            <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
              <Link href="https://appgallery.huawei.com/app/C115359927" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white text-black transition-all shadow-[0_0_20px_rgba(255,255,255,0.2)] hover:shadow-[0_0_30px_rgba(255,255,255,0.4)]">
                <svg className="w-10 h-10 text-red-600" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2zm3.938 14.5c-.378 0-.688-.309-.688-.688 0-.378.31-.688.688-.688.378 0 .688.31.688.688 0 .379-.31.688-.688.688zm-7.876 0c-.378 0-.688-.309-.688-.688 0-.378.31-.688.688-.688.378 0 .688.31.688.688 0 .379-.31.688-.688.688zm3.938-1.75c-2.312 0-4.188-1.875-4.188-4.188 0-2.312 1.876-4.188 4.188-4.188 2.312 0 4.188 1.876 4.188 4.188 0 2.313-1.876 4.188-4.188 4.188z"/>
                </svg>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-600">EXPLORE IT ON</span>
                  <span className="text-xl font-bold leading-tight">AppGallery</span>
                </div>
              </Link>
            </motion.div>

            {/* Web App */}
            <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
              <Link href="/" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-[var(--theme-glass-bg)] border border-[var(--theme-glass-border)] text-white hover:bg-white/10 transition-all shadow-lg">
                <svg className="w-10 h-10 text-[var(--theme-accent)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
                </svg>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-400">ACCESS ONLINE</span>
                  <span className="text-xl font-bold leading-tight">Web App</span>
                </div>
              </Link>
            </motion.div>

          </div>
        </motion.section>

        {/* Introduction / History Snippet */}
        <motion.section 
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.8 }}
          className="w-full bg-[var(--theme-glass-bg)] backdrop-blur-xl border border-[var(--theme-glass-border)] rounded-3xl p-8 md:p-12 mb-24 shadow-2xl flex flex-col md:flex-row items-center gap-12 group hover:border-[var(--theme-accent)]/30 transition-colors duration-500"
        >
          <div className="flex-1">
            <h2 className="text-3xl font-bold text-white mb-4">A Legacy Since 1770</h2>
            <p className="text-gray-300 font-light leading-relaxed mb-6">
              Our roots run deep. For centuries, The Twelve Apostles Church in Trinity has provided spiritual guidance, community support, and an unbroken lineage of apostolic teachings. 
            </p>
            <p className="text-gray-300 font-light leading-relaxed mb-8">
              Today, through the Dankie platform, we bring our rich history into the future—allowing members to stream archival greetings from our founding apostles while building a vibrant, modern community.
            </p>
            <Link href="/about-us" className="text-[var(--theme-accent)] font-medium hover:text-[var(--theme-accent-light)] transition-colors flex items-center gap-2 group-hover:translate-x-2 duration-300">
              Read our full story <span>→</span>
            </Link>
          </div>
          <div className="flex-1 w-full h-64 md:h-80 bg-[var(--theme-primary)]/10 border border-[var(--theme-primary)]/20 rounded-2xl flex items-center justify-center relative overflow-hidden">
            <motion.div 
              animate={{ rotate: 360 }}
              transition={{ duration: 60, repeat: Infinity, ease: "linear" }}
              className="absolute inset-0 opacity-30 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-[var(--theme-accent)] to-transparent"
            />
            <span className="text-6xl relative z-10 filter drop-shadow-[0_0_15px_rgba(255,255,255,0.5)]">🌍</span>
          </div>
        </motion.section>

        {/* The Dankie Ecosystem - Icon Driven Roles */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
          transition={{ duration: 0.8 }}
          className="w-full text-center mb-12"
        >
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">A Purpose-Built Ecosystem</h2>
        </motion.div>

        <motion.section 
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: "-50px" }}
          className="w-full grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-24"
        >
          {/* 1. Member */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-[var(--theme-glass-bg)] backdrop-blur-md border border-[var(--theme-glass-border)] rounded-3xl p-6 hover:bg-[var(--theme-primary)]/10 transition-all duration-300 shadow-xl">
            <div className="flex items-center gap-4 mb-6 border-b border-[var(--theme-glass-border)] pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-accent)]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
              </div>
              <h3 className="text-2xl font-bold text-white">Member</h3>
            </div>
            <ul className="space-y-4 text-gray-200 font-medium">
              <li className="flex items-center gap-3"><span className="text-2xl">📅</span> View Church Events</li>
              <li className="flex items-center gap-3"><span className="text-2xl">📍</span> Locate Nearby Branches</li>
              <li className="flex items-center gap-3"><span className="text-2xl">🎵</span> Stream & Download Music</li>
              <li className="flex items-center gap-3"><span className="text-2xl">🎓</span> Apply for Bursaries</li>
              <li className="flex items-center gap-3"><span className="text-2xl">📜</span> View Apostle Greetings (1770+)</li>
            </ul>
          </motion.div>

          {/* 2. TACTSO */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-[var(--theme-glass-bg)] backdrop-blur-md border border-[var(--theme-glass-border)] rounded-3xl p-6 hover:bg-[var(--theme-primary)]/10 transition-all duration-300 shadow-xl">
            <div className="flex items-center gap-4 mb-6 border-b border-[var(--theme-glass-border)] pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-accent)]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 14l9-5-9-5-9 5 9 5z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 14v7" /></svg>
              </div>
              <h3 className="text-2xl font-bold text-white">TACTSO</h3>
            </div>
            <ul className="space-y-4 text-gray-200 font-medium">
              <li className="flex items-center gap-3"><span className="text-2xl">🏫</span> Apply to Universities</li>
              <li className="flex items-center gap-3"><span className="text-2xl">🔐</span> Strict Document Encryption</li>
              <li className="flex items-center gap-3"><span className="text-2xl">📋</span> Digital Attendance Registers</li>
              <li className="flex items-center gap-3"><span className="text-2xl">🤝</span> Committee Assistance</li>
            </ul>
          </motion.div>

          {/* 3. Seller */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-[var(--theme-glass-bg)] backdrop-blur-md border border-[var(--theme-glass-border)] rounded-3xl p-6 hover:bg-[var(--theme-primary)]/10 transition-all duration-300 shadow-xl">
            <div className="flex items-center gap-4 mb-6 border-b border-[var(--theme-glass-border)] pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-accent)]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
              </div>
              <h3 className="text-2xl font-bold text-white">Seller</h3>
            </div>
            <ul className="space-y-4 text-gray-200 font-medium">
              <li className="flex items-center gap-3"><span className="text-2xl">🛒</span> Add Products & Services</li>
              <li className="flex items-center gap-3"><span className="text-2xl">🏷️</span> Set Custom Prices</li>
              <li className="flex items-center gap-3"><span className="text-2xl">📦</span> Manage Deliveries</li>
              <li className="flex items-center gap-3"><span className="text-2xl">💳</span> Sell to Church Community</li>
            </ul>
          </motion.div>

          {/* 4. Overseer */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-[var(--theme-glass-bg)] backdrop-blur-md border border-[var(--theme-glass-border)] rounded-3xl p-6 hover:bg-[var(--theme-primary)]/10 transition-all duration-300 shadow-xl">
            <div className="flex items-center gap-4 mb-6 border-b border-[var(--theme-glass-border)] pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-accent)]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
              </div>
              <h3 className="text-2xl font-bold text-white">Overseer</h3>
            </div>
            <ul className="space-y-4 text-gray-200 font-medium">
              <li className="flex items-center gap-3"><span className="text-2xl">👤</span> Face ID Login</li>
              <li className="flex items-center gap-3"><span className="text-2xl">✍️</span> Manage Events Diary</li>
              <li className="flex items-center gap-3"><span className="text-2xl">📊</span> Generate Balance Sheets</li>
              <li className="flex items-center gap-3"><span className="text-2xl">⛪</span> Manage District / Branch</li>
            </ul>
          </motion.div>

          {/* 5. Admin */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-[var(--theme-glass-bg)] backdrop-blur-md border border-[var(--theme-glass-border)] rounded-3xl p-6 hover:bg-[var(--theme-primary)]/10 transition-all duration-300 shadow-xl lg:col-span-2">
            <div className="flex items-center gap-4 mb-6 border-b border-[var(--theme-glass-border)] pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-accent)]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
              </div>
              <h3 className="text-2xl font-bold text-white">Admin</h3>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <ul className="space-y-4 text-gray-200 font-medium">
                <li className="flex items-center gap-3"><span className="text-2xl">🛡️</span> Supreme System Governance</li>
                <li className="flex items-center gap-3"><span className="text-2xl">👤</span> High-Security Face ID Login</li>
                <li className="flex items-center gap-3"><span className="text-2xl">📈</span> Advanced Spreadsheet Comparisons</li>
              </ul>
              <ul className="space-y-4 text-gray-200 font-medium">
                <li className="flex items-center gap-3"><span className="text-2xl">👥</span> View Total Church Membership</li>
                <li className="flex items-center gap-3"><span className="text-2xl">📑</span> Overseer Financial Data Access</li>
                <li className="flex items-center gap-3"><span className="text-2xl">⚙️</span> Platform Policy Enforcement</li>
              </ul>
            </div>
          </motion.div>
        </motion.section>
 

        {/* Closing CTA */}
        <motion.section 
          initial={{ opacity: 0, scale: 0.9 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8, type: "spring" }}
          className="w-full bg-gradient-to-r from-[var(--theme-primary)]/40 to-[var(--theme-bg-end)] border border-[var(--theme-primary)]/30 rounded-3xl p-10 md:p-16 text-center shadow-[0_0_50px_rgba(37,99,235,0.2)]"
        >
          <h2 className="text-3xl font-bold text-white mb-4">Join Our Growing Community</h2>
          <p className="text-gray-300 font-light max-w-2xl mx-auto mb-8">
            Whether you are seeking spiritual guidance, looking to connect with a local branch, or want to learn more about our student programs, our doors are open.
          </p>
           
        </motion.section>

      </div>
      
      <style dangerouslySetInnerHTML={{__html: `
        .custom-scrollbar::-webkit-scrollbar {
          width: 8px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.05);
          border-radius: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.2);
          border-radius: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(255, 255, 255, 0.3);
        }
      `}} />
    </main>
  );
}