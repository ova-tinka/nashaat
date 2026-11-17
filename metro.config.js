const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Configuration files can contain credentials and must never be treated as
// JavaScript modules or included in a development or production bundle.
const environmentFiles = /(?:^|[/\\])\.env(?:\.[^/\\]*)?$/;
const existingBlockList = config.resolver.blockList;
config.resolver.blockList = [
  ...(Array.isArray(existingBlockList) ? existingBlockList : existingBlockList ? [existingBlockList] : []),
  environmentFiles,
];

module.exports = config;
