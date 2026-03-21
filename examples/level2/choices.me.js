// SPDX-License-Identifier: PMPL-1.0-or-later
// Level 2: Making Choices - Teaching the computer to decide!

import { createMeEnvironment, execute } from '../../src/Main.res.js';

// This program makes choices based on what we tell it!
// Try changing "sunny" to "rainy" or "snowy" and see what happens!

const weatherChoices = {
  nodeType: 'Program',
  children: [
    // First, we remember what the weather is
    { nodeType: 'Remember', attributes: { name: 'weather' }, content: 'sunny' },
    { nodeType: 'Say', content: "Let me check the weather... it's {weather}!" },

    // Now we make choices based on the weather
    {
      nodeType: 'Choose',
      children: [
        {
          nodeType: 'When',
          attributes: { 'weather-is': 'sunny' },
          children: [
            { nodeType: 'Say', content: "It's sunny! Let's go to the park!" },
            { nodeType: 'Say', content: "Don't forget your sunscreen!" },
          ],
        },
        {
          nodeType: 'When',
          attributes: { 'weather-is': 'rainy' },
          children: [
            { nodeType: 'Say', content: "It's rainy! Let's stay inside." },
            { nodeType: 'Say', content: 'How about reading a book or playing a board game?' },
          ],
        },
        {
          nodeType: 'When',
          attributes: { 'weather-is': 'snowy' },
          children: [
            { nodeType: 'Say', content: "It's snowy! Time to build a snowman!" },
            { nodeType: 'Say', content: 'Bundle up warm!' },
          ],
        },
        {
          nodeType: 'Otherwise',
          children: [
            { nodeType: 'Say', content: "Hmm, I'm not sure what the weather is." },
            { nodeType: 'Say', content: 'Maybe look out the window?' },
          ],
        },
      ],
    },
  ],
};

console.log('=== Level 2: Making Choices ===\n');
execute(weatherChoices, createMeEnvironment());
console.log('\nYou taught the computer to make decisions!');
