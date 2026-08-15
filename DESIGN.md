# Design System: EduSchedule Pro (Academic Logic)

Extracted from Stitch Project: **EduSchedule Pro** (`projects/11921135442576229005`)

---

## 1. Overview & Brand Personality

- **Brand Personality**: Authoritative, functional, and modern corporate aesthetic tailored for academic administration and timetable automation.
- **Visual Style**: Functional minimalism with clear surface-on-base layering, high contrast, and reduced glare for administrative management.
- **Primary Goal**: Reduce cognitive load in scheduling through systematic visual hierarchy, clear color coding, and responsive multi-device layouts.

---

## 2. Color Palette

### Primary & Accent Colors
| Tokens | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| **Primary** | `#3525CD` / `#4F46E5` | Primary brand accent, main call-to-action buttons, active states |
| **Secondary** | `#006591` / `#0EA5E9` | Secondary actions, badges, interactive highlights |
| **Tertiary** | `#7E3000` / `#A44100` | Warning indicators, special class highlights |
| **Neutral Surface** | `#F8F9FF` | Cool-toned background canvas |
| **Surface Variant** | `#D3E4FE` / `#E5EEFF` | Subdued surface containers and matrix grid headers |
| **On-Surface / Text** | `#0B1C30` | Primary text and dark contrast headers |

### System Status & Feedback Colors
- **Success / Confirmed Cover**: `#10B981` (10% opacity container `#ECFDF5`, 100% opacity badge text)
- **Warning / Open Leave**: `#F59E0B` (10% opacity container `#FEF3C7`, 100% opacity text)
- **Danger / Conflict / Error**: `#BA1A1A` (Container `#FFDAD6`, On-Error `#93000A`)
- **Info / Swap Request**: `#0EA5E9` (Container `#E0F2FE`, On-Info `#0369A1`)

---

## 3. Typography

**Primary Font Family**: `Inter` (used exclusively across all viewports)

| Style Token | Font Size | Line Height | Weight | Letter Spacing | Target Use |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `display-lg` | 48px | 56px | Bold (`700`) | `-0.02em` | Desktop Hero Titles |
| `headline-lg` | 32px | 40px | Semi-Bold (`600`) | `-0.01em` | Section Headers / Page Titles |
| `headline-lg-mobile`| 24px | 32px | Semi-Bold (`600`) | Standard | Mobile Screen Headers |
| `title-md` | 20px | 28px | Semi-Bold (`600`) | Standard | Card Titles & Modal Headers |
| `body-md` | 16px | 24px | Regular (`400`) | Standard | Body Paragraphs, Primary List Items |
| `body-sm` | 14px | 20px | Regular (`400`) | Standard | Secondary Metadata, Subtitles |
| `label-md` | 12px | 16px | Semi-Bold (`600`) | `0.05em` | Grid Headers, Pill Badges, Category Tags |

---

## 4. Spacing & Rhythm

Built on an **8px grid rhythm** (4px for micro-spacing):

- **Base Unit**: `4px` (`spacingScale = 2`)
- **Card Gap**: `16px`
- **Gutter**: `24px`
- **Mobile Container Padding**: `16px`
- **Desktop Container Padding**: `32px`

---

## 5. Shape & Corner Radii

- **Cards / Main Containers**: `16px` (`1rem`)
- **Buttons / Inputs**: `8px` (`0.5rem`)
- **Status Badges / Chips**: `9999px` (Full Pill)

---

## 6. Component Specs

### Buttons
1. **Primary Action**: Solid `#4F46E5` background, `#FFFFFF` text, `8px` border radius, elevated shadow.
2. **Secondary Action**: Ghost border (`#4F46E5` 1px stroke) or soft Sky Blue `#E0F2FE` fill.
3. **1-Tap Quick Action**: Pill badge button with auto-icon indicator (`Icons.auto_awesome`).

### Cards & Surfaces
- **Level 0 (Canvas)**: Background `#F8F9FF`.
- **Level 1 (Card Container)**: Pure `#FFFFFF` background with subtle 8px blur shadow (`opacity: 4%`). `16px` border radius.
- **Level 2 (Hover/Interaction)**: Elevated 16px shadow depth (`opacity: 8%`) with 1px stroke `#CBD5E1`.

### Navigation Controls
- **Desktop Navigation**: Fixed-width sidebar (`280px`) with active route background highlight (`#E5EEFF`).
- **Mobile Navigation**: Fixed bottom navigation bar (`64px` height) with icon + `12px` label.
- **Segmented Role Selector**: Pill-shaped tab bar (Student / Faculty / Admin) with sliding background selector.

---

## 7. Layouts & Timetable Grid System

### Weekly Timetable 2D Matrix Grid
- **Columns**: Time Periods (`9:00-9:55`, `9:55-10:50`, `Tea Break`, `11:05-12:00`, `12:00-12:55`, `Lunch`, `1:55-2:50`, `2:50-3:45`, `Tea Break`, `3:55-4:50`).
- **Rows**: Days of the week (`Monday` to `Sunday`).
- **Sticky Column/Header**: Leftmost Day column remains pinned during horizontal scrolling.
- **Grid Cell Rendering**:
  - Course Code in **Bold**
  - Faculty Name
  - Room Number (`Room: R006`)
  - Status Color Overlay (Break / Special Class / Open Leave / Covered Class)

---

## 8. Responsive & Adaptive Behavior

- **Mobile Viewports (<768px)**:
  - Compressed page padding (`16px`).
  - 4-column layout stack.
  - Horizontal scrolling matrix grid for timetable view with sticky day column.
  - Bottom navigation bar replacing sidebar.
- **Desktop Viewports (>=768px)**:
  - Expanded page padding (`32px`).
  - 12-column layout grid.
  - Full side-by-side timetable matrix view.
  - Fixed 280px left navigation sidebar.
