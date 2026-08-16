// GENERATED FILE — DO NOT EDIT. Source: design/tokens.json (run design/build-tokens.py)
//
// The same tokens the desktop is built from. Import these rather than retyping
// a hex: with `as const`, a wrong name is a type error instead of a slightly
// wrong blue that nobody notices for a month.

export const color = {
  "bg-0": "#eef1f8",
  "bg-1": "#f8fbff",
  "bg-2": "#dceaf8",
  "border": "#bed7eb",
  "text-1": "#1b4c78",
  "text-2": "#466a9d",
  "accent": "#3478c4",
  "accent-dim": "#2e68a8",
  "glow": "#4a8cd033",
  "shade": "#1f466b",
  "accent-ink": "#ffffff",
  "field-base": "#7cb8e8",
  "field-mid": "#a8d3f2",
  "field-high": "#eef1f8",
  "field-edge": "#edf6ff",
  "field-line": "#e6f4ff",
} as const;

export const space = {
  "xs": 4,
  "sm": 8,
  "md": 12,
  "lg": 16,
  "xl": 24,
  "xxl": 32,
} as const;

export const radius = {
  "sm": 8,
  "md": 12,
  "lg": 16,
  "xl": 24,
  "full": 999,
} as const;

export const type = {
  family: ["Geist", "Inter Display"],
  size: {
  "caption": 11,
  "body": 13,
  "title": 15,
},
  weight: {
  "light": 300,
  "regular": 400,
},
  trackingEm: 0.02,
} as const;

export const motion = {
  // Feed straight into a CSS transition; the shell and compositor use the same.
  ease: "cubic-bezier(0.22, 1.0, 0.36, 1.0)",
  bezier: [0.22, 1.0, 0.36, 1.0],
  duration: {
  "fast": 150,
  "base": 250,
  "slow": 400,
},
  stagger: 24,
} as const;

// Surfaces you work IN are dark; chrome you work WITH is light. This is the
// dark family — editors, Spotify and the terminal all derive from it.
export const terminal = {
  background: "#14293f",
  foreground: "#dfe9f4",
  cursor: "#8cc6f7",
  ansi: ["#1b3350", "#d9738a", "#5cb894", "#d2b46e", "#6aa8e6", "#a98fd8", "#63bfd6", "#c3d3e4", "#4d6b8f", "#ee8ba0", "#79d2ac", "#ecd08c", "#8cc6f7", "#c1a9ef", "#85dbef", "#f2f7fc"],
} as const;

export type ColorToken = keyof typeof color;
export type SpaceToken = keyof typeof space;
export type RadiusToken = keyof typeof radius;

export const tokens = { color, space, radius, type, motion, terminal } as const;
export default tokens;
