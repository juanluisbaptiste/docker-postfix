// release.config.js
module.exports = {
  tagFormat: 'v${version}',       // match your existing tag naming
  branches: ['master', 'develop'],// match your workflow trigger branches
};
