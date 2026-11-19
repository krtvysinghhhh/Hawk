# HAWK DESIGN SYSTEM — SPECIFICATION & GUIDELINES
## Monochromatic Aesthetics, Design Tokens & SwiftUI Component Library

**Version:** 2.0.0  
**Design Philosophy:** Minimalist, Distraction-Free, Monochromatic Navigation with Single Accent Focus  
**Platform:** iOS 17.0+ (SwiftUI 5+)  

---

## 1. Visual Hierarchy & Philosophy

The HAWK Design System is engineered to eliminate the visual noise common in modern streaming applications. Rather than using rainbow-colored icons and saturated background panels that compete with album cover art, HAWK adopts an Apple-grade monochromatic hierarchy.

### Core Principles:
1. **Content is King:** Album art and typography take center stage; chrome and controls recede into the background.
2. **Monochromatic Navigation:** All library category icons share the exact same monochrome tint (`HawkLibraryStyle.iconTint`).
3. **Single Focused Accent:** Muted Violet (`#8878B5` Dark / `#6F5B9C` Light) is reserved strictly for primary interactive states, active playback indicators, and CTA highlights.
4. **Physical Haptics & Springs:** Standardized spring curves (`response: 0.25`, `dampingFraction: 0.75`) and subtle scale feedback (`0.97`) on all interactive surfaces.

---

## 2. Color Palette & Semantic Tokens

```
Dark AMOLED Palette:
┌──────────────────────────┬──────────┬────────────────────────┐
│ Semantic Token           │ Hex      │ Description            │
├──────────────────────────┼──────────┼────────────────────────┤
│ amoledBackground         │ #08090B  │ Deep true-black canvas │
│ amoledNavigation         │ #101114  │ Docked bottom bar      │
│ amoledElevatedSurface    │ #17191D  │ Card & list container  │
│ amoledSecondarySurface   │ #1D2025  │ Tiles, chips & inputs  │
│ amoledTextPrimary        │ #F4F3F0  │ High-contrast headers  │
│ amoledTextSecondary      │ #A3A5AA  │ Subtitles & metadata   │
│ amoledTextTertiary       │ #777A82  │ Captions & icons       │
│ amoledAccent             │ #8878B5  │ Focused Muted Violet   │
│ amoledDivider            │ #292C32  │ Subtle hairline border │
└──────────────────────────┴──────────┴────────────────────────┘

Light Clean Palette:
┌──────────────────────────┬──────────┬────────────────────────┐
│ Semantic Token           │ Hex      │ Description            │
├──────────────────────────┼──────────┼────────────────────────┤
│ lightBackground          │ #F7F7F5  │ Warm light canvas      │
│ lightNavigation          │ #FFFFFF  │ Pure white bottom bar  │
│ lightElevatedSurface     │ #FFFFFF  │ White card background  │
│ lightSecondarySurface    │ #F0F0EE  │ Light gray input/tile  │
│ lightTextPrimary         │ #17181B  │ Deep charcoal text     │
│ lightTextSecondary       │ #666970  │ Secondary body text    │
│ lightTextTertiary        │ #858890  │ Captions & icons       │
│ lightAccent              │ #6F5B9C  │ Deep Violet accent     │
│ lightDivider             │ #E5E5E2  │ Light separator border │
└──────────────────────────┴──────────┴────────────────────────┘
```

---

## 3. Typography Hierarchy (`HawkTypography`)

All font tokens utilize Apple SF Pro with tailored weights and tracking:

| Token | Size | Weight | Tracking | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `largeTitle` | 34pt | Bold | -0.4pt | Large navigation titles, top hero greetings |
| `title1` | 28pt | Bold | -0.3pt | View section titles |
| `title2` | 22pt | Bold | -0.2pt | Carousel headings |
| `title3` | 20pt | Semibold | 0.0pt | Subsection headers |
| `headline` | 17pt | Semibold | -0.1pt | Track titles, card headers |
| `body` | 17pt | Regular | 0.0pt | Standard text, list items |
| `callout` | 16pt | Regular | 0.0pt | Callout banners |
| `subheadline` | 15pt | Regular | 0.0pt | Artist names, secondary rows |
| `footnote` | 13pt | Regular | 0.0pt | Timestamps, durations, stats |
| `caption1` | 12pt | Regular | +0.2pt | Metadata tags, badges |
| `caption2` | 11pt | Regular | +0.4pt | Small indicators, mono digits |

---

## 4. Spacing & Corner Geometry

### Spacing Grid (`HawkSpacing`)
- `xxs`: 4pt
- `xs`: 8pt
- `sm`: 12pt
- `md`: 16pt (Standard page margin & list item padding)
- `lg`: 20pt
- `xl`: 24pt
- `xxl`: 32pt
- `huge`: 40pt

### Corner Radii (`HawkRadius`)
- `xs`: 4pt (Micro badges)
- `sm`: 8pt (Tiles, buttons, checkboxes)
- `md`: 12pt (Album cards, input fields)
- `lg`: 16pt (Primary card surfaces, mini-player)
- `xl`: 20pt (Modal sheets, hero banners)
- `pill`: 9999pt (Circular buttons, filter chips)

---

## 5. Standard Component Catalog

### 5.1 `HawkButton`
```swift
HawkButton("Sync Now", icon: "arrow.clockwise", style: .primary, size: .medium) {
    // Action trigger
}
```
Supports `.primary` (solid accent), `.secondary` (card background + border), `.ghost` (clear background), and `.destructive` (red).

### 5.2 `HawkIconButton`
Circular feedback button for transport controls and modal dismissals:
```swift
HawkIconButton(icon: "heart.fill", size: .medium, variant: .tinted, tint: HawkTheme.primaryAccent) {
    // Favorite toggle
}
```

### 5.3 `HawkArtwork`
High-performance asynchronous image loader:
```swift
HawkArtwork(url: song.artworkURL, size: 56, cornerRadius: HawkRadius.md)
```
Automatically preserves aspect ratio, falls back to a monochromatic placeholder, and paints a subtle 0.5pt border.

### 5.4 `HawkListRow`
Universal list row with selection support:
```swift
HawkListRow(
    title: song.title,
    subtitle: song.artist,
    isSelected: selectedSongIds.contains(song.id),
    isSelectionMode: isEditing
) {
    HawkArtwork(url: song.artworkURL, size: 48)
} trailing: {
    Text(Song.formatDuration(song.duration))
}
```

### 5.5 `HawkSearchField`
```swift
HawkSearchField(text: $query, placeholder: "Search songs, artists, playlists...")
```

### 5.6 `HawkEmptyState`, `HawkLoadingState`, `HawkErrorState`
State-driven container views for complete user guidance without raw spinners or blank canvases.
