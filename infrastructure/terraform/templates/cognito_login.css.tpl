/* Minimalist 80s hacker skin for the Ahara Cognito hosted UI */
:root {
  --ahara-bg: #010203;
  --ahara-panel: rgba(0, 10, 0, 0.82);
  --ahara-accent: #39ff14;
  --ahara-secondary: #0dccf2;
  --ahara-danger: #ff2079;
  --ahara-font: "Share Tech Mono", "Courier New", monospace;
  --ahara-logo: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20viewBox%3D%270%200%20256%20256%27%3E%0A%20%20%3Crect%20width%3D%27256%27%20height%3D%27256%27%20fill%3D%27%23020303%27%2F%3E%0A%20%20%3Crect%20x%3D%2710%27%20y%3D%2710%27%20width%3D%27236%27%20height%3D%27236%27%20fill%3D%27none%27%20stroke%3D%27%2339ff14%27%20stroke-width%3D%274%27%2F%3E%0A%20%20%3Crect%20x%3D%2726%27%20y%3D%2726%27%20width%3D%27204%27%20height%3D%27204%27%20fill%3D%27none%27%20stroke%3D%27%230dccf2%27%20stroke-width%3D%272%27%20stroke-dasharray%3D%276%206%27%2F%3E%0A%20%20%3Cpath%20d%3D%27M26%20190%20L230%2066%27%20stroke%3D%27%23ff2079%27%20stroke-width%3D%271.5%27%20fill%3D%27none%27%20stroke-dasharray%3D%274%208%27%2F%3E%0A%20%20%3Ctext%20x%3D%2750%25%27%20y%3D%2748%25%27%20fill%3D%27%2339ff14%27%20font-family%3D%27Courier%20New%2C%20monospace%27%20font-size%3D%2748%27%20text-anchor%3D%27middle%27%3EAHARA%3C%2Ftext%3E%0A%20%20%3Ctext%20x%3D%2750%25%27%20y%3D%2764%25%27%20fill%3D%27%230dccf2%27%20font-family%3D%27Courier%20New%2C%20monospace%27%20font-size%3D%2718%27%20text-anchor%3D%27middle%27%3EPLACEHOLDER%3C%2Ftext%3E%0A%3C%2Fsvg%3E");
}

html,
body {
  height: 100%;
  background: var(--ahara-bg);
  font-family: var(--ahara-font);
  color: var(--ahara-accent);
  text-transform: uppercase;
}

.background-customizable {
  position: relative;
  min-height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at top, rgba(57, 255, 20, 0.18), transparent 55%), var(--ahara-bg);
  overflow: hidden;
}

.background-customizable::before,
.background-customizable::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.background-customizable::before {
  background-image: linear-gradient(rgba(57, 255, 20, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(57, 255, 20, 0.08) 1px, transparent 1px);
  background-size: 22px 22px;
  opacity: 0.4;
}

.background-customizable::after {
  background: linear-gradient(rgba(5, 15, 5, 0.3), transparent 40%, rgba(5, 15, 5, 0.9));
  mix-blend-mode: screen;
}

.banner-customizable {
  display: none;
}

.modal-body {
  width: min(420px, calc(100% - 48px));
  background: var(--ahara-panel);
  border: 2px solid rgba(57, 255, 20, 0.65);
  box-shadow: 0 0 24px rgba(57, 255, 20, 0.22), 0 0 120px rgba(13, 204, 242, 0.1);
  padding: 48px 42px 54px;
  backdrop-filter: blur(2px);
  position: relative;
}

.modal-body::before {
  content: "AHARA NODE ACCESS";
  position: absolute;
  top: 12px;
  right: 18px;
  font-size: 12px;
  letter-spacing: 0.3em;
  color: rgba(13, 204, 242, 0.6);
}

.logo-customizable {
  width: 160px;
  height: 160px;
  margin: 0 auto 32px;
  background-image: var(--ahara-logo);
  background-size: cover;
  background-position: center;
  filter: drop-shadow(0 0 12px rgba(57, 255, 20, 0.3));
}

.logo-customizable img {
  opacity: 0;
}

.title-customizable,
.subtitle-customizable {
  text-align: center;
  color: var(--ahara-accent);
  letter-spacing: 0.2em;
}

.subtitle-customizable {
  margin-bottom: 36px;
  color: rgba(13, 204, 242, 0.8);
  font-size: 0.85rem;
}

label,
.label-customizable {
  display: none !important;
}

input[type="text"],
input[type="password"],
.inputField-customizable {
  width: 100%;
  background: transparent;
  border: none;
  border-bottom: 2px solid rgba(57, 255, 20, 0.6);
  color: var(--ahara-accent);
  padding: 14px 6px;
  font-size: 1rem;
  letter-spacing: 0.15em;
  transition: border 200ms ease, color 200ms ease, filter 200ms ease;
}

.inputField-customizable:focus,
input[type="text"]:focus,
input[type="password"]:focus {
  outline: none;
  border-bottom-color: var(--ahara-secondary);
  filter: drop-shadow(0 0 6px rgba(13, 204, 242, 0.6));
}

input::placeholder,
.inputField-customizable::placeholder {
  color: transparent;
}

.legalText-customizable,
.forgotPassword-customizable {
  color: rgba(57, 255, 20, 0.6);
  letter-spacing: 0.1em;
}

.submitButton-customizable {
  width: 100%;
  margin-top: 38px;
  background: linear-gradient(90deg, rgba(57, 255, 20, 0.7), rgba(13, 204, 242, 0.7));
  border: none;
  color: #001900;
  font-weight: bold;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  padding: 14px 18px;
  transition: transform 120ms ease, box-shadow 120ms ease;
  box-shadow: 0 0 18px rgba(57, 255, 20, 0.25);
}

.submitButton-customizable:hover {
  transform: translateY(-3px);
  box-shadow: 0 0 22px rgba(13, 204, 242, 0.45);
}

.submitButton-customizable:active {
  transform: translateY(1px);
}

.divider-customizable {
  color: rgba(57, 255, 20, 0.35);
  letter-spacing: 0.2em;
}

.federationButton-customizable {
  background: transparent;
  border: 1px dashed rgba(57, 255, 20, 0.4);
  color: rgba(57, 255, 20, 0.8);
  letter-spacing: 0.1em;
}

.federationButton-customizable:hover {
  border-color: var(--ahara-secondary);
  color: var(--ahara-secondary);
}

.errorMessage-customizable {
  background: rgba(255, 32, 121, 0.08);
  border: 1px solid rgba(255, 32, 121, 0.4);
  color: var(--ahara-danger);
  letter-spacing: 0.12em;
}

a {
  color: var(--ahara-secondary);
}

@keyframes ahara-scanline {
  0% {
    transform: translateY(-100%);
  }
  100% {
    transform: translateY(100%);
  }
}

.modal-body::after {
  content: "";
  position: absolute;
  inset: -8px;
  border: 1px solid rgba(57, 255, 20, 0.2);
  animation: ahara-scanline 6s linear infinite;
  opacity: 0.12;
}

.background-customizable,
.modal-body,
.logo-customizable {
  isolation: isolate;
}
