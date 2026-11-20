const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Bundled reader script is loaded as inert text inside the isolated WebView.
config.resolver.assetExts.push('bundle');

// Configuration files can contain credentials and must never be treated as
// JavaScript modules or included in a development or production bundle.
const environmentFiles = /(?:^|[/\\])\.env(?:\.[^/\\]*)?$/;
const existingBlockList = config.resolver.blockList;
config.resolver.blockList = [
  ...(Array.isArray(existingBlockList) ? existingBlockList : existingBlockList ? [existingBlockList] : []),
  environmentFiles,
];

module.exports = config;
