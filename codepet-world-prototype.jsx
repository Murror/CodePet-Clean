import { useState, useEffect, useRef } from "react";

// ─── Pixel Art Characters (SVG-based for crisp rendering) ───
const PixelChar = ({ name, size = 48, x, y, animated = false }) => {
  const colors = {
    byte: { body: "#7B6BD8", eye: "#FFFFFF", accent: "#534AB7" },
    nova: { body: "#E8845C", eye: "#FFFFFF", accent: "#C4613A" },
    crash: { body: "#5CB8E8", eye: "#FFFFFF", accent: "#3A8EC4" },
    luna: { body: "#C45CE8", eye: "#FFFFFF", accent: "#9A3AC4" },
  };
  const c = colors[name] || colors.byte;
  const px = size / 12;

  return (
    <g
      transform={`translate(${x - size / 2}, ${y - size / 2})`}
      style={animated ? { animation: "petBounce 0.6s ease-in-out infinite" } : {}}
    >
      {/* Body */}
      <rect x={px * 3} y={px * 2} width={px * 6} height={px * 7} fill={c.body} rx={px} />
      {/* Head */}
      <rect x={px * 2} y={px * 1} width={px * 8} height={px * 5} fill={c.body} rx={px} />
      {/* Eyes */}
      <rect x={px * 4} y={px * 3} width={px * 1.5} height={px * 1.5} fill={c.eye} rx={px * 0.3} />
      <rect x={px * 7} y={px * 3} width={px * 1.5} height={px * 1.5} fill={c.eye} rx={px * 0.3} />
      {/* Pupils */}
      <rect x={px * 4.5} y={px * 3.5} width={px * 0.8} height={px * 0.8} fill="#2D2B26" />
      <rect x={px * 7.5} y={px * 3.5} width={px * 0.8} height={px * 0.8} fill="#2D2B26" />
      {/* Feet */}
      <rect x={px * 3} y={px * 9} width={px * 2} height={px * 1.5} fill={c.accent} rx={px * 0.3} />
      <rect x={px * 7} y={px * 9} width={px * 2} height={px * 1.5} fill={c.accent} rx={px * 0.3} />
      {/* Ears/antenna */}
      <rect x={px * 2} y={px * 0} width={px * 2} height={px * 2} fill={c.accent} rx={px * 0.5} />
      <rect x={px * 8} y={px * 0} width={px * 2} height={px * 2} fill={c.accent} rx={px * 0.5} />
    </g>
  );
};

// ─── World Data ───
const worlds = [
  {
    id: "python-forest",
    name: "Python Forest",
    emoji: "🌲",
    color: "#2D5A27",
    bgGradient: ["#1a3a15", "#2D5A27", "#1a4a20"],
    accent: "#4CAF50",
    description: "Learn the basics of Python in a magical forest",
    unlocked: true,
    progress: 3,
    totalNodes: 8,
    nodes: [
      { id: 1, name: "Variables", type: "lesson", status: "completed", x: 120, y: 420 },
      { id: 2, name: "Data Types", type: "lesson", status: "completed", x: 220, y: 350 },
      { id: 3, name: "Print()", type: "lesson", status: "completed", x: 350, y: 310 },
      { id: 4, name: "If/Else", type: "challenge", status: "current", x: 480, y: 270 },
      { id: 5, name: "Loops", type: "lesson", status: "locked", x: 580, y: 200 },
      { id: 6, name: "Functions", type: "lesson", status: "locked", x: 680, y: 250 },
      { id: 7, name: "Lists", type: "challenge", status: "locked", x: 780, y: 180 },
      { id: 8, name: "Boss: Debug!", type: "boss", status: "locked", x: 880, y: 130 },
    ],
  },
  {
    id: "terminal-cave",
    name: "Terminal Cave",
    emoji: "🕳️",
    color: "#3A3A5C",
    bgGradient: ["#1a1a2e", "#3A3A5C", "#252545"],
    accent: "#9C88FF",
    description: "Navigate the dark caves of the command line",
    unlocked: true,
    progress: 0,
    totalNodes: 8,
    nodes: [
      { id: 1, name: "cd & ls", type: "lesson", status: "current", x: 120, y: 420 },
      { id: 2, name: "mkdir & touch", type: "lesson", status: "locked", x: 250, y: 360 },
      { id: 3, name: "cat & echo", type: "lesson", status: "locked", x: 380, y: 300 },
      { id: 4, name: "Pipes", type: "challenge", status: "locked", x: 500, y: 240 },
      { id: 5, name: "grep", type: "lesson", status: "locked", x: 620, y: 280 },
      { id: 6, name: "chmod", type: "lesson", status: "locked", x: 730, y: 210 },
      { id: 7, name: "Scripts", type: "challenge", status: "locked", x: 820, y: 150 },
      { id: 8, name: "Boss: Root!", type: "boss", status: "locked", x: 900, y: 100 },
    ],
  },
  {
    id: "html-kingdom",
    name: "HTML Kingdom",
    emoji: "🏰",
    color: "#8B4513",
    bgGradient: ["#4a2810", "#8B4513", "#6B3410"],
    accent: "#FF9800",
    description: "Build your kingdom with HTML & CSS",
    unlocked: false,
    progress: 0,
    totalNodes: 8,
    nodes: [],
  },
  {
    id: "git-galaxy",
    name: "Git Galaxy",
    emoji: "🌌",
    color: "#1a1a3e",
    bgGradient: ["#0a0a1e", "#1a1a3e", "#151535"],
    accent: "#E040FB",
    description: "Explore version control across the stars",
    unlocked: false,
    progress: 0,
    totalNodes: 10,
    nodes: [],
  },
];

// ─── Screens ───
const SCREEN = {
  WORLD_MAP: "world_map",
  ENTERING: "entering",
  INSIDE_WORLD: "inside_world",
  LESSON: "lesson",
};

export default function CodePetWorldPrototype() {
  const [screen, setScreen] = useState(SCREEN.WORLD_MAP);
  const [selectedWorld, setSelectedWorld] = useState(null);
  const [selectedNode, setSelectedNode] = useState(null);
  const [portalPhase, setPortalPhase] = useState(0);
  const [charPos, setCharPos] = useState({ x: 0, y: 0 });
  const [showLessonComplete, setShowLessonComplete] = useState(false);
  const [worldsState, setWorldsState] = useState(worlds);
  const [coins, setCoins] = useState(42);
  const [xp, setXp] = useState(340);
  const canvasRef = useRef(null);

  // Enter a world with portal transition
  const enterWorld = (world) => {
    if (!world.unlocked) return;
    setSelectedWorld(world);
    setScreen(SCREEN.ENTERING);
    setPortalPhase(0);

    // Portal animation phases
    setTimeout(() => setPortalPhase(1), 200);
    setTimeout(() => setPortalPhase(2), 600);
    setTimeout(() => setPortalPhase(3), 1000);
    setTimeout(() => {
      setScreen(SCREEN.INSIDE_WORLD);
      const currentNode = world.nodes.find((n) => n.status === "current");
      if (currentNode) {
        setCharPos({ x: currentNode.x, y: currentNode.y });
      } else {
        setCharPos({ x: world.nodes[0].x, y: world.nodes[0].y });
      }
    }, 1600);
  };

  // Click a node
  const clickNode = (node) => {
    if (node.status === "locked") return;
    if (node.status === "completed") return;
    setSelectedNode(node);
    // Animate character walking to node
    setCharPos({ x: node.x, y: node.y });
    setTimeout(() => {
      setScreen(SCREEN.LESSON);
    }, 500);
  };

  // Complete a lesson
  const completeLesson = () => {
    setShowLessonComplete(true);
    setCoins((c) => c + 10);
    setXp((x) => x + 25);

    setTimeout(() => {
      setShowLessonComplete(false);
      // Update world state
      setWorldsState((prev) =>
        prev.map((w) => {
          if (w.id !== selectedWorld.id) return w;
          const updatedNodes = w.nodes.map((n, i) => {
            if (n.id === selectedNode.id) return { ...n, status: "completed" };
            if (i > 0 && w.nodes[i - 1].id === selectedNode.id && n.status === "locked")
              return { ...n, status: "current" };
            return n;
          });
          return {
            ...w,
            nodes: updatedNodes,
            progress: updatedNodes.filter((n) => n.status === "completed").length,
          };
        })
      );

      // Find next node
      const currentIndex = selectedWorld.nodes.findIndex((n) => n.id === selectedNode.id);
      const nextNode = selectedWorld.nodes[currentIndex + 1];
      if (nextNode) {
        setCharPos({ x: nextNode.x, y: nextNode.y });
        setSelectedWorld((prev) => ({
          ...prev,
          nodes: prev.nodes.map((n, i) => {
            if (n.id === selectedNode.id) return { ...n, status: "completed" };
            if (i === currentIndex + 1 && n.status === "locked") return { ...n, status: "current" };
            return n;
          }),
        }));
      }
      setSelectedNode(null);
      setScreen(SCREEN.INSIDE_WORLD);
    }, 2000);
  };

  // ─── World Map Screen ───
  const WorldMapScreen = () => (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: "linear-gradient(180deg, #1a1428 0%, #2D2654 40%, #3D3670 100%)",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Stars background */}
      {Array.from({ length: 40 }).map((_, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            width: i % 3 === 0 ? 3 : 2,
            height: i % 3 === 0 ? 3 : 2,
            backgroundColor: "#fff",
            opacity: 0.3 + (i % 5) * 0.15,
            left: `${(i * 37) % 100}%`,
            top: `${(i * 23) % 60}%`,
            animation: `twinkle ${2 + (i % 3)}s ease-in-out infinite ${i * 0.3}s`,
          }}
        />
      ))}

      {/* Header */}
      <div
        style={{
          padding: "20px 24px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          position: "relative",
          zIndex: 2,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div
            style={{
              width: 40,
              height: 40,
              background: "#7B6BD8",
              borderRadius: 8,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 20,
              imageRendering: "pixelated",
              border: "2px solid #534AB7",
            }}
          >
            🐾
          </div>
          <div>
            <div style={{ color: "#fff", fontFamily: "monospace", fontSize: 16, fontWeight: "bold" }}>
              Byte's Journey
            </div>
            <div style={{ color: "#A89BF2", fontFamily: "monospace", fontSize: 11 }}>
              Level 4 · {xp} XP
            </div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          <div
            style={{
              background: "rgba(255,255,255,0.1)",
              padding: "6px 14px",
              borderRadius: 20,
              color: "#FFD700",
              fontFamily: "monospace",
              fontSize: 13,
              fontWeight: "bold",
              border: "1px solid rgba(255,215,0,0.3)",
            }}
          >
            🪙 {coins}
          </div>
          <div
            style={{
              background: "rgba(255,255,255,0.1)",
              padding: "6px 14px",
              borderRadius: 20,
              color: "#FF6B6B",
              fontFamily: "monospace",
              fontSize: 13,
              fontWeight: "bold",
              border: "1px solid rgba(255,107,107,0.3)",
            }}
          >
            ❤️ 5
          </div>
        </div>
      </div>

      {/* Title */}
      <div style={{ textAlign: "center", marginTop: 8, marginBottom: 24, position: "relative", zIndex: 2 }}>
        <div
          style={{
            color: "#fff",
            fontFamily: "monospace",
            fontSize: 28,
            fontWeight: "bold",
            textShadow: "0 2px 8px rgba(123,107,216,0.5)",
            letterSpacing: 2,
          }}
        >
          ✦ WORLD MAP ✦
        </div>
        <div style={{ color: "#A89BF2", fontFamily: "monospace", fontSize: 12, marginTop: 4 }}>
          Choose your next adventure
        </div>
      </div>

      {/* World Cards */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 16,
          padding: "0 24px",
          maxWidth: 700,
          margin: "0 auto",
          position: "relative",
          zIndex: 2,
        }}
      >
        {worldsState.map((world) => (
          <div
            key={world.id}
            onClick={() => enterWorld(world)}
            style={{
              background: world.unlocked
                ? `linear-gradient(135deg, ${world.bgGradient[0]}, ${world.bgGradient[1]})`
                : "rgba(255,255,255,0.05)",
              borderRadius: 16,
              padding: 20,
              cursor: world.unlocked ? "pointer" : "not-allowed",
              border: `2px solid ${world.unlocked ? world.accent + "60" : "rgba(255,255,255,0.1)"}`,
              transition: "all 0.3s ease",
              opacity: world.unlocked ? 1 : 0.5,
              position: "relative",
              overflow: "hidden",
            }}
            onMouseEnter={(e) => {
              if (world.unlocked) {
                e.currentTarget.style.transform = "translateY(-4px) scale(1.02)";
                e.currentTarget.style.boxShadow = `0 8px 24px ${world.accent}30`;
              }
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = "";
              e.currentTarget.style.boxShadow = "";
            }}
          >
            {/* Decorative pixels */}
            {world.unlocked && (
              <>
                <div
                  style={{
                    position: "absolute",
                    top: 8,
                    right: 8,
                    width: 6,
                    height: 6,
                    background: world.accent,
                    opacity: 0.4,
                  }}
                />
                <div
                  style={{
                    position: "absolute",
                    top: 16,
                    right: 16,
                    width: 4,
                    height: 4,
                    background: world.accent,
                    opacity: 0.3,
                  }}
                />
              </>
            )}

            <div style={{ fontSize: 36, marginBottom: 8 }}>{world.emoji}</div>
            <div
              style={{
                color: "#fff",
                fontFamily: "monospace",
                fontSize: 15,
                fontWeight: "bold",
                marginBottom: 4,
              }}
            >
              {world.name}
            </div>
            <div
              style={{
                color: "rgba(255,255,255,0.6)",
                fontFamily: "monospace",
                fontSize: 11,
                marginBottom: 12,
                lineHeight: 1.4,
              }}
            >
              {world.description}
            </div>

            {/* Progress bar */}
            {world.unlocked ? (
              <div>
                <div
                  style={{
                    height: 6,
                    background: "rgba(255,255,255,0.15)",
                    borderRadius: 3,
                    overflow: "hidden",
                  }}
                >
                  <div
                    style={{
                      height: "100%",
                      width: `${(world.progress / world.totalNodes) * 100}%`,
                      background: `linear-gradient(90deg, ${world.accent}, ${world.accent}CC)`,
                      borderRadius: 3,
                      transition: "width 0.5s ease",
                    }}
                  />
                </div>
                <div
                  style={{
                    color: "rgba(255,255,255,0.5)",
                    fontFamily: "monospace",
                    fontSize: 10,
                    marginTop: 6,
                  }}
                >
                  {world.progress}/{world.totalNodes} challenges
                </div>
              </div>
            ) : (
              <div
                style={{
                  color: "rgba(255,255,255,0.3)",
                  fontFamily: "monospace",
                  fontSize: 11,
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                }}
              >
                🔒 Complete previous world
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );

  // ─── Portal Transition ───
  const PortalScreen = () => (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: "#000",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Portal rings */}
      {[0, 1, 2, 3].map((ring) => (
        <div
          key={ring}
          style={{
            position: "absolute",
            width: portalPhase >= ring ? 300 + ring * 80 : 0,
            height: portalPhase >= ring ? 300 + ring * 80 : 0,
            borderRadius: "50%",
            border: `3px solid ${selectedWorld?.accent || "#7B6BD8"}`,
            opacity: portalPhase >= ring ? 0.6 - ring * 0.12 : 0,
            transition: "all 0.5s ease-out",
            animation: portalPhase >= ring ? `portalSpin ${3 + ring}s linear infinite` : "none",
          }}
        />
      ))}

      {/* Center flash */}
      <div
        style={{
          width: portalPhase >= 2 ? 600 : 10,
          height: portalPhase >= 2 ? 600 : 10,
          background: `radial-gradient(circle, ${selectedWorld?.accent || "#7B6BD8"}80 0%, transparent 70%)`,
          borderRadius: "50%",
          transition: "all 0.6s ease-out",
          position: "absolute",
        }}
      />

      {/* World name */}
      <div
        style={{
          position: "relative",
          zIndex: 2,
          textAlign: "center",
          opacity: portalPhase >= 2 ? 1 : 0,
          transform: portalPhase >= 2 ? "scale(1)" : "scale(0.5)",
          transition: "all 0.4s ease-out",
        }}
      >
        <div style={{ fontSize: 48, marginBottom: 8 }}>{selectedWorld?.emoji}</div>
        <div
          style={{
            color: "#fff",
            fontFamily: "monospace",
            fontSize: 24,
            fontWeight: "bold",
            textShadow: `0 0 20px ${selectedWorld?.accent}`,
            letterSpacing: 3,
          }}
        >
          {selectedWorld?.name}
        </div>
        <div style={{ color: "rgba(255,255,255,0.6)", fontFamily: "monospace", fontSize: 12, marginTop: 8 }}>
          Entering world...
        </div>
      </div>

      {/* Pixel particles */}
      {portalPhase >= 1 &&
        Array.from({ length: 20 }).map((_, i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              width: 4,
              height: 4,
              background: selectedWorld?.accent || "#7B6BD8",
              left: `${50 + Math.cos((i * 18 * Math.PI) / 180) * (20 + portalPhase * 15)}%`,
              top: `${50 + Math.sin((i * 18 * Math.PI) / 180) * (20 + portalPhase * 15)}%`,
              opacity: 0.8,
              animation: `particleFade 1s ease-out ${i * 0.05}s infinite`,
            }}
          />
        ))}
    </div>
  );

  // ─── Inside World Screen ───
  const InsideWorldScreen = () => {
    const world = worldsState.find((w) => w.id === selectedWorld?.id) || selectedWorld;
    if (!world) return null;

    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          background: `linear-gradient(180deg, ${world.bgGradient[0]} 0%, ${world.bgGradient[1]} 50%, ${world.bgGradient[2]} 100%)`,
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Atmospheric particles */}
        {Array.from({ length: 15 }).map((_, i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              width: i % 2 === 0 ? 3 : 2,
              height: i % 2 === 0 ? 3 : 2,
              background: world.accent,
              opacity: 0.2 + (i % 4) * 0.1,
              left: `${(i * 31) % 100}%`,
              top: `${20 + (i * 19) % 60}%`,
              animation: `float ${3 + (i % 3)}s ease-in-out infinite ${i * 0.4}s`,
            }}
          />
        ))}

        {/* Top bar */}
        <div
          style={{
            padding: "16px 20px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            position: "relative",
            zIndex: 10,
          }}
        >
          <div
            onClick={() => {
              setScreen(SCREEN.WORLD_MAP);
              setSelectedWorld(null);
            }}
            style={{
              background: "rgba(0,0,0,0.4)",
              padding: "8px 16px",
              borderRadius: 8,
              color: "#fff",
              fontFamily: "monospace",
              fontSize: 13,
              cursor: "pointer",
              border: "1px solid rgba(255,255,255,0.2)",
              display: "flex",
              alignItems: "center",
              gap: 6,
            }}
          >
            ← Back
          </div>
          <div style={{ color: "#fff", fontFamily: "monospace", fontSize: 16, fontWeight: "bold" }}>
            {world.emoji} {world.name}
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <span
              style={{
                background: "rgba(0,0,0,0.4)",
                padding: "6px 12px",
                borderRadius: 8,
                color: "#FFD700",
                fontFamily: "monospace",
                fontSize: 12,
              }}
            >
              🪙 {coins}
            </span>
            <span
              style={{
                background: "rgba(0,0,0,0.4)",
                padding: "6px 12px",
                borderRadius: 8,
                color: "#FF6B6B",
                fontFamily: "monospace",
                fontSize: 12,
              }}
            >
              ❤️ 5
            </span>
          </div>
        </div>

        {/* World map SVG with path and nodes */}
        <svg
          width="100%"
          height="calc(100% - 60px)"
          viewBox="0 0 1000 500"
          style={{ position: "absolute", top: 60, left: 0 }}
        >
          {/* Path between nodes */}
          {world.nodes.map((node, i) => {
            if (i === 0) return null;
            const prev = world.nodes[i - 1];
            const isActive = node.status !== "locked";
            return (
              <line
                key={`path-${i}`}
                x1={prev.x}
                y1={prev.y}
                x2={node.x}
                y2={node.y}
                stroke={isActive ? world.accent : "rgba(255,255,255,0.15)"}
                strokeWidth={isActive ? 4 : 2}
                strokeDasharray={isActive ? "none" : "8 8"}
                opacity={isActive ? 0.8 : 0.4}
              />
            );
          })}

          {/* Ground decorations */}
          {world.id === "python-forest" && (
            <>
              {[80, 200, 450, 600, 750, 900].map((x, i) => (
                <g key={`tree-${i}`}>
                  <rect x={x} y={380 + (i % 3) * 30} width={8} height={20} fill="#5D3A1A" />
                  <polygon
                    points={`${x - 10},${380 + (i % 3) * 30} ${x + 4},${350 + (i % 3) * 30} ${x + 18},${380 + (i % 3) * 30}`}
                    fill="#2D5A27"
                    opacity={0.6}
                  />
                </g>
              ))}
              {[150, 300, 520, 720].map((x, i) => (
                <rect key={`grass-${i}`} x={x} y={440 + (i % 2) * 15} width={6} height={10} fill="#4CAF50" opacity={0.3} />
              ))}
            </>
          )}

          {world.id === "terminal-cave" && (
            <>
              {[60, 180, 340, 500, 660, 820, 950].map((x, i) => (
                <g key={`stalac-${i}`}>
                  <polygon
                    points={`${x},0 ${x + 8},${30 + (i % 3) * 15} ${x + 16},0`}
                    fill="#4a4a6e"
                    opacity={0.5}
                  />
                  <polygon
                    points={`${x + 20},480 ${x + 28},${450 - (i % 3) * 15} ${x + 36},480`}
                    fill="#3a3a5e"
                    opacity={0.4}
                  />
                </g>
              ))}
            </>
          )}

          {/* Nodes */}
          {world.nodes.map((node) => {
            const isCompleted = node.status === "completed";
            const isCurrent = node.status === "current";
            const isLocked = node.status === "locked";
            const isBoss = node.type === "boss";
            const isChallenge = node.type === "challenge";
            const nodeSize = isBoss ? 32 : isChallenge ? 26 : 22;

            return (
              <g
                key={node.id}
                onClick={() => clickNode(node)}
                style={{ cursor: isLocked ? "not-allowed" : "pointer" }}
              >
                {/* Glow for current */}
                {isCurrent && (
                  <circle
                    cx={node.x}
                    cy={node.y}
                    r={nodeSize + 12}
                    fill={world.accent}
                    opacity={0.15}
                    style={{ animation: "pulse 2s ease-in-out infinite" }}
                  />
                )}

                {/* Node circle */}
                <circle
                  cx={node.x}
                  cy={node.y}
                  r={nodeSize}
                  fill={
                    isCompleted
                      ? world.accent
                      : isCurrent
                      ? world.bgGradient[1]
                      : "rgba(255,255,255,0.08)"
                  }
                  stroke={
                    isCompleted
                      ? world.accent
                      : isCurrent
                      ? world.accent
                      : "rgba(255,255,255,0.2)"
                  }
                  strokeWidth={isCurrent ? 3 : 2}
                  opacity={isLocked ? 0.4 : 1}
                />

                {/* Inner icon */}
                <text
                  x={node.x}
                  y={node.y + 5}
                  textAnchor="middle"
                  fontSize={isBoss ? 20 : 16}
                  opacity={isLocked ? 0.3 : 1}
                >
                  {isCompleted ? "✓" : isBoss ? "💀" : isChallenge ? "⚡" : isLocked ? "🔒" : "📖"}
                </text>

                {/* Completed checkmark */}
                {isCompleted && (
                  <circle cx={node.x + nodeSize - 4} cy={node.y - nodeSize + 4} r={8} fill="#4CAF50" stroke="#fff" strokeWidth={1.5} />
                )}
                {isCompleted && (
                  <text x={node.x + nodeSize - 4} y={node.y - nodeSize + 7.5} textAnchor="middle" fontSize={9} fill="#fff">
                    ✓
                  </text>
                )}

                {/* Label */}
                <text
                  x={node.x}
                  y={node.y + nodeSize + 18}
                  textAnchor="middle"
                  fill={isLocked ? "rgba(255,255,255,0.3)" : "#fff"}
                  fontFamily="monospace"
                  fontSize={11}
                  fontWeight={isCurrent ? "bold" : "normal"}
                >
                  {node.name}
                </text>
              </g>
            );
          })}

          {/* Character on map */}
          <PixelChar name="byte" size={40} x={charPos.x} y={charPos.y - 40} animated={true} />
        </svg>

        {/* Progress indicator */}
        <div
          style={{
            position: "absolute",
            bottom: 16,
            left: "50%",
            transform: "translateX(-50%)",
            background: "rgba(0,0,0,0.6)",
            padding: "8px 20px",
            borderRadius: 20,
            color: "#fff",
            fontFamily: "monospace",
            fontSize: 12,
            display: "flex",
            alignItems: "center",
            gap: 8,
            border: `1px solid ${world.accent}40`,
          }}
        >
          <span>{world.emoji}</span>
          <span>
            {world.progress}/{world.totalNodes} completed
          </span>
          <span style={{ color: world.accent }}>·</span>
          <span style={{ color: world.accent }}>
            {Math.round((world.progress / world.totalNodes) * 100)}%
          </span>
        </div>
      </div>
    );
  };

  // ─── Lesson Screen ───
  const LessonScreen = () => {
    const [answer, setAnswer] = useState(null);
    const world = selectedWorld;
    const node = selectedNode;

    const lessonData = {
      "If/Else": {
        title: "If/Else Statements",
        question: "What will this code print?",
        code: 'age = 15\nif age >= 18:\n    print("Adult")\nelse:\n    print("Minor")',
        options: ['"Adult"', '"Minor"', "Error", "Nothing"],
        correct: 1,
      },
      "cd & ls": {
        title: "Navigation Basics",
        question: "Which command lists files in a directory?",
        code: "$ ___\nDocuments  Downloads  Pictures",
        options: ["cd", "ls", "pwd", "mkdir"],
        correct: 1,
      },
    };

    const lesson = lessonData[node?.name] || {
      title: node?.name || "Lesson",
      question: "What is the output of this code?",
      code: 'x = 42\nprint(x)',
      options: ["42", "x", "Error", "None"],
      correct: 0,
    };

    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          background: `linear-gradient(180deg, ${world?.bgGradient[0] || "#1a1428"} 0%, #1a1a2e 100%)`,
          display: "flex",
          flexDirection: "column",
          position: "relative",
        }}
      >
        {/* Header */}
        <div
          style={{
            padding: "16px 20px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            borderBottom: "1px solid rgba(255,255,255,0.1)",
          }}
        >
          <div
            onClick={() => {
              setScreen(SCREEN.INSIDE_WORLD);
              setSelectedNode(null);
            }}
            style={{
              color: "rgba(255,255,255,0.6)",
              fontFamily: "monospace",
              fontSize: 13,
              cursor: "pointer",
            }}
          >
            ✕ Exit
          </div>
          <div style={{ color: "#fff", fontFamily: "monospace", fontSize: 14, fontWeight: "bold" }}>
            {node?.type === "challenge" ? "⚡ Challenge" : node?.type === "boss" ? "💀 Boss" : "📖 Lesson"} ·{" "}
            {lesson.title}
          </div>
          <div style={{ color: "#FF6B6B", fontFamily: "monospace", fontSize: 13 }}>❤️ 5</div>
        </div>

        {/* Lesson content */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 24 }}>
          {/* Question */}
          <div
            style={{
              color: "#fff",
              fontFamily: "monospace",
              fontSize: 18,
              fontWeight: "bold",
              marginBottom: 20,
              textAlign: "center",
            }}
          >
            {lesson.question}
          </div>

          {/* Code block */}
          <div
            style={{
              background: "#0d0d1a",
              border: "2px solid rgba(255,255,255,0.15)",
              borderRadius: 12,
              padding: 20,
              fontFamily: "monospace",
              fontSize: 15,
              color: "#E8D44D",
              whiteSpace: "pre",
              lineHeight: 1.6,
              marginBottom: 28,
              maxWidth: 400,
              width: "100%",
            }}
          >
            {lesson.code}
          </div>

          {/* Answer options */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, maxWidth: 400, width: "100%" }}>
            {lesson.options.map((opt, i) => (
              <div
                key={i}
                onClick={() => {
                  if (answer !== null) return;
                  setAnswer(i);
                  if (i === lesson.correct) {
                    setTimeout(() => completeLesson(), 800);
                  }
                }}
                style={{
                  background:
                    answer === null
                      ? "rgba(255,255,255,0.08)"
                      : i === lesson.correct
                      ? "rgba(76,175,80,0.3)"
                      : answer === i
                      ? "rgba(244,67,54,0.3)"
                      : "rgba(255,255,255,0.05)",
                  border: `2px solid ${
                    answer === null
                      ? "rgba(255,255,255,0.2)"
                      : i === lesson.correct
                      ? "#4CAF50"
                      : answer === i
                      ? "#F44336"
                      : "rgba(255,255,255,0.1)"
                  }`,
                  borderRadius: 10,
                  padding: "14px 16px",
                  color: "#fff",
                  fontFamily: "monospace",
                  fontSize: 14,
                  cursor: answer === null ? "pointer" : "default",
                  textAlign: "center",
                  transition: "all 0.2s ease",
                }}
              >
                {opt}
              </div>
            ))}
          </div>

          {/* Result feedback */}
          {answer !== null && (
            <div
              style={{
                marginTop: 20,
                padding: "12px 24px",
                borderRadius: 10,
                background: answer === lesson.correct ? "rgba(76,175,80,0.2)" : "rgba(244,67,54,0.2)",
                color: answer === lesson.correct ? "#81C784" : "#EF9A9A",
                fontFamily: "monospace",
                fontSize: 14,
                fontWeight: "bold",
              }}
            >
              {answer === lesson.correct ? "✓ Correct! +25 XP +10 coins" : "✕ Wrong! -1 ❤️"}
            </div>
          )}
        </div>

        {/* Lesson complete overlay */}
        {showLessonComplete && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "rgba(0,0,0,0.85)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              zIndex: 100,
            }}
          >
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 64, marginBottom: 16, animation: "bounce 0.6s ease-in-out" }}>⭐</div>
              <div
                style={{
                  color: "#FFD700",
                  fontFamily: "monospace",
                  fontSize: 24,
                  fontWeight: "bold",
                  marginBottom: 8,
                  letterSpacing: 2,
                }}
              >
                CHALLENGE COMPLETE!
              </div>
              <div style={{ color: "#fff", fontFamily: "monospace", fontSize: 14, opacity: 0.7 }}>
                Moving to next challenge...
              </div>
              <div style={{ display: "flex", gap: 16, justifyContent: "center", marginTop: 16 }}>
                <span
                  style={{
                    background: "rgba(255,215,0,0.2)",
                    padding: "6px 16px",
                    borderRadius: 8,
                    color: "#FFD700",
                    fontFamily: "monospace",
                    fontSize: 13,
                  }}
                >
                  +10 🪙
                </span>
                <span
                  style={{
                    background: "rgba(123,107,216,0.2)",
                    padding: "6px 16px",
                    borderRadius: 8,
                    color: "#A89BF2",
                    fontFamily: "monospace",
                    fontSize: 13,
                  }}
                >
                  +25 XP
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div style={{ width: "100%", maxWidth: 960, height: 600, margin: "0 auto", borderRadius: 16, overflow: "hidden", border: "2px solid rgba(255,255,255,0.1)", boxShadow: "0 20px 60px rgba(0,0,0,0.5)", position: "relative" }}>
      <style>{`
        @keyframes twinkle {
          0%, 100% { opacity: 0.2; }
          50% { opacity: 0.8; }
        }
        @keyframes pulse {
          0%, 100% { r: 34; opacity: 0.15; }
          50% { r: 40; opacity: 0.25; }
        }
        @keyframes float {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-8px); }
        }
        @keyframes portalSpin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        @keyframes particleFade {
          0% { opacity: 0.8; transform: scale(1); }
          100% { opacity: 0; transform: scale(0); }
        }
        @keyframes bounce {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-20px); }
        }
        @keyframes petBounce {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-4px); }
        }
      `}</style>

      {screen === SCREEN.WORLD_MAP && <WorldMapScreen />}
      {screen === SCREEN.ENTERING && <PortalScreen />}
      {screen === SCREEN.INSIDE_WORLD && <InsideWorldScreen />}
      {screen === SCREEN.LESSON && <LessonScreen />}
    </div>
  );
}
