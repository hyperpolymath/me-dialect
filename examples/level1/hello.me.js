// SPDX-License-Identifier: PMPL-1.0-or-later
// Level 1: Hello World - Your first Me program!

import { createMeEnvironment, execute } from '../../src/Main.res.js';

// This is your first Me program!
// It says "Hello" to the world.

const helloWorld = {
  nodeType: 'Program',
  children: [
    // <say> makes the computer talk!
    { nodeType: 'Say', content: 'Hello, world!' },
    { nodeType: 'Say', content: 'I am learning to code!' },
    { nodeType: 'Say', content: 'This is so fun!' },
  ],
};

console.log('=== Level 1: Hello World ===\n');
execute(helloWorld, createMeEnvironment());
console.log('\nGreat job! You wrote your first program!');
