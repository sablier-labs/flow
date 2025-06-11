/**
 * @type {import("lint-staged").Configuration}
 */
module.exports = {
  "*.{json,md,yml}": "bun prettier --cache --write",
  "*.sol": ["bun solhint --fix --noPrompt", "forge fmt"],
};
