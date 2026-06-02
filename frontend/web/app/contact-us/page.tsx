"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import { MapPin, Mail } from "lucide-react";

export default function ContactUs() {
  const [formData, setFormData] = useState({ firstName: "", lastName: "", email: "", message: "" });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState("");

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({ ...formData, [e.target.id]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setStatusMessage("");

    try {
      const BACKEND_NODE_JS = "https://api-7gbt42tr6q-uc.a.run.app";
      
      const response = await fetch(`${BACKEND_NODE_JS}/sendCustomEmail`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json" 
        },
        body: JSON.stringify({
          to: "dankiecommunications@gmail.com",
          subject: `Dankie App Support Inquiry from ${formData.firstName} ${formData.lastName} (${formData.email})`,
          body: `From: ${formData.firstName} ${formData.lastName}\nEmail: ${formData.email}\n\nMessage:\n${formData.message}`,
          attachmentUrl: "",
        }),
      });

      if (response.ok) {
        const result = await response.json();
        if (result.success === true) {
          setStatusMessage("Message sent successfully. Our support team will review your inquiry.");
          setFormData({ firstName: "", lastName: "", email: "", message: "" });
        } else {
          setStatusMessage("Transmission failed. Please try again.");
        }
      } else {
        let errorMessage = "Unknown Server Error";
        try {
          const errorData = await response.json();
          if (errorData && errorData.error) {
            errorMessage = errorData.error;
          }
        } catch (_) {
          errorMessage = await response.text();
        }
        console.error('Server Error:', errorMessage);
        setStatusMessage(`Transmission failed: ${errorMessage}`);
      }
    } catch (error) {
      console.error('Exception:', error);
      setStatusMessage("Network error. Please check your connection.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="w-full max-w-6xl mx-auto p-6 md:p-16 flex flex-col items-center relative z-10">
      <div className="w-full grid grid-cols-1 md:grid-cols-2 gap-12">
        
        {/* Support Info Side */}
        <motion.div 
          initial={{ opacity: 0, x: -50 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8 }}
          className="flex flex-col justify-center"
        >
          <h1 className="text-4xl md:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-[var(--theme-primary)] to-[var(--theme-primary-hover)] mb-6">
            Support & Inquiries
          </h1>
          <p className="text-[var(--theme-text-muted)] font-normal mb-10 text-lg">
            Need assistance with your portal access, TACTSO applications, or marketplace listings? Contact the Dankie system administration team.
          </p>

          <div className="space-y-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)] shrink-0 shadow-sm">
                <MapPin className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-[var(--theme-text-main)] text-lg">Headquarters</h3>
                <p className="text-[var(--theme-text-muted)] font-normal mt-1">The Twelve Apostles Church in Trinity<br/>Central Administration Office</p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-full bg-[var(--theme-primary)]/10 flex items-center justify-center text-[var(--theme-primary)] shrink-0 shadow-sm">
                <Mail className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-[var(--theme-text-main)] text-lg">System Support</h3>
                <p className="text-[var(--theme-text-muted)] font-normal mt-1">dankiecommunications@gmail.com</p>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Contact Form Side */}
        <motion.div 
          initial={{ opacity: 0, x: 50 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="bg-[var(--theme-card-bg)] rounded-3xl p-8 shadow-xl border border-gray-100"
        >
          <form className="space-y-6" onSubmit={handleSubmit}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="flex flex-col gap-2">
                <label htmlFor="firstName" className="text-sm font-medium text-[var(--theme-text-main)] ml-1">First Name</label>
                <input type="text" id="firstName" value={formData.firstName} onChange={handleChange} required className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-[var(--theme-text-main)] placeholder-gray-400 focus:outline-none focus:border-[var(--theme-primary)] focus:ring-1 focus:ring-[var(--theme-primary)] transition-all" placeholder="First Name" />
              </div>
              <div className="flex flex-col gap-2">
                <label htmlFor="lastName" className="text-sm font-medium text-[var(--theme-text-main)] ml-1">Last Name</label>
                <input type="text" id="lastName" value={formData.lastName} onChange={handleChange} required className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-[var(--theme-text-main)] placeholder-gray-400 focus:outline-none focus:border-[var(--theme-primary)] focus:ring-1 focus:ring-[var(--theme-primary)] transition-all" placeholder="Last Name" />
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <label htmlFor="email" className="text-sm font-medium text-[var(--theme-text-main)] ml-1">Email Address</label>
              <input type="email" id="email" value={formData.email} onChange={handleChange} required className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-[var(--theme-text-main)] placeholder-gray-400 focus:outline-none focus:border-[var(--theme-primary)] focus:ring-1 focus:ring-[var(--theme-primary)] transition-all" placeholder="Email" />
            </div>

            <div className="flex flex-col gap-2">
              <label htmlFor="message" className="text-sm font-medium text-[var(--theme-text-main)] ml-1">Inquiry Details</label>
              <textarea id="message" rows={5} value={formData.message} onChange={handleChange} required className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-[var(--theme-text-main)] placeholder-gray-400 focus:outline-none focus:border-[var(--theme-primary)] focus:ring-1 focus:ring-[var(--theme-primary)] transition-all resize-none" placeholder="Describe your issue or inquiry..."></textarea>
            </div>

            {statusMessage && (
              <div className={`p-4 rounded-xl text-sm font-semibold ${statusMessage.includes("successfully") ? "bg-green-50 text-green-700 border border-green-200" : "bg-red-50 text-red-700 border border-red-200"}`}>
                {statusMessage}
              </div>
            )}

            <button type="submit" disabled={isSubmitting} className={`w-full text-white font-bold py-4 rounded-xl transition-all shadow-md ${isSubmitting ? "bg-blue-400 cursor-not-allowed" : "bg-[var(--theme-primary)] hover:bg-[var(--theme-primary-hover)] hover:shadow-lg"}`}>
              {isSubmitting ? "Transmitting..." : "Submit Inquiry"}
            </button>
          </form>
        </motion.div>

      </div>
    </main>
  );
}