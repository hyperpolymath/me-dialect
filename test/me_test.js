// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
//
// Tests for Me Language Interpreter

import { assertEquals } from '@std/assert';
import { createMeEnvironment, execute, interpolate } from '../src/Main.res.js';

Deno.test('createMeEnvironment - creates empty environment', () => {
  const env = createMeEnvironment();
  assertEquals(Object.keys(env.variables).length, 0);
  assertEquals(env.output.length, 0);
  assertEquals(env.stopped, false);
});

Deno.test('interpolate - replaces variables', () => {
  const env = createMeEnvironment();
  env.variables['name'] = { TAG: 0, _0: 'Alex' }; // String("Alex")
  env.variables['age'] = { TAG: 1, _0: 10 }; // Number(10)

  const result = interpolate('My name is {name} and I am {age} years old.', env);
  assertEquals(result, 'My name is Alex and I am 10 years old.');
});

Deno.test('interpolate - keeps unknown variables', () => {
  const env = createMeEnvironment();
  const result = interpolate('Hello {unknown}!', env);
  assertEquals(result, 'Hello {unknown}!');
});

Deno.test('execute say - adds to output', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [{ nodeType: 'Say', content: 'Hello!' }],
  };

  execute(program, env);
  assertEquals(env.output, ['Hello!']);
});

Deno.test('execute remember - stores string variable', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'color' }, content: 'blue' },
    ],
  };

  execute(program, env);
  assertEquals(env.variables['color'], { TAG: 0, _0: 'blue' }); // String("blue")
});

Deno.test('execute remember - stores number variable', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'score' }, content: '42' },
    ],
  };

  execute(program, env);
  assertEquals(env.variables['score'], { TAG: 1, _0: 42 }); // Number(42)
});

Deno.test('execute add - increments number', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'count' }, content: '5' },
      { nodeType: 'Add', attributes: { to: 'count' }, content: '3' },
    ],
  };

  execute(program, env);
  assertEquals(env.variables['count'], { TAG: 1, _0: 8 }); // Number(8)
});

Deno.test('execute subtract - decrements number', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'lives' }, content: '3' },
      { nodeType: 'Subtract', attributes: { from: 'lives' }, content: '1' },
    ],
  };

  execute(program, env);
  assertEquals(env.variables['lives'], { TAG: 1, _0: 2 }); // Number(2)
});

Deno.test('execute repeat - runs multiple times', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      {
        nodeType: 'Repeat',
        attributes: { times: '3' },
        children: [{ nodeType: 'Say', content: 'Loop!' }],
      },
    ],
  };

  execute(program, env);
  assertEquals(env.output.length, 3);
  assertEquals(env.output, ['Loop!', 'Loop!', 'Loop!']);
});

Deno.test('execute choose - selects matching when', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'animal' }, content: 'cat' },
      {
        nodeType: 'Choose',
        children: [
          {
            nodeType: 'When',
            attributes: { 'animal-is': 'dog' },
            children: [{ nodeType: 'Say', content: 'Woof!' }],
          },
          {
            nodeType: 'When',
            attributes: { 'animal-is': 'cat' },
            children: [{ nodeType: 'Say', content: 'Meow!' }],
          },
        ],
      },
    ],
  };

  execute(program, env);
  assertEquals(env.output, ['Meow!']);
});

Deno.test('execute choose - uses otherwise when no match', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'animal' }, content: 'fish' },
      {
        nodeType: 'Choose',
        children: [
          {
            nodeType: 'When',
            attributes: { 'animal-is': 'dog' },
            children: [{ nodeType: 'Say', content: 'Woof!' }],
          },
          {
            nodeType: 'When',
            attributes: { 'animal-is': 'cat' },
            children: [{ nodeType: 'Say', content: 'Meow!' }],
          },
          {
            nodeType: 'Otherwise',
            children: [{ nodeType: 'Say', content: 'Blub!' }],
          },
        ],
      },
    ],
  };

  execute(program, env);
  assertEquals(env.output, ['Blub!']);
});

Deno.test('execute stop - halts execution', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Say', content: 'Before stop' },
      { nodeType: 'Stop' },
      { nodeType: 'Say', content: 'After stop' },
    ],
  };

  execute(program, env);
  assertEquals(env.output, ['Before stop']);
  assertEquals(env.stopped, true);
});

Deno.test('combined program - counting game', () => {
  const env = createMeEnvironment();
  const program = {
    nodeType: 'Program',
    children: [
      { nodeType: 'Remember', attributes: { name: 'score' }, content: '0' },
      {
        nodeType: 'Repeat',
        attributes: { times: '3' },
        children: [{ nodeType: 'Add', attributes: { to: 'score' }, content: '10' }],
      },
      { nodeType: 'Say', content: 'Final score: {score}' },
    ],
  };

  execute(program, env);
  assertEquals(env.variables['score'], { TAG: 1, _0: 30 }); // Number(30)
  assertEquals(env.output, ['Final score: 30']);
});
