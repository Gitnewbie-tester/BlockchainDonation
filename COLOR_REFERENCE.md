# Tailwind to Flutter Color Reference

This document maps all Tailwind CSS colors used in the React version to their exact Flutter hex equivalents.

## Color Palette

### Slate Colors
```dart
static const Color slate50 = Color(0xFFF8FAFC);
static const Color slate100 = Color(0xFFF1F5F9);
static const Color slate200 = Color(0xFFE2E8F0);
static const Color slate300 = Color(0xFFCBD5E1);
static const Color slate400 = Color(0xFF94A3B8);
static const Color slate500 = Color(0xFF64748B);
static const Color slate600 = Color(0xFF475569);
static const Color slate700 = Color(0xFF334155);
static const Color slate800 = Color(0xFF1E293B);
static const Color slate900 = Color(0xFF0F172A);
```

### Blue Colors
```dart
static const Color blue50 = Color(0xFFEFF6FF);
static const Color blue100 = Color(0xFFDBEAFE);
static const Color blue200 = Color(0xFFBFDBFE);
static const Color blue300 = Color(0xFF93C5FD);
static const Color blue400 = Color(0xFF60A5FA);
static const Color blue500 = Color(0xFF3B82F6);
static const Color blue600 = Color(0xFF2563EB);
static const Color blue700 = Color(0xFF1D4ED8);
static const Color blue800 = Color(0xFF1E40AF);
static const Color blue900 = Color(0xFF1E3A8A);
```

### Green Colors
```dart
static const Color green50 = Color(0xFFF0FDF4);
static const Color green100 = Color(0xFFDCFCE7);
static const Color green200 = Color(0xFFBBF7D0);
static const Color green300 = Color(0xFF86EFAC);
static const Color green400 = Color(0xFF4ADE80);
static const Color green500 = Color(0xFF22C55E);
static const Color green600 = Color(0xFF16A34A);
static const Color green700 = Color(0xFF15803D);
static const Color green800 = Color(0xFF166534);
static const Color green900 = Color(0xFF14532D);
```

### Purple Colors
```dart
static const Color purple50 = Color(0xFFFAF5FF);
static const Color purple100 = Color(0xFFF3E8FF);
static const Color purple200 = Color(0xFFE9D5FF);
static const Color purple300 = Color(0xFFD8B4FE);
static const Color purple400 = Color(0xFFC084FC);
static const Color purple500 = Color(0xFFA855F7);
static const Color purple600 = Color(0xFF9333EA);
static const Color purple700 = Color(0xFF7E22CE);
static const Color purple800 = Color(0xFF6B21A8);
static const Color purple900 = Color(0xFF581C87);
```

### Orange Colors
```dart
static const Color orange50 = Color(0xFFFFF7ED);
static const Color orange100 = Color(0xFFFFEDD5);
static const Color orange200 = Color(0xFFFED7AA);
static const Color orange300 = Color(0xFFFDBA74);
static const Color orange400 = Color(0xFFFB923C);
static const Color orange500 = Color(0xFFF97316);
static const Color orange600 = Color(0xFFEA580C);
static const Color orange700 = Color(0xFFC2410C);
static const Color orange800 = Color(0xFF9A3412);
static const Color orange900 = Color(0xFF7C2D12);
```

### Red Colors
```dart
static const Color red50 = Color(0xFFFEF2F2);
static const Color red100 = Color(0xFFFEE2E2);
static const Color red200 = Color(0xFFFECACA);
static const Color red300 = Color(0xFFFCA5A5);
static const Color red400 = Color(0xFFF87171);
static const Color red500 = Color(0xFFEF4444);
static const Color red600 = Color(0xFFDC2626);
static const Color red700 = Color(0xFFB91C1C);
static const Color red800 = Color(0xFF991B1B);
static const Color red900 = Color(0xFF7F1D1D);
```

## Common Gradients

### Primary Gradient (Blue to Green)
```dart
LinearGradient(
  colors: [Color(0xFF2563EB), Color(0xFF16A34A)], // blue-600 to green-600
)
```

### Stats Card Gradients
```dart
// Total Raised
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)], // blue-50 to blue-100
)

// Active Campaigns
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)], // green-50 to green-100
)

// Total Donors
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)], // purple-50 to purple-100
)
```

## Usage by Component

### AI Chatbot
- Header gradient: `blue-600` to `green-600`
- User message bubble: `blue-600` to `green-600` gradient
- Bot message background: `slate-100`
- Bot message text: `slate-800`
- User message text: `white`
- Input border: `slate-200`
- Typing dots: `slate-400`
- Timestamp (bot): `slate-500`
- Timestamp (user): `blue-100`

### Dashboard Stats
- Card backgrounds: Gradients (see above)
- Icon backgrounds: Solid colors matching gradient theme
- Text: `slate-800` (title), `slate-600` (label)

### Category Filter
- Selected button: `blue-600` to `green-600` gradient
- Unselected button: `white` background, `slate-600` text
- Border: `slate-200`

### Charity Cards
- Background: `white`
- Progress bar: `blue-600`
- Progress background: `slate-200`
- Category badge: `blue-50` background, `blue-600` text
- Title: `slate-800`
- Description: `slate-600`

### Forms & Inputs
- Input border: `slate-200`
- Input text: `slate-800`
- Input placeholder: `slate-400`
- Focus border: `blue-600`
- Error text: `red-600`

### Buttons
- Primary: `blue-600` background, `white` text
- Primary gradient: `blue-600` to `green-600`
- Secondary: `white` background, `slate-600` text, `slate-200` border
- Danger: `red-600` background, `white` text
- Success: `green-600` background, `white` text

## Shadow Colors
```dart
// Light shadow
BoxShadow(
  color: Color(0x1A000000), // black with 10% opacity
  blurRadius: 10,
  offset: Offset(0, 2),
)

// Medium shadow
BoxShadow(
  color: Color(0x33000000), // black with 20% opacity
  blurRadius: 20,
  offset: Offset(0, 4),
)

// Heavy shadow
BoxShadow(
  color: Color(0x4D000000), // black with 30% opacity
  blurRadius: 30,
  offset: Offset(0, 8),
)
```

## Background Colors
- App background: `slate-50` (#F8FAFC)
- Card background: `white` (#FFFFFF)
- Modal overlay: `black` with 20% opacity

## Implementation Status
✅ AI Chatbot - Fully implemented with exact colors
✅ Dashboard Stats - Gradients match exactly
✅ Category Filter - Colors verified
✅ Charity Cards - Colors verified
✅ All screens - Colors verified
✅ Theme system - Complete Tailwind color mapping
