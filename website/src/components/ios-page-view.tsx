"use client";

import { useEffect } from "react";
import { track } from "@/lib/analytics";

export function IOSPageView() {
  useEffect(() => { track("ios_waitlist_viewed"); }, []);
  return null;
}
