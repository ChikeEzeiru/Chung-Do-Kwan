import type { Metadata } from 'next';
import { ClerkProvider } from '@clerk/nextjs';
import './globals.css';

export const metadata: Metadata = {
  title: 'Chung-Do Kwan Quiz Dojo',
  description: 'A 24-hour recall trainer for the Chung-Do Kwan white-to-orange belt manual.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body><ClerkProvider>{children}</ClerkProvider></body>
    </html>
  );
}
