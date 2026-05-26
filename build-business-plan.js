// Codepet Academy — Business Plan deck
// Run: node build-business-plan.js

const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const {
  FaRocket, FaGraduationCap, FaUsers, FaCoins, FaChartLine, FaShieldAlt,
  FaCog, FaBullseye, FaLightbulb, FaCheckCircle, FaCrown, FaSeedling,
  FaStore, FaPaintBrush, FaHandshake, FaSchool, FaGlobeAsia, FaStar,
  FaArrowRight, FaPlay, FaCode, FaPalette, FaMoneyBillWave, FaBrain,
  FaUserGraduate, FaBriefcase, FaQuestionCircle, FaFlag, FaBolt
} = require("react-icons/fa");

// ---------- Palette: "Twilight Founder" (Codepet brand) ----------
const C = {
  inkDeep:   "1A1240",   // deep navy-purple (dark slides)
  ink:       "2D2664",   // primary brand dark
  purple:    "534AB7",   // royal purple
  lavender:  "8B7BE8",   // brand lavender
  light:     "F5F3FA",   // pale purple bg (light slides)
  paper:     "FFFFFF",
  gold:      "D4A24C",   // premium accent
  goldLite:  "F4E4BC",
  charcoal:  "2D2B26",
  muted:     "6B6582",
  rule:      "E3DEF0",
  green:     "3FA67A",
  coral:     "E96A6A"
};

// ---------- Icon helper ----------
async function iconPng(IconComponent, hex, size = 256) {
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { color: "#" + hex, size: String(size) })
  );
  const buf = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

const makeShadow = () => ({
  type: "outer", blur: 10, offset: 2, angle: 90,
  color: "1A1240", opacity: 0.10
});

(async () => {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE";   // 13.333 × 7.5
  pres.author = "MURROR — Codepet";
  pres.title  = "Codepet Academy — Business Plan";
  const SW = 13.333, SH = 7.5;

  // Pre-render icons we'll reuse
  const ico = {
    rocket:    await iconPng(FaRocket, C.gold),
    grad:      await iconPng(FaGraduationCap, C.purple),
    users:     await iconPng(FaUsers, C.purple),
    coins:     await iconPng(FaCoins, C.gold),
    chart:     await iconPng(FaChartLine, C.purple),
    shield:    await iconPng(FaShieldAlt, C.purple),
    cog:       await iconPng(FaCog, C.purple),
    target:    await iconPng(FaBullseye, C.purple),
    bulb:      await iconPng(FaLightbulb, C.gold),
    check:     await iconPng(FaCheckCircle, C.green),
    crown:     await iconPng(FaCrown, C.gold),
    seed:      await iconPng(FaSeedling, C.green),
    store:     await iconPng(FaStore, C.purple),
    brush:     await iconPng(FaPaintBrush, C.lavender),
    hand:      await iconPng(FaHandshake, C.purple),
    school:    await iconPng(FaSchool, C.purple),
    globe:     await iconPng(FaGlobeAsia, C.purple),
    star:      await iconPng(FaStar, C.gold),
    arrow:     await iconPng(FaArrowRight, C.purple),
    code:      await iconPng(FaCode, C.purple),
    palette:   await iconPng(FaPalette, C.lavender),
    money:     await iconPng(FaMoneyBillWave, C.green),
    brain:     await iconPng(FaBrain, C.purple),
    junior:    await iconPng(FaSeedling, C.lavender),
    teen:      await iconPng(FaUserGraduate, C.lavender),
    operator:  await iconPng(FaBriefcase, C.lavender),
    q:         await iconPng(FaQuestionCircle, C.gold),
    flag:      await iconPng(FaFlag, C.gold),
    bolt:      await iconPng(FaBolt, C.gold),
    rocketLav: await iconPng(FaRocket, C.lavender),
    starWhite: await iconPng(FaStar, "FFFFFF"),
    crownWhite: await iconPng(FaCrown, "FFFFFF")
  };

  // ---------- Helpers ----------
  function pageHeader(slide, kicker, title) {
    // Kicker bar
    slide.addShape(pres.shapes.RECTANGLE, {
      x: 0.6, y: 0.55, w: 0.35, h: 0.07, fill: { color: C.gold }, line: { color: C.gold }
    });
    slide.addText(kicker, {
      x: 1.05, y: 0.42, w: 8, h: 0.35, margin: 0,
      fontFace: "Calibri", fontSize: 12, bold: true, color: C.purple, charSpacing: 4
    });
    slide.addText(title, {
      x: 0.6, y: 0.75, w: 12, h: 0.8, margin: 0,
      fontFace: "Georgia", fontSize: 32, bold: true, color: C.ink
    });
  }
  function footer(slide, n) {
    slide.addText("Codepet Academy  ·  Business Plan  ·  MURROR", {
      x: 0.6, y: SH - 0.4, w: 8, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 9, color: C.muted
    });
    slide.addText(String(n), {
      x: SW - 1, y: SH - 0.4, w: 0.4, h: 0.3, margin: 0, align: "right",
      fontFace: "Calibri", fontSize: 9, color: C.muted
    });
  }
  function lightBg(slide) { slide.background = { color: C.light }; }
  function darkBg(slide) { slide.background = { color: C.inkDeep }; }

  function card(slide, x, y, w, h, fill = C.paper) {
    slide.addShape(pres.shapes.RECTANGLE, {
      x, y, w, h, fill: { color: fill }, line: { color: C.rule, width: 0.5 },
      shadow: makeShadow()
    });
  }
  function accentBar(slide, x, y, h, color = C.purple) {
    slide.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 0.07, h, fill: { color }, line: { color }
    });
  }
  function iconCircle(slide, x, y, d, color, iconData) {
    slide.addShape(pres.shapes.OVAL, {
      x, y, w: d, h: d, fill: { color }, line: { color }
    });
    const pad = d * 0.22;
    slide.addImage({ data: iconData, x: x + pad, y: y + pad, w: d - 2*pad, h: d - 2*pad });
  }

  // ============================================================
  // SLIDE 1 — COVER (dark)
  // ============================================================
  {
    const s = pres.addSlide(); darkBg(s);
    // top hairline gold accent
    s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: SW, h: 0.08, fill: { color: C.gold }, line: { color: C.gold } });

    // brand mark row
    s.addShape(pres.shapes.RECTANGLE, { x: 0.8, y: 0.7, w: 0.35, h: 0.07, fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("CODEPET ACADEMY", {
      x: 1.25, y: 0.55, w: 8, h: 0.4, margin: 0,
      fontFace: "Calibri", fontSize: 13, bold: true, color: C.goldLite, charSpacing: 6
    });

    s.addText("AI Founders,\nBuilt Different.", {
      x: 0.8, y: 2.1, w: 11, h: 2.2, margin: 0,
      fontFace: "Georgia", fontSize: 64, bold: true, color: "FFFFFF"
    });

    s.addText(
      "A premium coding & entrepreneurship program for Vietnam's next generation —\nages 12 to 30, taught by an AI pet companion that ships real products with them.",
      { x: 0.8, y: 4.5, w: 11, h: 1.0, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 18, color: C.goldLite }
    );

    // bottom info
    s.addShape(pres.shapes.RECTANGLE, { x: 0.8, y: SH - 1.1, w: 11.7, h: 0.02, fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("By MURROR  ·  murror.app", {
      x: 0.8, y: SH - 0.95, w: 6, h: 0.35, margin: 0,
      fontFace: "Calibri", fontSize: 11, color: "FFFFFF", charSpacing: 3
    });
    s.addText("Confidential business plan  ·  v1.0  ·  May 2026", {
      x: 6.5, y: SH - 0.95, w: 6, h: 0.35, margin: 0, align: "right",
      fontFace: "Calibri", fontSize: 11, color: C.goldLite
    });
  }

  // ============================================================
  // SLIDE 2 — THESIS
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "01  ·  THE THESIS", "The parents who paid for piano now pay for AI.");

    s.addText(
      "Three forces are converging in Vietnam — and they will only converge once.",
      { x: 0.6, y: 1.7, w: 12, h: 0.4, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 16, color: C.muted });

    const stats = [
      { big: "$4.2B", label: "Vietnam private edtech market by 2027 (Statista, 2024)", icon: ico.chart },
      { big: "1.2M",  label: "Households earning >$30K/yr — willing to spend $1K+ per child on enrichment", icon: ico.users },
      { big: "73%",   label: "Vietnamese parents who believe AI fluency is critical by age 14 (HSBC, 2024)", icon: ico.bulb }
    ];
    const cardW = 3.95, cardH = 3.4, gap = 0.25, startX = 0.6;
    stats.forEach((st, i) => {
      const x = startX + i * (cardW + gap), y = 2.5;
      card(s, x, y, cardW, cardH);
      accentBar(s, x, y, cardH, C.purple);
      iconCircle(s, x + 0.35, y + 0.4, 0.85, C.light, st.icon);
      s.addText(st.big, {
        x: x + 0.35, y: y + 1.4, w: cardW - 0.7, h: 1.1, margin: 0,
        fontFace: "Georgia", fontSize: 60, bold: true, color: C.ink
      });
      s.addText(st.label, {
        x: x + 0.35, y: y + 2.55, w: cardW - 0.7, h: 0.75, margin: 0,
        fontFace: "Calibri", fontSize: 12, color: C.charcoal
      });
    });

    s.addText(
      "Premium parents in HCMC and Hanoi are the world's most underserved AI-education buyers — and they buy now.",
      { x: 0.6, y: 6.25, w: 12.1, h: 0.5, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 14, color: C.purple, bold: true }
    );

    footer(s, 2);
  }

  // ============================================================
  // SLIDE 3 — THE PROBLEM
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "02  ·  THE PROBLEM", "Coding camps teach syntax. Schools teach theory. Neither teaches shipping.");

    const probs = [
      { title: "Coding bootcamps", body: "Drill Scratch, Python, or web syntax. Kids finish a course and have nothing they can show, sell, or stand on.", icon: ico.code },
      { title: "International schools", body: "Excellent at theory and exams. But \"build a real product, find a customer, take money\" is not on the curriculum.", icon: ico.school },
      { title: "AI changed the game", body: "A 13-year-old with Cursor + Claude can ship a product in a weekend. Nobody is teaching them to think like founders while they do it.", icon: ico.bolt }
    ];
    const cardW = 3.95, cardH = 3.6, gap = 0.25, startX = 0.6, y = 1.9;
    probs.forEach((p, i) => {
      const x = startX + i * (cardW + gap);
      card(s, x, y, cardW, cardH);
      iconCircle(s, x + 0.35, y + 0.35, 0.95, C.light, p.icon);
      s.addText(p.title, {
        x: x + 0.35, y: y + 1.5, w: cardW - 0.7, h: 0.55, margin: 0,
        fontFace: "Georgia", fontSize: 22, bold: true, color: C.ink
      });
      s.addText(p.body, {
        x: x + 0.35, y: y + 2.1, w: cardW - 0.7, h: 1.4, margin: 0,
        fontFace: "Calibri", fontSize: 13, color: C.charcoal, paraSpaceAfter: 4
      });
    });

    // Insight strip
    s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: 5.8, w: 12.1, h: 1.0, fill: { color: C.ink }, line: { color: C.ink } });
    s.addText("The gap:", {
      x: 0.9, y: 5.95, w: 1.5, h: 0.7, margin: 0,
      fontFace: "Calibri", fontSize: 13, bold: true, color: C.gold, charSpacing: 4
    });
    s.addText(
      "An AI-native, founder-mindset program designed for Vietnam's premium families — where the deliverable is a shipped product, not a certificate.",
      { x: 2.4, y: 5.9, w: 10.0, h: 0.85, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 14, color: "FFFFFF" }
    );

    footer(s, 3);
  }

  // ============================================================
  // SLIDE 4 — MARKET OPPORTUNITY
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "03  ·  MARKET", "A $4.2B market — and the premium tier is barely served.");

    // Left: text
    const Lx = 0.6, Lw = 5.6, Ly = 1.9;
    card(s, Lx, Ly, Lw, 4.9);
    accentBar(s, Lx, Ly, 4.9, C.gold);
    s.addText("Vietnam premium edtech, sized.", {
      x: Lx + 0.3, y: Ly + 0.35, w: Lw - 0.6, h: 0.5, margin: 0,
      fontFace: "Georgia", fontSize: 22, bold: true, color: C.ink
    });
    const points = [
      { h: "TAM",  v: "$4.2B private edtech in Vietnam by 2027" },
      { h: "SAM",  v: "$680M premium tier (intl. schools + top private) — ~340K students aged 10–22" },
      { h: "SOM (Y3)", v: "$25M obtainable share — 2% of premium tier @ avg $1.8K ARPU" },
      { h: "Wedge", v: "Intl. school families in HCMC District 2/7 + Hanoi Tay Ho — ~22K target households" }
    ];
    points.forEach((p, i) => {
      const yy = Ly + 1.05 + i * 0.92;
      s.addText(p.h, {
        x: Lx + 0.3, y: yy, w: 1.5, h: 0.35, margin: 0,
        fontFace: "Calibri", fontSize: 12, bold: true, color: C.purple, charSpacing: 3
      });
      s.addText(p.v, {
        x: Lx + 0.3, y: yy + 0.3, w: Lw - 0.6, h: 0.6, margin: 0,
        fontFace: "Calibri", fontSize: 13, color: C.charcoal
      });
    });

    // Right: chart — premium parent ed-spend growth
    const Rx = 6.5, Ry = 1.9, Rw = 6.2, Rh = 4.9;
    card(s, Rx, Ry, Rw, Rh);
    s.addText("Avg annual enrichment spend per child  (HCMC premium households, USD)", {
      x: Rx + 0.3, y: Ry + 0.3, w: Rw - 0.6, h: 0.5, margin: 0,
      fontFace: "Calibri", fontSize: 12, bold: true, color: C.muted
    });
    s.addChart(pres.charts.BAR, [{
      name: "USD",
      labels: ["2019","2020","2021","2022","2023","2024","2025"],
      values: [820, 950, 1050, 1280, 1540, 1820, 2150]
    }], {
      x: Rx + 0.3, y: Ry + 0.85, w: Rw - 0.6, h: Rh - 1.15, barDir: "col",
      chartColors: [C.purple],
      chartArea: { fill: { color: "FFFFFF" } },
      catAxisLabelColor: C.muted, catAxisLabelFontSize: 10,
      valAxisLabelColor: C.muted, valAxisLabelFontSize: 10,
      valGridLine: { color: C.rule, size: 0.5 },
      catGridLine: { style: "none" },
      showValue: true, dataLabelPosition: "outEnd",
      dataLabelColor: C.ink, dataLabelFontSize: 10,
      showLegend: false
    });

    footer(s, 4);
  }

  // ============================================================
  // SLIDE 5 — ICP (single, simple statement)
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "04  ·  ICP", "Built for anyone 12+ who wants to become a future founder.");

    // One full-width hero card
    const Hx = 0.6, Hy = 1.95, Hw = 12.1, Hh = 4.05;
    card(s, Hx, Hy, Hw, Hh, C.ink);
    s.addShape(pres.shapes.RECTANGLE, { x: Hx, y: Hy, w: Hw, h: 0.4,
      fill: { color: C.gold }, line: { color: C.gold } });

    // Icon centered near top
    iconCircle(s, Hx + Hw/2 - 0.6, Hy + 0.65, 1.2, C.purple, ico.teen);

    // AGE tag
    s.addText("AGE 12+  ·  NO UPPER LIMIT", {
      x: Hx, y: Hy + 2.05, w: Hw, h: 0.3, margin: 0, align: "center",
      fontFace: "Calibri", fontSize: 11, bold: true, color: C.gold, charSpacing: 5
    });

    // Audience name
    s.addText("The Future Founder", {
      x: Hx, y: Hy + 2.4, w: Hw, h: 0.65, margin: 0, align: "center",
      fontFace: "Georgia", fontSize: 32, bold: true, color: "FFFFFF"
    });

    // The statement
    s.addText(
      "\"For anyone 12 and older who wants to learn how to become a future founder —\nto build real products and run a company from a young age.\"",
      { x: Hx + 0.6, y: Hy + 3.15, w: Hw - 1.2, h: 0.85, margin: 0, align: "center",
        fontFace: "Georgia", italic: true, fontSize: 17, color: C.goldLite }
    );

    // Pricing strip
    s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: 6.25, w: 12.1, h: 0.6,
      fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("$3,000 / 3 months  ·  $9,600 / year (save 20%)", {
      x: 0.6, y: 6.25, w: 12.1, h: 0.6, margin: 0, align: "center", valign: "middle",
      fontFace: "Calibri", fontSize: 16, bold: true, color: C.ink, charSpacing: 2
    });

    footer(s, 5);
  }

  // ============================================================
  // SLIDE 6 — POSITIONING
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "05  ·  POSITIONING", "Not a coding camp. Not a junior MBA. An AI-native founder school.");

    // 2x2 matrix
    const Mx = 0.9, My = 1.9, Mw = 6.5, Mh = 4.8;
    s.addShape(pres.shapes.RECTANGLE, { x: Mx, y: My, w: Mw, h: Mh, fill: { color: "FFFFFF" }, line: { color: C.rule } });
    // axes labels
    s.addText("PRACTICAL ↑", { x: Mx - 0.05, y: My - 0.4, w: 3, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.muted, charSpacing: 3 });
    s.addText("THEORY ↓", { x: Mx - 0.05, y: My + Mh + 0.1, w: 3, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.muted, charSpacing: 3 });
    s.addText("→ FOUNDER MINDSET", { x: Mx + Mw - 3, y: My + Mh + 0.1, w: 3, h: 0.3, margin: 0, align: "right",
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.muted, charSpacing: 3 });
    s.addText("← GENERIC COURSE", { x: Mx, y: My + Mh + 0.1, w: 3, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.muted, charSpacing: 3 });
    // crosshair
    s.addShape(pres.shapes.LINE, { x: Mx + Mw/2, y: My, w: 0, h: Mh, line: { color: C.rule, width: 1, dashType: "dash" } });
    s.addShape(pres.shapes.LINE, { x: Mx, y: My + Mh/2, w: Mw, h: 0, line: { color: C.rule, width: 1, dashType: "dash" } });

    // competitors as small dots
    const dot = (x, y, label, color = C.muted) => {
      s.addShape(pres.shapes.OVAL, { x: x - 0.08, y: y - 0.08, w: 0.16, h: 0.16, fill: { color }, line: { color } });
      s.addText(label, { x: x + 0.15, y: y - 0.13, w: 1.7, h: 0.3, margin: 0,
        fontFace: "Calibri", fontSize: 10, color: C.charcoal });
    };
    dot(Mx + 1.0, My + 3.7, "Scratch / school IT");
    dot(Mx + 2.2, My + 4.2, "MindX kids");
    dot(Mx + 4.0, My + 3.5, "Juni Learning");
    dot(Mx + 1.7, My + 1.8, "MBA prep");
    dot(Mx + 4.4, My + 2.4, "CoderSchool");

    // Codepet star — top right
    const cx = Mx + 5.2, cy = My + 1.0;
    s.addShape(pres.shapes.OVAL, { x: cx - 0.45, y: cy - 0.45, w: 0.9, h: 0.9,
      fill: { color: C.gold }, line: { color: C.gold } });
    s.addImage({ data: ico.starWhite, x: cx - 0.28, y: cy - 0.28, w: 0.56, h: 0.56 });
    s.addText("CODEPET\nACADEMY", { x: cx + 0.55, y: cy - 0.35, w: 1.5, h: 0.7, margin: 0,
      fontFace: "Georgia", fontSize: 13, bold: true, color: C.ink });

    // Right column: positioning statement
    const Rx = 8.0, Ry = 1.9, Rw = 4.7, Rh = 4.8;
    card(s, Rx, Ry, Rw, Rh, C.ink);
    accentBar(s, Rx, Ry, Rh, C.gold);
    s.addText("Our promise.", {
      x: Rx + 0.3, y: Ry + 0.3, w: Rw - 0.6, h: 0.5, margin: 0,
      fontFace: "Georgia", fontSize: 22, bold: true, color: "FFFFFF"
    });
    s.addText(
      "In one cohort, your child will ship a real AI-powered product, find their first customer, and earn their first dollar.",
      { x: Rx + 0.3, y: Ry + 0.95, w: Rw - 0.6, h: 1.5, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 16, color: C.goldLite });

    s.addText("THREE THINGS WE ARE NOT", {
      x: Rx + 0.3, y: Ry + 2.6, w: Rw - 0.6, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.gold, charSpacing: 3
    });
    s.addText([
      { text: "A coding bootcamp that ends in a certificate.", options: { bullet: true, breakLine: true } },
      { text: "A junior MBA program with no actual product.", options: { bullet: true, breakLine: true } },
      { text: "A SaaS that asks parents to teach the kid themselves.", options: { bullet: true } }
    ], { x: Rx + 0.3, y: Ry + 2.95, w: Rw - 0.6, h: 1.7, margin: 0,
      fontFace: "Calibri", fontSize: 12, color: "FFFFFF", paraSpaceAfter: 6 });

    footer(s, 6);
  }

  // ============================================================
  // SLIDE 7 — CODEPET INTEGRATION
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "06  ·  PRODUCT", "Codepet is the always-on co-pilot. The class is just the live layer.");

    s.addText(
      "Every student gets a Codepet — a pixel-art companion that holds the full curriculum, runs daily 15-min lessons, and walks them through their first product.",
      { x: 0.6, y: 1.7, w: 12.1, h: 0.6, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 14, color: C.muted });

    const features = [
      { icon: ico.brain,   t: "AI mentor in their pocket", b: "Pet character roleplays as cofounder, mentor, customer. Adapts tone per age." },
      { icon: ico.bolt,    t: "Daily 15-min loops",        b: "Streaks, hearts, coins gamify failure and keep kids returning between live sessions." },
      { icon: ico.code,    t: "Build alongside",           b: "Lessons hand off to Cursor / Claude. Pet reviews code, asks questions, suggests next steps." },
      { icon: ico.target,  t: "Founder coaching",          b: "After Module 6, pet starts running customer-discovery sprints with the student." },
      { icon: ico.users,   t: "Parent dashboard",          b: "Weekly digest: what they built, what they learned, what they sold. Premium-parent-friendly." },
      { icon: ico.shield,  t: "Safe by design",            b: "No social. No ads. No external chat. COPPA-grade controls for under-13." }
    ];
    const cw = 3.95, ch = 1.55, gap = 0.2, startX = 0.6, startY = 2.5;
    features.forEach((f, i) => {
      const col = i % 3, row = Math.floor(i / 3);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      iconCircle(s, x + 0.2, y + 0.25, 1.05, C.light, f.icon);
      s.addText(f.t, { x: x + 1.4, y: y + 0.2, w: cw - 1.55, h: 0.4, margin: 0,
        fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });
      s.addText(f.b, { x: x + 1.4, y: y + 0.6, w: cw - 1.55, h: 0.95, margin: 0,
        fontFace: "Calibri", fontSize: 11, color: C.charcoal });
    });

    // bottom strip
    s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: 6.0, w: 12.1, h: 0.85, fill: { color: C.purple }, line: { color: C.purple } });
    s.addText(
      "Codepet does ~70% of the teaching. Live instructors do 30%. That's how we hit 83% gross margin at $1.8K ARPU.",
      { x: 0.6, y: 6.05, w: 12.1, h: 0.75, margin: 0, align: "center", valign: "middle",
        fontFace: "Georgia", italic: true, fontSize: 14, color: "FFFFFF", bold: true });

    footer(s, 7);
  }

  // ============================================================
  // SLIDE 8 — THE ONE PROGRAM (Astro Vinh-led)
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "07  ·  THE PROGRAM", "One founder. One program. One promise: ship a real AI-agent product.");

    // Hero card (Astro Vinh intro)
    const Hx = 0.6, Hy = 1.85, Hw = 12.1, Hh = 2.5;
    card(s, Hx, Hy, Hw, Hh, C.ink);
    s.addShape(pres.shapes.RECTANGLE, { x: Hx, y: Hy, w: Hw, h: 0.35, fill: { color: C.gold }, line: { color: C.gold } });

    // Astro icon + name + bio
    iconCircle(s, Hx + 0.4, Hy + 0.6, 1.5, C.purple, ico.crown);
    s.addText("LED PERSONALLY BY", {
      x: Hx + 2.2, y: Hy + 0.6, w: 9, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.gold, charSpacing: 4
    });
    s.addText("ASTRO VINH", {
      x: Hx + 2.2, y: Hy + 0.92, w: 9, h: 0.6, margin: 0,
      fontFace: "Georgia", fontSize: 30, bold: true, color: "FFFFFF"
    });
    s.addText(
      "[Co-founder & Lead Coach. Add 1-line bio: e.g., \"Operator behind X. Built and shipped Y AI products. 10+ years founding companies.\"]",
      { x: Hx + 2.2, y: Hy + 1.6, w: 9.5, h: 0.7, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 12, color: C.goldLite });

    // 4-attribute row (own cards below the hero)
    const attrs = [
      { t: "FORMAT",      v: "12-week cohort,\nfounder-led live" },
      { t: "DELIVERABLE", v: "A working AI-agent\nproduct, in market" },
      { t: "GUARANTEE",   v: "Build, manage,\noperate AI products" },
      { t: "BONUS",       v: "Run a startup\nlike a real founder" }
    ];
    const Ay = 4.55, Aw = 2.95, gap = 0.18, Ah = 1.55;
    attrs.forEach((a, i) => {
      const x = Hx + i * (Aw + gap);
      card(s, x, Ay, Aw, Ah);
      accentBar(s, x, Ay, Ah, C.purple);
      s.addText(a.t, {
        x: x + 0.25, y: Ay + 0.25, w: Aw - 0.5, h: 0.3, margin: 0,
        fontFace: "Calibri", fontSize: 10, bold: true, color: C.purple, charSpacing: 4
      });
      s.addText(a.v, {
        x: x + 0.25, y: Ay + 0.55, w: Aw - 0.5, h: 0.95, margin: 0,
        fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink
      });
    });

    // Pricing strip at the bottom
    s.addShape(pres.shapes.RECTANGLE, { x: Hx, y: 6.3, w: Hw, h: 0.55,
      fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("$3,000 / 3 months  ·  Save 20% with annual: $9,600 / year", {
      x: Hx, y: 6.3, w: Hw, h: 0.55, margin: 0, align: "center", valign: "middle",
      fontFace: "Calibri", fontSize: 14, bold: true, color: C.ink, charSpacing: 2
    });

    footer(s, 8);
  }

  // ============================================================
  // SLIDE 9 — 12-WEEK CURRICULUM (single program)
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "08  ·  CURRICULUM", "12 weeks, 4 phases — from idea to a launched AI-agent product.");

    const phases = [
      { wk: "WEEKS 1–3", t: "Mindset & idea",
        color: C.lavender, body: [
          "Astro on founder thinking — how operators see opportunity.",
          "Tear apart 10 real AI-agent products in market today.",
          "Pick your wedge — one painful, narrow problem you'll solve.",
          "Customer-discovery sprint: 20 real conversations."
      ]},
      { wk: "WEEKS 4–6", t: "Build the agent",
        color: C.purple, body: [
          "AI-native stack: Cursor, Claude, agent frameworks, n8n.",
          "Architect the agent — you become the product manager.",
          "Build V1 end-to-end with Astro reviewing weekly.",
          "Connect to real systems: APIs, payments, databases."
      ]},
      { wk: "WEEKS 7–9", t: "Launch as a startup",
        color: C.ink, body: [
          "Startup mechanics: pricing, payments, legal, brand.",
          "Launch day — your first 10 paying customers.",
          "Operate the product: dashboards, support, churn.",
          "Talk to every customer in week one."
      ]},
      { wk: "WEEKS 10–12", t: "Scale or pivot",
        color: C.gold, body: [
          "Read your P&L like a real founder. Decide.",
          "Growth channels: content, cold, partnerships.",
          "Demo Day — pitch to Astro + a guest investor.",
          "90-day plan post-program: keep going, or kill it cleanly."
      ]}
    ];

    const cw = 2.95, ch = 4.55, gap = 0.18, startX = 0.6, y = 1.95;
    phases.forEach((p, i) => {
      const x = startX + i * (cw + gap);
      card(s, x, y, cw, ch);
      accentBar(s, x, y, ch, p.color);
      s.addText(p.wk, { x: x + 0.25, y: y + 0.3, w: cw - 0.5, h: 0.3, margin: 0,
        fontFace: "Calibri", fontSize: 10, bold: true, color: C.purple, charSpacing: 4 });
      s.addText(p.t, { x: x + 0.25, y: y + 0.6, w: cw - 0.5, h: 0.55, margin: 0,
        fontFace: "Georgia", fontSize: 22, bold: true, color: C.ink });
      s.addText(
        p.body.map((line, idx) => ({
          text: line, options: { bullet: true, breakLine: idx !== p.body.length - 1 }
        })),
        { x: x + 0.25, y: y + 1.3, w: cw - 0.5, h: ch - 1.5, margin: 0,
          fontFace: "Calibri", fontSize: 11, color: C.charcoal, paraSpaceAfter: 6 }
      );
    });

    s.addText(
      "Astro Vinh leads every cohort personally — weekly live workshop + 1:1 reviews + Demo Day. Codepet platform is the daily co-pilot in between.",
      { x: 0.6, y: 6.65, w: 12.1, h: 0.4, margin: 0, align: "center",
        fontFace: "Georgia", italic: true, fontSize: 12, color: C.purple, bold: true });

    footer(s, 9);
  }

  // ============================================================
  // SLIDE 10 — OUTCOMES GUARANTEE
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "09  ·  OUTCOMES", "What every graduate will be able to do — guaranteed in 12 weeks.");

    // Top promise
    s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: 1.85, w: 12.1, h: 0.95, fill: { color: C.ink }, line: { color: C.ink } });
    s.addText("\"After this program, you will independently build, manage, and operate an AI-agent product — and run it like a real startup.\"", {
      x: 0.6, y: 1.85, w: 12.1, h: 0.95, margin: 0, align: "center", valign: "middle",
      fontFace: "Georgia", italic: true, fontSize: 14, color: C.goldLite, bold: true
    });

    const outcomes = [
      { icon: ico.brain, t: "Think like a founder",
        b: "See opportunity where others see chaos. Make decisions under uncertainty. Pick what to ignore." },
      { icon: ico.code, t: "Build AI-agent products",
        b: "Design, code, and ship working AI agents end-to-end with Cursor, Claude, and modern frameworks." },
      { icon: ico.target, t: "Find real customers",
        b: "Run customer-discovery interviews. Validate demand before you build. Sell without sounding desperate." },
      { icon: ico.money, t: "Operate a startup",
        b: "Pricing, payments, legal, brand, P&L. Run a real business — not just a demo." },
      { icon: ico.chart, t: "Read your numbers",
        b: "Build dashboards. Read retention, churn, LTV. Decide weekly: scale, pivot, or sunset." },
      { icon: ico.crown, t: "Keep going alone",
        b: "After Demo Day, you have a 90-day plan, the tools, and the muscle to operate without us." }
    ];
    const cw = 3.95, ch = 1.75, gap = 0.2, startX = 0.6, startY = 2.95;
    outcomes.forEach((o, i) => {
      const col = i % 3, row = Math.floor(i / 3);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      iconCircle(s, x + 0.2, y + 0.25, 1.0, C.light, o.icon);
      s.addText(o.t, { x: x + 1.35, y: y + 0.25, w: cw - 1.5, h: 0.4, margin: 0,
        fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });
      s.addText(o.b, { x: x + 1.35, y: y + 0.65, w: cw - 1.5, h: 1.05, margin: 0,
        fontFace: "Calibri", fontSize: 11, color: C.charcoal });
    });

    s.addText(
      "Guarantee: if a graduate cannot ship a working AI-agent product by week 12, we re-enroll them in the next cohort, free.",
      { x: 0.6, y: 6.7, w: 12.1, h: 0.35, margin: 0, align: "center",
        fontFace: "Georgia", italic: true, fontSize: 12, color: C.purple, bold: true });

    footer(s, 10);
  }

  // ============================================================
  // SLIDE 11 — WHY FOUNDER-LED (Astro Vinh's philosophy)
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "10  ·  WHY FOUNDER-LED", "Premium parents don't pay for content. They pay for who teaches it.");

    // Left card — the philosophy
    const Lx = 0.6, Ly = 1.9, Lw = 6.0, Lh = 4.9;
    card(s, Lx, Ly, Lw, Lh, C.ink);
    s.addShape(pres.shapes.RECTANGLE, { x: Lx, y: Ly, w: Lw, h: 0.4, fill: { color: C.gold }, line: { color: C.gold } });
    iconCircle(s, Lx + 0.4, Ly + 0.85, 1.2, C.purple, ico.crown);
    s.addText("ASTRO VINH'S COACHING PHILOSOPHY", {
      x: Lx + 1.85, y: Ly + 1.0, w: Lw - 2.0, h: 0.35, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.gold, charSpacing: 4
    });
    s.addText("Operator first.\nTheory second.", {
      x: Lx + 1.85, y: Ly + 1.35, w: Lw - 2.0, h: 1.0, margin: 0,
      fontFace: "Georgia", fontSize: 26, bold: true, color: "FFFFFF"
    });

    s.addText(
      "\"I'm not here to lecture. I'm here to ship alongside you — like a co-founder for 12 weeks. We make decisions together. You feel what real founder pressure feels like, in safety. That's the only way the lessons stick.\"",
      { x: Lx + 0.4, y: Ly + 2.55, w: Lw - 0.8, h: 1.7, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 14, color: C.goldLite });

    s.addText("— ASTRO VINH, CO-FOUNDER", {
      x: Lx + 0.4, y: Ly + Lh - 0.6, w: Lw - 0.8, h: 0.35, margin: 0,
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.gold, charSpacing: 4
    });

    // Right card — the unfair advantages
    const Rx = 6.85, Ry = 1.9, Rw = 5.85, Rh = 4.9;
    card(s, Rx, Ry, Rw, Rh);
    accentBar(s, Rx, Ry, Rh, C.purple);
    s.addText("Why this beats group classes & SaaS courses", {
      x: Rx + 0.3, y: Ry + 0.3, w: Rw - 0.6, h: 0.5, margin: 0,
      fontFace: "Georgia", fontSize: 17, bold: true, color: C.ink
    });

    const advs = [
      { t: "Decisions, not lectures",
        b: "Astro reviews your real product weekly. You walk out with answers, not notes." },
      { t: "Real founder pattern-matching",
        b: "Years of operator scars baked into every feedback loop. You skip mistakes that took us a decade." },
      { t: "Network compounds",
        b: "Astro's contacts open doors — investors, customers, hires — for graduates who deserve it." },
      { t: "Skin in the game",
        b: "If you fail, Astro fails. That accountability makes the program work." }
    ];
    advs.forEach((a, i) => {
      const yy = Ry + 1.0 + i * 0.92;
      iconCircle(s, Rx + 0.3, yy, 0.5, C.light, ico.check);
      s.addText(a.t, {
        x: Rx + 1.0, y: yy, w: Rw - 1.2, h: 0.35, margin: 0,
        fontFace: "Georgia", fontSize: 13, bold: true, color: C.ink
      });
      s.addText(a.b, {
        x: Rx + 1.0, y: yy + 0.32, w: Rw - 1.2, h: 0.55, margin: 0,
        fontFace: "Calibri", fontSize: 11, color: C.charcoal
      });
    });

    footer(s, 11);
  }

  // ============================================================
  // SLIDE 12 — PRICING & PACKAGING
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "11  ·  PRICING", "Two ways to pay. The annual plan saves you $2,400.");

    // Twin pricing cards — equal weight, both dark for visual parity
    const cw = 5.95, ch = 3.85, gap = 0.2, startX = 0.6, y = 1.85;

    // ===== LEFT CARD — 3-MONTH PLAN =====
    const Lx = startX;
    card(s, Lx, y, cw, ch, C.ink);
    // Top accent
    s.addShape(pres.shapes.RECTANGLE, { x: Lx, y, w: cw, h: 0.35,
      fill: { color: C.purple }, line: { color: C.purple } });

    s.addText("3-MONTH PLAN", {
      x: Lx + 0.4, y: y + 0.55, w: cw - 0.8, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 11, bold: true, color: C.gold, charSpacing: 4
    });
    s.addText("Pay quarterly", {
      x: Lx + 0.4, y: y + 0.85, w: cw - 0.8, h: 0.5, margin: 0,
      fontFace: "Georgia", fontSize: 22, bold: true, color: "FFFFFF"
    });

    // Big price
    s.addText("$3,000", {
      x: Lx + 0.4, y: y + 1.6, w: cw - 0.8, h: 1.0, margin: 0,
      fontFace: "Georgia", fontSize: 60, bold: true, color: C.gold
    });
    // Per-month
    s.addText("$1,000 / month", {
      x: Lx + 0.4, y: y + 2.7, w: cw - 0.8, h: 0.35, margin: 0,
      fontFace: "Calibri", italic: true, fontSize: 14, color: C.goldLite
    });

    // Divider
    s.addShape(pres.shapes.LINE, { x: Lx + 0.4, y: y + 3.1, w: cw - 0.8, h: 0,
      line: { color: C.purple, width: 0.75 } });

    s.addText([
      { text: "Pay every 12 weeks", options: { bullet: true, breakLine: true } },
      { text: "Cancel after current cohort, no commitment", options: { bullet: true } }
    ], { x: Lx + 0.4, y: y + 3.2, w: cw - 0.8, h: 0.55, margin: 0,
      fontFace: "Calibri", fontSize: 11, color: "FFFFFF", paraSpaceAfter: 3 });

    // ===== RIGHT CARD — ANNUAL PLAN =====
    const Rx = startX + cw + gap;
    card(s, Rx, y, cw, ch, C.ink);
    // Top accent — gold to signal "premium / save"
    s.addShape(pres.shapes.RECTANGLE, { x: Rx, y, w: cw, h: 0.35,
      fill: { color: C.gold }, line: { color: C.gold } });

    // SAVE 20% pill on top-right
    s.addShape(pres.shapes.RECTANGLE, { x: Rx + cw - 1.55, y: y + 0.5, w: 1.4, h: 0.32,
      fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("SAVE 20%", {
      x: Rx + cw - 1.55, y: y + 0.5, w: 1.4, h: 0.32, margin: 0, align: "center", valign: "middle",
      fontFace: "Calibri", fontSize: 10, bold: true, color: C.ink, charSpacing: 3
    });

    s.addText("ANNUAL PLAN", {
      x: Rx + 0.4, y: y + 0.55, w: 3.5, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 11, bold: true, color: C.gold, charSpacing: 4
    });
    s.addText("Pay once, commit", {
      x: Rx + 0.4, y: y + 0.85, w: cw - 0.8, h: 0.5, margin: 0,
      fontFace: "Georgia", fontSize: 22, bold: true, color: "FFFFFF"
    });

    // Strikethrough $12,000 above the actual price
    s.addText("$12,000", {
      x: Rx + 0.4, y: y + 1.3, w: cw - 0.8, h: 0.35, margin: 0,
      fontFace: "Georgia", fontSize: 18, color: C.muted, strike: true
    });
    // Big price
    s.addText("$9,600", {
      x: Rx + 0.4, y: y + 1.6, w: cw - 0.8, h: 1.0, margin: 0,
      fontFace: "Georgia", fontSize: 60, bold: true, color: C.gold
    });
    // Per-month
    s.addText("$800 / month", {
      x: Rx + 0.4, y: y + 2.7, w: cw - 0.8, h: 0.35, margin: 0,
      fontFace: "Calibri", italic: true, fontSize: 14, color: C.goldLite
    });

    // Divider
    s.addShape(pres.shapes.LINE, { x: Rx + 0.4, y: y + 3.1, w: cw - 0.8, h: 0,
      line: { color: C.purple, width: 0.75 } });

    s.addText([
      { text: "Pay once for 4 back-to-back cohorts", options: { bullet: true, breakLine: true } },
      { text: "Lock in a full year of founder access", options: { bullet: true } }
    ], { x: Rx + 0.4, y: y + 3.2, w: cw - 0.8, h: 0.55, margin: 0,
      fontFace: "Calibri", fontSize: 11, color: "FFFFFF", paraSpaceAfter: 3 });

    // ===== SAVINGS COMPARISON STRIP =====
    const Sx = 0.6, Sy = 5.9, Sw = 12.1, Sh = 0.85;
    s.addShape(pres.shapes.RECTANGLE, { x: Sx, y: Sy, w: Sw, h: Sh,
      fill: { color: C.gold }, line: { color: C.gold } });

    // Three-zone strip: quarterly total | arrow + savings | annual total
    const z = Sw / 3;

    // Zone 1 — Quarterly total (struck through)
    s.addText("$12,000", {
      x: Sx + 0.2, y: Sy + 0.08, w: z - 0.4, h: 0.45, margin: 0, align: "center", valign: "middle",
      fontFace: "Georgia", fontSize: 24, bold: true, color: C.ink, strike: true
    });
    s.addText("4 cohorts paid quarterly", {
      x: Sx + 0.2, y: Sy + 0.5, w: z - 0.4, h: 0.3, margin: 0, align: "center",
      fontFace: "Calibri", fontSize: 10, color: C.ink
    });

    // Zone 2 — Savings callout
    s.addText("SAVE  $2,400", {
      x: Sx + z, y: Sy, w: z, h: Sh, margin: 0, align: "center", valign: "middle",
      fontFace: "Georgia", fontSize: 30, bold: true, color: C.ink
    });

    // Zone 3 — Annual total
    s.addText("$9,600", {
      x: Sx + 2 * z + 0.2, y: Sy + 0.08, w: z - 0.4, h: 0.45, margin: 0, align: "center", valign: "middle",
      fontFace: "Georgia", fontSize: 28, bold: true, color: C.ink
    });
    s.addText("Annual plan, paid once", {
      x: Sx + 2 * z + 0.2, y: Sy + 0.55, w: z - 0.4, h: 0.3, margin: 0, align: "center",
      fontFace: "Calibri", fontSize: 10, color: C.ink
    });

    // Closing italic line
    s.addText(
      "No tiers, no upsells, no scholarships. The price is the price. The outcome is the outcome.",
      { x: 0.6, y: 6.88, w: 12.1, h: 0.22, margin: 0, align: "center",
        fontFace: "Georgia", italic: true, fontSize: 10, color: C.purple, bold: true });

    footer(s, 12);
  }

  // ============================================================
  // SLIDE 13 — UNIT ECONOMICS
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "12  ·  UNIT ECONOMICS", "Single SKU, founder-led: ~85% gross margin and a 1-month CAC payback.");

    // Big stat callouts
    const stats = [
      { v: "$3,000", l: "Price per 3-mo program"     },
      { v: "$2,700", l: "Net ARPU (after annual mix)" },
      { v: "85%",    l: "Gross margin"               },
      { v: "$300",   l: "Target CAC (Y1)"            },
      { v: "9×",     l: "Year-1 LTV / CAC"           },
      { v: "30%",    l: "Annual-plan attach (target)" }
    ];
    const cw = 1.95, ch = 1.7, gap = 0.12, startX = 0.6, y = 1.9;
    stats.forEach((st, i) => {
      const col = i % 6;
      const x = startX + col * (cw + gap);
      card(s, x, y, cw, ch);
      s.addText(st.v, { x: x + 0.15, y: y + 0.25, w: cw - 0.3, h: 0.7, margin: 0,
        fontFace: "Georgia", fontSize: 26, bold: true, color: C.ink, align: "center" });
      s.addText(st.l, { x: x + 0.15, y: y + 1.0, w: cw - 0.3, h: 0.55, margin: 0,
        fontFace: "Calibri", fontSize: 9.5, color: C.muted, align: "center" });
    });

    // Breakdown table
    const Tx = 0.6, Ty = 4.0, Tw = 6.2;
    card(s, Tx, Ty, Tw, 3.0);
    accentBar(s, Tx, Ty, 3.0, C.purple);
    s.addText("Per-student P&L  ·  blended (3-mo + annual mix)", { x: Tx + 0.25, y: Ty + 0.25, w: Tw - 0.5, h: 0.35, margin: 0,
      fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });

    const rows = [
      ["List price (3-mo program)",     "$3,000"],
      ["Annual-plan discount blended",  "($300)"],
      ["Net revenue per program",       "$2,700"],
      ["Founder coach time (allocated)","($240)"],
      ["AI / infra / ops",              "($90)"],
      ["Materials, venue, swag",        "($75)"],
      ["Gross profit",                  "$2,295  (85%)"],
      ["CAC (Y1 target)",               "($300)"],
      ["Contribution margin",           "$1,995  (74%)"]
    ];
    rows.forEach((r, i) => {
      const yy = Ty + 0.7 + i * 0.24;
      const isTotal = (r[0].startsWith("Net") || r[0].startsWith("Gross") || r[0].startsWith("Contribution"));
      s.addText(r[0], { x: Tx + 0.25, y: yy, w: Tw - 2.5, h: 0.25, margin: 0,
        fontFace: "Calibri", fontSize: 11, bold: isTotal, color: isTotal ? C.ink : C.charcoal });
      s.addText(r[1], { x: Tx + Tw - 2.3, y: yy, w: 2.05, h: 0.25, margin: 0, align: "right",
        fontFace: "Calibri", fontSize: 11, bold: isTotal, color: isTotal ? C.purple : C.charcoal });
    });

    // Chart — where every $1 of revenue goes
    const Cx = 7.0, Cy = 4.0, Cw = 5.7, Ch = 3.0;
    card(s, Cx, Cy, Cw, Ch);
    s.addText("Where every $1 of revenue goes", { x: Cx + 0.25, y: Cy + 0.25, w: Cw - 0.5, h: 0.35, margin: 0,
      fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });
    s.addChart(pres.charts.PIE, [{
      name: "$ allocation",
      labels: ["Founder coach time", "AI / infra / ops", "Materials & venue", "CAC", "Profit retained"],
      values: [8, 3, 2.5, 10, 76.5]
    }], {
      x: Cx + 0.25, y: Cy + 0.7, w: Cw - 0.5, h: Ch - 0.85,
      chartColors: [C.purple, C.lavender, C.muted, C.coral, C.gold],
      chartArea: { fill: { color: "FFFFFF" } },
      showLegend: true, legendPos: "r", legendFontSize: 9, legendColor: C.charcoal,
      showPercent: true, dataLabelColor: "FFFFFF", dataLabelFontSize: 9
    });

    footer(s, 13);
  }

  // ============================================================
  // SLIDE 14 — GO-TO-MARKET
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "13  ·  GO-TO-MARKET", "Win the parent. Then win the school. Then scale.");

    const channels = [
      { icon: ico.school, t: "International school partnerships",
        b: "BIS, ISHCMC, AIS, EIS, VAS, ISSP, Concordia. After-school program contracts + summer intensives. 3 paid pilots in Y1.",
        kpi: "Target 8 schools by EOY1" },
      { icon: ico.users, t: "Parent influencer network",
        b: "Co-marketing with 20 trusted Vietnamese mom influencers (Facebook + TikTok). 'My kid built X' content is the lead magnet.",
        kpi: "$80 CAC blended" },
      { icon: ico.crown, t: "Demo Day as marketing engine",
        b: "Quarterly public Demo Day at venue partners. Parents see other kids ship. Word-of-mouth flywheel ignites.",
        kpi: "30% leads convert post-Demo Day" },
      { icon: ico.globe, t: "MURROR brand halo",
        b: "Codepet has growing organic reach. Free tier → paid course funnel. App store + landing page co-converts.",
        kpi: "12% free→paid in Y2" },
      { icon: ico.hand, t: "Returning diaspora",
        b: "Vietnamese families returning from US/AU. They miss US-style enrichment, recognise the format, pay quickly.",
        kpi: "~15% of Y1 revenue" },
      { icon: ico.star, t: "Alumni angel network",
        b: "Year-2: alumni parents become investors and referrers. Exclusive 'Codepet Founders Society' brand layer.",
        kpi: "Y2 referral 25%" }
    ];
    const cw = 3.95, ch = 1.9, gap = 0.2, startX = 0.6, startY = 1.9;
    channels.forEach((ch_, i) => {
      const col = i % 3, row = Math.floor(i / 3);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      iconCircle(s, x + 0.2, y + 0.2, 0.85, C.light, ch_.icon);
      s.addText(ch_.t, { x: x + 1.2, y: y + 0.15, w: cw - 1.35, h: 0.4, margin: 0,
        fontFace: "Georgia", fontSize: 13, bold: true, color: C.ink });
      s.addText(ch_.b, { x: x + 1.2, y: y + 0.55, w: cw - 1.35, h: 1.1, margin: 0,
        fontFace: "Calibri", fontSize: 10, color: C.charcoal });
      // KPI strip
      s.addShape(pres.shapes.RECTANGLE, { x, y: y + ch - 0.3, w: cw, h: 0.3, fill: { color: C.ink }, line: { color: C.ink } });
      s.addText(ch_.kpi, { x: x + 0.2, y: y + ch - 0.3, w: cw - 0.4, h: 0.3, margin: 0, valign: "middle",
        fontFace: "Calibri", fontSize: 10, bold: true, color: C.gold });
    });

    footer(s, 14);
  }

  // ============================================================
  // SLIDE 15 — Y1 FINANCIAL PROJECTION
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "14  ·  YEAR 1 PROJECTION", "Slow, sure, profitable: 119 students and $215K in Year 1.");

    // Left chart — quarterly revenue
    const Lx = 0.6, Ly = 1.9, Lw = 7.0, Lh = 4.4;
    card(s, Lx, Ly, Lw, Lh);
    s.addText("Quarterly revenue & cumulative students  (Y1)", {
      x: Lx + 0.3, y: Ly + 0.3, w: Lw - 0.6, h: 0.4, margin: 0,
      fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });

    s.addChart(pres.charts.BAR, [
      { name: "Revenue (USD)", labels: ["Q1","Q2","Q3","Q4"], values: [17000, 35000, 63000, 100000] }
    ], {
      x: Lx + 0.3, y: Ly + 0.85, w: Lw - 0.6, h: Lh - 1.05, barDir: "col",
      chartColors: [C.purple],
      chartArea: { fill: { color: "FFFFFF" } },
      catAxisLabelColor: C.muted, catAxisLabelFontSize: 11,
      valAxisLabelColor: C.muted, valAxisLabelFontSize: 10,
      valGridLine: { color: C.rule, size: 0.5 },
      catGridLine: { style: "none" },
      showValue: true, dataLabelPosition: "outEnd",
      dataLabelColor: C.ink, dataLabelFontSize: 10,
      dataLabelFormatCode: "$#,##0",
      showLegend: false
    });

    // Right — assumptions / KPIs
    const Rx = 7.85, Ry = 1.9, Rw = 4.85, Rh = 4.4;
    card(s, Rx, Ry, Rw, Rh, C.ink);
    accentBar(s, Rx, Ry, Rh, C.gold);
    s.addText("Y1 model — key assumptions", { x: Rx + 0.3, y: Ry + 0.3, w: Rw - 0.6, h: 0.4, margin: 0,
      fontFace: "Georgia", fontSize: 14, bold: true, color: "FFFFFF" });
    const lines = [
      ["Cohorts run",           "Q1: 1  ·  Q2: 1  ·  Q3: 2  ·  Q4: 3"],
      ["Avg students / cohort", "9 (capped at 15)"],
      ["Mix (by students)",     "34% self-paced · 50% cohort · 15% 1:1"],
      ["Blended ARPU",          "~$1,800"],
      ["Total students Y1",     "~119"],
      ["Y1 revenue",            "$215K"],
      ["Gross profit",          "$172K (80%)"],
      ["Operating cost (lean)", "$140K"],
      ["EBITDA Y1",             "~$32K  (cash-flow positive)"]
    ];
    lines.forEach((l, i) => {
      const yy = Ry + 0.85 + i * 0.36;
      s.addText(l[0], { x: Rx + 0.3, y: yy, w: 2.2, h: 0.32, margin: 0,
        fontFace: "Calibri", fontSize: 11, color: C.goldLite });
      s.addText(l[1], { x: Rx + 2.5, y: yy, w: Rw - 2.7, h: 0.32, margin: 0, align: "right",
        fontFace: "Calibri", fontSize: 11, bold: true, color: "FFFFFF" });
    });

    // Bottom strip — risks / sensitivities
    s.addShape(pres.shapes.RECTANGLE, { x: 0.6, y: 6.5, w: 12.1, h: 0.7, fill: { color: C.gold }, line: { color: C.gold } });
    s.addText(
      "Sensitivity: 20% downside (~$170K) if Q4 cohort fill slips. 30% upside (~$280K) if first intl-school contract closes in H2.",
      { x: 0.6, y: 6.5, w: 12.1, h: 0.7, margin: 0, align: "center", valign: "middle",
        fontFace: "Georgia", italic: true, fontSize: 13, bold: true, color: C.ink });

    footer(s, 15);
  }

  // ============================================================
  // SLIDE 16 — OPERATIONS & TEAM
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "15  ·  OPERATIONS & TEAM", "Two co-founders. One platform. Codepet does the heavy lifting in between.");

    const roles = [
      { t: "Astro Vinh — Co-founder & Lead Coach", n: "1.0 FTE", icon: ico.crown,
        d: "Leads every cohort personally. Owns curriculum, weekly workshops, 1:1 reviews, Demo Day. The product is the founder." },
      { t: "Operating Co-founder",                  n: "1.0 FTE", icon: ico.cog,
        d: "Owns ops, marketing, parent-success, school partnerships, finance. The reason the program runs." },
      { t: "Parent Success",                        n: "0.5 PT", icon: ico.hand,
        d: "Onboarding, weekly digests, retention calls. Hired in Q3 once cohort #2 lands." },
      { t: "Codepet platform team",                 n: "Existing", icon: ico.brain,
        d: "MURROR core team. Builds the AI co-pilot, parent dashboard, content modules. Not a new hire." },
      { t: "Guest founder coaches",                 n: "Per-cohort", icon: ico.star,
        d: "1–2 senior operators per cohort for guest sessions + Demo Day. Paid per appearance, not retained." },
      { t: "Content & community",                   n: "0.5 PT", icon: ico.bolt,
        d: "Social, alumni, Demo Day events. Hired Q4 when alumni network needs a steward." }
    ];
    const cw = 3.95, ch = 1.85, gap = 0.2, startX = 0.6, startY = 1.9;
    roles.forEach((r, i) => {
      const col = i % 3, row = Math.floor(i / 3);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      iconCircle(s, x + 0.2, y + 0.25, 0.85, C.light, r.icon);
      s.addText(r.t, { x: x + 1.2, y: y + 0.2, w: cw - 1.95, h: 0.4, margin: 0,
        fontFace: "Georgia", fontSize: 14, bold: true, color: C.ink });
      // FTE pill
      s.addShape(pres.shapes.RECTANGLE, { x: x + cw - 0.95, y: y + 0.25, w: 0.75, h: 0.32,
        fill: { color: C.purple }, line: { color: C.purple } });
      s.addText(r.n, { x: x + cw - 0.95, y: y + 0.25, w: 0.75, h: 0.32, margin: 0, align: "center", valign: "middle",
        fontFace: "Calibri", fontSize: 9, bold: true, color: "FFFFFF", charSpacing: 2 });
      s.addText(r.d, { x: x + 1.2, y: y + 0.65, w: cw - 1.35, h: 1.05, margin: 0,
        fontFace: "Calibri", fontSize: 10.5, color: C.charcoal });
    });

    s.addText(
      "Y1 headcount: 2 FTE co-founders + 1 PT (added Q3) + Codepet platform team. Fixed opex held under ~$140K — the entire program runs on founder cash flow.",
      { x: 0.6, y: 6.55, w: 12.1, h: 0.5, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 13, bold: true, color: C.purple });

    footer(s, 16);
  }

  // ============================================================
  // SLIDE 17 — COMPETITION
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "16  ·  COMPETITION", "Nobody is doing AI-native, founder-mindset, in Vietnamese.");

    const headers = ["", "Codepet Academy", "MindX (VN)", "Juni Learning (US)", "CoderSchool (VN)"];
    const data = [
      ["Vietnam-first",          "✓ HCMC + Hanoi",           "✓",                "✗",                  "✓ adults"],
      ["AI-native curriculum",   "✓ Cursor + Claude core",   "Partial",          "✗ Scratch-heavy",    "Partial"],
      ["Ships real products",    "✓ Required outcome",       "✗",                "✗",                  "✓ for adults"],
      ["Founder mindset",        "✓ Customer + revenue",     "✗",                "✗",                  "✗"],
      ["AI pet companion",       "✓ Codepet platform",       "✗",                "✗",                  "✗"],
      ["Premium pricing $1–3K",  "✓",                        "$300–600",         "$2K+",               "$1K+"],
      ["Parents see weekly progress", "✓ Dashboard",         "Partial",          "✓",                  "Partial"]
    ];

    const Tx = 0.6, Ty = 1.85, Tw = 12.1;
    const rows = [headers, ...data];
    const colW = [3.4, 2.4, 2.0, 2.2, 2.1];

    const tableRows = rows.map((row, ri) => row.map((cell, ci) => {
      const isHeader = ri === 0;
      const isUs = ci === 1;
      const isLeftCol = ci === 0;
      let fill;
      if (isHeader && isUs) fill = C.gold;
      else if (isHeader) fill = C.ink;
      else if (isUs) fill = C.goldLite;
      else if (ri % 2 === 0) fill = "FFFFFF";
      else fill = C.light;

      return {
        text: cell,
        options: {
          fill: { color: fill },
          color: isHeader ? (isUs ? C.ink : "FFFFFF") : (isLeftCol ? C.ink : C.charcoal),
          bold: isHeader || isLeftCol || isUs,
          fontSize: isHeader ? 11 : 10.5,
          fontFace: "Calibri",
          align: ci === 0 ? "left" : "center",
          valign: "middle",
          margin: 0.08
        }
      };
    }));

    s.addTable(tableRows, {
      x: Tx, y: Ty, w: Tw, colW,
      rowH: 0.45,
      border: { type: "solid", pt: 0.5, color: C.rule }
    });

    s.addText(
      "Defensibility: Codepet IP (the pet companion + AI coach) + 12-month head start with Vietnam premium families + alumni network compounding.",
      { x: 0.6, y: 6.55, w: 12.1, h: 0.5, margin: 0,
        fontFace: "Georgia", italic: true, fontSize: 13, color: C.purple, bold: true });

    footer(s, 17);
  }

  // ============================================================
  // SLIDE 18 — 12-MONTH ROADMAP
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "17  ·  ROADMAP", "12 months. Pilot → repeatable cohort engine → school B2B.");

    const phases = [
      { q: "Q1", t: "PILOT",       fill: C.lavender,
        bullets: ["1 Founder cohort × 12 students", "1 Junior cohort × 12 students", "Curriculum v1 locked", "First Demo Day at HCMC venue"] },
      { q: "Q2", t: "VALIDATE",    fill: C.purple,
        bullets: ["Test all 3 price tiers in market", "Launch parent-influencer co-marketing", "First school pilot signed", "Refine Codepet AI coach v2"] },
      { q: "Q3", t: "SCALE",       fill: C.ink,
        bullets: ["Open Hanoi cohort", "Hire Parent Success FTE", "Run 6 cohorts simultaneously", "Launch alumni angel network"] },
      { q: "Q4", t: "EXPAND",      fill: C.gold,
        bullets: ["Operator Studio launch", "B2B school annual contracts", "Brand event: Founders Society Gala", "Y2 fundraise prep / cash-flow positive"] }
    ];

    const cw = 2.95, ch = 4.7, gap = 0.18, startX = 0.6, y = 1.9;
    phases.forEach((p, i) => {
      const x = startX + i * (cw + gap);
      card(s, x, y, cw, ch);
      // top color block
      s.addShape(pres.shapes.RECTANGLE, { x, y, w: cw, h: 1.1, fill: { color: p.fill }, line: { color: p.fill } });
      s.addText(p.q, { x: x + 0.25, y: y + 0.2, w: cw - 0.5, h: 0.4, margin: 0,
        fontFace: "Calibri", fontSize: 12, bold: true, color: C.gold, charSpacing: 4 });
      s.addText(p.t, { x: x + 0.25, y: y + 0.5, w: cw - 0.5, h: 0.55, margin: 0,
        fontFace: "Georgia", fontSize: 24, bold: true, color: "FFFFFF" });
      s.addText(
        p.bullets.map((b, j) => ({ text: b, options: { bullet: true, breakLine: j !== p.bullets.length - 1 } })),
        { x: x + 0.25, y: y + 1.3, w: cw - 0.5, h: ch - 1.5, margin: 0,
          fontFace: "Calibri", fontSize: 12, color: C.charcoal, paraSpaceAfter: 8 }
      );
    });

    footer(s, 18);
  }

  // ============================================================
  // SLIDE 19 — RISKS
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "18  ·  RISKS & MITIGATIONS", "What we're worried about — and what we're doing about it.");

    const risks = [
      { r: "Parents see \"play\" and balk at premium pricing.",
        m: "Outcome-first marketing: shipped products, real revenue from graduates, founder-led story. The $3K price IS the marketing — it filters in serious buyers." },
      { r: "Founder bandwidth — Astro Vinh is the bottleneck.",
        m: "Cap at 1–2 cohorts simultaneously. Document everything via Codepet so a future master coach can be trained. Y2: clone Astro's playbook for second instructor." },
      { r: "Refund risk / completion drop-off.",
        m: "14-day money-back. Codepet daily co-pilot keeps momentum between live sessions. Founder accountability + small cohort = highest completion in category." },
      { r: "Regulatory: youth + payments + AI in Vietnam.",
        m: "COPPA-grade controls, Vietnam education registration, parent consent flows, no model training on student data, clear AI disclosure." },
      { r: "Competition from US / global edtech.",
        m: "Vietnam-first, Vietnamese-language, founder-led. The product is Astro. US incumbents cannot replicate the founder." },
      { r: "Codepet platform is still early (pre-MVP shipping).",
        m: "Pilot cohort runs even with a stripped-down Codepet. Founder-led teaching carries the program. Platform upgrades are additive, not gating." }
    ];
    const cw = 6.0, ch = 1.65, gap = 0.18, startX = 0.6, startY = 1.9;
    risks.forEach((r, i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      accentBar(s, x, y, ch, C.coral);
      s.addText(r.r, { x: x + 0.3, y: y + 0.2, w: cw - 0.55, h: 0.55, margin: 0,
        fontFace: "Georgia", fontSize: 13, bold: true, color: C.ink });
      s.addText([
        { text: "MITIGATION  ", options: { bold: true, color: C.green } },
        { text: r.m, options: { color: C.charcoal } }
      ], { x: x + 0.3, y: y + 0.78, w: cw - 0.55, h: 0.85, margin: 0,
        fontFace: "Calibri", fontSize: 11 });
    });

    footer(s, 19);
  }

  // ============================================================
  // SLIDE 20 — WHY IT WINS / CLOSING
  // ============================================================
  {
    const s = pres.addSlide(); darkBg(s);
    s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: SW, h: 0.08, fill: { color: C.gold }, line: { color: C.gold } });

    s.addShape(pres.shapes.RECTANGLE, { x: 0.8, y: 0.7, w: 0.35, h: 0.07, fill: { color: C.gold }, line: { color: C.gold } });
    s.addText("19  ·  WHY IT WINS", {
      x: 1.25, y: 0.55, w: 8, h: 0.4, margin: 0,
      fontFace: "Calibri", fontSize: 13, bold: true, color: C.goldLite, charSpacing: 6
    });

    s.addText(
      "\"In Vietnam, the next great\nfounder won't be born in the\nValley. They'll be 14, in District\n7, with a pet on their desk.\"",
      { x: 0.8, y: 1.5, w: 11.5, h: 3.2, margin: 0,
        fontFace: "Georgia", fontSize: 44, bold: true, italic: true, color: "FFFFFF" });

    // Three closing reasons
    const reasons = [
      { icon: ico.bolt,    t: "Right time",   d: "AI just made shipping accessible at age 14." },
      { icon: ico.flag,    t: "Right place",  d: "Vietnam premium families are ready and underserved." },
      { icon: ico.crown,   t: "Right team",   d: "MURROR + Codepet + a curriculum no one else has." }
    ];
    const cw = 3.85, ch = 1.7, gap = 0.25, startX = 0.8, y = 5.1;
    reasons.forEach((r, i) => {
      const x = startX + i * (cw + gap);
      s.addShape(pres.shapes.RECTANGLE, { x, y, w: cw, h: ch, fill: { color: C.ink }, line: { color: C.purple, width: 0.75 } });
      iconCircle(s, x + 0.25, y + 0.3, 1.0, C.purple, r.icon);
      s.addText(r.t, { x: x + 1.4, y: y + 0.3, w: cw - 1.55, h: 0.4, margin: 0,
        fontFace: "Georgia", fontSize: 18, bold: true, color: C.gold });
      s.addText(r.d, { x: x + 1.4, y: y + 0.78, w: cw - 1.55, h: 0.85, margin: 0,
        fontFace: "Calibri", fontSize: 11, color: "FFFFFF" });
    });

    s.addText("Codepet Academy  ·  Confidential", {
      x: 0.8, y: SH - 0.4, w: 8, h: 0.3, margin: 0,
      fontFace: "Calibri", fontSize: 9, color: C.goldLite });
    s.addText("20", {
      x: SW - 1, y: SH - 0.4, w: 0.4, h: 0.3, margin: 0, align: "right",
      fontFace: "Calibri", fontSize: 9, color: C.goldLite });
  }

  // ============================================================
  // SLIDE 21 — OPEN QUESTIONS FOR FOUNDER
  // ============================================================
  {
    const s = pres.addSlide(); lightBg(s);
    pageHeader(s, "20  ·  OPEN QUESTIONS", "Eight decisions that will shape the v1 program.");

    const qs = [
      "Pilot language: Vietnamese, English, or bilingual? Astro's natural delivery + parent ICP both matter.",
      "Cohort cap: 8, 10, or 12 students max for V1? Tighter = better outcomes, slower revenue ramp.",
      "Refund policy: 14-day full refund, or 'no refund but free re-enrol if outcome guarantee not met'?",
      "Annual plan: 4 back-to-back cohorts, or 1 cohort + alumni-only access for the rest of the year?",
      "Demo Day investors: real angels, MURROR network, or simulated for V1? Affects credibility + risk.",
      "Brand: keep 'Codepet Academy' or launch as 'Astro Vinh Founder Program' powered by Codepet?",
      "Founder bandwidth: hard cap of 1 cohort at a time, or run 2 in parallel from Q3 onward?",
      "B2B schools: revisit in Y2 only, or open conversations with 2–3 international schools now?"
    ];

    const cw = 6.05, ch = 1.05, gap = 0.15, startX = 0.6, startY = 1.85;
    qs.forEach((q, i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const x = startX + col * (cw + gap), y = startY + row * (ch + gap);
      card(s, x, y, cw, ch);
      // number bubble
      s.addShape(pres.shapes.OVAL, { x: x + 0.2, y: y + 0.3, w: 0.6, h: 0.6,
        fill: { color: C.gold }, line: { color: C.gold } });
      s.addText(String(i + 1), { x: x + 0.2, y: y + 0.3, w: 0.6, h: 0.6, margin: 0, align: "center", valign: "middle",
        fontFace: "Georgia", fontSize: 18, bold: true, color: C.ink });
      s.addText(q, { x: x + 0.95, y: y + 0.2, w: cw - 1.1, h: ch - 0.4, margin: 0, valign: "middle",
        fontFace: "Calibri", fontSize: 12, color: C.charcoal });
    });

    s.addText(
      "Recommended next step: lock pilot cohort dates + 5 founding-student commitments before refining anything else on this list.",
      { x: 0.6, y: 6.65, w: 12.1, h: 0.3, margin: 0, align: "center",
        fontFace: "Georgia", italic: true, fontSize: 12, bold: true, color: C.purple });

    footer(s, 21);
  }

  // ============================================================
  // Save
  // ============================================================
  const outPath = "/Users/monatruong/Downloads/CodePet-Clean/Codepet-Academy-Business-Plan.pptx";
  await pres.writeFile({ fileName: outPath });
  console.log("Saved:", outPath);
})();
