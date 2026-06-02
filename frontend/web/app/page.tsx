"use client";

import { motion } from "framer-motion";
import type { Variants } from "framer-motion";
import Link from "next/link";
import Image from "next/image"; 

// Replace with your actual logo URL when ready
const IMG_LOGO = "https://res.cloudinary.com/dajihjqkc/image/upload/v1779755909/dankie_logo_htz2re.png"; 
const BG_IMAGE = "https://res.cloudinary.com/dajihjqkc/image/upload/v1780435393/IMG_1832_ytemp8.jpg";

export default function Page() { 
  const container: Variants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.15,
        delayChildren: 0.2,
      },
    },
  };

  const item: Variants = {
    hidden: { opacity: 0, y: 40 },
    show: {
      opacity: 1,
      y: 0,
      transition: { type: "spring", stiffness: 100, damping: 20 } as any,
    },
  };

  return (
    <main className="min-h-screen bg-[#f1f5f9] text-[var(--theme-text-main)] flex flex-col items-center relative overflow-hidden">
      
      {/* Background Layer: Image + Ambient Glow Effects */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none z-0">
        
        {/* Hero Background Image */}
        <div className="absolute top-0 left-0 w-full h-[110vh]">
          <Image 
            src={BG_IMAGE}
            alt="Church Choir Background"
            fill
            className="object-cover opacity-40 blur-[2px]" 
            priority
          />
          {/* Gradient mask to blend the bottom of the image into the page background color */}
          <div className="absolute inset-0 bg-gradient-to-b from-white/40 via-[#f1f5f9]/80 to-[#f1f5f9]"></div>
        </div>

        {/* Glassmorphic Ambient Orbs */}
        <motion.div 
          animate={{ scale: [1, 1.15, 1], opacity: [0.3, 0.4, 0.3], rotate: [0, 90, 0] }}
          transition={{ duration: 15, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[-15%] left-[-10%] w-[50vw] h-[50vw] bg-blue-300/40 rounded-full blur-[100px]"
        />
        <motion.div 
          animate={{ scale: [1, 1.2, 1], opacity: [0.2, 0.3, 0.2], rotate: [0, -90, 0] }}
          transition={{ duration: 18, repeat: Infinity, ease: "easeInOut", delay: 2 }}
          className="absolute bottom-[-10%] right-[-5%] w-[45vw] h-[45vw] bg-cyan-200/40 rounded-full blur-[120px]"
        />
      </div>

      <div className="w-full max-w-7xl relative z-10 px-6 md:px-16 pt-12 pb-24">
        
        {/* Hero Section */}
        <motion.section 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: "easeOut" }}
          className="w-full flex flex-col items-center text-center py-20 mb-16"
        >
          {/* Animated White Logo Container - Glassmorphic Base */}
          <motion.div 
            animate={{ y: [0, -10, 0] }}
            transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
            className="relative w-28 h-28 md:w-32 md:h-32 rounded-full bg-white/70 backdrop-blur-md flex items-center justify-center mb-8 shadow-[0_8px_32px_rgba(37,99,235,0.15)] border border-white overflow-hidden"
          >
            {IMG_LOGO ? (
              <Image src={IMG_LOGO} alt="Dankie Logo" fill className="object-contain p-2" />
            ) : (
              <span className="text-[var(--theme-primary)] font-black text-xs tracking-widest uppercase">LOGO</span>
            )}
          </motion.div>

          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight mb-6 text-[var(--theme-text-main)] leading-tight">
            The Twelve Apostles <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-primary)] to-[var(--theme-primary-hover)] drop-shadow-sm">
              Church in Trinity
            </span>
          </h1>
          <p className="text-lg md:text-xl text-[var(--theme-text-muted)] font-medium max-w-3xl mx-auto mb-10 leading-relaxed">
            A spiritual home bridging centuries of legacy with modern community connection. Welcome to Dankie—our official digital ecosystem for faith, education, and growth.
          </p>
          
          {/* App Download Buttons */}
          <div className="flex flex-wrap gap-6 items-center justify-center">
            
            {/* iOS App */}
            <motion.div whileHover={{ scale: 1.05, y: -2 }} whileTap={{ scale: 0.95 }}>
              <Link href="https://apps.apple.com/za/app/dankie-mobile/id6767526580" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white/70 backdrop-blur-xl border border-white/80 text-black transition-all shadow-[0_8px_30px_rgba(0,0,0,0.06)] hover:shadow-[0_8px_30px_rgba(37,99,235,0.15)] hover:bg-white/90">
                <i className="fa-brands fa-apple text-4xl"></i>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-500">Download on the</span>
                  <span className="text-xl font-bold leading-tight">App Store</span>
                </div>
              </Link>
            </motion.div>

            {/* Android App */}
            <motion.div whileHover={{ scale: 1.05, y: -2 }} whileTap={{ scale: 0.95 }}>
              <Link href="https://play.google.com/store/apps/details?id=com.thetact.ttact" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white/70 backdrop-blur-xl border border-white/80 text-black transition-all shadow-[0_8px_30px_rgba(0,0,0,0.06)] hover:shadow-[0_8px_30px_rgba(37,99,235,0.15)] hover:bg-white/90">
                <i className="fa-brands fa-google-play text-3xl"></i>
                <div className="text-left flex flex-col pl-1">
                  <span className="text-xs leading-none font-medium text-gray-500">GET IT ON</span>
                  <span className="text-xl font-bold leading-tight">Google Play</span>
                </div>
              </Link>
            </motion.div>

            {/* Huawei AppGallery */}
            <motion.div whileHover={{ scale: 1.05, y: -2 }} whileTap={{ scale: 0.95 }}>
              <Link href="https://appgallery.huawei.com/app/C115359927" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-white/70 backdrop-blur-xl border border-white/80 text-black transition-all shadow-[0_8px_30px_rgba(0,0,0,0.06)] hover:shadow-[0_8px_30px_rgba(37,99,235,0.15)] hover:bg-white/90">
                <i className="fa-solid fa-bag-shopping text-3xl text-red-600"></i>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-gray-500">EXPLORE IT ON</span>
                  <span className="text-xl font-bold leading-tight">AppGallery</span>
                </div>
              </Link>
            </motion.div>

            {/* Web App */}
            <motion.div whileHover={{ scale: 1.05, y: -2 }} whileTap={{ scale: 0.95 }}>
              <Link href="/" className="flex items-center gap-4 px-8 py-4 rounded-2xl bg-[var(--theme-primary)]/90 backdrop-blur-xl border border-[var(--theme-primary)] text-white transition-all shadow-[0_8px_30px_rgba(37,99,235,0.2)] hover:bg-[var(--theme-primary)]">
                <i className="fa-solid fa-globe text-3xl"></i>
                <div className="text-left flex flex-col">
                  <span className="text-xs leading-none font-medium text-blue-200">ACCESS ONLINE</span>
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
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.8 }}
          className="w-full bg-white/50 backdrop-blur-xl border border-white/70 rounded-3xl p-8 md:p-12 mb-24 shadow-[0_8px_32px_rgba(0,0,0,0.04)] flex flex-col md:flex-row items-center gap-12 group hover:bg-white/70 hover:shadow-[0_8px_32px_rgba(37,99,235,0.08)] transition-all duration-500"
        >
          <div className="flex-1">
            <h2 className="text-3xl font-bold text-[var(--theme-text-main)] mb-4">A Legacy Since 1770</h2>
            <p className="text-[var(--theme-text-muted)] font-medium leading-relaxed mb-6">
              Our roots run deep. For centuries, The Twelve Apostles Church in Trinity has provided spiritual guidance, community support, and an unbroken lineage of apostolic teachings. 
            </p>
            <p className="text-[var(--theme-text-muted)] font-medium leading-relaxed mb-8">
              Today, through the Dankie platform, we bring our rich history into the future—allowing members to stream archival greetings from our founding apostles while building a vibrant, modern community.
            </p>
            <Link href="/about-us" className="text-[var(--theme-primary)] font-bold hover:text-[var(--theme-primary-hover)] transition-colors flex items-center gap-2 group-hover:translate-x-2 duration-300">
              Read our full story <i className="fa-solid fa-arrow-right text-sm"></i>
            </Link>
          </div>
          <div className="flex-1 w-full h-64 md:h-80 bg-white/40 border border-white/80 rounded-2xl flex items-center justify-center relative overflow-hidden shadow-inner">
            <motion.div 
              animate={{ rotate: 360 }}
              transition={{ duration: 60, repeat: Infinity, ease: "linear" }}
              className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-[var(--theme-primary)] to-transparent"
            />
            <i className="fa-solid fa-globe text-7xl text-[var(--theme-primary)]/80 relative z-10 drop-shadow-lg"></i>
          </div>
        </motion.section>

        {/* The Dankie Ecosystem - Icon Driven Roles */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.5 }}
          transition={{ duration: 0.8 }}
          className="w-full text-center mb-12"
        >
          <h2 className="text-3xl md:text-4xl font-bold text-[var(--theme-text-main)] mb-4">A Purpose-Built Ecosystem</h2>
        </motion.div>

        <motion.section 
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, amount: 0.1 }}
          className="w-full grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-24"
        >
          {/* 1. Member */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-white/60 backdrop-blur-xl border border-white/80 rounded-3xl p-6 hover:bg-white/90 hover:shadow-[0_8px_30px_rgba(37,99,235,0.1)] transition-all duration-300 shadow-[0_8px_24px_rgba(0,0,0,0.04)]">
            <div className="flex items-center gap-4 mb-6 border-b border-gray-200/50 pb-4">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[var(--theme-primary)] shadow-sm border border-gray-100">
                <i className="fa-solid fa-circle-user text-2xl"></i>
              </div>
              <h3 className="text-2xl font-bold text-[var(--theme-text-main)]">Member</h3>
            </div>
            <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
              <li className="flex items-center gap-3"><i className="fa-regular fa-calendar text-[var(--theme-primary)] w-5 text-center"></i> View Church Events</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-location-dot text-[var(--theme-primary)] w-5 text-center"></i> Locate Nearby Branches</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-music text-[var(--theme-primary)] w-5 text-center"></i> Stream & Download Music</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-graduation-cap text-[var(--theme-primary)] w-5 text-center"></i> Apply for Bursaries</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-scroll text-[var(--theme-primary)] w-5 text-center"></i> View Apostle Greetings (1770+)</li>
            </ul>
          </motion.div>

          {/* 2. TACTSO */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-white/60 backdrop-blur-xl border border-white/80 rounded-3xl p-6 hover:bg-white/90 hover:shadow-[0_8px_30px_rgba(37,99,235,0.1)] transition-all duration-300 shadow-[0_8px_24px_rgba(0,0,0,0.04)]">
            <div className="flex items-center gap-4 mb-6 border-b border-gray-200/50 pb-4">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[var(--theme-primary)] shadow-sm border border-gray-100">
                <i className="fa-solid fa-graduation-cap text-2xl"></i>
              </div>
              <h3 className="text-2xl font-bold text-[var(--theme-text-main)]">TACTSO</h3>
            </div>
            <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
              <li className="flex items-center gap-3"><i className="fa-solid fa-school text-[var(--theme-primary)] w-5 text-center"></i> Apply to Universities</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-lock text-[var(--theme-primary)] w-5 text-center"></i> Strict Document Encryption</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-clipboard-list text-[var(--theme-primary)] w-5 text-center"></i> Digital Attendance Registers</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-users text-[var(--theme-primary)] w-5 text-center"></i> Committee Assistance</li>
            </ul>
          </motion.div>

          {/* 3. Seller */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-white/60 backdrop-blur-xl border border-white/80 rounded-3xl p-6 hover:bg-white/90 hover:shadow-[0_8px_30px_rgba(37,99,235,0.1)] transition-all duration-300 shadow-[0_8px_24px_rgba(0,0,0,0.04)]">
            <div className="flex items-center gap-4 mb-6 border-b border-gray-200/50 pb-4">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[var(--theme-primary)] shadow-sm border border-gray-100">
                <i className="fa-solid fa-cart-shopping text-2xl"></i>
              </div>
              <h3 className="text-2xl font-bold text-[var(--theme-text-main)]">Seller</h3>
            </div>
            <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
              <li className="flex items-center gap-3"><i className="fa-solid fa-tag text-[var(--theme-primary)] w-5 text-center"></i> Add Products & Services</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-cart-arrow-down text-[var(--theme-primary)] w-5 text-center"></i> Set Custom Prices</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-box text-[var(--theme-primary)] w-5 text-center"></i> Manage Deliveries</li>
              <li className="flex items-center gap-3"><i className="fa-regular fa-credit-card text-[var(--theme-primary)] w-5 text-center"></i> Sell to Church Community</li>
            </ul>
          </motion.div>

          {/* 4. Overseer */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-white/60 backdrop-blur-xl border border-white/80 rounded-3xl p-6 hover:bg-white/90 hover:shadow-[0_8px_30px_rgba(37,99,235,0.1)] transition-all duration-300 shadow-[0_8px_24px_rgba(0,0,0,0.04)]">
            <div className="flex items-center gap-4 mb-6 border-b border-gray-200/50 pb-4">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[var(--theme-primary)] shadow-sm border border-gray-100">
                <i className="fa-solid fa-user-gear text-2xl"></i>
              </div>
              <h3 className="text-2xl font-bold text-[var(--theme-text-main)]">Overseer</h3>
            </div>
            <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
              <li className="flex items-center gap-3"><i className="fa-solid fa-id-badge text-[var(--theme-primary)] w-5 text-center"></i> Face ID Login</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-calendar-days text-[var(--theme-primary)] w-5 text-center"></i> Manage Events Diary</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-file-excel text-[var(--theme-primary)] w-5 text-center"></i> Generate Balance Sheets</li>
              <li className="flex items-center gap-3"><i className="fa-solid fa-church text-[var(--theme-primary)] w-5 text-center"></i> Manage District / Branch</li>
            </ul>
          </motion.div>

          {/* 5. Admin */}
          <motion.div variants={item} whileHover={{ y: -8, scale: 1.02 }} className="bg-white/60 backdrop-blur-xl border border-white/80 rounded-3xl p-6 hover:bg-white/90 hover:shadow-[0_8px_30px_rgba(37,99,235,0.1)] transition-all duration-300 shadow-[0_8px_24px_rgba(0,0,0,0.04)] lg:col-span-2">
            <div className="flex items-center gap-4 mb-6 border-b border-gray-200/50 pb-4">
              <div className="w-12 h-12 bg-[var(--theme-primary)]/10 border border-[var(--theme-primary)]/20 rounded-full flex items-center justify-center text-[var(--theme-primary)] shadow-sm">
                <i className="fa-solid fa-shield-halved text-2xl"></i>
              </div>
              <h3 className="text-2xl font-bold text-[var(--theme-text-main)]">Admin</h3>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
                <li className="flex items-center gap-3"><i className="fa-solid fa-database text-[var(--theme-primary)] w-5 text-center"></i> Supreme System Governance</li>
                <li className="flex items-center gap-3"><i className="fa-solid fa-id-badge text-[var(--theme-primary)] w-5 text-center"></i> High-Security Face ID Login</li>
                <li className="flex items-center gap-3"><i className="fa-solid fa-arrow-trend-up text-[var(--theme-primary)] w-5 text-center"></i> Advanced Spreadsheet Comparisons</li>
              </ul>
              <ul className="space-y-4 text-[var(--theme-text-muted)] font-medium">
                <li className="flex items-center gap-3"><i className="fa-solid fa-users text-[var(--theme-primary)] w-5 text-center"></i> View Total Church Membership</li>
                <li className="flex items-center gap-3"><i className="fa-solid fa-file-invoice-dollar text-[var(--theme-primary)] w-5 text-center"></i> Overseer Financial Data Access</li>
                <li className="flex items-center gap-3"><i className="fa-solid fa-gear text-[var(--theme-primary)] w-5 text-center"></i> Platform Policy Enforcement</li>
              </ul>
            </div>
          </motion.div>
        </motion.section>
 
        {/* Closing CTA */}
        <motion.section 
          initial={{ opacity: 0, scale: 0.9 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true, amount: 0.5 }}
          transition={{ duration: 0.8, type: "spring" }}
          className="w-full bg-white/50 backdrop-blur-xl border border-white/80 rounded-3xl p-10 md:p-16 text-center shadow-[0_8px_32px_rgba(37,99,235,0.08)] relative overflow-hidden"
        >
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[80%] h-full bg-[var(--theme-primary)]/5 blur-3xl pointer-events-none rounded-full"></div>
          <h2 className="text-3xl font-bold text-[var(--theme-text-main)] mb-4 relative z-10">Join Our Growing Community</h2>
          <p className="text-[var(--theme-text-muted)] font-medium max-w-2xl mx-auto relative z-10">
            Whether you are seeking spiritual guidance, looking to connect with a local branch, or want to learn more about our student programs, our doors are open.
          </p>
        </motion.section>

      </div>
    </main>
  );
}