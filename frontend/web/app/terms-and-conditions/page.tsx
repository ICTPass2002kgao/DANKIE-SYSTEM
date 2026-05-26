"use client";

import { motion } from "framer-motion";

export default function Terms() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-[var(--theme-bg-start)] via-[var(--theme-bg-mid)] to-[var(--theme-bg-end)] text-white flex flex-col items-center relative overflow-hidden px-6 py-12 md:px-16 md:py-24">
      
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

      <div className="w-full max-w-5xl relative z-10">
        {/* Terms and Conditions Section */}
        <motion.section 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="w-full bg-[#0a0a0a]/80 backdrop-blur-xl border border-gray-800 rounded-3xl p-8 md:p-12 shadow-2xl"
        >
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 border-b border-gray-800 pb-6">
            <div>
              <h2 className="text-3xl font-bold text-white mb-2">Terms & Conditions</h2>
              <p className="text-gray-400 text-sm">Effective Date: 5 January 2026 | Jurisdiction: Republic of South Africa</p>
            </div>
            <div className="mt-4 md:mt-0 px-4 py-2 bg-gray-800/50 rounded-lg border border-gray-700 text-xs text-gray-300">
              Service Provider: Dankie (TACT)
            </div>
          </div>
          
          <div className="h-96 overflow-y-auto pr-4 text-gray-300 text-sm space-y-6 custom-scrollbar">
            
            <div>
              <h3 className="text-white font-bold text-lg mb-2">1. ACCEPTANCE OF TERMS</h3>
              <p className="leading-relaxed">By downloading, installing, accessing, browsing, registering on, or otherwise using the Dankie mobile application, website, or any related services (collectively referred to as the “Platform”), you confirm that you have read, understood, and agreed to be legally bound by these Terms and Conditions (“Terms”). If you do not agree to these Terms, you must immediately discontinue all use of the Platform. Continued use of the Platform constitutes ongoing acceptance of these Terms as amended from time to time. These Terms constitute a legally binding agreement between you (“the User”) and Dankie, which is operated by the Twelve Apostles Church in Trinity (TACT), a religious organisation operating within the Republic of South Africa.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">2. DEFINITIONS</h3>
              <ul className="list-disc pl-5 space-y-1">
                <li><strong>Admin:</strong> Means authorised persons responsible for system governance, product listings, access control, and policy enforcement.</li>
                <li><strong>Overseer / Father:</strong> Means a senior church leader responsible for the administration of a District or Branch, including member oversight and financial reporting.</li>
                <li><strong>Committee Member:</strong> Means a user appointed by an Overseer or Admin to perform administrative, financial, or TACTSO-related duties.</li>
                <li><strong>Member:</strong> Means a registered user who belongs to the Twelve Apostles Church in Trinity.</li>
                <li><strong>External Member:</strong> Means a registered user who does not belong to TACT.</li>
                <li><strong>Guest:</strong> Means an unregistered user with limited read-only access.</li>
                <li><strong>Seller:</strong> Means a user authorised to offer goods or services through the Marketplace.</li>
                <li><strong>TACTSO:</strong> Refers to the student organisation component of the Platform facilitating academic and university-related assistance.</li>
              </ul>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">3. ACCOUNT REGISTRATION AND ELIGIBILITY</h3>
              <p className="font-semibold text-white mt-3 mb-1">3.1 Guest Access</p>
              <p>Guests may access limited content such as sermons, music previews, TACTSO branch information, and career listings. Guests may not download content, submit applications, record financial data, or participate in restricted services.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">3.2 Proxy Registration (Elderly Member Clause)</p>
              <p>Where an Overseer or Committee Member registers an account on behalf of another individual who is unable to use the Platform independently (including elderly members), the registering party warrants that: They have obtained the individual’s informed consent (verbal or written); All information provided is accurate and up to date; They accept responsibility for any inaccuracies or misrepresentations entered on behalf of that individual. Dankie relies on the honesty of such representations and bears no liability for disputes arising from proxy registration.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">3.3 Account Security</p>
              <p>Users are responsible for maintaining the confidentiality of their login credentials and for all activities conducted under their account. Dankie shall not be liable for losses arising from unauthorised access resulting from user negligence.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">3.4 Account Suspension and Termination</p>
              <p>Dankie reserves the right, at its sole discretion, to suspend, restrict, or permanently terminate any user account without prior notice where there is reasonable suspicion of: Fraud, misrepresentation, or unlawful activity; Abuse of proxy registration privileges; Deliberate falsification or manipulation of financial records; Unauthorised use or misuse of biometric authentication; Any breach of these Terms or applicable laws. Termination does not extinguish outstanding obligations or liabilities incurred prior to termination. Affected users may submit an appeal via the in-app Help page. Dankie is not obligated to reinstate access following an appeal.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">4. BIOMETRIC AUTHENTICATION</h3>
              <p className="font-semibold text-white mt-3 mb-1">4.1 Purpose and Mandatory Use</p>
              <p>Facial recognition biometric authentication is mandatory for Overseers and Committee Members in order to: Verify identity; Secure access to sensitive financial and administrative tools; Maintain accountability for actions performed on the Platform.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">4.2 Consent to Processing</p>
              <p>By using biometric authentication, you provide explicit consent for Dankie to process your biometric information (facial images and facial geometry templates) strictly for identity verification and security purposes.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">4.3 Third-Party Uploads</p>
              <p>Where biometric data is uploaded by another authorised user (e.g., Admin or Overseer), the uploader warrants that explicit consent has been obtained from the data subject. Dankie disclaims all liability arising from biometric data uploaded without lawful consent.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">4.4 Biometric Data Deletion</p>
              <p>Biometric data is deleted immediately and permanently upon removal of Overseer or Committee privileges. No biometric data is retained beyond the period of active authorisation.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">5. MARKETPLACE AND COMMISSIONS</h3>
              <p className="font-semibold text-white mt-3 mb-1">5.1 Platform Role</p>
              <p>Dankie operates solely as a digital marketplace facilitator. Dankie is not the seller, manufacturer, or distributor of goods or services offered on the Platform. Any contract of sale is concluded exclusively between the Buyer and the Seller.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">5.2 Commission Structure</p>
              <p>Dankie charges an 8% platform commission on completed transactions. This commission excludes VAT and any applicable taxes unless otherwise stated.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">5.3 Seller Payouts</p>
              <p>Sellers are responsible for providing accurate banking details. Dankie shall not be liable for losses arising from incorrect banking information supplied by Sellers.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">5.4 Seller Obligations</p>
              <p>Sellers are solely responsible for: Product availability and delivery; Quality, specifications, size, and colour accuracy; Compliance with applicable laws and standards.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">5.5 Refunds, Chargebacks, and Disputes</p>
              <p>Dankie does not issue refunds. Refunds, returns, and disputes must be resolved directly between Buyer and Seller. In the event of disputes or chargebacks, Dankie reserves the right to: Temporarily withhold Seller payouts; Reverse previously paid commissions where fraud or abuse is proven; Suspend or permanently remove Seller access.</p>
              
              <p className="font-semibold text-white mt-3 mb-1">5.6 Tax and VAT Responsibility</p>
              <p>Sellers are solely responsible for all tax obligations, including VAT registration (where applicable), income tax reporting, and issuance of compliant tax invoices. Dankie does not provide tax advice and bears no responsibility for Seller compliance with SARS.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">6. OVERSEER SUBSCRIPTIONS & FINANCIAL REPORTING</h3>
              <p className="font-semibold text-white mt-3 mb-1">6.1 Subscription Tiers</p>
              <p>Subscription fees are charged monthly based on member count: 0–49: Free | 50–199: R189 | 200–399: R389 | 400+: R689</p>
              <p className="font-semibold text-white mt-3 mb-1">6.2 Non-Payment</p>
              <p>Failure to pay subscription fees will result in restricted access to reports and financial tools until payment is settled.</p>
              <p className="font-semibold text-white mt-3 mb-1">6.3 Financial Accuracy Disclaimer</p>
              <p>All financial data is user-generated. Dankie is not an accounting firm and does not audit or verify financial records.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">7. TACTSO & UNIVERSITY APPLICATIONS</h3>
              <p><strong>7.1 Eligibility:</strong> TACTSO services are available exclusively to registered TACT Members.</p>
              <p><strong>7.2 “Ask for Help” Function:</strong> By uploading documents and selecting “Ask for Help”, you appoint an authorised Committee Member as a limited agent to submit applications on your behalf.</p>
              <p><strong>7.3 No Admission Guarantee:</strong> Dankie does not guarantee admission outcomes. All admission decisions remain solely with educational institutions.</p>
              <p><strong>7.4 Audit Trail:</strong> All actions related to TACTSO applications are logged in an immutable audit system for accountability.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">8. CAREERS AND EXTERNAL LINKS</h3>
              <p>Dankie aggregates third-party opportunities for convenience. Dankie does not verify or endorse third-party recruiters and bears no responsibility for external engagements.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">9. INTELLECTUAL PROPERTY</h3>
              <p>All sermons, music, historical records, and official content belong to TACT. Users are granted a limited licence to share links for non-commercial, spiritual, or promotional purposes only.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">10. LIMITATION OF LIABILITY</h3>
              <p>To the maximum extent permitted by law, Dankie shall not be liable for indirect, incidental, or consequential damages, including loss of data, loss of income, or rejection from academic institutions.</p>
              <p className="font-semibold text-white mt-3 mb-1">10.1 Force Majeure</p>
              <p>Dankie shall not be liable for service interruptions caused by events beyond reasonable control, including load shedding, internet outages, cloud service downtime, strikes, or acts of God.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">11. GOVERNING LAW</h3>
              <p>These Terms are governed by the laws of the Republic of South Africa.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">12. AMENDMENTS</h3>
              <p>Dankie may amend these Terms from time to time. Material changes will be communicated via email. Continued use constitutes acceptance.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">13. USER-GENERATED CONTENT</h3>
              <p>Users retain ownership of uploaded content but grant Dankie a non-exclusive, royalty-free licence to store and process such content for service delivery.</p>
            </div>

            <div>
              <h3 className="text-white font-bold text-lg mb-2">14. SERVICE PROVIDER</h3>
              <p>Dankie is operated by the Twelve Apostles Church in Trinity (TACT).</p>
            </div>

          </div>
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