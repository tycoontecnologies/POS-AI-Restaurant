import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "Tycoon POS | Restaurant Operations", description: "Tycoon Restaurant Point of Sale", applicationName: "Tycoon POS" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }