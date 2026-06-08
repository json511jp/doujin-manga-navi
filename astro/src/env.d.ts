/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />

declare namespace App {
  interface SiteLocals {
    siteName: string;
    siteDescription: string;
    siteUrl: string;
    tagline: string;
    contactEmail: string;
    ctaLabel: string;
    features: {
      actresses: boolean;
      sampleMovie: boolean;
      trialReading: boolean;
      duration: boolean;
      director: boolean;
      maker: boolean;
      vrBadge: boolean;
    };
    affiliate: {
      programName: string;
      ageRestricted: boolean;
    };
  }

  interface Locals {
    adminUser: { email: string } | null;
    themeVars: string;
    siteSettings: SiteLocals;
    customCss: string;
  }
}

interface ImportMetaEnv {
  readonly PUBLIC_SUPABASE_URL: string;
  readonly PUBLIC_SUPABASE_ANON_KEY: string;
  readonly PUBLIC_GA4_ID: string;
  readonly SUPABASE_URL: string;
  readonly SUPABASE_SERVICE_ROLE_KEY: string;
  readonly ADMIN_EMAIL: string;
  readonly GITHUB_TOKEN?: string;
  readonly GITHUB_REPO?: string;
  readonly GITHUB_DEFAULT_BRANCH?: string;
}
