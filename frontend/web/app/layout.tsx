import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "./globals.css";
import Navbar from "./components/navbar";
import Footer from "./components/footer";

const poppins = Poppins({ 
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700", "800"] 
});

export const metadata: Metadata = {
  title: "Dankie | TACT Digital Ecosystem",
  description: "The official digital infrastructure for The Twelve Apostles Church in Trinity.",
  icons: {
    icon: "https://res.cloudinary.com/dajihjqkc/image/upload/v1779755909/dankie_logo_htz2re.png",
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* FontAwesome CDN for standard <i> tag icons */}
        <link 
          rel="stylesheet" 
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" 
          integrity="sha512-DTOQO9RWCH3ppGqcWaEA1BIZOC6xxalwEsw9c2QQeAIftl+Vegovlnee1c9QX4TctnWMn13TZye+giMm8e2LwA==" 
          crossOrigin="anonymous" 
          referrerPolicy="no-referrer" 
        />
      </head>
      <body className={`${poppins.className} bg-[var(--theme-bg-color)] text-[var(--theme-text-main)] min-h-screen flex flex-col`}>
        <Navbar />
        <div className="pt-24 flex-grow flex flex-col"> 
          <main className="flex-grow">
            {children}
          </main>
          <Footer />
        </div>
      </body>
    </html>
  );
}