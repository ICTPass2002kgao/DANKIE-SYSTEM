"use client";

import Link from "next/link";

export default function Footer() {
  return (
    <footer className="w-full mt-16 bg-black/40 backdrop-blur-xl border-t border-white/10 text-white">
      <div className="max-w-7xl mx-auto px-6 py-12 md:py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 md:gap-8">
          
          {/* Brand & Mission */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <div className="w-16 h-16 rounded-full bg-blue-900/30 flex items-center justify-center text-blue-400 text-2xl mb-4 border border-blue-500/30 shadow-[0_0_15px_rgba(37,99,235,0.2)]">
              T
            </div>
            <h3 className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-white mb-2">
              Dankie
            </h3>
            <p className="text-sm text-gray-400 font-light leading-relaxed">
              The official digital ecosystem for The Twelve Apostles Church in Trinity. Connecting members globally.
            </p>
          </div>

          {/* Quick Links */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-blue-400 mb-4">Portals</h4>
            <nav className="flex flex-col gap-3">
              <Link href="/" className="text-gray-300 hover:text-white transition-colors text-sm font-light">Member Access</Link>
              <Link href="/" className="text-gray-300 hover:text-white transition-colors text-sm font-light">TACTSO </Link>
              <Link href="/" className="text-gray-300 hover:text-white transition-colors text-sm font-light">Seller Dashboard</Link>
              <Link href="/" className="text-gray-300 hover:text-white transition-colors text-sm font-light">Overseer Admin</Link>
            </nav>
          </div>

          {/* Contact Details */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-blue-400 mb-4">Administration</h4>
            <div className="space-y-3 text-sm text-gray-300 font-light">
              <p>✉️ support@dankieapp.com</p>
              <p className="leading-relaxed">
                📍 Central Administration<br/>
                The Twelve Apostles Church<br/>
                in Trinity
              </p>
            </div>
          </div>

          {/* Socials & Community */}
          <div className="flex flex-col items-center md:items-start text-center md:text-left">
            <h4 className="text-lg font-bold text-blue-400 mb-4">Our Community</h4>
            <p className="text-sm text-gray-300 font-light mb-4">
              Stay updated with the latest church events, bursaries, and historical archives.
            </p>
            
            <h4 className="text-sm font-bold text-blue-400 mb-3 uppercase tracking-wider">Follow Us</h4>
            <div className="flex gap-3">
              {/* Facebook */}
              <a href="https://facebook.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-gray-300 hover:bg-[#1877F2] hover:border-[#1877F2] hover:text-white transition-all" aria-label="Facebook">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path fillRule="evenodd" d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12z" clipRule="evenodd" />
                </svg>
              </a>
              {/* Instagram */}
              <a href="https://instagram.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-gray-300 hover:bg-[#E4405F] hover:border-[#E4405F] hover:text-white transition-all" aria-label="Instagram">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path fillRule="evenodd" d="M12.315 2c2.43 0 2.784.013 3.808.06 1.064.049 1.791.218 2.427.465a4.902 4.902 0 011.772 1.153 4.902 4.902 0 011.153 1.772c.247.636.416 1.363.465 2.427.048 1.067.06 1.407.06 4.123v.08c0 2.643-.012 2.987-.06 4.043-.049 1.064-.218 1.791-.465 2.427a4.902 4.902 0 01-1.153 1.772 4.902 4.902 0 01-1.772 1.153c-.636.247-1.363.416-2.427.465-1.067.048-1.407.06-4.123.06h-.08c-2.643 0-2.987-.012-4.043-.06-1.064-.049-1.791-.218-2.427-.465a4.902 4.902 0 01-1.772-1.153 4.902 4.902 0 01-1.153-1.772c-.247-.636-.416-1.363-.465-2.427-.047-1.024-.06-1.379-.06-3.808v-.63c0-2.43.013-2.784.06-3.808.049-1.064.218-1.791.465-2.427a4.902 4.902 0 011.153-1.772A4.902 4.902 0 015.45 2.525c.636-.247 1.363-.416 2.427-.465C8.901 2.013 9.256 2 11.685 2h.63zm-.081 1.802h-.468c-2.456 0-2.784.011-3.807.058-.975.045-1.504.207-1.857.344-.467.182-.8.398-1.15.748-.35.35-.566.683-.748 1.15-.137.353-.3.882-.344 1.857-.047 1.023-.058 1.351-.058 3.807v.468c0 2.456.011 2.784.058 3.807.045.975.207 1.504.344 1.857.182.466.399.8.748 1.15.35.35.683.566 1.15.748.353.137.882.3 1.857.344 1.054.048 1.37.058 4.041.058h.08c2.597 0 2.917-.01 3.96-.058.976-.045 1.505-.207 1.858-.344.466-.182.8-.398 1.15-.748.35-.35.566-.683.748-1.15.137-.353.3-.882.344-1.857.048-1.055.058-1.37.058-4.041v-.08c0-2.597-.01-2.917-.058-3.96-.045-.976-.207-1.505-.344-1.858a3.097 3.097 0 00-.748-1.15 3.098 3.098 0 00-1.15-.748c-.353-.137-.882-.3-1.857-.344-1.023-.047-1.351-.058-3.807-.058zM12 6.865a5.135 5.135 0 110 10.27 5.135 5.135 0 010-10.27zm0 1.802a3.333 3.333 0 100 6.666 3.333 3.333 0 000-6.666zm5.338-3.205a1.2 1.2 0 110 2.4 1.2 1.2 0 010-2.4z" clipRule="evenodd" />
                </svg>
              </a>
              {/* YouTube */}
              <a href="https://youtube.com" target="_blank" rel="noopener noreferrer" className="w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-gray-300 hover:bg-[#FF0000] hover:border-[#FF0000] hover:text-white transition-all" aria-label="YouTube">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path fillRule="evenodd" d="M21.582 6.186a2.684 2.684 0 00-1.884-1.895C17.973 3.82 12 3.82 12 3.82s-5.973 0-7.698.471a2.684 2.684 0 00-1.884 1.895C2 7.922 2 12 2 12s0 4.078.418 5.814a2.684 2.684 0 001.884 1.895c1.725.471 7.698.471 7.698.471s5.973 0 7.698-.471a2.684 2.684 0 001.884-1.895C22 16.078 22 12 22 12s0-4.078-.418-5.814zM9.99 15.484V8.516l6.51 3.484-6.51 3.484z" clipRule="evenodd" />
                </svg>
              </a>
            </div>
          </div>
          
        </div>
        
        {/* Copyright */}
        <div className="mt-12 pt-8 border-t border-white/5 text-center flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-xs text-gray-500">
            © {new Date().getFullYear()} Dankie. The Twelve Apostles Church in Trinity. All rights reserved.
          </p>
          <div className="flex gap-4 text-xs text-gray-500">
            <Link href="/policy-privacy" className="hover:text-blue-400 transition-colors">Privacy Policy</Link>
            <Link href="/terms-and-conditions" className="hover:text-blue-400 transition-colors">Terms of Service</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}