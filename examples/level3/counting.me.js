// SPDX-License-Identifier: PMPL-1.0-or-later
// Level 3: Counting and Repeating - Make the computer count!

import { createMeEnvironment, execute } from '../../src/Main.res.js';

// This program counts and repeats things!
// It's like when you count sheep to fall asleep.

const countingSheep = {
  nodeType: 'Program',
  children: [
    { nodeType: 'Say', content: "Let's count some sheep!" },
    { nodeType: 'Say', content: '' },

    // Start with zero sheep
    { nodeType: 'Remember', attributes: { name: 'sheep' }, content: '0' },

    // Count 5 sheep
    {
      nodeType: 'Repeat',
      attributes: { times: '5' },
      children: [
        { nodeType: 'Add', attributes: { to: 'sheep' }, content: '1' },
        { nodeType: 'Say', content: '{sheep} sheep jumping over the fence!' },
      ],
    },

    { nodeType: 'Say', content: '' },
    { nodeType: 'Say', content: 'I counted {sheep} sheep! Time for sleep!' },
  ],
};

console.log('=== Level 3: Counting Sheep ===\n');
execute(countingSheep, createMeEnvironment());

// Another example: Hip hip hooray!
console.log('\n=== Bonus: Hip Hip Hooray! ===\n');

const celebration = {
  nodeType: 'Program',
  children: [
    { nodeType: 'Say', content: "Let's celebrate!" },
    {
      nodeType: 'Repeat',
      attributes: { times: '3' },
      children: [{ nodeType: 'Say', content: 'Hip hip hooray!' }],
    },
    { nodeType: 'Say', content: 'What a party!' },
  ],
};

execute(celebration, createMeEnvironment());
console.log('\nYou learned how to make the computer repeat things!');
