"use client";

import Link from "next/link";
import Image from "next/image";

const IMG_LOGO = "https://res.cloudinary.com/dajihjqkc/image/upload/v1779755909/dankie_logo_htz2re.png";

export default function Footer() {
  return (
    <footer className="w-full mt-16 bg-[var(--theme-card-bg)] shadow-[0_-10px_40px_rgba(0,0,0,0.03)] text-[var(--theme-text-main)]">
      <div className="max-w-7xl mx-auto px-6 py-12 md:py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 md:gap-8">
          
          {/* Brand & Mission */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <div className="relative w-16 h-16 rounded-full bg-white flex items-center justify-center mb-4 shadow-sm border border-gray-100 overflow-hidden">
              <Image src={IMG_LOGO} alt="Dankie Logo" fill className="object-contain p-1.5" />
            </div>
            <h3 className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-primary)] to-[var(--theme-primary-hover)] mb-2">
              Dankie
            </h3>
            <p className="text-sm text-[var(--theme-text-muted)] font-normal leading-relaxed">
              The official digital platform for The Twelve Apostles Church in Trinity. Connecting members globally.
            </p>
          </div>

          {/* Quick Links */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-[var(--theme-text-main)] mb-4">Portals</h4>
            <nav className="flex flex-col gap-3">
              <Link href="/" className="text-[var(--theme-text-muted)] hover:text-[var(--theme-primary)] transition-colors text-sm font-medium">Member Access</Link>
              <Link href="/" className="text-[var(--theme-text-muted)] hover:text-[var(--theme-primary)] transition-colors text-sm font-medium">TACTSO</Link>
              <Link href="/" className="text-[var(--theme-text-muted)] hover:text-[var(--theme-primary)] transition-colors text-sm font-medium">Seller Dashboard</Link>
              <Link href="/" className="text-[var(--theme-text-muted)] hover:text-[var(--theme-primary)] transition-colors text-sm font-medium">Overseer Admin</Link>
            </nav>
          </div>

          {/* Contact Details */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-[var(--theme-text-main)] mb-4">Administration</h4>
            <div className="space-y-3 text-sm text-[var(--theme-text-muted)] font-medium">
              <p>✉️ dankiecommunications@gmail.com</p>
              <p className="leading-relaxed">
                📍 Central Administration<br/>
                The Twelve Apostles Church<br/>
                in Trinity
              </p>
            </div>
          </div>

          {/* Socials & Community */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-[var(--theme-text-main)] mb-4">Our Community</h4>
            <p className="text-sm text-[var(--theme-text-muted)] font-normal mb-4">
              Stay updated with the latest church events, bursaries, and historical archives.
            </p>
            
            <h4 className="text-sm font-bold text-[var(--theme-text-main)] mb-3 uppercase tracking-wider">Follow Us</h4>
            <div className="flex gap-3">
              {/* Facebook */}
              <a href="https://facebook.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-gray-500 hover:bg-[#1877F2] hover:text-white transition-all shadow-sm" aria-label="Facebook">
                <i className="fa-brands fa-facebook-f text-lg"></i>
              </a>
              {/* Instagram */}
              <a href="https://instagram.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-gray-500 hover:bg-[#E4405F] hover:text-white transition-all shadow-sm" aria-label="Instagram">
                <i className="fa-brands fa-instagram text-lg"></i>
              </a>
              {/* YouTube */}
              <a href="https://youtube.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-gray-500 hover:bg-[#FF0000] hover:text-white transition-all shadow-sm" aria-label="YouTube">
                <i className="fa-brands fa-youtube text-lg"></i>
              </a>
            </div>
          </div>
          
        </div>
        
        {/* Copyright */}
        <div className="mt-12 pt-8 border-t border-gray-100 text-center flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-xs text-[var(--theme-text-muted)] font-medium">
            © {new Date().getFullYear()} Dankie. The Twelve Apostles Church in Trinity. All rights reserved.
          </p>
          <div className="flex gap-4 text-xs text-[var(--theme-text-muted)] font-medium">
            <Link href="/policy-privacy" className="hover:text-[var(--theme-primary)] transition-colors">Privacy Policy</Link>
            <Link href="/terms-and-conditions" className="hover:text-[var(--theme-primary)] transition-colors">Terms of Service</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}