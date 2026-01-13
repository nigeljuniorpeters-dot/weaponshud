const hud = document.getElementById('hud');
const mode = document.getElementById('mode');
const weapon = document.getElementById('weapon');
const armed = document.getElementById('armed');
const state = document.getElementById('state');
const range = document.getElementById('range');
const proj = document.getElementById('proj');

const targetBox = document.getElementById('targetBox');
const leadDot = document.getElementById('leadDot');
const funnel = document.getElementById('funnel');
const impactDot = document.getElementById('impactDot');
const bombTarget = document.getElementById('bombTarget');

const cone = document.getElementById('cone');

function place(el, p) {
  el.style.left = `${(p.x * 100).toFixed(3)}%`;
  el.style.top  = `${(p.y * 100).toFixed(3)}%`;
}

window.addEventListener('message', (e) => {
  const msg = e.data;

  if (msg.type === "hud") {
    hud.classList.toggle('hidden', !msg.enabled);
    return;
  }

  if (msg.type !== "state") return;
  const d = msg.data || {};

  mode.textContent = d.mode || "A-A";
  weapon.textContent = d.weapon || "";
  armed.textContent = d.armed ? "ARMED" : "SAFE";
  state.textContent = d.projectileActive ? (d.projectileKind || "") : "";
  range.textContent = d.range ? `${Math.round(d.range)}m` : "";
  proj.textContent = d.projectileActive ? "ACTIVE" : "";

  if (d.targetBox) {
    targetBox.classList.remove('hidden');
    place(targetBox, d.targetBox);
    targetBox.classList.toggle('locked', !!d.lockReady);
  } else {
    targetBox.classList.add('hidden');
    targetBox.classList.remove('locked');
  }

  if (d.lead) {
    leadDot.classList.remove('hidden');
    place(leadDot, d.lead);
  } else {
    leadDot.classList.add('hidden');
  }

  funnel.classList.toggle('hidden', !d.showFunnel);

  if (d.impact) {
    impactDot.classList.remove('hidden');
    place(impactDot, d.impact);
  } else {
    impactDot.classList.add('hidden');
  }

  if (d.bombTarget) {
    bombTarget.classList.remove('hidden');
    place(bombTarget, d.bombTarget);
    const rot = (typeof d.bombTarget.rot === "number") ? d.bombTarget.rot : 0.0;
    bombTarget.style.transform = `translate(-50%,-50%) rotate(${rot.toFixed(2)}deg)`;
  } else {
    bombTarget.classList.add('hidden');
  }

  // cone HUD (only IR/RADAR)
  if (d.coneMode === "IR" || d.coneMode === "RADAR") {
    cone.classList.remove('hidden');
    const radius = (typeof d.coneRadius === "number") ? d.coneRadius : 0.0;
    const diameterVh = radius * 200.0;
    cone.style.width = `${diameterVh}vh`;
    cone.style.height = `${diameterVh}vh`;
  } else {
    cone.classList.add('hidden');
  }
});
