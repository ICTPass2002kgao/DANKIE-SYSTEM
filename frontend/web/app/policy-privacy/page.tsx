"use client";

import { motion } from "framer-motion";

export default function PrivacyPolicy() {
  return (
    <main className="w-full flex flex-col items-center relative overflow-hidden px-6 py-12 md:px-16 md:py-24">
      
      {/* Ambient Glow Effects (Thematic Background) updated for light mode */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none z-0">
        <motion.div 
          animate={{ scale: [1, 1.2, 1], opacity: [0.1, 0.15, 0.1] }}
          transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[-10%] left-[-10%] w-[60vw] h-[60vw] bg-[var(--theme-primary)]/10 rounded-full blur-[120px]"
        />
        <motion.div 
          animate={{ scale: [1, 1.3, 1], opacity: [0.05, 0.1, 0.05] }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut", delay: 1 }}
          className="absolute bottom-[-10%] right-[-10%] w-[50vw] h-[50vw] bg-[var(--theme-primary)]/5 rounded-full blur-[100px]"
        />
      </div>

      <div className="w-full max-w-4xl relative z-10">
        
        {/* Privacy Policy Document Section */}
        <motion.section 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="w-full bg-[var(--theme-card-bg)] border border-gray-200 rounded-2xl p-8 md:p-14 shadow-xl"
        >
          {/* Header */}
          <div className="border-b border-gray-200 pb-8 mb-8">
            <h1 className="text-3xl md:text-4xl font-bold text-[var(--theme-text-main)] mb-6">PRIVACY POLICY</h1>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-[var(--theme-text-muted)]">
              <div>
                <p><strong className="text-[var(--theme-text-main)]">Effective Date:</strong> 5 January 2026</p>
                <p><strong className="text-[var(--theme-text-main)]">Last Updated:</strong> 22 May 2026</p>
              </div>
              <div>
                <p><strong className="text-[var(--theme-text-main)]">Jurisdiction:</strong> Republic of South Africa</p>
                <p><strong className="text-[var(--theme-text-main)]">Regulatory Compliance:</strong> POPIA & GDPR-aligned</p>
              </div>
            </div>
          </div>
          
          {/* Document Content */}
          <div className="text-[var(--theme-text-muted)] text-sm md:text-base leading-relaxed space-y-8">
            
            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">1. INTRODUCTION</h2>
              <p>
                Dankie (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;), operated by the Twelve Apostles Church in Trinity (TACT), is committed to maintaining the confidentiality, integrity, and security of your personal information. This Privacy Policy details the types of information we collect, why we collect it, how we use it, and the rights you have regarding your data.
              </p>
              <p className="mt-2">
                By downloading, accessing, or using the Dankie mobile application, you explicitly consent to the data collection and processing practices described herein.
              </p>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">2. INFORMATION COLLECTION</h2>
              <p className="mb-4">We collect information to provide specific services, improve app functionality, and ensure security. The data we collect falls into three categories:</p>
              
              <h3 className="text-[var(--theme-text-main)] font-semibold text-lg mt-4 mb-2">2.1 Information You Provide Directly</h3>
              <ul className="list-disc pl-6 space-y-2 mb-4">
                <li><strong>Account Registration:</strong> Name, surname, mobile number, email address, physical address, and church membership affiliation (Branch/District).</li>
                <li><strong>TACTSO Academic Data:</strong> Matric results, identification documents (ID numbers/passports), and academic transcripts for university application services.</li>
                <li><strong>Financial Data:</strong> Banking details (Bank name, account number, branch code) for payouts and transaction processing. Note: Sensitive payment card information is handled via secure, PCI-DSS compliant third-party payment gateways and is not stored on our servers.</li>
              </ul>

              <h3 className="text-[var(--theme-text-main)] font-semibold text-lg mt-4 mb-2">2.2 Automated Data Collection</h3>
              <p className="mb-2">When you use the Dankie app, we may automatically collect technical information, including:</p>
              <ul className="list-disc pl-6 space-y-2 mb-4">
                <li><strong>Device Information:</strong> Device model, operating system version, unique device identifiers, and IP address.</li>
                <li><strong>Usage Data:</strong> Features accessed, time spent on the app, and navigation patterns to help us improve user experience.</li>
                <li><strong>Diagnostics:</strong> Crash reports and performance logs to resolve technical issues.</li>
              </ul>

              <h3 className="text-[var(--theme-text-main)] font-semibold text-lg mt-4 mb-2">2.3 Biometric Information</h3>
              <p>For Overseers and Committee members, we collect facial geometry data for security authentication. This is classified as Special Personal Information under POPIA.</p>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">3. BIOMETRIC DATA & SECURITY POLICIES</h2>
              <p className="mb-2">We treat biometric data with the highest level of security:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Encryption:</strong> Facial data is converted into an encrypted mathematical template (embedding). We do not store raw photographs of your face on our servers.</li>
                <li><strong>Processing:</strong> Verification occurs either on-device or within a secure, encrypted cloud environment.</li>
                <li><strong>Non-Disclosure:</strong> Biometric data is strictly used for authentication and identity verification. It is never sold, traded, or used for surveillance, marketing, or third-party profiling.</li>
                <li><strong>Deletion:</strong> Upon the termination of your administrative role or account deletion, all biometric templates associated with your profile are permanently purged from our systems.</li>
              </ul>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">4. HOW WE USE YOUR INFORMATION</h2>
              <p className="mb-2">Your data is processed for the following legitimate interests:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Identity Verification:</strong> Ensuring authorized personnel only access administrative/financial tools.</li>
                <li><strong>Administrative Service:</strong> Managing church membership rolls and district organizational structures.</li>
                <li><strong>Transaction Management:</strong> Facilitating secure payouts and records for marketplace activities.</li>
                <li><strong>Academic Assistance:</strong> Assisting students with university applications through TACTSO.</li>
                <li><strong>Communication:</strong> Sending essential system notifications, security alerts, and organizational updates.</li>
              </ul>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">5. DATA SHARING & THIRD PARTIES</h2>
              <p className="mb-2">We do not sell your personal data. We share data only when necessary:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Service Providers:</strong> We utilize trusted third-party providers (e.g., Firebase, Cloud Hosting) to operate our infrastructure. These parties are contractually bound to maintain strict confidentiality and security standards.</li>
                <li><strong>Legal Compliance:</strong> We may disclose information if required by law, such as to comply with a subpoena, court order, or when we believe disclosure is necessary to protect our rights or the safety of our members.</li>
                <li><strong>Educational Institutions:</strong> With your explicit consent, we share student data with universities or bursary providers during the application process.</li>
              </ul>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">6. DATA RETENTION & SECURITY</h2>
              <p>
                We retain information for as long as necessary to fulfill the purposes for which it was collected or to comply with statutory legal requirements (e.g., SARS/Financial record-keeping for 5 years). We employ industry-standard security measures, including AES-256 encryption for data at rest and TLS 1.3 for data in transit, to prevent unauthorized access, alteration, or destruction of your information.
              </p>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">7. CHILDREN&apos;S PRIVACY</h2>
              <p>
                Dankie is intended for use by the church community, which may include minors. We do not knowingly collect personal information from children under the age of 13 without the verifiable consent of a parent or legal guardian. If you are a parent or guardian and believe your child has provided data, please contact us for immediate deletion.
              </p>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">8. YOUR RIGHTS UNDER POPIA</h2>
              <p className="mb-2">Under the Protection of Personal Information Act, you have the right to:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Right to Access:</strong> Request a record of the personal information we hold about you.</li>
                <li><strong>Right to Rectification:</strong> Request correction of inaccurate or incomplete data.</li>
                <li><strong>Right to Erasure:</strong> Request the deletion of your data (subject to our legal retention obligations).</li>
                <li><strong>Right to Object:</strong> Object to the processing of your data for specific purposes.</li>
              </ul>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">9. POLICY UPDATES</h2>
              <p>
                We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy within the app or via registered contact details. Your continued use of the app after such changes constitutes acceptance of the updated policy.
              </p>
            </div>

            <div>
              <h2 className="text-[var(--theme-text-main)] font-bold text-xl mb-3">10. CONTACT US</h2>
              <p>
                If you have questions regarding this policy or wish to exercise your privacy rights, please reach out to the TACT Administration office or use the support contact details provided within the &quot;Help&quot; section of the Dankie app.
              </p>
            </div>

          </div>
        </motion.section>
      </div>
    </main>
  );
}