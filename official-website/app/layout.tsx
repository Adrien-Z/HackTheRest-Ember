import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host");
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "https";
  const origin = host ? `${protocol}://${host}` : "https://ember.rest";

  return {
    metadataBase: new URL(origin),
    title: "EMBER — Sleep is a skill. We coach it.",
    description:
      "EMBER turns your sleep, calendar, and environment into a personalized plan for tonight.",
    icons: {
      icon: "/assets/ember-app-icon.png",
      apple: "/assets/ember-app-icon.png",
    },
    openGraph: {
      title: "EMBER — Sleep is a skill. We coach it.",
      description:
        "A personal rest coach that turns your real life into a better plan for tonight.",
      type: "website",
      images: [{ url: `${origin}/og.png`, width: 1200, height: 630, alt: "EMBER — Sleep is a skill. We coach it." }],
    },
    twitter: {
      card: "summary_large_image",
      title: "EMBER — Sleep is a skill. We coach it.",
      description:
        "A personal rest coach that turns your real life into a better plan for tonight.",
      images: [`${origin}/og.png`],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
