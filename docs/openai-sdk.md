Directory Structure:

└── ./
    ├── examples
    │   └── docs
    │       ├── agents
    │       │   ├── agentCloning.ts
    │       │   ├── agentForcingToolUse.ts
    │       │   ├── agentWithAodOutputType.ts
    │       │   ├── agentWithContext.ts
    │       │   ├── agentWithDynamicInstructions.ts
    │       │   ├── agentWithHandoffs.ts
    │       │   ├── agentWithLifecycleHooks.ts
    │       │   ├── agentWithTools.ts
    │       │   └── simpleAgent.ts
    │       ├── running-agents
    │       │   ├── chatLoop.ts
    │       │   ├── exceptions1.ts
    │       │   └── exceptions2.ts
    │       ├── streaming
    │       │   ├── basicStreaming.ts
    │       │   ├── handleAllEvents.ts
    │       │   ├── nodeTextStream.ts
    │       │   └── streamedHITL.ts
    │       ├── tools
    │       │   ├── agentsAsTools.ts
    │       │   ├── functionTools.ts
    │       │   ├── hostedTools.ts
    │       │   ├── mcpLocalServer.ts
    │       │   └── nonStrictSchemaTools.ts
    │       ├── toppage
    │       │   ├── textAgent.ts
    │       │   └── voiceAgent.ts
    │       ├── tracing
    │       │   └── cloudflareWorkers.ts
    │       ├── voice-agents
    │       │   ├── agent.ts
    │       │   ├── audioInterrupted.ts
    │       │   ├── configureSession.ts
    │       │   ├── createAgent.ts
    │       │   ├── createSession.ts
    │       │   ├── customWebRTCTransport.ts
    │       │   ├── defineTool.ts
    │       │   ├── delegationAgent.ts
    │       │   ├── guardrails.ts
    │       │   ├── guardrailSettings.ts
    │       │   ├── handleAudio.ts
    │       │   ├── helloWorld.ts
    │       │   ├── historyUpdated.ts
    │       │   ├── multiAgents.ts
    │       │   ├── sendMessage.ts
    │       │   ├── serverAgent.ts
    │       │   ├── sessionHistory.ts
    │       │   ├── sessionInterrupt.ts
    │       │   ├── thinClient.ts
    │       │   ├── toolApprovalEvent.ts
    │       │   ├── toolHistory.ts
    │       │   ├── transportEvents.ts
    │       │   ├── turnDetection.ts
    │       │   ├── updateHistory.ts
    │       │   └── websocketSession.ts
    │       ├── custom-trace.ts
    │       ├── hello-world-with-runner.ts
    │       ├── hello-world.ts
    │       ├── package.json
    │       ├── README.md
    │       └── tsconfig.json
    └── packages
        └── agents-core
            ├── src
            │   ├── extensions
            │   │   ├── handoffFilters.ts
            │   │   ├── handoffPrompt.ts
            │   │   └── index.ts
            │   ├── helpers
            │   │   └── message.ts
            │   ├── types
            │   │   ├── aliases.ts
            │   │   ├── helpers.ts
            │   │   ├── index.ts
            │   │   ├── protocol.ts
            │   │   └── providerData.ts
            │   ├── utils
            │   │   ├── index.ts
            │   │   ├── messages.ts
            │   │   ├── safeExecute.ts
            │   │   ├── serialize.ts
            │   │   ├── smartString.ts
            │   │   ├── tools.ts
            │   │   └── typeGuards.ts
            │   ├── agent.ts
            │   ├── computer.ts
            │   ├── config.ts
            │   ├── errors.ts
            │   ├── events.ts
            │   ├── guardrail.ts
            │   ├── handoff.ts
            │   ├── index.ts
            │   ├── items.ts
            │   ├── lifecycle.ts
            │   ├── logger.ts
            │   ├── mcp.ts
            │   ├── metadata.ts
            │   ├── model.ts
            │   ├── providers.ts
            │   ├── result.ts
            │   ├── run.ts
            │   ├── runContext.ts
            │   ├── runImplementation.ts
            │   ├── runState.ts
            │   ├── tool.ts
            │   └── usage.ts
            ├── CHANGELOG.md
            ├── package.json
            ├── README.md
            ├── tsconfig.json
            └── tsconfig.test.json



---
File: /examples/docs/agents/agentCloning.ts
---

import { Agent } from '@openai/agents';

const pirateAgent = new Agent({
  name: 'Pirate',
  instructions: 'Respond like a pirate – lots of “Arrr!”',
  model: 'o4-mini',
});

const robotAgent = pirateAgent.clone({
  name: 'Robot',
  instructions: 'Respond like a robot – be precise and factual.',
});



---
File: /examples/docs/agents/agentForcingToolUse.ts
---

import { Agent, tool } from '@openai/agents';
import { z } from 'zod';

const calculatorTool = tool({
  name: 'Calculator',
  description: 'Use this tool to answer questions about math problems.',
  parameters: z.object({ question: z.string() }),
  execute: async (input) => {
    throw new Error('TODO: implement this');
  },
});

const agent = new Agent({
  name: 'Strict tool user',
  instructions: 'Always answer using the calculator tool.',
  tools: [calculatorTool],
  modelSettings: { toolChoice: 'auto' },
});



---
File: /examples/docs/agents/agentWithAodOutputType.ts
---

import { Agent } from '@openai/agents';
import { z } from 'zod';

const CalendarEvent = z.object({
  name: z.string(),
  date: z.string(),
  participants: z.array(z.string()),
});

const extractor = new Agent({
  name: 'Calendar extractor',
  instructions: 'Extract calendar events from the supplied text.',
  outputType: CalendarEvent,
});



---
File: /examples/docs/agents/agentWithContext.ts
---

import { Agent } from '@openai/agents';

interface Purchase {
  id: string;
  uid: string;
  deliveryStatus: string;
}
interface UserContext {
  uid: string;
  isProUser: boolean;

  // this function can be used within tools
  fetchPurchases(): Promise<Purchase[]>;
}

const agent = new Agent<UserContext>({
  name: 'Personal shopper',
  instructions: 'Recommend products the user will love.',
});

// Later
import { run } from '@openai/agents';

const result = await run(agent, 'Find me a new pair of running shoes', {
  context: { uid: 'abc', isProUser: true, fetchPurchases: async () => [] },
});



---
File: /examples/docs/agents/agentWithDynamicInstructions.ts
---

import { Agent, RunContext } from '@openai/agents';

interface UserContext {
  name: string;
}

function buildInstructions(runContext: RunContext<UserContext>) {
  return `The user's name is ${runContext.context.name}.  Be extra friendly!`;
}

const agent = new Agent<UserContext>({
  name: 'Personalized helper',
  instructions: buildInstructions,
});



---
File: /examples/docs/agents/agentWithHandoffs.ts
---

import { Agent } from '@openai/agents';

const bookingAgent = new Agent({
  name: 'Booking Agent',
  instructions: 'Help users with booking requests.',
});

const refundAgent = new Agent({
  name: 'Refund Agent',
  instructions: 'Process refund requests politely and efficiently.',
});

// Use Agent.create method to ensure the finalOutput type considers handoffs
const triageAgent = Agent.create({
  name: 'Triage Agent',
  instructions: [
    'Help the user with their questions.',
    'If the user asks about booking, hand off to the booking agent.',
    'If the user asks about refunds, hand off to the refund agent.',
  ].join('\n'),
  handoffs: [bookingAgent, refundAgent],
});



---
File: /examples/docs/agents/agentWithLifecycleHooks.ts
---

import { Agent } from '@openai/agents';

const agent = new Agent({
  name: 'Verbose agent',
  instructions: 'Explain things thoroughly.',
});

agent.on('agent_start', (ctx, agent) => {
  console.log(`[${agent.name}] started`);
});
agent.on('agent_end', (ctx, output) => {
  console.log(`[agent] produced:`, output);
});



---
File: /examples/docs/agents/agentWithTools.ts
---

import { Agent, tool } from '@openai/agents';
import { z } from 'zod';

const getWeather = tool({
  name: 'get_weather',
  description: 'Return the weather for a given city.',
  parameters: z.object({ city: z.string() }),
  async execute({ city }) {
    return `The weather in ${city} is sunny.`;
  },
});

const agent = new Agent({
  name: 'Weather bot',
  instructions: 'You are a helpful weather bot.',
  model: 'o4-mini',
  tools: [getWeather],
});



---
File: /examples/docs/agents/simpleAgent.ts
---

import { Agent } from '@openai/agents';

const agent = new Agent({
  name: 'Haiku Agent',
  instructions: 'Always respond in haiku form.',
  model: 'o4-mini', // optional – falls back to the default model
});



---
File: /examples/docs/running-agents/chatLoop.ts
---

import { Agent, AgentInputItem, run } from '@openai/agents';

let thread: AgentInputItem[] = [];

const agent = new Agent({
  name: 'Assistant',
});

async function userSays(text: string) {
  const result = await run(
    agent,
    thread.concat({ role: 'user', content: text }),
  );

  thread = result.history; // Carry over history + newly generated items
  return result.finalOutput;
}

await userSays('What city is the Golden Gate Bridge in?');
// -> "San Francisco"

await userSays('What state is it in?');
// -> "California"



---
File: /examples/docs/running-agents/exceptions1.ts
---

import {
  Agent,
  run,
  GuardrailExecutionError,
  InputGuardrail,
  InputGuardrailTripwireTriggered,
} from '@openai/agents';
import { z } from 'zod';

const guardrailAgent = new Agent({
  name: 'Guardrail check',
  instructions: 'Check if the user is asking you to do their math homework.',
  outputType: z.object({
    isMathHomework: z.boolean(),
    reasoning: z.string(),
  }),
});

const unstableGuardrail: InputGuardrail = {
  name: 'Math Homework Guardrail (unstable)',
  execute: async () => {
    throw new Error('Something is wrong!');
  },
};

const fallbackGuardrail: InputGuardrail = {
  name: 'Math Homework Guardrail (fallback)',
  execute: async ({ input, context }) => {
    const result = await run(guardrailAgent, input, { context });
    return {
      outputInfo: result.finalOutput,
      tripwireTriggered: result.finalOutput?.isMathHomework ?? false,
    };
  },
};

const agent = new Agent({
  name: 'Customer support agent',
  instructions:
    'You are a customer support agent. You help customers with their questions.',
  inputGuardrails: [unstableGuardrail],
});

async function main() {
  try {
    const input = 'Hello, can you help me solve for x: 2x + 3 = 11?';
    const result = await run(agent, input);
    console.log(result.finalOutput);
  } catch (e) {
    if (e instanceof GuardrailExecutionError) {
      console.error(`Guardrail execution failed: ${e}`);
      // If you want to retry the execution with different settings,
      // you can reuse the runner's latest state this way:
      if (e.state) {
        try {
          agent.inputGuardrails = [fallbackGuardrail]; // fallback
          const result = await run(agent, e.state);
          console.log(result.finalOutput);
        } catch (ee) {
          if (ee instanceof InputGuardrailTripwireTriggered) {
            console.log('Math homework guardrail tripped');
          }
        }
      }
    } else {
      throw e;
    }
  }
}

main().catch(console.error);



---
File: /examples/docs/running-agents/exceptions2.ts
---

import { z } from 'zod';
import { Agent, run, tool, ToolCallError } from '@openai/agents';

const unstableTool = tool({
  name: 'get_weather (unstable)',
  description: 'Get the weather for a given city',
  parameters: z.object({ city: z.string() }),
  errorFunction: (_, error) => {
    throw error; // the built-in error handler returns string instead
  },
  execute: async () => {
    throw new Error('Failed to get weather');
  },
});

const stableTool = tool({
  name: 'get_weather (stable)',
  description: 'Get the weather for a given city',
  parameters: z.object({ city: z.string() }),
  execute: async (input) => {
    return `The weather in ${input.city} is sunny`;
  },
});

const agent = new Agent({
  name: 'Data agent',
  instructions: 'You are a data agent',
  tools: [unstableTool],
});

async function main() {
  try {
    const result = await run(agent, 'What is the weather in Tokyo?');
    console.log(result.finalOutput);
  } catch (e) {
    if (e instanceof ToolCallError) {
      console.error(`Tool call failed: ${e}`);
      // If you want to retry the execution with different settings,
      // you can reuse the runner's latest state this way:
      if (e.state) {
        agent.tools = [stableTool]; // fallback
        const result = await run(agent, e.state);
        console.log(result.finalOutput);
      }
    } else {
      throw e;
    }
  }
}

main().catch(console.error);



---
File: /examples/docs/streaming/basicStreaming.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Storyteller',
  instructions:
    'You are a storyteller. You will be given a topic and you will tell a story about it.',
});

const result = await run(agent, 'Tell me a story about a cat.', {
  stream: true,
});



---
File: /examples/docs/streaming/handleAllEvents.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Storyteller',
  instructions:
    'You are a storyteller. You will be given a topic and you will tell a story about it.',
});

const result = await run(agent, 'Tell me a story about a cat.', {
  stream: true,
});

for await (const event of result) {
  // these are the raw events from the model
  if (event.type === 'raw_model_stream_event') {
    console.log(`${event.type} %o`, event.data);
  }
  // agent updated events
  if (event.type === 'agent_updated_stream_event') {
    console.log(`${event.type} %s`, event.agent.name);
  }
  // Agent SDK specific events
  if (event.type === 'run_item_stream_event') {
    console.log(`${event.type} %o`, event.item);
  }
}



---
File: /examples/docs/streaming/nodeTextStream.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Storyteller',
  instructions:
    'You are a storyteller. You will be given a topic and you will tell a story about it.',
});

const result = await run(agent, 'Tell me a story about a cat.', {
  stream: true,
});

result
  .toTextStream({
    compatibleWithNodeStreams: true,
  })
  .pipe(process.stdout);



---
File: /examples/docs/streaming/streamedHITL.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Storyteller',
  instructions:
    'You are a storyteller. You will be given a topic and you will tell a story about it.',
});

let stream = await run(
  agent,
  'What is the weather in San Francisco and Oakland?',
  { stream: true },
);
stream.toTextStream({ compatibleWithNodeStreams: true }).pipe(process.stdout);
await stream.completed;

while (stream.interruptions?.length) {
  console.log(
    'Human-in-the-loop: approval required for the following tool calls:',
  );
  const state = stream.state;
  for (const interruption of stream.interruptions) {
    const approved = confirm(
      `Agent ${interruption.agent.name} would like to use the tool ${interruption.rawItem.name} with "${interruption.rawItem.arguments}". Do you approve?`,
    );
    if (approved) {
      state.approve(interruption);
    } else {
      state.reject(interruption);
    }
  }

  // Resume execution with streaming output
  stream = await run(agent, state, { stream: true });
  const textStream = stream.toTextStream({ compatibleWithNodeStreams: true });
  textStream.pipe(process.stdout);
  await stream.completed;
}



---
File: /examples/docs/tools/agentsAsTools.ts
---

import { Agent } from '@openai/agents';

const summarizer = new Agent({
  name: 'Summarizer',
  instructions: 'Generate a concise summary of the supplied text.',
});

const summarizerTool = summarizer.asTool({
  toolName: 'summarize_text',
  toolDescription: 'Generate a concise summary of the supplied text.',
});

const mainAgent = new Agent({
  name: 'Research assistant',
  tools: [summarizerTool],
});



---
File: /examples/docs/tools/functionTools.ts
---

import { tool } from '@openai/agents';
import { z } from 'zod';

const getWeatherTool = tool({
  name: 'get_weather',
  description: 'Get the weather for a given city',
  parameters: z.object({ city: z.string() }),
  async execute({ city }) {
    return `The weather in ${city} is sunny.`;
  },
});



---
File: /examples/docs/tools/hostedTools.ts
---

import { Agent, webSearchTool, fileSearchTool } from '@openai/agents';

const agent = new Agent({
  name: 'Travel assistant',
  tools: [webSearchTool(), fileSearchTool('VS_ID')],
});



---
File: /examples/docs/tools/mcpLocalServer.ts
---

import { Agent, MCPServerStdio } from '@openai/agents';

const server = new MCPServerStdio({
  fullCommand: 'npx -y @modelcontextprotocol/server-filesystem ./sample_files',
});

await server.connect();

const agent = new Agent({
  name: 'Assistant',
  mcpServers: [server],
});



---
File: /examples/docs/tools/nonStrictSchemaTools.ts
---

import { tool } from '@openai/agents';

interface LooseToolInput {
  text: string;
}

const looseTool = tool({
  description: 'Echo input; be forgiving about typos',
  strict: false,
  parameters: {
    type: 'object',
    properties: { text: { type: 'string' } },
    required: ['text'],
    additionalProperties: true,
  },
  execute: async (input) => {
    // because strict is false we need to do our own verification
    if (typeof input !== 'object' || input === null || !('text' in input)) {
      return 'Invalid input. Please try again';
    }
    return (input as LooseToolInput).text;
  },
});



---
File: /examples/docs/toppage/textAgent.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant.',
});

const result = await run(
  agent,
  'Write a haiku about recursion in programming.',
);

console.log(result.finalOutput);



---
File: /examples/docs/toppage/voiceAgent.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant.',
});

// Automatically connects your microphone and audio output in the browser via WebRTC.
const session = new RealtimeSession(agent);
await session.connect({
  apiKey: '<client-api-key>',
});



---
File: /examples/docs/tracing/cloudflareWorkers.ts
---

import { getGlobalTraceProvider } from '@openai/agents';

export default {
  // @ts-expect-error - Cloudflare Workers types are not typed
  async fetch(request, env, ctx): Promise<Response> {
    try {
      // your agent code here
      return new Response(`success`);
    } catch (error) {
      console.error(error);
      return new Response(String(error), { status: 500 });
    } finally {
      // make sure to flush any remaining traces before exiting
      ctx.waitUntil(getGlobalTraceProvider().forceFlush());
    }
  },
};



---
File: /examples/docs/voice-agents/agent.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

export const agent = new RealtimeAgent({
  name: 'Assistant',
});

export const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
});



---
File: /examples/docs/voice-agents/audioInterrupted.ts
---

import { session } from './agent';

session.on('audio_interrupted', () => {
  // handle local playback interruption
});



---
File: /examples/docs/voice-agents/configureSession.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
  config: {
    inputAudioFormat: 'pcm16',
    outputAudioFormat: 'pcm16',
    inputAudioTranscription: {
      model: 'gpt-4o-mini-transcribe',
    },
  },
});



---
File: /examples/docs/voice-agents/createAgent.ts
---

import { RealtimeAgent } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});



---
File: /examples/docs/voice-agents/createSession.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

async function main() {
  // define which agent you want to start your session with
  const session = new RealtimeSession(agent, {
    model: 'gpt-4o-realtime-preview-2025-06-03',
  });
  // start your session
  await session.connect({ apiKey: '<your api key>' });
}



---
File: /examples/docs/voice-agents/customWebRTCTransport.ts
---

import { RealtimeAgent, RealtimeSession, OpenAIRealtimeWebRTC } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

async function main() {
  const transport = new OpenAIRealtimeWebRTC({
    mediaStream: await navigator.mediaDevices.getUserMedia({ audio: true }),
    audioElement: document.createElement('audio'),
  });

  const customSession = new RealtimeSession(agent, { transport });
}



---
File: /examples/docs/voice-agents/defineTool.ts
---

import { tool, RealtimeAgent } from '@openai/agents/realtime';
import { z } from 'zod';

const getWeather = tool({
  name: 'get_weather',
  description: 'Return the weather for a city.',
  parameters: z.object({ city: z.string() }),
  async execute({ city }) {
    return `The weather in ${city} is sunny.`;
  },
});

const weatherAgent = new RealtimeAgent({
  name: 'Weather assistant',
  instructions: 'Answer weather questions.',
  tools: [getWeather],
});



---
File: /examples/docs/voice-agents/delegationAgent.ts
---

import {
  RealtimeAgent,
  RealtimeContextData,
  tool,
} from '@openai/agents/realtime';
import { handleRefundRequest } from './serverAgent';
import z from 'zod';

const refundSupervisorParameters = z.object({
  request: z.string(),
});

const refundSupervisor = tool<
  typeof refundSupervisorParameters,
  RealtimeContextData
>({
  name: 'escalateToRefundSupervisor',
  description: 'Escalate a refund request to the refund supervisor',
  parameters: refundSupervisorParameters,
  execute: async ({ request }, details) => {
    // This will execute on the server
    return handleRefundRequest(request, details?.context?.history ?? []);
  },
});

const agent = new RealtimeAgent({
  name: 'Customer Support',
  instructions:
    'You are a customer support agent. If you receive any requests for refunds, you need to delegate to your supervisor.',
  tools: [refundSupervisor],
});



---
File: /examples/docs/voice-agents/guardrails.ts
---

import { RealtimeOutputGuardrail, RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

const guardrails: RealtimeOutputGuardrail[] = [
  {
    name: 'No mention of Dom',
    async execute({ agentOutput }) {
      const domInOutput = agentOutput.includes('Dom');
      return {
        tripwireTriggered: domInOutput,
        outputInfo: { domInOutput },
      };
    },
  },
];

const guardedSession = new RealtimeSession(agent, {
  outputGuardrails: guardrails,
});



---
File: /examples/docs/voice-agents/guardrailSettings.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

const guardedSession = new RealtimeSession(agent, {
  outputGuardrails: [
    /*...*/
  ],
  outputGuardrailSettings: {
    debounceTextLength: 500, // run guardrail every 500 characters or set it to -1 to run it only at the end
  },
});



---
File: /examples/docs/voice-agents/handleAudio.ts
---

import {
  RealtimeAgent,
  RealtimeSession,
  TransportLayerAudio,
} from '@openai/agents/realtime';

const agent = new RealtimeAgent({ name: 'My agent' });
const session = new RealtimeSession(agent);
const newlyRecordedAudio = new ArrayBuffer(0);

session.on('audio', (event: TransportLayerAudio) => {
  // play your audio
});

// send new audio to the agent
session.sendAudio(newlyRecordedAudio);



---
File: /examples/docs/voice-agents/helloWorld.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant.',
});

const session = new RealtimeSession(agent);

// Automatically connects your microphone and audio output
// in the browser via WebRTC.
await session.connect({
  apiKey: '<client-api-key>',
});



---
File: /examples/docs/voice-agents/historyUpdated.ts
---

import { session } from './agent';

session.on('history_updated', (newHistory) => {
  // save the new history
});



---
File: /examples/docs/voice-agents/multiAgents.ts
---

import { RealtimeAgent } from '@openai/agents/realtime';

const mathTutorAgent = new RealtimeAgent({
  name: 'Math Tutor',
  handoffDescription: 'Specialist agent for math questions',
  instructions:
    'You provide help with math problems. Explain your reasoning at each step and include examples',
});

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
  handoffs: [mathTutorAgent],
});



---
File: /examples/docs/voice-agents/sendMessage.ts
---

import { RealtimeSession, RealtimeAgent } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Assistant',
});

const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
});

session.sendMessage('Hello, how are you?');



---
File: /examples/docs/voice-agents/serverAgent.ts
---

// This runs on the server
import 'server-only';

import { Agent, run } from '@openai/agents';
import type { RealtimeItem } from '@openai/agents/realtime';
import z from 'zod';

const agent = new Agent({
  name: 'Refund Expert',
  instructions:
    'You are a refund expert. You are given a request to process a refund and you need to determine if the request is valid.',
  model: 'o4-mini',
  outputType: z.object({
    reasong: z.string(),
    refundApproved: z.boolean(),
  }),
});

export async function handleRefundRequest(
  request: string,
  history: RealtimeItem[],
) {
  const input = `
The user has requested a refund.

The request is: ${request}

Current conversation history: 
${JSON.stringify(history, null, 2)}
`.trim();

  const result = await run(agent, input);

  return JSON.stringify(result.finalOutput, null, 2);
}



---
File: /examples/docs/voice-agents/sessionHistory.ts
---

import { session } from './agent';

console.log(session.history);



---
File: /examples/docs/voice-agents/sessionInterrupt.ts
---

import { session } from './agent';

session.interrupt();
// this will still trigger the `audio_interrupted` event for you
// to cut off the audio playback when using WebSockets



---
File: /examples/docs/voice-agents/thinClient.ts
---

import { OpenAIRealtimeWebRTC } from '@openai/agents/realtime';

const client = new OpenAIRealtimeWebRTC();
const audioBuffer = new ArrayBuffer(0);

await client.connect({
  apiKey: '<api key>',
  model: 'gpt-4o-mini-realtime-preview',
  initialSessionConfig: {
    instructions: 'Speak like a pirate',
    voice: 'ash',
    modalities: ['text', 'audio'],
    inputAudioFormat: 'pcm16',
    outputAudioFormat: 'pcm16',
  },
});

// optionally for WebSockets
client.on('audio', (newAudio) => {});

client.sendAudio(audioBuffer);



---
File: /examples/docs/voice-agents/toolApprovalEvent.ts
---

import { session } from './agent';

session.on('tool_approval_requested', (_context, _agent, request) => {
  // show a UI to the user to approve or reject the tool call
  // you can use the `session.approve(...)` or `session.reject(...)` methods to approve or reject the tool call

  session.approve(request.approvalItem); // or session.reject(request.rawItem);
});



---
File: /examples/docs/voice-agents/toolHistory.ts
---

import {
  tool,
  RealtimeContextData,
  RealtimeItem,
} from '@openai/agents/realtime';
import { z } from 'zod';

const parameters = z.object({
  request: z.string(),
});

const refundTool = tool<typeof parameters, RealtimeContextData>({
  name: 'Refund Expert',
  description: 'Evaluate a refund',
  parameters,
  execute: async ({ request }, details) => {
    // The history might not be available
    const history: RealtimeItem[] = details?.context?.history ?? [];
    // making your call to process the refund request
  },
});



---
File: /examples/docs/voice-agents/transportEvents.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
});

session.transport.on('*', (event) => {
  // JSON parsed version of the event received on the connection
});

// Send any valid event as JSON. For example triggering a new response
session.transport.sendEvent({
  type: 'response.create',
  // ...
});



---
File: /examples/docs/voice-agents/turnDetection.ts
---

import { RealtimeSession } from '@openai/agents/realtime';
import { agent } from './agent';

const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
  config: {
    turnDetection: {
      type: 'semantic_vad',
      eagerness: 'medium',
      createResponse: true,
      interruptResponse: true,
    },
  },
});



---
File: /examples/docs/voice-agents/updateHistory.ts
---

import { RealtimeSession, RealtimeAgent } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Assistant',
});

const session = new RealtimeSession(agent, {
  model: 'gpt-4o-realtime-preview-2025-06-03',
});

await session.connect({ apiKey: '<client-api-key>' });

// listening to the history_updated event
session.on('history_updated', (history) => {
  // returns the full history of the session
  console.log(history);
});

// Option 1: explicit setting
session.updateHistory([
  /* specific history */
]);

// Option 2: override based on current state like removing all agent messages
session.updateHistory((currentHistory) => {
  return currentHistory.filter(
    (item) => !(item.type === 'message' && item.role === 'assistant'),
  );
});



---
File: /examples/docs/voice-agents/websocketSession.ts
---

import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Greeter',
  instructions: 'Greet the user with cheer and answer questions.',
});

const myRecordedArrayBuffer = new ArrayBuffer(0);

const wsSession = new RealtimeSession(agent, {
  transport: 'websocket',
  model: 'gpt-4o-realtime-preview-2025-06-03',
});
await wsSession.connect({ apiKey: process.env.OPENAI_API_KEY! });

wsSession.on('audio', (event) => {
  // event.data is a chunk of PCM16 audio
});

wsSession.sendAudio(myRecordedArrayBuffer);



---
File: /examples/docs/custom-trace.ts
---

import { Agent, run, withTrace } from '@openai/agents';

const agent = new Agent({
  name: 'Joke generator',
  instructions: 'Tell funny jokes.',
});

await withTrace('Joke workflow', async () => {
  const result = await run(agent, 'Tell me a joke');
  const secondResult = await run(
    agent,
    `Rate this joke: ${result.finalOutput}`,
  );
  console.log(`Joke: ${result.finalOutput}`);
  console.log(`Rating: ${secondResult.finalOutput}`);
});



---
File: /examples/docs/hello-world-with-runner.ts
---

import { Agent, Runner } from '@openai/agents';

const agent = new Agent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant',
});

// You can pass custom configuration to the runner
const runner = new Runner();

const result = await runner.run(
  agent,
  'Write a haiku about recursion in programming.',
);
console.log(result.finalOutput);

// Code within the code,
// Functions calling themselves,
// Infinite loop's dance.



---
File: /examples/docs/hello-world.ts
---

import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant',
});

const result = await run(
  agent,
  'Write a haiku about recursion in programming.',
);
console.log(result.finalOutput);

// Code within the code,
// Functions calling themselves,
// Infinite loop's dance.



---
File: /examples/docs/package.json
---

{
  "private": true,
  "name": "docs",
  "dependencies": {
    "@openai/agents": "workspace:*",
    "@openai/agents-core": "workspace:*",
    "@openai/agents-realtime": "workspace:*",
    "@openai/agents-extensions": "workspace:*",
    "@ai-sdk/openai": "^1.0.0",
    "server-only": "^0.0.1",
    "openai": "^5.10.1",
    "zod": "3.25.40 - 3.25.67"
  },
  "scripts": {
    "build-check": "tsc --noEmit"
  },
  "devDependencies": {
    "typedoc-plugin-zod": "^1.4.1"
  }
}



---
File: /examples/docs/README.md
---

# Documentation Snippets

This directory contains small scripts used throughout the documentation. Run them with `pnpm` using the commands shown below.

- `agents-basic-configuration.ts` – Configure a weather agent with a tool and model.
  ```bash
  pnpm -F docs start:agents-basic-configuration
  ```
- `agents-cloning.ts` – Clone an agent and reuse its configuration.
  ```bash
  pnpm -F docs start:agents-cloning
  ```
- `agents-context.ts` – Access user context from tools during execution.
  ```bash
  pnpm -F docs start:agents-context
  ```
- `agents-dynamic-instructions.ts` – Build instructions dynamically from context.
  ```bash
  pnpm -F docs start:agents-dynamic-instructions
  ```
- `agents-forcing-tool-use.ts` – Require specific tools before producing output.
  ```bash
  pnpm -F docs start:agents-forcing-tool-use
  ```
- `agents-handoffs.ts` – Route requests to specialized agents using handoffs.
  ```bash
  pnpm -F docs start:agents-handoffs
  ```
- `agents-lifecycle-hooks.ts` – Log agent lifecycle events as they run.
  ```bash
  pnpm -F docs start:agents-lifecycle-hooks
  ```
- `agents-output-types.ts` – Return structured data using a Zod schema.
  ```bash
  pnpm -F docs start:agents-output-types
  ```
- `guardrails-input.ts` – Block unwanted requests using input guardrails.
  ```bash
  pnpm -F docs start:guardrails-input
  ```
- `guardrails-output.ts` – Check responses with output guardrails.
  ```bash
  pnpm -F docs start:guardrails-output
  ```
- `models-custom-providers.ts` – Create and use a custom model provider.
  ```bash
  pnpm -F docs start:models-custom-providers
  ```
- `models-openai-provider.ts` – Run agents with the OpenAI provider.
  ```bash
  pnpm -F docs start:models-openai-provider
  ```
- `quickstart.ts` – Simple triage agent that hands off questions to tutors.
  ```bash
  pnpm -F docs start:quickstart
  ```
- `readme-functions.ts` – README example showing how to call functions as tools.
  ```bash
  pnpm -F docs start:readme-functions
  ```
- `readme-handoffs.ts` – README example that demonstrates handoffs.
  ```bash
  pnpm -F docs start:readme-handoffs
  ```
- `readme-hello-world.ts` – The hello world snippet from the README.
  ```bash
  pnpm -F docs start:readme-hello-world
  ```
- `readme-voice-agent.ts` – Browser-based realtime voice agent example.
  ```bash
  pnpm -F docs start:readme-voice-agent
  ```
- `running-agents-exceptions1.ts` – Retry after a guardrail execution error.
  ```bash
  pnpm -F docs start:running-agents-exceptions1
  ```
- `running-agents-exceptions2.ts` – Retry after a failed tool call.
  ```bash
  pnpm -F docs start:running-agents-exceptions2
  ```



---
File: /examples/docs/tsconfig.json
---

{
  "extends": "../../tsconfig.examples.json",
  "compilerOptions": {
    "noUnusedLocals": false
  }
}



---
File: /packages/agents-core/src/extensions/handoffFilters.ts
---

import { HandoffInputData } from '../handoff';
import {
  RunHandoffCallItem,
  RunHandoffOutputItem,
  RunItem,
  RunToolCallItem,
  RunToolCallOutputItem,
} from '../items';
import { AgentInputItem } from '../types';

const TOOL_TYPES = new Set([
  'function_call',
  'function_call_result',
  'computer_call',
  'computer_call_result',
  'hosted_tool_call',
]);

/**
 * Filters out all tool items: file search, web search and function calls+output
 * @param handoffInputData
 * @returns
 */
export function removeAllTools(
  handoffInputData: HandoffInputData,
): HandoffInputData {
  const { inputHistory, preHandoffItems, newItems } = handoffInputData;

  const filteredHistory = Array.isArray(inputHistory)
    ? removeToolTypesFromInput(inputHistory)
    : inputHistory;

  const filteredPreHandoffItems = removeToolsFromItems(preHandoffItems);
  const filteredNewItems = removeToolsFromItems(newItems);

  return {
    inputHistory: filteredHistory,
    preHandoffItems: filteredPreHandoffItems,
    newItems: filteredNewItems,
  };
}

function removeToolsFromItems(items: RunItem[]): RunItem[] {
  return items.filter(
    (item) =>
      !(item instanceof RunHandoffCallItem) &&
      !(item instanceof RunHandoffOutputItem) &&
      !(item instanceof RunToolCallItem) &&
      !(item instanceof RunToolCallOutputItem),
  );
}

function removeToolTypesFromInput(items: AgentInputItem[]): AgentInputItem[] {
  return items.filter((item) => !TOOL_TYPES.has(item.type ?? ''));
}



---
File: /packages/agents-core/src/extensions/handoffPrompt.ts
---

/**
 * A recommended prompt prefix for agents that use handoffs. We recommend including this or
 * similar instructions in any agents that use handoffs.
 */
export const RECOMMENDED_PROMPT_PREFIX = `# System context
You are part of a multi-agent system called the Agents SDK, designed to make agent coordination and execution easy. Agents uses two primary abstractions: **Agents** and **Handoffs**. An agent encompasses instructions and tools and can hand off a conversation to another agent when appropriate. Handoffs are achieved by calling a handoff function, generally named \`transfer_to_<agent_name>\`. Transfers between agents are handled seamlessly in the background; do not mention or draw attention to these transfers in your conversation with the user.`;

/**
 * Add recommended instructions to the prompt for agents that use handoffs.
 *
 * @param prompt - The original prompt string.
 * @returns The prompt prefixed with recommended handoff instructions.
 */
export function promptWithHandoffInstructions(prompt: string): string {
  return `${RECOMMENDED_PROMPT_PREFIX}\n\n${prompt}`;
}



---
File: /packages/agents-core/src/extensions/index.ts
---

export { RECOMMENDED_PROMPT_PREFIX, promptWithHandoffInstructions } from './handoffPrompt';
export { removeAllTools } from './handoffFilters';


---
File: /packages/agents-core/src/helpers/message.ts
---

import {
  AssistantContent,
  AssistantMessageItem,
  SystemMessageItem,
  UserContent,
  UserMessageItem,
} from '../types/protocol';

/**
 * Creates a user message entry
 *
 * @param input The input message from the user
 * @param options Any additional options that will be directly passed to the model
 * @returns a message entry
 */
export function user(
  input: string | UserContent[],
  options?: Record<string, any>,
): UserMessageItem {
  return {
    type: 'message',
    role: 'user',
    content:
      typeof input === 'string'
        ? [
            {
              type: 'input_text',
              text: input,
            },
          ]
        : input,
    providerData: options,
  };
}

/**
 * Creates a system message entry
 *
 * @param input The system prompt
 * @param options Any additional options that will be directly passed to the model
 * @returns a message entry
 */
export function system(
  input: string,
  options?: Record<string, any>,
): SystemMessageItem {
  return {
    type: 'message',
    role: 'system',
    content: input,
    providerData: options,
  };
}

/**
 * Creates an assistant message entry for example for multi-shot prompting
 *
 * @param input The assistant response
 * @param options Any additional options that will be directly passed to the model
 * @returns a message entry
 */
export function assistant(
  content: string | AssistantContent[],
  options?: Record<string, any>,
): AssistantMessageItem {
  return {
    type: 'message',
    role: 'assistant',
    content:
      typeof content === 'string'
        ? [
            {
              type: 'output_text',
              text: content,
            },
          ]
        : content,
    status: 'completed',
    providerData: options,
  };
}



---
File: /packages/agents-core/src/types/aliases.ts
---

import {
  UserMessageItem,
  AssistantMessageItem,
  SystemMessageItem,
  HostedToolCallItem,
  FunctionCallItem,
  ComputerUseCallItem,
  FunctionCallResultItem,
  ComputerCallResultItem,
  ReasoningItem,
  UnknownItem,
} from './protocol';

/**
 * Context that is being passed around as part of the session is unknown
 */
export type UnknownContext = unknown;

/**
 * Agent is expected to output text
 */
export type TextOutput = 'text';

/**
 * Agent output items
 */
export type AgentOutputItem =
  | UserMessageItem
  | AssistantMessageItem
  | SystemMessageItem
  | HostedToolCallItem
  | FunctionCallItem
  | ComputerUseCallItem
  | FunctionCallResultItem
  | ComputerCallResultItem
  | ReasoningItem
  | UnknownItem;

/**
 * Agent input
 */
export type AgentInputItem =
  | UserMessageItem
  | AssistantMessageItem
  | SystemMessageItem
  | HostedToolCallItem
  | FunctionCallItem
  | ComputerUseCallItem
  | FunctionCallResultItem
  | ComputerCallResultItem
  | ReasoningItem
  | UnknownItem;



---
File: /packages/agents-core/src/types/helpers.ts
---

import type { ZodObject, infer as zInfer } from 'zod/v3';
import { Agent, AgentOutputType } from '../agent';
import { ToolInputParameters } from '../tool';
import { Handoff } from '../handoff';
import { ModelItem, StreamEvent } from './protocol';
import { TextOutput } from './aliases';

/**
 * Item representing an output in a model response.
 */
export type ResponseOutputItem = ModelItem;

/**
 * Event emitted when streaming model responses.
 */
export type ResponseStreamEvent = StreamEvent;

export type ResolveParsedToolParameters<
  TInputType extends ToolInputParameters,
> =
  TInputType extends ZodObject<any>
    ? zInfer<TInputType>
    : TInputType extends JsonObjectSchema<any>
      ? unknown
      : string;

export type ResolvedAgentOutput<
  TOutput extends AgentOutputType<H>,
  H = unknown,
> = TOutput extends TextOutput
  ? string
  : TOutput extends ZodObject<any>
    ? zInfer<TOutput>
    : TOutput extends HandoffsOutput<infer H>
      ? HandoffsOutput<H>
      : TOutput extends Record<string, any>
        ? unknown
        : never;

export type JsonSchemaDefinitionEntry = Record<string, any>;

export type JsonObjectSchemaStrict<
  Properties extends Record<string, JsonSchemaDefinitionEntry>,
> = {
  type: 'object';
  properties: Properties;
  required: (keyof Properties)[];
  additionalProperties: false;
};

export type JsonObjectSchemaNonStrict<
  Properties extends Record<string, JsonSchemaDefinitionEntry>,
> = {
  type: 'object';
  properties: Properties;
  required: (keyof Properties)[];
  additionalProperties: true;
};

export type JsonObjectSchema<
  Properties extends Record<string, JsonSchemaDefinitionEntry>,
> = JsonObjectSchemaStrict<Properties> | JsonObjectSchemaNonStrict<Properties>;

/**
 * Wrapper around a JSON schema used for describing tool parameters.
 */
export type JsonSchemaDefinition = {
  type: 'json_schema';
  name: string;
  strict: boolean;
  schema: JsonObjectSchema<Record<string, JsonSchemaDefinitionEntry>>;
};

// DeepPartial makes all nested properties optional recursively
export type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

// --- Utility types for handoff-aware output typing ---
// Extracts the resolved output type from an Agent
export type ExtractAgentOutput<T> =
  T extends Agent<any, any> ? ResolvedAgentOutput<T['outputType']> : never;

// Extracts the resolved output type from a Handoff
export type ExtractHandoffOutput<T> = T extends Handoff<any> ? unknown : never;

// Union of all possible outputs from handoffs array
export type HandoffsOutput<H> =
  H extends Array<infer U>
    ? ExtractAgentOutput<U> | ExtractHandoffOutput<U>
    : never;

/**
 * Converts a snake_case string to camelCase.
 */
export type SnakeToCamelCase<S extends string> =
  S extends `${infer T}_${infer U}`
    ? `${T}${Capitalize<SnakeToCamelCase<U>>}`
    : S;

/**
 * Expands a type to include all properties of the type.
 */
export type Expand<T> = T extends infer O ? { [K in keyof O]: O[K] } : never;



---
File: /packages/agents-core/src/types/index.ts
---

export * from './protocol';
export * from './helpers';
export * from '../model';
export * from './aliases';
export * as ProviderData from './providerData';



---
File: /packages/agents-core/src/types/protocol.ts
---

import { z } from '@openai/zod/v3';

// ----------------------------
// Shared base types
// ----------------------------

/**
 * Every item in the protocol provides a `providerData` field to accommodate custom functionality
 * or new fields
 */
export const SharedBase = z.object({
  /**
   * Additional optional provider specific data. Used for custom functionality or model provider
   * specific fields.
   */
  providerData: z.record(z.string(), z.any()).optional(),
});

export type SharedBase = z.infer<typeof SharedBase>;

/**
 * Every item has a shared of shared item data including an optional ID.
 */
export const ItemBase = SharedBase.extend({
  /**
   * An ID to identify the item. This is optional by default. If a model provider absolutely
   * requires this field, it will be validated on the model level.
   */
  id: z.string().optional(),
});

export type ItemBase = z.infer<typeof ItemBase>;

// ----------------------------
// Content types
// ----------------------------

export const Refusal = SharedBase.extend({
  type: z.literal('refusal'),
  /**
   * The refusal explanation from the model.
   */
  refusal: z.string(),
});

export type Refusal = z.infer<typeof Refusal>;

export const OutputText = SharedBase.extend({
  type: z.literal('output_text'),
  /**
   * The text output from the model.
   */
  text: z.string(),
});

export type OutputText = z.infer<typeof OutputText>;

export const InputText = SharedBase.extend({
  type: z.literal('input_text'),
  /**
   * A text input for example a message from a user
   */
  text: z.string(),
});

export type InputText = z.infer<typeof InputText>;

export const InputImage = SharedBase.extend({
  type: z.literal('input_image'),

  /**
   * The image input to the model. Could be a URL, base64 or an object with a file ID.
   */
  image: z
    .string()
    .or(
      z.object({
        id: z.string(),
      }),
    )
    .describe('Could be a URL, base64 or an object with a file ID.'),
});

export type InputImage = z.infer<typeof InputImage>;

export const InputFile = SharedBase.extend({
  type: z.literal('input_file'),

  /**
   * The file input to the model. Could be a URL, base64 or an object with a file ID.
   */
  file: z
    .string()
    .describe(
      'Either base64 encoded file data or a publicly accessible file URL',
    )
    .or(
      z.object({
        id: z.string().describe('OpenAI file ID'),
      }),
    )
    .or(
      z.object({
        url: z.string().describe('Publicly accessible PDF file URL'),
      }),
    )
    .describe('Contents of the file or an object with a file ID.'),
});

export type InputFile = z.infer<typeof InputFile>;

export const AudioContent = SharedBase.extend({
  type: z.literal('audio'),

  /**
   * The audio input to the model. Could be base64 encoded audio data or an object with a file ID.
   */
  audio: z
    .string()
    .or(
      z.object({
        id: z.string(),
      }),
    )
    .describe('Base64 encoded audio data or file id'),

  /**
   * The format of the audio.
   */
  format: z.string().nullable().optional(),

  /**
   * The transcript of the audio.
   */
  transcript: z.string().nullable().optional(),
});

export type AudioContent = z.infer<typeof AudioContent>;

export const ImageContent = SharedBase.extend({
  type: z.literal('image'),

  /**
   * The image input to the model. Could be base64 encoded image data or an object with a file ID.
   */
  image: z.string().describe('Base64 encoded image data'),
});

export type ImageContent = z.infer<typeof ImageContent>;

export const ToolOutputText = SharedBase.extend({
  type: z.literal('text'),

  /**
   * The text output from the model.
   */
  text: z.string(),
});

export const ToolOutputImage = SharedBase.extend({
  type: z.literal('image'),

  /**
   * The image data. Could be base64 encoded image data or an object with a file ID.
   */
  data: z.string().describe('Base64 encoded image data'),

  /**
   * The media type of the image.
   */
  mediaType: z.string().describe('IANA media type of the image'),
});

export const ComputerToolOutput = SharedBase.extend({
  type: z.literal('computer_screenshot'),

  /**
   * A base64 encoded image data or a URL representing the screenshot.
   */
  data: z.string().describe('Base64 encoded image data or URL'),
});

export type ComputerToolOutput = z.infer<typeof ComputerToolOutput>;

export const computerActions = z.discriminatedUnion('type', [
  z.object({ type: z.literal('screenshot') }),
  z.object({
    type: z.literal('click'),
    x: z.number(),
    y: z.number(),
    button: z.enum(['left', 'right', 'wheel', 'back', 'forward']),
  }),
  z.object({
    type: z.literal('double_click'),
    x: z.number(),
    y: z.number(),
  }),
  z.object({
    type: z.literal('scroll'),
    x: z.number(),
    y: z.number(),
    scroll_x: z.number(),
    scroll_y: z.number(),
  }),
  z.object({
    type: z.literal('type'),
    text: z.string(),
  }),
  z.object({ type: z.literal('wait') }),
  z.object({
    type: z.literal('move'),
    x: z.number(),
    y: z.number(),
  }),
  z.object({
    type: z.literal('keypress'),
    keys: z.array(z.string()),
  }),
  z.object({
    type: z.literal('drag'),
    path: z.array(z.object({ x: z.number(), y: z.number() })),
  }),
]);

export type ComputerAction = z.infer<typeof computerActions>;

// ----------------------------
// Message types
// ----------------------------

export const AssistantContent = z.discriminatedUnion('type', [
  OutputText,
  Refusal,
  InputText,
  AudioContent,
  ImageContent,
]);

export type AssistantContent = z.infer<typeof AssistantContent>;

const MessageBase = ItemBase.extend({
  /**
   * Any item without a type is treated as a message
   */
  type: z.literal('message').optional(),
});

export const AssistantMessageItem = MessageBase.extend({
  /**
   * Representing a message from the assistant (i.e. the model)
   */
  role: z.literal('assistant'),

  /**
   * The status of the message.
   */
  status: z.enum(['in_progress', 'completed', 'incomplete']),

  /**
   * The content of the message.
   */
  content: z.array(AssistantContent),
});

export type AssistantMessageItem = z.infer<typeof AssistantMessageItem>;

export const UserContent = z.discriminatedUnion('type', [
  InputText,
  InputImage,
  InputFile,
  AudioContent,
]);

export type UserContent = z.infer<typeof UserContent>;

export const UserMessageItem = MessageBase.extend({
  // type: z.literal('message'),

  /**
   * Representing a message from the user
   */
  role: z.literal('user'),

  /**
   * The content of the message.
   */
  content: z.array(UserContent).or(z.string()),
});

export type UserMessageItem = z.infer<typeof UserMessageItem>;

const SystemMessageItem = MessageBase.extend({
  // type: z.literal('message'),

  /**
   * Representing a system message to the user
   */
  role: z.literal('system'),

  /**
   * The content of the message.
   */
  content: z.string(),
});

export type SystemMessageItem = z.infer<typeof SystemMessageItem>;

export const MessageItem = z.discriminatedUnion('role', [
  SystemMessageItem,
  AssistantMessageItem,
  UserMessageItem,
]);

export type MessageItem = z.infer<typeof MessageItem>;

// ----------------------------
// Tool call types
// ----------------------------

export const HostedToolCallItem = ItemBase.extend({
  type: z.literal('hosted_tool_call'),
  /**
   * The name of the hosted tool. For example `web_search_call` or `file_search_call`
   */
  name: z.string().describe('The name of the hosted tool'),

  /**
   * The arguments of the hosted tool call.
   */
  arguments: z
    .string()
    .describe('The arguments of the hosted tool call')
    .optional(),

  /**
   * The status of the tool call.
   */
  status: z.string().optional(),

  /**
   * The primary output of the tool call. Additional output might be in the `providerData` field.
   */
  output: z.string().optional(),
});

export type HostedToolCallItem = z.infer<typeof HostedToolCallItem>;

export const FunctionCallItem = ItemBase.extend({
  type: z.literal('function_call'),
  /**
   * The ID of the tool call. Required to match up the respective tool call result.
   */
  callId: z.string().describe('The ID of the tool call'),

  /**
   * The name of the function.
   */
  name: z.string().describe('The name of the function'),

  /**
   * The status of the function call.
   */
  status: z.enum(['in_progress', 'completed', 'incomplete']).optional(),

  /**
   * The arguments of the function call.
   */
  arguments: z.string(),
});

export type FunctionCallItem = z.infer<typeof FunctionCallItem>;

export const FunctionCallResultItem = ItemBase.extend({
  type: z.literal('function_call_result'),
  /**
   * The name of the tool that was called
   */
  name: z.string().describe('The name of the tool'),

  /**
   * The ID of the tool call. Required to match up the respective tool call result.
   */
  callId: z.string().describe('The ID of the tool call'),

  /**
   * The status of the tool call.
   */
  status: z.enum(['in_progress', 'completed', 'incomplete']),

  /**
   * The output of the tool call.
   */
  output: z.discriminatedUnion('type', [ToolOutputText, ToolOutputImage]),
});

export type FunctionCallResultItem = z.infer<typeof FunctionCallResultItem>;

export const ComputerUseCallItem = ItemBase.extend({
  type: z.literal('computer_call'),

  /**
   * The ID of the computer call. Required to match up the respective computer call result.
   */
  callId: z.string().describe('The ID of the computer call'),

  /**
   * The status of the computer call.
   */
  status: z.enum(['in_progress', 'completed', 'incomplete']),

  /**
   * The action to be performed by the computer.
   */
  action: computerActions,
});

export type ComputerUseCallItem = z.infer<typeof ComputerUseCallItem>;

export const ComputerCallResultItem = ItemBase.extend({
  type: z.literal('computer_call_result'),

  /**
   * The ID of the computer call. Required to match up the respective computer call result.
   */
  callId: z.string().describe('The ID of the computer call'),

  /**
   * The output of the computer call.
   */
  output: ComputerToolOutput,
});

export type ComputerCallResultItem = z.infer<typeof ComputerCallResultItem>;

export const ToolCallItem = z.discriminatedUnion('type', [
  ComputerUseCallItem,
  FunctionCallItem,
  HostedToolCallItem,
]);

export type ToolCallItem = z.infer<typeof ToolCallItem>;

// ----------------------------
// Special item types
// ----------------------------

export const ReasoningItem = SharedBase.extend({
  id: z.string().optional(),
  type: z.literal('reasoning'),

  /**
   * The user facing representation of the reasoning. Additional information might be in the `providerData` field.
   */
  content: z.array(InputText),
});

export type ReasoningItem = z.infer<typeof ReasoningItem>;

/**
 * This is a catch all for items that are not part of the protocol.
 *
 * For example, a model might return an item that is not part of the protocol using this type.
 *
 * In that case everything returned from the model should be passed in the `providerData` field.
 *
 * This enables new features to be added to be added by a model provider without breaking the protocol.
 */
export const UnknownItem = ItemBase.extend({
  type: z.literal('unknown'),
});

export type UnknownItem = z.infer<typeof UnknownItem>;

// ----------------------------
// Joined item types
// ----------------------------

export const OutputModelItem = z.discriminatedUnion('type', [
  AssistantMessageItem,
  HostedToolCallItem,
  FunctionCallItem,
  ComputerUseCallItem,
  ReasoningItem,
  UnknownItem,
]);

export type OutputModelItem = z.infer<typeof OutputModelItem>;

export const ModelItem = z.union([
  UserMessageItem,
  AssistantMessageItem,
  SystemMessageItem,
  HostedToolCallItem,
  FunctionCallItem,
  ComputerUseCallItem,
  FunctionCallResultItem,
  ComputerCallResultItem,
  ReasoningItem,
  UnknownItem,
]);

export type ModelItem = z.infer<typeof ModelItem>;

// ----------------------------
// Meta data types
// ----------------------------

export const UsageData = z.object({
  requests: z.number().optional(),
  inputTokens: z.number(),
  outputTokens: z.number(),
  totalTokens: z.number(),
  inputTokensDetails: z.record(z.string(), z.number()).optional(),
  outputTokensDetails: z.record(z.string(), z.number()).optional(),
});

export type UsageData = z.infer<typeof UsageData>;

// ----------------------------
// Stream event types
// ----------------------------

/**
 * Event returned by the model when new output text is available to stream to the user.
 */
export const StreamEventTextStream = SharedBase.extend({
  type: z.literal('output_text_delta'),
  /**
   * The delta text that was streamed by the modelto the user.
   */
  delta: z.string(),
});

export type StreamEventTextStream = z.infer<typeof StreamEventTextStream>;

/**
 * Event returned by the model when a new response is started.
 */
export const StreamEventResponseStarted = SharedBase.extend({
  type: z.literal('response_started'),
});

export type StreamEventResponseStarted = z.infer<
  typeof StreamEventResponseStarted
>;

/**
 * Event returned by the model when a response is completed.
 */
export const StreamEventResponseCompleted = SharedBase.extend({
  type: z.literal('response_done'),
  /**
   * The response from the model.
   */
  response: SharedBase.extend({
    /**
     * The ID of the response.
     */
    id: z.string(),

    /**
     * The usage data for the response.
     */
    usage: UsageData,

    /**
     * The output from the model.
     */
    output: z.array(OutputModelItem),
  }),
});

export type StreamEventResponseCompleted = z.infer<
  typeof StreamEventResponseCompleted
>;

/**
 * Event returned for every item that gets streamed to the model. Used to expose the raw events
 * from the model.
 */
export const StreamEventGenericItem = SharedBase.extend({
  type: z.literal('model'),
  event: z.any().describe('The event from the model'),
});
export type StreamEventGenericItem = z.infer<typeof StreamEventGenericItem>;

export const StreamEvent = z.discriminatedUnion('type', [
  StreamEventTextStream,
  StreamEventResponseCompleted,
  StreamEventResponseStarted,
  StreamEventGenericItem,
]);

export type StreamEvent =
  | StreamEventTextStream
  | StreamEventResponseCompleted
  | StreamEventResponseStarted
  | StreamEventGenericItem;



---
File: /packages/agents-core/src/types/providerData.ts
---

import { HostedMCPApprovalFunction } from '../tool';
import { UnknownContext } from './aliases';

/**
 * OpenAI providerData type definition
 */
export type HostedMCPTool<Context = UnknownContext> = {
  type: 'mcp';
  server_label: string;
  server_url: string;
  allowed_tools?: string[] | { tool_names: string[] };
  headers?: Record<string, string>;
} & (
  | { require_approval?: 'never'; on_approval?: never }
  | {
      require_approval:
        | 'always'
        | {
            never?: { tool_names: string[] };
            always?: { tool_names: string[] };
          };
      on_approval?: HostedMCPApprovalFunction<Context>;
    }
);

export type HostedMCPListTools = {
  id: string;
  server_label: string;
  tools: {
    input_schema: unknown;
    name: string;
    annotations?: unknown | null;
    description?: string | null;
  }[];
  error?: string | null;
};
export type HostedMCPCall = {
  id: string;
  arguments: string;
  name: string;
  server_label: string;
  error?: string | null;
  // excluding this large data field
  // output?: string | null;
};

export type HostedMCPApprovalRequest = {
  id: string;
  name: string;
  arguments: string;
  server_label: string;
};

export type HostedMCPApprovalResponse = {
  id?: string;
  approve: boolean;
  approval_request_id: string;
  reason?: string;
};



---
File: /packages/agents-core/src/utils/index.ts
---

export { isZodObject } from './typeGuards';
export { toSmartString } from './smartString';
export { EventEmitterDelegate } from '../lifecycle';



---
File: /packages/agents-core/src/utils/messages.ts
---

import { ResponseOutputItem } from '../types';
import { ModelResponse } from '../model';

/**
 * Get the last text from the output message.
 * @param outputMessage
 * @returns
 */
export function getLastTextFromOutputMessage(
  outputMessage: ResponseOutputItem,
): string | undefined {
  if (outputMessage.type !== 'message') {
    return undefined;
  }

  if (outputMessage.role !== 'assistant') {
    return undefined;
  }

  const lastItem = outputMessage.content[outputMessage.content.length - 1];
  if (lastItem.type !== 'output_text') {
    return undefined;
  }

  return lastItem.text;
}

/**
 * Get the last text from the output message.
 * @param output
 * @returns
 */
export function getOutputText(output: ModelResponse) {
  if (output.output.length === 0) {
    return '';
  }

  return (
    getLastTextFromOutputMessage(output.output[output.output.length - 1]) || ''
  );
}



---
File: /packages/agents-core/src/utils/safeExecute.ts
---

export type SafeExecuteResult<T> = [Error | unknown | null, T | null];

export async function safeExecute<T>(
  fn: () => T
): Promise<SafeExecuteResult<T>> {
  try {
    return [null, await fn()];
  } catch (error) {
    return [error, null];
  }
}



---
File: /packages/agents-core/src/utils/serialize.ts
---

import { JsonObjectSchema } from '../types';
import { Handoff } from '../handoff';
import { Tool } from '../tool';
import { SerializedHandoff, SerializedTool } from '../model';

export function serializeTool(tool: Tool<any>): SerializedTool {
  if (tool.type === 'function') {
    return {
      type: 'function',
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters as JsonObjectSchema<any>,
      strict: tool.strict,
    };
  }
  if (tool.type === 'computer') {
    return {
      type: 'computer',
      name: tool.name,
      environment: tool.computer.environment,
      dimensions: tool.computer.dimensions,
    };
  }
  return {
    type: 'hosted_tool',
    name: tool.name,
    providerData: tool.providerData,
  };
}

export function serializeHandoff(h: Handoff): SerializedHandoff {
  return {
    toolName: h.toolName,
    toolDescription: h.toolDescription,
    inputJsonSchema: h.inputJsonSchema as JsonObjectSchema<any>,
    strictJsonSchema: h.strictJsonSchema,
  };
}



---
File: /packages/agents-core/src/utils/smartString.ts
---

export function toSmartString(value: unknown): string {
  if (value === null || value === undefined) {
    return String(value);
  } else if (typeof value === 'string') {
    return value;
  } else if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch (_e) {
      return '[object with circular references]';
    }
  }
  return String(value);
}



---
File: /packages/agents-core/src/utils/tools.ts
---

import { zodResponsesFunction, zodTextFormat } from 'openai/helpers/zod';
import { UserError } from '../errors';
import { ToolInputParameters } from '../tool';
import { JsonObjectSchema, JsonSchemaDefinition, TextOutput } from '../types';
import { isZodObject } from './typeGuards';
import { AgentOutputType } from '../agent';

export type FunctionToolName = string & { __brand?: 'ToolName' } & {
  readonly __pattern?: '^[a-zA-Z0-9_]+$';
};

/**
 * Convert a string to a function tool name by replacing spaces with underscores and
 * non-alphanumeric characters with underscores.
 * @param name - The name of the tool.
 * @returns The function tool name.
 */
export function toFunctionToolName(name: string): FunctionToolName {
  // Replace spaces with underscores
  name = name.replace(/\s/g, '_');

  // Replace non-alphanumeric characters with underscores
  name = name.replace(/[^a-zA-Z0-9]/g, '_');

  // Ensure the name is not empty
  if (name.length === 0) {
    throw new Error('Tool name cannot be empty');
  }

  return name as FunctionToolName;
}

/**
 * Get the schema and parser from an input type. If the input type is a ZodObject, we will convert
 * it into a JSON Schema and use Zod as parser. If the input type is a JSON schema, we use the
 * JSON.parse function to get the parser.
 * @param inputType - The input type to get the schema and parser from.
 * @param name - The name of the tool.
 * @returns The schema and parser.
 */
export function getSchemaAndParserFromInputType<T extends ToolInputParameters>(
  inputType: T,
  name: string,
): {
  schema: JsonObjectSchema<any>;
  parser: (input: string) => any;
} {
  const parser = (input: string) => JSON.parse(input);

  if (isZodObject(inputType)) {
    const formattedFunction = zodResponsesFunction({
      name,
      parameters: inputType,
      function: () => {}, // empty function here to satisfy the OpenAI helper
      description: '',
    });

    return {
      schema: formattedFunction.parameters as JsonObjectSchema<any>,
      parser: formattedFunction.$parseRaw,
    };
  } else if (typeof inputType === 'object' && inputType !== null) {
    return {
      schema: inputType,
      parser,
    };
  }

  throw new UserError('Input type is not a ZodObject or a valid JSON schema');
}

/**
 * Converts the agent output type provided to a serializable version
 */
export function convertAgentOutputTypeToSerializable(
  outputType: AgentOutputType,
): JsonSchemaDefinition | TextOutput {
  if (outputType === 'text') {
    return 'text';
  }

  if (isZodObject(outputType)) {
    const output = zodTextFormat(outputType, 'output');
    return {
      type: output.type,
      name: output.name,
      strict: output.strict || false,
      schema: output.schema as JsonObjectSchema<any>,
    };
  }

  return outputType;
}



---
File: /packages/agents-core/src/utils/typeGuards.ts
---

import type { ZodObject } from 'zod/v3';

/**
 * Verifies that an input is a ZodObject without needing to have Zod at runtime since it's an
 * optional dependency.
 * @param input
 * @returns
 */

export function isZodObject(input: unknown): input is ZodObject<any> {
  return (
    typeof input === 'object' &&
    input !== null &&
    '_def' in input &&
    typeof input._def === 'object' &&
    input._def !== null &&
    'typeName' in input._def &&
    input._def.typeName === 'ZodObject'
  );
}
/**
 * Verifies that an input is an object with an `input` property.
 * @param input
 * @returns
 */

export function isAgentToolInput(input: unknown): input is {
  input: string;
} {
  return (
    typeof input === 'object' &&
    input !== null &&
    'input' in input &&
    typeof (input as any).input === 'string'
  );
}



---
File: /packages/agents-core/src/agent.ts
---

import type { ZodObject } from 'zod/v3';

import type { InputGuardrail, OutputGuardrail } from './guardrail';
import { AgentHooks } from './lifecycle';
import { getAllMcpTools, type MCPServer } from './mcp';
import type { Model, ModelSettings, Prompt } from './model';
import type { RunContext } from './runContext';
import {
  type FunctionTool,
  type FunctionToolResult,
  tool,
  type Tool,
} from './tool';
import type {
  ResolvedAgentOutput,
  JsonSchemaDefinition,
  HandoffsOutput,
  Expand,
} from './types';
import type { RunResult } from './result';
import type { Handoff } from './handoff';
import { Runner } from './run';
import { toFunctionToolName } from './utils/tools';
import { getOutputText } from './utils/messages';
import { isAgentToolInput } from './utils/typeGuards';
import { isZodObject } from './utils/typeGuards';
import { ModelBehaviorError, UserError } from './errors';
import { RunToolApprovalItem } from './items';
import logger from './logger';
import { UnknownContext, TextOutput } from './types';

export type ToolUseBehaviorFlags = 'run_llm_again' | 'stop_on_first_tool';

export type ToolsToFinalOutputResult =
  | {
      /**
       * Whether this is the final output. If `false`, the LLM will run again and receive the tool call output
       */
      isFinalOutput: false;
      /**
       * Whether the agent was interrupted by a tool approval. If `true`, the LLM will run again and receive the tool call output
       */
      isInterrupted: undefined;
    }
  | {
      isFinalOutput: false;
      /**
       * Whether the agent was interrupted by a tool approval. If `true`, the LLM will run again and receive the tool call output
       */
      isInterrupted: true;
      interruptions: RunToolApprovalItem[];
    }
  | {
      /**
       * Whether this is the final output. If `false`, the LLM will run again and receive the tool call output
       */
      isFinalOutput: true;

      /**
       * Whether the agent was interrupted by a tool approval. If `true`, the LLM will run again and receive the tool call output
       */
      isInterrupted: undefined;

      /**
       * The final output. Can be undefined if `isFinalOutput` is `false`, otherwise it must be a string
       * that will be processed based on the `outputType` of the agent.
       */
      finalOutput: string;
    };

/**
 * The type of the output object. If not provided, the output will be a string.
 * 'text' is a special type that indicates the output will be a string.
 *
 * @template HandoffOutputType The type of the output of the handoff.
 */
export type AgentOutputType<HandoffOutputType = UnknownContext> =
  | TextOutput
  | ZodObject<any>
  | JsonSchemaDefinition
  | HandoffsOutput<HandoffOutputType>;

/**
 * A function that takes a run context and a list of tool results and returns a `ToolsToFinalOutputResult`.
 */
export type ToolToFinalOutputFunction = (
  context: RunContext,
  toolResults: FunctionToolResult[],
) => ToolsToFinalOutputResult | Promise<ToolsToFinalOutputResult>;

/**
 * The behavior of the agent when a tool is called.
 */
export type ToolUseBehavior =
  | ToolUseBehaviorFlags
  | {
      /**
       * List of tool names that will stop the agent from running further. The final output will be
       * the output of the first tool in the list that was called.
       */
      stopAtToolNames: string[];
    }
  | ToolToFinalOutputFunction;

/**
 * Configuration for an agent.
 *
 * @template TContext The type of the context object.
 * @template TOutput The type of the output object.
 */
export interface AgentConfiguration<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> {
  /**
   * The name of the agent.
   */
  name: string;

  /**
   * The instructions for the agent. Will be used as the "system prompt" when this agent is
   * invoked. Describes what the agent should do, and how it responds.
   *
   * Can either be a string, or a function that dynamically generates instructions for the agent.
   * If you provide a function, it will be called with the context and the agent instance. It
   * must return a string.
   */
  instructions:
    | string
    | ((
        runContext: RunContext<TContext>,
        agent: Agent<TContext, TOutput>,
      ) => Promise<string> | string);

  /**
   * The prompt template to use for the agent (OpenAI Responses API only).
   *
   * Can either be a prompt template object, or a function that returns a prompt
   * template object. If a function is provided, it will be called with the run
   * context and the agent instance. It must return a prompt template object.
   */
  prompt?:
    | Prompt
    | ((
        runContext: RunContext<TContext>,
        agent: Agent<TContext, TOutput>,
      ) => Promise<Prompt> | Prompt);

  /**
   * A description of the agent. This is used when the agent is used as a handoff, so that an LLM
   * knows what it does and when to invoke it.
   */
  handoffDescription: string;

  /**
   * Handoffs are sub-agents that the agent can delegate to. You can provide a list of handoffs,
   * and the agent can choose to delegate to them if relevant. Allows for separation of concerns
   * and modularity.
   */
  handoffs: (Agent<any, any> | Handoff<any, TOutput>)[];

  /**
   * The warning log would be enabled when multiple output types by handoff agents are detected.
   */
  handoffOutputTypeWarningEnabled?: boolean;

  /**
   * The model implementation to use when invoking the LLM. By default, if not set, the agent will
   * use the default model configured in modelSettings.defaultModel
   */
  model: string | Model;

  /**
   * Configures model-specific tuning parameters (e.g. temperature, top_p, etc.)
   */
  modelSettings: ModelSettings;

  /**
   * A list of tools the agent can use.
   */
  tools: Tool<TContext>[];

  /**
   * A list of [Model Context Protocol](https://modelcontextprotocol.io/) servers the agent can use.
   * Every time the agent runs, it will include tools from these servers in the list of available
   * tools.
   *
   * NOTE: You are expected to manage the lifecycle of these servers. Specifically, you must call
   * `server.connect()` before passing it to the agent, and `server.cleanup()` when the server is
   * no longer needed.
   */
  mcpServers: MCPServer[];

  /**
   * A list of checks that run in parallel to the agent's execution, before generating a response.
   * Runs only if the agent is the first agent in the chain.
   */
  inputGuardrails: InputGuardrail[];

  /**
   * A list of checks that run on the final output of the agent, after generating a response. Runs
   * only if the agent produces a final output.
   */
  outputGuardrails: OutputGuardrail<TOutput>[];

  /**
   * The type of the output object. If not provided, the output will be a string.
   */
  outputType: TOutput;

  /**
   * This lets you configure how tool use is handled.
   * - run_llm_again: The default behavior. Tools are run, and then the LLM receives the results
   *   and gets to respond.
   * - stop_on_first_tool: The output of the first tool call is used as the final output. This means
   *   that the LLM does not process the result of the tool call.
   * - A list of tool names: The agent will stop running if any of the tools in the list are called.
   *   The final output will be the output of the first matching tool call. The LLM does not process
   *   the result of the tool call.
   * - A function: if you pass a function, it will be called with the run context and the list of
   *   tool results. It must return a `ToolsToFinalOutputResult`, which determines whether the tool
   *   call resulted in a final output.
   *
   * NOTE: This configuration is specific to `FunctionTools`. Hosted tools, such as file search, web
   * search, etc. are always processed by the LLM
   */
  toolUseBehavior: ToolUseBehavior;

  /**
   * Whether to reset the tool choice to the default value after a tool has been called. Defaults
   * to `true`. This ensures that the agent doesn't enter an infinite loop of tool usage.
   */
  resetToolChoice: boolean;
}

export type AgentOptions<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> = Expand<
  Pick<AgentConfiguration<TContext, TOutput>, 'name'> &
    Partial<AgentConfiguration<TContext, TOutput>>
>;

/**
 * An agent is an AI model configured with instructions, tools, guardrails, handoffs and more.
 *
 * We strongly recommend passing `instructions`, which is the "system prompt" for the agent. In
 * addition, you can pass `handoffDescription`, which is a human-readable description of the
 * agent, used when the agent is used inside tools/handoffs.
 *
 * Agents are generic on the context type. The context is a (mutable) object you create. It is
 * passed to tool functions, handoffs, guardrails, etc.
 */
// --- Type utilities for inferring output type from handoffs ---
type ExtractAgentOutput<T> = T extends Agent<any, infer O> ? O : never;
type ExtractHandoffOutput<T> = T extends Handoff<any, infer O> ? O : never;
export type HandoffsOutputUnion<
  Handoffs extends readonly (Agent<any, any> | Handoff<any, any>)[],
> =
  | ExtractAgentOutput<Handoffs[number]>
  | ExtractHandoffOutput<Handoffs[number]>;

/**
 * Helper type for config with handoffs
 *
 * @template TOutput The type of the output object.
 * @template Handoffs The type of the handoffs.
 */
export type AgentConfigWithHandoffs<
  TOutput extends AgentOutputType,
  Handoffs extends readonly (Agent<any, any> | Handoff<any, any>)[],
> = { name: string; handoffs?: Handoffs; outputType?: TOutput } & Partial<
  Omit<
    AgentConfiguration<UnknownContext, TOutput | HandoffsOutputUnion<Handoffs>>,
    'name' | 'handoffs' | 'outputType'
  >
>;

/**
 * The class representing an AI agent configured with instructions, tools, guardrails, handoffs and more.
 *
 * We strongly recommend passing `instructions`, which is the "system prompt" for the agent. In
 * addition, you can pass `handoffDescription`, which is a human-readable description of the
 * agent, used when the agent is used inside tools/handoffs.
 *
 * Agents are generic on the context type. The context is a (mutable) object you create. It is
 * passed to tool functions, handoffs, guardrails, etc.
 */
export class Agent<
    TContext = UnknownContext,
    TOutput extends AgentOutputType = TextOutput,
  >
  extends AgentHooks<TContext, TOutput>
  implements AgentConfiguration<TContext, TOutput>
{
  /**
   * Create an Agent with handoffs and automatically infer the union type for TOutput from the handoff agents' output types.
   */
  static create<
    TOutput extends AgentOutputType = TextOutput,
    Handoffs extends readonly (Agent<any, any> | Handoff<any, any>)[] = [],
  >(
    config: AgentConfigWithHandoffs<TOutput, Handoffs>,
  ): Agent<UnknownContext, TOutput | HandoffsOutputUnion<Handoffs>> {
    return new Agent<UnknownContext, TOutput | HandoffsOutputUnion<Handoffs>>({
      ...config,
      handoffs: config.handoffs as any,
      outputType: config.outputType,
      handoffOutputTypeWarningEnabled: false,
    });
  }

  static DEFAULT_MODEL_PLACEHOLDER = '';

  name: string;
  instructions:
    | string
    | ((
        runContext: RunContext<TContext>,
        agent: Agent<TContext, TOutput>,
      ) => Promise<string> | string);
  prompt?:
    | Prompt
    | ((
        runContext: RunContext<TContext>,
        agent: Agent<TContext, TOutput>,
      ) => Promise<Prompt> | Prompt);
  handoffDescription: string;
  handoffs: (Agent<any, TOutput> | Handoff<any, TOutput>)[];
  model: string | Model;
  modelSettings: ModelSettings;
  tools: Tool<TContext>[];
  mcpServers: MCPServer[];
  inputGuardrails: InputGuardrail[];
  outputGuardrails: OutputGuardrail<AgentOutputType>[];
  outputType: TOutput = 'text' as TOutput;
  toolUseBehavior: ToolUseBehavior;
  resetToolChoice: boolean;

  constructor(config: AgentOptions<TContext, TOutput>) {
    super();
    if (typeof config.name !== 'string' || config.name.trim() === '') {
      throw new UserError('Agent must have a name.');
    }
    this.name = config.name;
    this.instructions = config.instructions ?? Agent.DEFAULT_MODEL_PLACEHOLDER;
    this.prompt = config.prompt;
    this.handoffDescription = config.handoffDescription ?? '';
    this.handoffs = config.handoffs ?? [];
    this.model = config.model ?? '';
    this.modelSettings = config.modelSettings ?? {};
    this.tools = config.tools ?? [];
    this.mcpServers = config.mcpServers ?? [];
    this.inputGuardrails = config.inputGuardrails ?? [];
    this.outputGuardrails = config.outputGuardrails ?? [];
    if (config.outputType) {
      this.outputType = config.outputType;
    }
    this.toolUseBehavior = config.toolUseBehavior ?? 'run_llm_again';
    this.resetToolChoice = config.resetToolChoice ?? true;

    // --- Runtime warning for handoff output type compatibility ---
    if (
      config.handoffOutputTypeWarningEnabled === undefined ||
      config.handoffOutputTypeWarningEnabled
    ) {
      if (this.handoffs && this.outputType) {
        const outputTypes = new Set<string>([JSON.stringify(this.outputType)]);
        for (const h of this.handoffs) {
          if ('outputType' in h && h.outputType) {
            outputTypes.add(JSON.stringify(h.outputType));
          } else if ('agent' in h && h.agent.outputType) {
            outputTypes.add(JSON.stringify(h.agent.outputType));
          }
        }
        if (outputTypes.size > 1) {
          logger.warn(
            `[Agent] Warning: Handoff agents have different output types: ${Array.from(outputTypes).join(', ')}. You can make it type-safe by using Agent.create({ ... }) method instead.`,
          );
        }
      }
    }
  }

  /**
   * Output schema name.
   */
  get outputSchemaName(): string {
    if (this.outputType === 'text') {
      return 'text';
    } else if (isZodObject(this.outputType)) {
      return 'ZodOutput';
    } else if (typeof this.outputType === 'object') {
      return this.outputType.name;
    }

    throw new Error(`Unknown output type: ${this.outputType}`);
  }

  /**
   * Makes a copy of the agent, with the given arguments changed. For example, you could do:
   *
   * ```
   * const newAgent = agent.clone({ instructions: 'New instructions' })
   * ```
   *
   * @param config - A partial configuration to change.
   * @returns A new agent with the given changes.
   */
  clone(
    config: Partial<AgentConfiguration<TContext, TOutput>>,
  ): Agent<TContext, TOutput> {
    return new Agent({
      ...this,
      ...config,
    });
  }

  /**
   * Transform this agent into a tool, callable by other agents.
   *
   * This is different from handoffs in two ways:
   * 1. In handoffs, the new agent receives the conversation history. In this tool, the new agent
   *    receives generated input.
   * 2. In handoffs, the new agent takes over the conversation. In this tool, the new agent is
   *    called as a tool, and the conversation is continued by the original agent.
   *
   * @param options - Options for the tool.
   * @returns A tool that runs the agent and returns the output text.
   */
  asTool(options: {
    /**
     * The name of the tool. If not provided, the name of the agent will be used.
     */
    toolName?: string;
    /**
     * The description of the tool, which should indicate what the tool does and when to use it.
     */
    toolDescription?: string;
    /**
     * A function that extracts the output text from the agent. If not provided, the last message
     * from the agent will be used.
     */
    customOutputExtractor?: (
      output: RunResult<TContext, Agent<TContext, any>>,
    ) => string | Promise<string>;
  }): FunctionTool {
    const { toolName, toolDescription, customOutputExtractor } = options;
    return tool({
      name: toolName ?? toFunctionToolName(this.name),
      description: toolDescription ?? '',
      parameters: {
        type: 'object',
        properties: {
          input: {
            type: 'string',
          },
        },
        required: ['input'],
        additionalProperties: false,
      },
      strict: true,
      execute: async (data, context) => {
        if (!isAgentToolInput(data)) {
          throw new ModelBehaviorError('Agent tool called with invalid input');
        }

        const runner = new Runner();
        const result = await runner.run(this, data.input, {
          context: context?.context,
        });
        if (typeof customOutputExtractor === 'function') {
          return customOutputExtractor(result as any);
        }
        return getOutputText(
          result.rawResponses[result.rawResponses.length - 1],
        );
      },
    });
  }

  /**
   * Returns the system prompt for the agent.
   *
   * If the agent has a function as its instructions, this function will be called with the
   * runContext and the agent instance.
   */
  async getSystemPrompt(
    runContext: RunContext<TContext>,
  ): Promise<string | undefined> {
    if (typeof this.instructions === 'function') {
      return await this.instructions(runContext, this);
    }

    return this.instructions;
  }

  /**
   * Returns the prompt template for the agent, if defined.
   *
   * If the agent has a function as its prompt, this function will be called with the
   * runContext and the agent instance.
   */
  async getPrompt(
    runContext: RunContext<TContext>,
  ): Promise<Prompt | undefined> {
    if (typeof this.prompt === 'function') {
      return await this.prompt(runContext, this);
    }
    return this.prompt;
  }

  /**
   * Fetches the available tools from the MCP servers.
   * @returns the MCP powered tools
   */
  async getMcpTools(): Promise<Tool<TContext>[]> {
    if (this.mcpServers.length > 0) {
      return getAllMcpTools(this.mcpServers);
    }

    return [];
  }

  /**
   * ALl agent tools, including the MCPl and function tools.
   *
   * @returns all configured tools
   */
  async getAllTools(): Promise<Tool<TContext>[]> {
    return [...(await this.getMcpTools()), ...this.tools];
  }

  /**
   * Processes the final output of the agent.
   *
   * @param output - The output of the agent.
   * @returns The parsed out.
   */
  processFinalOutput(output: string): ResolvedAgentOutput<TOutput> {
    if (this.outputType === 'text') {
      return output as ResolvedAgentOutput<TOutput>;
    }

    if (typeof this.outputType === 'object') {
      const parsed = JSON.parse(output);

      if (isZodObject(this.outputType)) {
        return this.outputType.parse(parsed) as ResolvedAgentOutput<TOutput>;
      }

      return parsed as ResolvedAgentOutput<TOutput>;
    }

    throw new Error(`Unknown output type: ${this.outputType}`);
  }

  /**
   * Returns a JSON representation of the agent, which is serializable.
   *
   * @returns A JSON object containing the agent's name.
   */
  toJSON() {
    return {
      name: this.name,
    };
  }
}



---
File: /packages/agents-core/src/computer.ts
---

export type Environment = 'mac' | 'windows' | 'ubuntu' | 'browser';
export type Button = 'left' | 'right' | 'wheel' | 'back' | 'forward';

import { Expand, SnakeToCamelCase } from './types/helpers';
import type { ComputerAction } from './types/protocol';

type Promisable<T> = T | Promise<T>;

/**
 * Interface to implement for a computer environment to be used by the agent.
 */
interface ComputerBase {
  environment: Environment;
  dimensions: [number, number];

  screenshot(): Promisable<string>;
  click(x: number, y: number, button: Button): Promisable<void>;
  doubleClick(x: number, y: number): Promisable<void>;
  scroll(
    x: number,
    y: number,
    scrollX: number,
    scrollY: number,
  ): Promisable<void>;
  type(text: string): Promisable<void>;
  wait(): Promisable<void>;
  move(x: number, y: number): Promisable<void>;
  keypress(keys: string[]): Promisable<void>;
  drag(path: [number, number][]): Promisable<void>;
}

// This turns every snake_case string in the ComputerAction['type'] into a camelCase string
type ActionNames = SnakeToCamelCase<ComputerAction['type']>;

/**
 * Interface representing a fully implemented computer environment.
 * Combines the base operations with a constraint that no extra
 * action names beyond those in `ComputerAction` are present.
 */
export type Computer = Expand<
  ComputerBase & Record<Exclude<ActionNames, keyof ComputerBase>, never>
>;



---
File: /packages/agents-core/src/config.ts
---

// Use function instead of exporting the value to prevent
// circular dependency resolution issues caused by other exports in '@openai/agents-core/_shims'
import {
  loadEnv as _loadEnv,
  isBrowserEnvironment,
} from '@openai/agents-core/_shims';

/**
 * Loads environment variables from the process environment.
 *
 * @returns An object containing the environment variables.
 */
export function loadEnv(): Record<string, string | undefined> {
  return _loadEnv();
}

/**
 * Checks if a flag is enabled in the environment.
 *
 * @param flagName - The name of the flag to check.
 * @returns `true` if the flag is enabled, `false` otherwise.
 */
function isEnabled(flagName: string): boolean {
  const env = loadEnv();
  return (
    typeof env !== 'undefined' &&
    (env[flagName] === 'true' || env[flagName] === '1')
  );
}

/**
 * Global configuration for tracing.
 */
export const tracing = {
  get disabled() {
    if (isBrowserEnvironment()) {
      return true;
    } else if (loadEnv().NODE_ENV === 'test') {
      // disabling by default in tests
      return true;
    }
    return isEnabled('OPENAI_AGENTS_DISABLE_TRACING');
  },
};

/**
 * Global configuration for logging.
 */
export const logging = {
  get dontLogModelData() {
    return isEnabled('OPENAI_AGENTS_DONT_LOG_MODEL_DATA');
  },
  get dontLogToolData() {
    return isEnabled('OPENAI_AGENTS_DONT_LOG_TOOL_DATA');
  },
};



---
File: /packages/agents-core/src/errors.ts
---

import { Agent, AgentOutputType } from './agent';
import {
  InputGuardrailResult,
  OutputGuardrailMetadata,
  OutputGuardrailResult,
} from './guardrail';
import { RunState } from './runState';
import { TextOutput } from './types';

/**
 * Base class for all errors thrown by the library.
 */
export abstract class AgentsError extends Error {
  state?: RunState<any, Agent<any, any>>;

  constructor(message: string, state?: RunState<any, Agent<any, any>>) {
    super(message);
    this.state = state;
  }
}

/**
 * System error thrown when the library encounters an error that is not caused by the user's
 * misconfiguration.
 */
export class SystemError extends AgentsError {}

/**
 * Error thrown when the maximum number of turns is exceeded.
 */
export class MaxTurnsExceededError extends AgentsError {}

/**
 * Error thrown when a model behavior is unexpected.
 */
export class ModelBehaviorError extends AgentsError {}

/**
 * Error thrown when the error is caused by the library user's misconfiguration.
 */
export class UserError extends AgentsError {}

/**
 * Error thrown when a guardrail execution fails.
 */
export class GuardrailExecutionError extends AgentsError {
  error: Error;
  constructor(
    message: string,
    error: Error,
    state?: RunState<any, Agent<any, any>>,
  ) {
    super(message, state);
    this.error = error;
  }
}

/**
 * Error thrown when a tool call fails.
 */
export class ToolCallError extends AgentsError {
  error: Error;
  constructor(
    message: string,
    error: Error,
    state?: RunState<any, Agent<any, any>>,
  ) {
    super(message, state);
    this.error = error;
  }
}

/**
 * Error thrown when an input guardrail tripwire is triggered.
 */
export class InputGuardrailTripwireTriggered extends AgentsError {
  result: InputGuardrailResult;
  constructor(
    message: string,
    result: InputGuardrailResult,
    state?: RunState<any, any>,
  ) {
    super(message, state);
    this.result = result;
  }
}

/**
 * Error thrown when an output guardrail tripwire is triggered.
 */
export class OutputGuardrailTripwireTriggered<
  TMeta extends OutputGuardrailMetadata,
  TOutputType extends AgentOutputType = TextOutput,
> extends AgentsError {
  result: OutputGuardrailResult<TMeta, TOutputType>;
  constructor(
    message: string,
    result: OutputGuardrailResult<TMeta, TOutputType>,
    state?: RunState<any, any>,
  ) {
    super(message, state);
    this.result = result;
  }
}



---
File: /packages/agents-core/src/events.ts
---

import { Agent } from './agent';
import { RunItem } from './items';
import { ResponseStreamEvent } from './types';

/**
 * Streaming event from the LLM. These are `raw` events, i.e. they are directly passed through from
 * the LLM.
 */
export class RunRawModelStreamEvent {
  /**
   * The type of the event.
   */
  public readonly type = 'raw_model_stream_event';

  /**
   * @param data The raw responses stream events from the LLM.
   */
  constructor(public data: ResponseStreamEvent) {}
}

/**
 * The names of the events that can be generated by the agent.
 */
export type RunItemStreamEventName =
  | 'message_output_created'
  | 'handoff_requested'
  | 'handoff_occurred'
  | 'tool_called'
  | 'tool_output'
  | 'reasoning_item_created'
  | 'tool_approval_requested';

/**
 * Streaming events that wrap a `RunItem`. As the agent processes the LLM response, it will generate
 * these events from new messages, tool calls, tool outputs, handoffs, etc.
 */
export class RunItemStreamEvent {
  public readonly type = 'run_item_stream_event';

  /**
   * @param name The name of the event.
   * @param item The item that was created.
   */
  constructor(
    public name: RunItemStreamEventName,
    public item: RunItem,
  ) {}
}

/**
 * Event that notifies that there is a new agent running.
 */
export class RunAgentUpdatedStreamEvent {
  public readonly type = 'agent_updated_stream_event';

  /**
   * @param agent The new agent
   */
  constructor(public agent: Agent<any, any>) {}
}

/**
 * A streaming event from an agent run.
 */
export type RunStreamEvent =
  | RunRawModelStreamEvent
  | RunItemStreamEvent
  | RunAgentUpdatedStreamEvent;



---
File: /packages/agents-core/src/guardrail.ts
---

import type { ModelItem } from './types/protocol';
import { Agent, AgentOutputType } from './agent';
import { RunContext } from './runContext';
import { ResolvedAgentOutput, TextOutput, UnknownContext } from './types';
import type { ModelResponse } from './model';

/**
 * Definition of input/output guardrails; SDK users usually do not need to create this.
 */
export type GuardrailDefinition =
  | InputGuardrailDefinition
  | OutputGuardrailDefinition;

// common

/**
 * The output of a guardrail function.
 */
export interface GuardrailFunctionOutput {
  /**
   * Whether the tripwire was triggered. If triggered, the agent's execution will be halted.
   */
  tripwireTriggered: boolean;
  /**
   * Optional information about the guardrail's output.
   * For example, the guardrail could include information about the checks it performed and granular results.
   */
  outputInfo: any;
}

// ----------------------------------------------------------
// Input Guardrail
// ----------------------------------------------------------

/**
 * Arguments for an input guardrail function.
 */
export interface InputGuardrailFunctionArgs<TContext = UnknownContext> {
  /**
   * The agent that is being run.
   */
  agent: Agent<any, any>;

  /**
   * The input to the agent.
   */
  input: string | ModelItem[];

  /**
   * The context of the agent run.
   */
  context: RunContext<TContext>;
}

/**
 * A guardrail that checks the input to the agent.
 */
export interface InputGuardrail {
  /**
   * The name of the guardrail.
   */
  name: string;

  /**
   * The function that performs the guardrail check
   */
  execute: InputGuardrailFunction;
}

/**
 * The result of an input guardrail execution.
 */
export interface InputGuardrailResult {
  /**
   * The metadata of the guardrail.
   */
  guardrail: InputGuardrailMetadata;

  /**
   * The output of the guardrail.
   */
  output: GuardrailFunctionOutput;
}

// function

/**
 * The function that performs the actual input guardrail check and returns the decision on whether
 * a guardrail was triggered.
 */
export type InputGuardrailFunction = (
  args: InputGuardrailFunctionArgs,
) => Promise<GuardrailFunctionOutput>;

/**
 * Metadata for an input guardrail.
 */
export interface InputGuardrailMetadata {
  type: 'input';
  name: string;
}

/**
 * Definition of an input guardrail. SDK users usually do not need to create this.
 */
export interface InputGuardrailDefinition extends InputGuardrailMetadata {
  guardrailFunction: InputGuardrailFunction;
  run(args: InputGuardrailFunctionArgs): Promise<InputGuardrailResult>;
}

/**
 * Arguments for defining an input guardrail definition.
 */
export interface DefineInputGuardrailArgs {
  name: string;
  execute: InputGuardrailFunction;
}

/**
 * Defines an input guardrail definition.
 */
export function defineInputGuardrail({
  name,
  execute,
}: DefineInputGuardrailArgs): InputGuardrailDefinition {
  return {
    type: 'input',
    name,
    guardrailFunction: execute,
    async run(args: InputGuardrailFunctionArgs): Promise<InputGuardrailResult> {
      return {
        guardrail: { type: 'input', name },
        output: await execute(args),
      };
    },
  };
}

// ----------------------------------------------------------
// Output Guardrail
// ----------------------------------------------------------

/**
 * Arguments for an output guardrail function.
 */
export interface OutputGuardrailFunctionArgs<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> {
  agent: Agent<any, any>;
  agentOutput: ResolvedAgentOutput<TOutput>;
  context: RunContext<TContext>;
  /**
   * Additional details about the agent output.
   */
  details?: {
    /** Model response associated with the output if available. */
    modelResponse?: ModelResponse;
  };
}
/**
 * The result of an output guardrail execution.
 */
export interface OutputGuardrailResult<
  TMeta = OutputGuardrailMetadata,
  TOutput extends AgentOutputType = TextOutput,
> {
  /**
   * The metadata of the guardrail.
   */
  guardrail: TMeta;

  /**
   * The output of the agent that ran.
   */
  agentOutput: ResolvedAgentOutput<TOutput>;

  /**
   * The agent that ran.
   */
  agent: Agent<UnknownContext, TOutput>;

  /**
   * The output of the guardrail.
   */
  output: GuardrailFunctionOutput;
}
// function

/**
 * A function that takes an output guardrail function arguments and returns a `GuardrailFunctionOutput`.
 */
export type OutputGuardrailFunction<
  TOutput extends AgentOutputType = TextOutput,
> = (
  args: OutputGuardrailFunctionArgs<UnknownContext, TOutput>,
) => Promise<GuardrailFunctionOutput>;

/**
 * A guardrail that checks the output of the agent.
 */
export interface OutputGuardrail<TOutput extends AgentOutputType = TextOutput> {
  /**
   * The name of the guardrail.
   */
  name: string;

  /**
   * The function that performs the guardrail check.
   */
  execute: OutputGuardrailFunction<TOutput>;
}

/**
 * Metadata for an output guardrail.
 */
export interface OutputGuardrailMetadata {
  type: 'output';
  name: string;
}

/**
 * Definition of an output guardrail.
 */
export interface OutputGuardrailDefinition<
  TMeta = OutputGuardrailMetadata,
  TOutput extends AgentOutputType = TextOutput,
> extends OutputGuardrailMetadata {
  guardrailFunction: OutputGuardrailFunction<TOutput>;
  run(
    args: OutputGuardrailFunctionArgs<UnknownContext, TOutput>,
  ): Promise<OutputGuardrailResult<TMeta, TOutput>>;
}

/**
 * Arguments for defining an output guardrail definition.
 */
export interface DefineOutputGuardrailArgs<
  TOutput extends AgentOutputType = TextOutput,
> {
  name: string;
  execute: OutputGuardrailFunction<TOutput>;
}

/**
 * Creates an output guardrail definition.
 */
export function defineOutputGuardrail<
  TOutput extends AgentOutputType = TextOutput,
>({
  name,
  execute,
}: DefineOutputGuardrailArgs<TOutput>): OutputGuardrailDefinition<
  OutputGuardrailMetadata,
  TOutput
> {
  return {
    type: 'output',
    name,
    guardrailFunction: execute,
    async run(
      args: OutputGuardrailFunctionArgs<UnknownContext, TOutput>,
    ): Promise<OutputGuardrailResult<OutputGuardrailMetadata, TOutput>> {
      return {
        guardrail: { type: 'output', name },
        agent: args.agent,
        agentOutput: args.agentOutput,
        output: await execute(args),
      };
    },
  };
}



---
File: /packages/agents-core/src/handoff.ts
---

import { Agent, AgentOutputType } from './agent';
import { RunContext } from './runContext';
import {
  AgentInputItem,
  JsonObjectSchema,
  ResolveParsedToolParameters,
  TextOutput,
  UnknownContext,
} from './types';
import { RunItem } from './items';
import { ModelBehaviorError, UserError } from './errors';
import { ToolInputParameters } from './tool';
import { toFunctionToolName } from './utils/tools';
import { getSchemaAndParserFromInputType } from './utils/tools';
import { addErrorToCurrentSpan } from './tracing/context';
import logger from './logger';

/**
 * Data passed to the handoff function.
 */
export type HandoffInputData = {
  /**
   * The input history before `Runner.run()` was called.
   */
  inputHistory: string | AgentInputItem[];

  /**
   * The items generated before the agent turn where the handoff was invoked.
   */
  preHandoffItems: RunItem[];

  /**
   * The new items generated during the current agent turn, including the item that triggered the
   * handoff and the tool output message representing the response from the handoff output.
   */
  newItems: RunItem[];
};

export type HandoffInputFilter = (input: HandoffInputData) => HandoffInputData;

/**
 * Generates the message that will be given as tool output to the model that requested the handoff.
 *
 * @param agent The agent to transfer to
 * @returns The message that will be given as tool output to the model that requested the handoff
 */
export function getTransferMessage<TContext, TOutput extends AgentOutputType>(
  agent: Agent<TContext, TOutput>,
) {
  return JSON.stringify({ assistant: agent.name });
}

/**
 * The default name of the tool that represents the handoff.
 *
 * @param agent The agent to transfer to
 * @returns The name of the tool that represents the handoff
 */
function defaultHandoffToolName<TContext, TOutput extends AgentOutputType>(
  agent: Agent<TContext, TOutput>,
) {
  return `transfer_to_${toFunctionToolName(agent.name)}`;
}

/**
 * Generates the description of the tool that represents the handoff.
 *
 * @param agent The agent to transfer to
 * @returns The description of the tool that represents the handoff
 */
function defaultHandoffToolDescription<
  TContext,
  TOutput extends AgentOutputType,
>(agent: Agent<TContext, TOutput>) {
  return `Handoff to the ${agent.name} agent to handle the request. ${
    agent.handoffDescription ?? ''
  }`;
}

/**
 * A handoff is when an agent delegates a task to another agent.
 * For example, in a customer support scenario you might have a "triage agent" that determines which
 * agent should handle the user's request, and sub-agents that specialize in different areas like
 * billing, account management, etc.
 *
 * @template TContext The context of the handoff
 * @template TOutput The output type of the handoff
 */
export class Handoff<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> {
  /**
   * The name of the tool that represents the handoff.
   */
  public toolName: string;

  /**
   * The description of the tool that represents the handoff.
   */
  public toolDescription: string;

  /**
   * The JSON schema for the handoff input. Can be empty if the handoff does not take an input
   */
  public inputJsonSchema: JsonObjectSchema<any> = {
    type: 'object',
    properties: {},
    required: [],
    additionalProperties: false,
  };

  /**
   * Whether the input JSON schema is in strict mode. We **strongly** recommend setting this to
   * true, as it increases the likelihood of correct JSON input.
   */
  public strictJsonSchema: boolean = true;

  /**
   * The function that invokes the handoff. The parameters passed are:
   * 1. The handoff run context
   * 2. The arguments from the LLM, as a JSON string. Empty string if inputJsonSchema is empty.
   *
   * Must return an agent
   */
  public onInvokeHandoff: (
    context: RunContext<TContext>,
    args: string,
  ) => Promise<Agent<TContext, TOutput>> | Agent<TContext, TOutput>;

  /**
   * The name of the agent that is being handed off to.
   */
  public agentName: string;

  /**
   * A function that filters the inputs that are passed to the next agent. By default, the new agent
   * sees the entire conversation history. In some cases, you may want to filter inputs e.g. to
   * remove older inputs, or remove tools from existing inputs.
   *
   * The function will receive the entire conversation hisstory so far, including the input item
   * that triggered the handoff and a tool call output item representing the handoff tool's output.
   *
   * You are free to modify the input history or new items as you see fit. The next agent that runs
   * will receive `handoffInputData.allItems
   */
  public inputFilter?: HandoffInputFilter;

  /**
   * The agent that is being handed off to.
   */
  public agent: Agent<TContext, TOutput>;

  /**
   * Returns a function tool definition that can be used to invoke the handoff.
   */
  getHandoffAsFunctionTool() {
    return {
      type: 'function' as const,
      name: this.toolName,
      description: this.toolDescription,
      parameters: this.inputJsonSchema,
      strict: this.strictJsonSchema,
    };
  }

  constructor(
    agent: Agent<TContext, TOutput>,
    onInvokeHandoff: (
      context: RunContext<TContext>,
      args: string,
    ) => Promise<Agent<TContext, TOutput>> | Agent<TContext, TOutput>,
  ) {
    this.agentName = agent.name;
    this.onInvokeHandoff = onInvokeHandoff;
    this.toolName = defaultHandoffToolName(agent);
    this.toolDescription = defaultHandoffToolDescription(agent);
    this.agent = agent;
  }
}

/**
 * A function that runs when the handoff is invoked.
 */
export type OnHandoffCallback<TInputType extends ToolInputParameters> = (
  context: RunContext<any>,
  input?: ResolveParsedToolParameters<TInputType>,
) => Promise<void> | void;

/**
 * Configuration for a handoff.
 */
export type HandoffConfig<TInputType extends ToolInputParameters> = {
  /**
   * Optional override for the name of the tool that represents the handoff.
   */
  toolNameOverride?: string;

  /**
   * Optional override for the description of the tool that represents the handoff.
   */
  toolDescriptionOverride?: string;

  /**
   * A function that runs when the handoff is invoked
   */
  onHandoff?: OnHandoffCallback<TInputType>;

  /**
   * The type of the input to the handoff. If provided as a Zod schema, the input will be validated
   * against this type. Only relevant if you pass a function that takes an input
   */
  inputType?: TInputType;

  /**
   * A function that filters the inputs that are passed to the next agent.
   */
  inputFilter?: HandoffInputFilter;
};

/**
 * Creates a handoff from an agent. Handoffs are automatically created when you pass an agent
 * into the `handoffs` option of the `Agent` constructor. Alternatively, you can use this function
 * to create a handoff manually, giving you more control over configuration.
 *
 * @template TContext The context of the handoff
 * @template TOutput The output type of the handoff
 * @template TInputType The input type of the handoff
 */
export function handoff<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
  TInputType extends ToolInputParameters = ToolInputParameters,
>(agent: Agent<TContext, TOutput>, config: HandoffConfig<TInputType> = {}) {
  let parser: ((input: string) => Promise<any>) | undefined = undefined;

  const hasOnHandoff = !!config.onHandoff;
  const hasInputType = !!config.inputType;
  const hasBothOrNeitherHandoffAndInputType = hasOnHandoff === hasInputType;

  if (!hasBothOrNeitherHandoffAndInputType) {
    throw new UserError(
      'You must provide either both `onHandoff` and `inputType` or neither.',
    );
  }

  async function onInvokeHandoff(
    context: RunContext<any>,
    inputJsonString?: string,
  ) {
    if (parser) {
      if (!inputJsonString) {
        addErrorToCurrentSpan({
          message: `Handoff function expected non empty input but got: ${inputJsonString}`,
          data: {
            details: `input is empty`,
          },
        });
        throw new ModelBehaviorError(
          'Handoff function expected non empty input',
        );
      }
      try {
        // verify that it's valid input but we don't care about the result
        const parsed = await parser(inputJsonString);
        if (config.onHandoff) {
          await config.onHandoff(context, parsed);
        }
      } catch (error) {
        addErrorToCurrentSpan({
          message: `Invalid JSON provided`,
          data: {},
        });
        if (!logger.dontLogToolData) {
          logger.error(
            `Invalid JSON when parsing: ${inputJsonString}. Error: ${error}`,
          );
        }
        throw new ModelBehaviorError('Invalid JSON provided');
      }
    } else {
      await config.onHandoff?.(context);
    }

    return agent;
  }

  const handoff = new Handoff(agent, onInvokeHandoff);

  if (config.inputType) {
    const result = getSchemaAndParserFromInputType(
      config.inputType,
      handoff.toolName,
    );
    handoff.inputJsonSchema = result.schema;
    handoff.strictJsonSchema = true;
    parser = result.parser;
  }

  if (config.toolNameOverride) {
    handoff.toolName = config.toolNameOverride;
  }

  if (config.toolDescriptionOverride) {
    handoff.toolDescription = config.toolDescriptionOverride;
  }

  if (config.inputFilter) {
    handoff.inputFilter = config.inputFilter;
  }

  return handoff;
}

/**
 * Returns a handoff for the given agent. If the agent is already wrapped into a handoff,
 * it will be returned as is. Otherwise, a new handoff instance will be created.
 *
 * @template TContext The context of the handoff
 * @template TOutput The output type of the handoff
 */
export function getHandoff<TContext, TOutput extends AgentOutputType>(
  agent: Agent<TContext, TOutput> | Handoff<TContext, TOutput>,
) {
  if (agent instanceof Handoff) {
    return agent;
  }

  return handoff(agent);
}



---
File: /packages/agents-core/src/index.ts
---

import { addTraceProcessor } from './tracing';
import { defaultProcessor } from './tracing/processor';

export { RuntimeEventEmitter } from '@openai/agents-core/_shims';
export {
  Agent,
  AgentConfiguration,
  AgentConfigWithHandoffs,
  AgentOptions,
  AgentOutputType,
  ToolsToFinalOutputResult,
  ToolToFinalOutputFunction,
  ToolUseBehavior,
  ToolUseBehaviorFlags,
} from './agent';
export { Computer } from './computer';
export {
  AgentsError,
  GuardrailExecutionError,
  InputGuardrailTripwireTriggered,
  MaxTurnsExceededError,
  ModelBehaviorError,
  OutputGuardrailTripwireTriggered,
  ToolCallError,
  UserError,
  SystemError,
} from './errors';
export {
  RunAgentUpdatedStreamEvent,
  RunRawModelStreamEvent,
  RunItemStreamEvent,
  RunStreamEvent,
} from './events';
export {
  defineOutputGuardrail,
  GuardrailFunctionOutput,
  InputGuardrail,
  InputGuardrailFunction,
  InputGuardrailFunctionArgs,
  InputGuardrailMetadata,
  InputGuardrailResult,
  OutputGuardrail,
  OutputGuardrailDefinition,
  OutputGuardrailFunction,
  OutputGuardrailFunctionArgs,
  OutputGuardrailMetadata,
  OutputGuardrailResult,
} from './guardrail';
export {
  getHandoff,
  getTransferMessage,
  Handoff,
  handoff,
  HandoffInputData,
} from './handoff';
export { assistant, system, user } from './helpers/message';
export {
  extractAllTextOutput,
  RunHandoffCallItem,
  RunHandoffOutputItem,
  RunItem,
  RunMessageOutputItem,
  RunReasoningItem,
  RunToolApprovalItem,
  RunToolCallItem,
  RunToolCallOutputItem,
} from './items';
export { AgentHooks } from './lifecycle';
export { getLogger } from './logger';
export {
  getAllMcpTools,
  invalidateServerToolsCache,
  MCPServer,
  MCPServerStdio,
  MCPServerStreamableHttp,
} from './mcp';
export {
  Model,
  ModelProvider,
  ModelRequest,
  ModelResponse,
  ModelSettings,
  ModelSettingsToolChoice,
  SerializedHandoff,
  SerializedTool,
  SerializedOutputType,
} from './model';
export { setDefaultModelProvider } from './providers';
export { RunResult, StreamedRunResult } from './result';
export {
  IndividualRunOptions,
  NonStreamRunOptions,
  run,
  RunConfig,
  Runner,
  StreamRunOptions,
} from './run';
export { RunContext } from './runContext';
export { RunState } from './runState';
export {
  HostedTool,
  ComputerTool,
  computerTool,
  HostedMCPTool,
  hostedMcpTool,
  FunctionTool,
  FunctionToolResult,
  Tool,
  tool,
  ToolExecuteArgument,
} from './tool';
export * from './tracing';
export { getGlobalTraceProvider, TraceProvider } from './tracing/provider';
/* only export the types not the parsers */
export type {
  AgentInputItem,
  AgentOutputItem,
  AssistantMessageItem,
  HostedToolCallItem,
  ComputerCallResultItem,
  ComputerUseCallItem,
  FunctionCallItem,
  FunctionCallResultItem,
  JsonSchemaDefinition,
  ReasoningItem,
  ResponseStreamEvent,
  SystemMessageItem,
  TextOutput,
  UnknownContext,
  UnknownItem,
  UserMessageItem,
  StreamEvent,
  StreamEventTextStream,
  StreamEventResponseCompleted,
  StreamEventResponseStarted,
  StreamEventGenericItem,
} from './types';
export { Usage } from './usage';

/**
 * Exporting the whole protocol as an object here. This contains both the types
 * and the zod schemas for parsing the protocol.
 */
export * as protocol from './types/protocol';

/**
 * Add the default processor, which exports traces and spans to the backend in batches. You can
 * change the default behavior by either:
 * 1. calling addTraceProcessor, which adds additional processors, or
 * 2. calling setTraceProcessors, which sets the processors and discards the default one
 */
addTraceProcessor(defaultProcessor());



---
File: /packages/agents-core/src/items.ts
---

import { Agent } from './agent';
import { toSmartString } from './utils/smartString';
import * as protocol from './types/protocol';

export class RunItemBase {
  public readonly type: string = 'base_item' as const;
  public rawItem?: protocol.ModelItem;

  toJSON() {
    return {
      type: this.type,
      rawItem: this.rawItem,
    };
  }
}

export class RunMessageOutputItem extends RunItemBase {
  public readonly type = 'message_output_item' as const;

  constructor(
    public rawItem: protocol.AssistantMessageItem,
    public agent: Agent,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
    };
  }

  get content(): string {
    let content = '';
    for (const part of this.rawItem.content) {
      if (part.type === 'output_text') {
        content += part.text;
      }
    }
    return content;
  }
}

export class RunToolCallItem extends RunItemBase {
  public readonly type = 'tool_call_item' as const;

  constructor(
    public rawItem: protocol.ToolCallItem,
    public agent: Agent,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
    };
  }
}

export class RunToolCallOutputItem extends RunItemBase {
  public readonly type = 'tool_call_output_item' as const;

  constructor(
    public rawItem:
      | protocol.FunctionCallResultItem
      | protocol.ComputerCallResultItem,
    public agent: Agent<any, any>,
    public output: string | unknown,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
      output: toSmartString(this.output),
    };
  }
}

export class RunReasoningItem extends RunItemBase {
  public readonly type = 'reasoning_item' as const;

  constructor(
    public rawItem: protocol.ReasoningItem,
    public agent: Agent,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
    };
  }
}

export class RunHandoffCallItem extends RunItemBase {
  public readonly type = 'handoff_call_item' as const;

  constructor(
    public rawItem: protocol.FunctionCallItem,
    public agent: Agent,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
    };
  }
}

export class RunHandoffOutputItem extends RunItemBase {
  public readonly type = 'handoff_output_item' as const;

  constructor(
    public rawItem: protocol.FunctionCallResultItem,
    public sourceAgent: Agent<any, any>,
    public targetAgent: Agent<any, any>,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      sourceAgent: this.sourceAgent.toJSON(),
      targetAgent: this.targetAgent.toJSON(),
    };
  }
}

export class RunToolApprovalItem extends RunItemBase {
  public readonly type = 'tool_approval_item' as const;

  constructor(
    public rawItem: protocol.FunctionCallItem | protocol.HostedToolCallItem,
    public agent: Agent<any, any>,
  ) {
    super();
  }

  toJSON() {
    return {
      ...super.toJSON(),
      agent: this.agent.toJSON(),
    };
  }
}

export type RunItem =
  | RunMessageOutputItem
  | RunToolCallItem
  | RunReasoningItem
  | RunHandoffCallItem
  | RunToolCallOutputItem
  | RunHandoffOutputItem
  | RunToolApprovalItem;

/**
 * Extract all text output from a list of run items by concatenating the content of all
 * message output items.
 *
 * @param items - The list of run items to extract text from.
 * @returns A string of all the text output from the run items.
 */
export function extractAllTextOutput(items: RunItem[]) {
  return items
    .filter((item) => item.type === 'message_output_item')
    .map((item) => item.content)
    .join('');
}



---
File: /packages/agents-core/src/lifecycle.ts
---

import { RunContext } from './runContext';
import type { Agent, AgentOutputType } from './agent';
import { Tool } from './tool';
import {
  RuntimeEventEmitter,
  EventEmitter,
  EventEmitterEvents,
} from '@openai/agents-core/_shims';
import { TextOutput, UnknownContext } from './types';
import * as protocol from './types/protocol';

export abstract class EventEmitterDelegate<
  EventTypes extends EventEmitterEvents = Record<string, any[]>,
> implements EventEmitter<EventTypes>
{
  protected abstract eventEmitter: EventEmitter<EventTypes>;

  on<K extends keyof EventTypes>(
    type: K,
    listener: (...args: EventTypes[K]) => void,
  ): EventEmitter<EventTypes> {
    this.eventEmitter.on(type, listener);
    return this.eventEmitter;
  }
  off<K extends keyof EventTypes>(
    type: K,
    listener: (...args: EventTypes[K]) => void,
  ): EventEmitter<EventTypes> {
    this.eventEmitter.off(type, listener);
    return this.eventEmitter;
  }
  emit<K extends keyof EventTypes>(type: K, ...args: EventTypes[K]): boolean {
    return this.eventEmitter.emit(type, ...args);
  }
  once<K extends keyof EventTypes>(
    type: K,
    listener: (...args: EventTypes[K]) => void,
  ): EventEmitter<EventTypes> {
    this.eventEmitter.once(type, listener);
    return this.eventEmitter;
  }
}

export type AgentHookEvents<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> = {
  /**
   * @param context - The context of the run
   */
  agent_start: [context: RunContext<TContext>, agent: Agent<TContext, TOutput>];
  /**
   * @param context - The context of the run
   * @param output - The output of the agent
   */
  agent_end: [context: RunContext<TContext>, output: string];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is handing off
   * @param nextAgent - The next agent to run
   */
  agent_handoff: [context: RunContext<TContext>, nextAgent: Agent<any, any>];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is starting a tool
   * @param tool - The tool that is starting
   */
  agent_tool_start: [
    context: RunContext<TContext>,
    tool: Tool<any>,
    details: { toolCall: protocol.ToolCallItem },
  ];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is ending a tool
   * @param tool - The tool that is ending
   * @param result - The result of the tool
   */
  agent_tool_end: [
    context: RunContext<TContext>,
    tool: Tool<any>,
    result: string,
    details: { toolCall: protocol.ToolCallItem },
  ];
};

/**
 * Event emitter that every Agent instance inherits from and that emits events for the lifecycle
 * of the agent.
 */
export class AgentHooks<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> extends EventEmitterDelegate<AgentHookEvents<TContext, TOutput>> {
  protected eventEmitter = new RuntimeEventEmitter<
    AgentHookEvents<TContext, TOutput>
  >();
}

export type RunHookEvents<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> = {
  /**
   * @param context - The context of the run
   * @param agent - The agent that is starting
   */
  agent_start: [context: RunContext<TContext>, agent: Agent<TContext, TOutput>];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is ending
   * @param output - The output of the agent
   */
  agent_end: [
    context: RunContext<TContext>,
    agent: Agent<TContext, TOutput>,
    output: string,
  ];
  /**
   * @param context - The context of the run
   * @param fromAgent - The agent that is handing off
   * @param toAgent - The next agent to run
   */
  agent_handoff: [
    context: RunContext<TContext>,
    fromAgent: Agent<any, any>,
    toAgent: Agent<any, any>,
  ];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is starting a tool
   * @param tool - The tool that is starting
   */
  agent_tool_start: [
    context: RunContext<TContext>,
    agent: Agent<TContext, TOutput>,
    tool: Tool,
    details: { toolCall: protocol.ToolCallItem },
  ];
  /**
   * @param context - The context of the run
   * @param agent - The agent that is ending a tool
   * @param tool - The tool that is ending
   * @param result - The result of the tool
   */
  agent_tool_end: [
    context: RunContext<TContext>,
    agent: Agent<TContext, TOutput>,
    tool: Tool,
    result: string,
    details: { toolCall: protocol.ToolCallItem },
  ];
};

/**
 * Event emitter that every Runner instance inherits from and that emits events for the lifecycle
 * of the overall run.
 */
export class RunHooks<
  TContext = UnknownContext,
  TOutput extends AgentOutputType = TextOutput,
> extends EventEmitterDelegate<RunHookEvents<TContext, TOutput>> {
  protected eventEmitter = new RuntimeEventEmitter<
    RunHookEvents<TContext, TOutput>
  >();
}



---
File: /packages/agents-core/src/logger.ts
---

import debug from 'debug';
import { logging } from './config';

/**
 * By default we don't log LLM inputs/outputs, to prevent exposing sensitive data. Set this flag
 * to enable logging them.
 */
const dontLogModelData = logging.dontLogModelData;

/**
 * By default we don't log tool inputs/outputs, to prevent exposing sensitive data. Set this flag
 * to enable logging them.
 */
const dontLogToolData = logging.dontLogToolData;

/**
 * A logger instance with debug, error, warn, and dontLogModelData and dontLogToolData methods.
 */
export type Logger = {
  /**
   * The namespace used for the debug logger.
   */
  namespace: string;

  /**
   * Log a debug message when debug logging is enabled.
   * @param message - The message to log.
   * @param args - The arguments to log.
   */
  debug: (message: string, ...args: any[]) => void;
  /**
   * Log an error message.
   * @param message - The message to log.
   * @param args - The arguments to log.
   */
  error: (message: string, ...args: any[]) => void;
  /**
   * Log a warning message.
   * @param message - The message to log.
   * @param args - The arguments to log.
   */
  warn: (message: string, ...args: any[]) => void;
  /**
   * Whether to log model data.
   */
  dontLogModelData: boolean;
  /**
   * Whether to log tool data.
   */
  dontLogToolData: boolean;
};

/**
 * Get a logger for a given package.
 *
 * @param namespace - the namespace to use for the logger.
 * @returns A logger object with `debug` and `error` methods.
 */
export function getLogger(namespace: string = 'openai-agents'): Logger {
  return {
    namespace,
    debug: debug(namespace),
    error: console.error,
    warn: console.warn,
    dontLogModelData,
    dontLogToolData,
  };
}

export const logger = getLogger('openai-agents:core');

export default logger;



---
File: /packages/agents-core/src/mcp.ts
---

import { FunctionTool, tool, Tool } from './tool';
import { UserError } from './errors';
import {
  MCPServerStdio as UnderlyingMCPServerStdio,
  MCPServerStreamableHttp as UnderlyingMCPServerStreamableHttp,
} from '@openai/agents-core/_shims';
import { getCurrentSpan, withMCPListToolsSpan } from './tracing';
import { logger as globalLogger, getLogger, Logger } from './logger';
import debug from 'debug';
import { z } from '@openai/zod/v3';
import {
  JsonObjectSchema,
  JsonObjectSchemaNonStrict,
  JsonObjectSchemaStrict,
  UnknownContext,
} from './types';

export const DEFAULT_STDIO_MCP_CLIENT_LOGGER_NAME =
  'openai-agents:stdio-mcp-client';

export const DEFAULT_STREAMABLE_HTTP_MCP_CLIENT_LOGGER_NAME =
  'openai-agents:streamable-http-mcp-client';

/**
 * Interface for MCP server implementations.
 * Provides methods for connecting, listing tools, calling tools, and cleanup.
 */
export interface MCPServer {
  cacheToolsList: boolean;
  connect(): Promise<void>;
  readonly name: string;
  close(): Promise<void>;
  listTools(): Promise<MCPTool[]>;
  callTool(
    toolName: string,
    args: Record<string, unknown> | null,
  ): Promise<CallToolResultContent>;
  invalidateToolsCache(): Promise<void>;
}

export abstract class BaseMCPServerStdio implements MCPServer {
  public cacheToolsList: boolean;
  protected _cachedTools: any[] | undefined = undefined;

  protected logger: Logger;
  constructor(options: MCPServerStdioOptions) {
    this.logger =
      options.logger ?? getLogger(DEFAULT_STDIO_MCP_CLIENT_LOGGER_NAME);
    this.cacheToolsList = options.cacheToolsList ?? false;
  }

  abstract get name(): string;
  abstract connect(): Promise<void>;
  abstract close(): Promise<void>;
  abstract listTools(): Promise<any[]>;
  abstract callTool(
    _toolName: string,
    _args: Record<string, unknown> | null,
  ): Promise<CallToolResultContent>;
  abstract invalidateToolsCache(): Promise<void>;

  /**
   * Logs a debug message when debug logging is enabled.
   * @param buildMessage A function that returns the message to log.
   */
  protected debugLog(buildMessage: () => string): void {
    if (debug.enabled(this.logger.namespace)) {
      // only when this is true, the function to build the string is called
      this.logger.debug(buildMessage());
    }
  }
}

export abstract class BaseMCPServerStreamableHttp implements MCPServer {
  public cacheToolsList: boolean;
  protected _cachedTools: any[] | undefined = undefined;

  protected logger: Logger;
  constructor(options: MCPServerStreamableHttpOptions) {
    this.logger =
      options.logger ??
      getLogger(DEFAULT_STREAMABLE_HTTP_MCP_CLIENT_LOGGER_NAME);
    this.cacheToolsList = options.cacheToolsList ?? false;
  }

  abstract get name(): string;
  abstract connect(): Promise<void>;
  abstract close(): Promise<void>;
  abstract listTools(): Promise<any[]>;
  abstract callTool(
    _toolName: string,
    _args: Record<string, unknown> | null,
  ): Promise<CallToolResultContent>;
  abstract invalidateToolsCache(): Promise<void>;

  /**
   * Logs a debug message when debug logging is enabled.
   * @param buildMessage A function that returns the message to log.
   */
  protected debugLog(buildMessage: () => string): void {
    if (debug.enabled(this.logger.namespace)) {
      // only when this is true, the function to build the string is called
      this.logger.debug(buildMessage());
    }
  }
}

/**
 * Minimum MCP tool data definition.
 * This type definition does not intend to cover all possible properties.
 * It supports the properties that are used in this SDK.
 */
export const MCPTool = z.object({
  name: z.string(),
  description: z.string().optional(),
  inputSchema: z.object({
    type: z.literal('object'),
    properties: z.record(z.string(), z.any()),
    required: z.array(z.string()),
    additionalProperties: z.boolean(),
  }),
});
export type MCPTool = z.infer<typeof MCPTool>;

/**
 * Public interface of an MCP server that provides tools.
 * You can use this class to pass MCP server settings to your agent.
 */
export class MCPServerStdio extends BaseMCPServerStdio {
  private underlying: UnderlyingMCPServerStdio;
  constructor(options: MCPServerStdioOptions) {
    super(options);
    this.underlying = new UnderlyingMCPServerStdio(options);
  }
  get name(): string {
    return this.underlying.name;
  }
  connect(): Promise<void> {
    return this.underlying.connect();
  }
  close(): Promise<void> {
    return this.underlying.close();
  }
  async listTools(): Promise<MCPTool[]> {
    if (this.cacheToolsList && this._cachedTools) {
      return this._cachedTools;
    }
    const tools = await this.underlying.listTools();
    if (this.cacheToolsList) {
      this._cachedTools = tools;
    }
    return tools;
  }
  callTool(
    toolName: string,
    args: Record<string, unknown> | null,
  ): Promise<CallToolResultContent> {
    return this.underlying.callTool(toolName, args);
  }
  invalidateToolsCache(): Promise<void> {
    return this.underlying.invalidateToolsCache();
  }
}

export class MCPServerStreamableHttp extends BaseMCPServerStreamableHttp {
  private underlying: UnderlyingMCPServerStreamableHttp;
  constructor(options: MCPServerStreamableHttpOptions) {
    super(options);
    this.underlying = new UnderlyingMCPServerStreamableHttp(options);
  }
  get name(): string {
    return this.underlying.name;
  }
  connect(): Promise<void> {
    return this.underlying.connect();
  }
  close(): Promise<void> {
    return this.underlying.close();
  }
  async listTools(): Promise<MCPTool[]> {
    if (this.cacheToolsList && this._cachedTools) {
      return this._cachedTools;
    }
    const tools = await this.underlying.listTools();
    if (this.cacheToolsList) {
      this._cachedTools = tools;
    }
    return tools;
  }
  callTool(
    toolName: string,
    args: Record<string, unknown> | null,
  ): Promise<CallToolResultContent> {
    return this.underlying.callTool(toolName, args);
  }
  invalidateToolsCache(): Promise<void> {
    return this.underlying.invalidateToolsCache();
  }
}

/**
 * Fetches and flattens all tools from multiple MCP servers.
 * Logs and skips any servers that fail to respond.
 */
export async function getAllMcpFunctionTools<TContext = UnknownContext>(
  mcpServers: MCPServer[],
  convertSchemasToStrict = false,
): Promise<Tool<TContext>[]> {
  const allTools: Tool<TContext>[] = [];
  const toolNames = new Set<string>();
  for (const server of mcpServers) {
    const serverTools = await getFunctionToolsFromServer(
      server,
      convertSchemasToStrict,
    );
    const serverToolNames = new Set(serverTools.map((t) => t.name));
    const intersection = [...serverToolNames].filter((n) => toolNames.has(n));
    if (intersection.length > 0) {
      throw new UserError(
        `Duplicate tool names found across MCP servers: ${intersection.join(', ')}`,
      );
    }
    for (const t of serverTools) {
      toolNames.add(t.name);
      allTools.push(t);
    }
  }
  return allTools;
}

const _cachedTools: Record<string, MCPTool[]> = {};
/**
 * Remove cached tools for the given server so the next lookup fetches fresh data.
 *
 * @param serverName - Name of the MCP server whose cache should be cleared.
 */
export async function invalidateServerToolsCache(serverName: string) {
  delete _cachedTools[serverName];
}
/**
 * Fetches all function tools from a single MCP server.
 */
async function getFunctionToolsFromServer<TContext = UnknownContext>(
  server: MCPServer,
  convertSchemasToStrict: boolean,
): Promise<FunctionTool<TContext, any, unknown>[]> {
  if (server.cacheToolsList && _cachedTools[server.name]) {
    return _cachedTools[server.name].map((t) =>
      mcpToFunctionTool(t, server, convertSchemasToStrict),
    );
  }
  return withMCPListToolsSpan(
    async (span) => {
      const mcpTools = await server.listTools();
      span.spanData.result = mcpTools.map((t) => t.name);
      const tools: FunctionTool<TContext, any, string>[] = mcpTools.map((t) =>
        mcpToFunctionTool(t, server, convertSchemasToStrict),
      );
      if (server.cacheToolsList) {
        _cachedTools[server.name] = mcpTools;
      }
      return tools;
    },
    { data: { server: server.name } },
  );
}

/**
 * Returns all MCP tools from the provided servers, using the function tool conversion.
 */
export async function getAllMcpTools<TContext = UnknownContext>(
  mcpServers: MCPServer[],
  convertSchemasToStrict = false,
): Promise<Tool<TContext>[]> {
  return getAllMcpFunctionTools(mcpServers, convertSchemasToStrict);
}

/**
 * Converts an MCP tool definition to a function tool for the Agents SDK.
 */
export function mcpToFunctionTool(
  mcpTool: MCPTool,
  server: MCPServer,
  convertSchemasToStrict: boolean,
) {
  async function invoke(input: any, _context: UnknownContext) {
    let args = {};
    if (typeof input === 'string' && input) {
      args = JSON.parse(input);
    } else if (typeof input === 'object' && input != null) {
      args = input;
    }
    const currentSpan = getCurrentSpan();
    if (currentSpan) {
      currentSpan.spanData['mcp_data'] = { server: server.name };
    }
    const content = await server.callTool(mcpTool.name, args);
    return content.length === 1 ? content[0] : content;
  }

  const schema: JsonObjectSchema<any> = {
    ...mcpTool.inputSchema,
    type: mcpTool.inputSchema?.type ?? 'object',
    properties: mcpTool.inputSchema?.properties ?? {},
    required: mcpTool.inputSchema?.required ?? [],
    additionalProperties: mcpTool.inputSchema?.additionalProperties ?? false,
  };

  if (convertSchemasToStrict || schema.additionalProperties === true) {
    try {
      const strictSchema = ensureStrictJsonSchema(schema);
      return tool({
        name: mcpTool.name,
        description: mcpTool.description || '',
        parameters: strictSchema,
        strict: true,
        execute: invoke,
      });
    } catch (e) {
      globalLogger.warn(`Error converting MCP schema to strict mode: ${e}`);
    }
  }

  const nonStrictSchema: JsonObjectSchemaNonStrict<any> = {
    ...schema,
    additionalProperties: true,
  };
  return tool({
    name: mcpTool.name,
    description: mcpTool.description || '',
    parameters: nonStrictSchema,
    strict: false,
    execute: invoke,
  });
}

/**
 * Ensures the given JSON schema is strict (no additional properties, required fields set).
 */
function ensureStrictJsonSchema(
  schema: JsonObjectSchemaNonStrict<any> | JsonObjectSchemaStrict<any>,
): JsonObjectSchemaStrict<any> {
  const out: JsonObjectSchemaStrict<any> = {
    ...schema,
    additionalProperties: false,
  };
  if (!out.required) out.required = [];
  return out;
}

/**
 * Abstract base class for MCP servers that use a ClientSession for communication.
 * Handles session management, tool listing, tool calling, and cleanup.
 */

// Params for stdio-based MCP server
export interface BaseMCPServerStdioOptions {
  env?: Record<string, string>;
  cwd?: string;
  cacheToolsList?: boolean;
  clientSessionTimeoutSeconds?: number;
  name?: string;
  encoding?: string;
  encodingErrorHandler?: 'strict' | 'ignore' | 'replace';
  logger?: Logger;
}
export interface DefaultMCPServerStdioOptions
  extends BaseMCPServerStdioOptions {
  command: string;
  args?: string[];
}
export interface FullCommandMCPServerStdioOptions
  extends BaseMCPServerStdioOptions {
  fullCommand: string;
}
export type MCPServerStdioOptions =
  | DefaultMCPServerStdioOptions
  | FullCommandMCPServerStdioOptions;

export interface MCPServerStreamableHttpOptions {
  url: string;
  cacheToolsList?: boolean;
  clientSessionTimeoutSeconds?: number;
  name?: string;
  logger?: Logger;

  // ----------------------------------------------------
  // OAuth
  // import { OAuthClientProvider } from '@modelcontextprotocol/sdk/client/auth.js';
  authProvider?: any;
  // RequestInit
  requestInit?: any;
  // import { StreamableHTTPReconnectionOptions } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
  reconnectionOptions?: any;
  sessionId?: string;
  // ----------------------------------------------------
}

/**
 * Represents a JSON-RPC request message.
 */
export interface JsonRpcRequest {
  jsonrpc: '2.0';
  id: number;
  method: string;
  params?: Record<string, unknown>;
}

/**
 * Represents a JSON-RPC notification message (no response expected).
 */
export interface JsonRpcNotification {
  jsonrpc: '2.0';
  method: string;
  params?: Record<string, unknown>;
}

/**
 * Represents a JSON-RPC response message.
 */
export interface JsonRpcResponse {
  jsonrpc: '2.0';
  id: number;
  result?: any;
  error?: any;
}

export interface CallToolResponse extends JsonRpcResponse {
  result: {
    content: { type: string; text: string }[];
  };
}
export type CallToolResult = CallToolResponse['result'];
export type CallToolResultContent = CallToolResult['content'];

export interface InitializeResponse extends JsonRpcResponse {
  result: {
    protocolVersion: string;
    capabilities: {
      tools: Record<string, unknown>;
    };
    serverInfo: {
      name: string;
      version: string;
    };
  };
}
export type InitializeResult = InitializeResponse['result'];



---
File: /packages/agents-core/src/metadata.ts
---


// This file is automatically generated

export const METADATA = {
  "name": "@openai/agents-core",
  "version": "0.0.13",
  "versions": {
    "@openai/agents-core": "0.0.13",
    "@openai/zod": "npm:zod@3.25.40 - 3.25.67",
    "openai": "^5.10.1"
  }
};

export default METADATA;



---
File: /packages/agents-core/src/model.ts
---

import { Usage } from './usage';
import { StreamEvent } from './types/protocol';
import { HostedTool, ComputerTool, FunctionTool } from './tool';
import { Handoff } from './handoff';
import {
  AgentInputItem,
  AgentOutputItem,
  JsonSchemaDefinition,
  TextOutput,
  InputText,
  InputImage,
  InputFile,
} from './types';

export type ModelSettingsToolChoice =
  | 'auto'
  | 'required'
  | 'none'
  | (string & {});

/**
 * Settings to use when calling an LLM.
 *
 * This class holds optional model configuration parameters (e.g. temperature,
 * topP, penalties, truncation, etc.).
 *
 * Not all models/providers support all of these parameters, so please check the API documentation
 * for the specific model and provider you are using.
 */
export type ModelSettings = {
  /**
   * The temperature to use when calling the model.
   */
  temperature?: number;

  /**
   * The topP to use when calling the model.
   */
  topP?: number;

  /**
   * The frequency penalty to use when calling the model.
   */
  frequencyPenalty?: number;

  /**
   * The presence penalty to use when calling the model.
   */
  presencePenalty?: number;

  /**
   * The tool choice to use when calling the model.
   */
  toolChoice?: ModelSettingsToolChoice;

  /**
   * Whether to use parallel tool calls when calling the model.
   * Defaults to false if not provided.
   */
  parallelToolCalls?: boolean;

  /**
   * The truncation strategy to use when calling the model.
   */
  truncation?: 'auto' | 'disabled';

  /**
   * The maximum number of output tokens to generate.
   */
  maxTokens?: number;

  /**
   * Whether to store the generated model response for later retrieval.
   * Defaults to true if not provided.
   */
  store?: boolean;

  /**
   * Additional provider specific settings to be passed directly to the model
   * request.
   */
  providerData?: Record<string, any>;
};

export type ModelTracing = boolean | 'enabled_without_data';

export type SerializedFunctionTool = {
  /**
   * The type of the tool.
   */
  type: FunctionTool['type'];

  /**
   * The name of the tool.
   */
  name: FunctionTool['name'];

  /**
   * The description of the tool that helps the model to understand when to use the tool
   */
  description: FunctionTool['description'];

  /**
   * A JSON schema describing the parameters of the tool.
   */
  parameters: FunctionTool['parameters'];

  /**
   * Whether the tool is strict. If true, the model must try to strictly follow the schema
   * (might result in slower response times).
   */
  strict: FunctionTool['strict'];
};

export type SerializedComputerTool = {
  type: ComputerTool['type'];
  name: ComputerTool['name'];
  environment: ComputerTool['computer']['environment'];
  dimensions: ComputerTool['computer']['dimensions'];
};

export type SerializedHostedTool = {
  type: HostedTool['type'];
  name: HostedTool['name'];
  providerData?: HostedTool['providerData'];
};

export type SerializedTool =
  | SerializedFunctionTool
  | SerializedComputerTool
  | SerializedHostedTool;

export type SerializedHandoff = {
  /**
   * The name of the tool that represents the handoff.
   */
  toolName: Handoff['toolName'];

  /**
   * The tool description for the handoff
   */
  toolDescription: Handoff['toolDescription'];

  /**
   * The JSON schema for the handoff input. Can be empty if the handoff does not take an input
   */
  inputJsonSchema: Handoff['inputJsonSchema'];

  /**
   * Whether the input JSON schema is in strict mode. We strongly recommend setting this to true,
   * as it increases the likelihood of correct JSON input.
   */
  strictJsonSchema: Handoff['strictJsonSchema'];
};

/**
 * The output type passed to the model. Has any Zod types serialized to JSON Schema
 */
export type SerializedOutputType = JsonSchemaDefinition | TextOutput;

/**
 * A request to a large language model.
 */
export type ModelRequest = {
  /**
   * The system instructions to use for the model.
   */
  systemInstructions?: string;

  /**
   * The input to the model.
   */
  input: string | AgentInputItem[];

  /**
   * The ID of the previous response to use for the model.
   */
  previousResponseId?: string;

  /**
   * The model settings to use for the model.
   */
  modelSettings: ModelSettings;

  /**
   * The tools to use for the model.
   */
  tools: SerializedTool[];

  /**
   * The type of the output to use for the model.
   */
  outputType: SerializedOutputType;

  /**
   * The handoffs to use for the model.
   */
  handoffs: SerializedHandoff[];

  /**
   * Whether to enable tracing for the model.
   */
  tracing: ModelTracing;

  /**
   * An optional signal to abort the model request.
   */
  signal?: AbortSignal;

  /**
   * The prompt template to use for the model, if any.
   */
  prompt?: Prompt;
};

export type ModelResponse = {
  /**
   * The usage information for response.
   */
  usage: Usage;

  /**
   * A list of outputs (messages, tool calls, etc.) generated by the model.
   */
  output: AgentOutputItem[];

  /**
   * An ID for the response which can be used to refer to the response in subsequent calls to the
   * model. Not supported by all model providers.
   */
  responseId?: string;

  /**
   * Raw response data from the underlying model provider.
   */
  providerData?: Record<string, any>;
};

/**
 * The base interface for calling an LLM.
 */
export interface Model {
  /**
   * Get a response from the model.
   *
   * @param request - The request to get a response for.
   */
  getResponse(request: ModelRequest): Promise<ModelResponse>;

  /**
   * Get a streamed response from the model.
   *
   */
  getStreamedResponse(request: ModelRequest): AsyncIterable<StreamEvent>;
}

/**
 * The base interface for a model provider.
 *
 * The model provider is responsible for looking up `Model` instances by name.
 */
export interface ModelProvider {
  /**
   * Get a model by name
   *
   * @param modelName - The name of the model to get.
   */
  getModel(modelName?: string): Promise<Model> | Model;
}

/**
 * Reference to a prompt template and its variables.
 */
export type Prompt = {
  /**
   * The unique identifier of the prompt template to use.
   */
  promptId: string;
  /**
   * Optional version of the prompt template.
   */
  version?: string;
  /**
   * Optional variables to substitute into the prompt template.
   * Can be a string, or an object with string keys and values that are string,
   * InputText, InputImage, or InputFile.
   */
  variables?: {
    [key: string]: string | InputText | InputImage | InputFile;
  };
};



---
File: /packages/agents-core/src/providers.ts
---

import { ModelProvider } from './model';

let DEFAULT_PROVIDER: ModelProvider | undefined;

/**
 * Set the model provider used when no explicit provider is supplied.
 *
 * @param provider - The provider to use by default.
 */
export function setDefaultModelProvider(provider: ModelProvider) {
  DEFAULT_PROVIDER = provider;
}

/**
 * Returns the default model provider.
 *
 * @returns The default model provider.
 */
export function getDefaultModelProvider(): ModelProvider {
  if (typeof DEFAULT_PROVIDER === 'undefined') {
    throw new Error(
      'No default model provider set. Make sure to set a provider using setDefaultModelProvider before calling getDefaultModelProvider or pass an explicit provider.',
    );
  }
  return DEFAULT_PROVIDER;
}



---
File: /packages/agents-core/src/result.ts
---

import { Agent, AgentOutputType } from './agent';
import { Handoff } from './handoff';
import {
  ResolvedAgentOutput,
  HandoffsOutput,
  AgentInputItem,
  AgentOutputItem,
} from './types';
import { RunItem, RunToolApprovalItem } from './items';
import { ModelResponse } from './model';
import {
  ReadableStreamController,
  ReadableStream as _ReadableStream,
  TransformStream,
  Readable,
} from '@openai/agents-core/_shims';
import { ReadableStream } from './shims/interface';
import { RunStreamEvent } from './events';
import { getTurnInput } from './run';
import { RunState } from './runState';
import type { InputGuardrailResult, OutputGuardrailResult } from './guardrail';
import logger from './logger';
import { StreamEventTextStream } from './types/protocol';

/**
 * Data returned by the run() method of an agent.
 */
export interface RunResultData<
  TAgent extends Agent<any, any>,
  THandoffs extends (Agent<any, any> | Handoff<any>)[] = any[],
> {
  /**
   * The original input items i.e. the items before run() was called. This may be mutated version
   * of the input, if there are handoff input filters that mutate the input.
   */
  input: string | AgentInputItem[];

  /**
   * The new items generated during the agent run. These include things like new messages, tool
   * calls and their outputs, etc.
   */
  newItems: RunItem[];

  /**
   * The raw LLM responses generated by the model during the agent run.
   */
  rawResponses: ModelResponse[];

  /**
   * The last response ID generated by the model during the agent run.
   */
  lastResponseId: string | undefined;

  /**
   * The last agent that was run
   */
  lastAgent: TAgent | undefined;

  /**
   * Guardrail results for the input messages.
   */
  inputGuardrailResults: InputGuardrailResult[];

  /**
   * Guardrail results for the final output of the agent.
   */
  outputGuardrailResults: OutputGuardrailResult[];

  /**
   * The output of the last agent, or any handoff agent.
   */
  finalOutput?:
    | ResolvedAgentOutput<TAgent['outputType']>
    | HandoffsOutput<THandoffs>;

  /**
   * The interruptions that occurred during the agent run.
   */
  interruptions?: RunToolApprovalItem[];

  /**
   * The state of the run.
   */
  state: RunState<any, TAgent>;
}

class RunResultBase<TContext, TAgent extends Agent<TContext, any>>
  implements RunResultData<TAgent>
{
  readonly state: RunState<TContext, TAgent>;

  constructor(state: RunState<TContext, TAgent>) {
    this.state = state;
  }

  /**
   * The history of the agent run. This includes the input items and the new items generated during
   * the agent run.
   *
   * This can be used as inputs for the next agent run.
   */
  get history(): AgentInputItem[] {
    return getTurnInput(this.input, this.newItems);
  }

  /**
   * The new items generated during the agent run. These include things like new messages, tool
   * calls and their outputs, etc.
   *
   * It does not include information about the agents and instead represents the model data.
   *
   * For the output including the agents, use the `newItems` property.
   */
  get output(): AgentOutputItem[] {
    return getTurnInput([], this.newItems);
  }

  /**
   * A copy of the original input items.
   */
  get input(): string | AgentInputItem[] {
    return this.state._originalInput;
  }

  /**
   * The run items generated during the agent run. This associates the model data with the agents.
   *
   * For the model data that can be used as inputs for the next agent run, use the `output` property.
   */
  get newItems(): RunItem[] {
    return this.state._generatedItems;
  }

  /**
   * The raw LLM responses generated by the model during the agent run.
   */
  get rawResponses(): ModelResponse[] {
    return this.state._modelResponses;
  }

  /**
   * The last response ID generated by the model during the agent run.
   */
  get lastResponseId(): string | undefined {
    const responses = this.rawResponses;
    return responses && responses.length > 0
      ? responses[responses.length - 1].responseId
      : undefined;
  }

  /**
   * The last agent that was run
   */
  get lastAgent(): TAgent | undefined {
    return this.state._currentAgent;
  }

  /**
   * Guardrail results for the input messages.
   */
  get inputGuardrailResults(): InputGuardrailResult[] {
    return this.state._inputGuardrailResults;
  }

  /**
   * Guardrail results for the final output of the agent.
   */
  get outputGuardrailResults(): OutputGuardrailResult[] {
    return this.state._outputGuardrailResults;
  }

  /**
   * Any interruptions that occurred during the agent run for example for tool approvals.
   */
  get interruptions(): RunToolApprovalItem[] {
    if (this.state._currentStep?.type === 'next_step_interruption') {
      return this.state._currentStep.data.interruptions;
    }

    return [];
  }

  /**
   * The final output of the agent. If the output type was set to anything other than `text`,
   * this will be parsed either as JSON or using the Zod schema you provided.
   */
  get finalOutput(): ResolvedAgentOutput<TAgent['outputType']> | undefined {
    if (this.state._currentStep?.type === 'next_step_final_output') {
      return this.state._currentAgent.processFinalOutput(
        this.state._currentStep.output,
      ) as ResolvedAgentOutput<TAgent['outputType']>;
    }

    logger.warn('Accessed finalOutput before agent run is completed.');
    return undefined;
  }
}

/**
 * The result of an agent run.
 */
export class RunResult<
  TContext,
  TAgent extends Agent<TContext, AgentOutputType>,
> extends RunResultBase<TContext, TAgent> {
  constructor(state: RunState<TContext, TAgent>) {
    super(state);
  }
}

/**
 * The result of an agent run in streaming mode.
 */
export class StreamedRunResult<
    TContext,
    TAgent extends Agent<TContext, AgentOutputType>,
  >
  extends RunResultBase<TContext, TAgent>
  implements AsyncIterable<RunStreamEvent>
{
  /**
   * The current agent that is running
   */
  public get currentAgent(): TAgent | undefined {
    return this.lastAgent;
  }

  /**
   * The current turn number
   */
  public currentTurn: number = 0;

  /**
   * The maximum number of turns that can be run
   */
  public maxTurns: number | undefined;

  #error: unknown = null;
  #signal?: AbortSignal;
  #readableController: ReadableStreamController<RunStreamEvent> | undefined;
  #readableStream: _ReadableStream<RunStreamEvent>;
  #completedPromise: Promise<void>;
  #completedPromiseResolve: (() => void) | undefined;
  #completedPromiseReject: ((err: unknown) => void) | undefined;
  #cancelled: boolean = false;

  constructor(
    result: {
      state: RunState<TContext, TAgent>;
      signal?: AbortSignal;
    } = {} as any,
  ) {
    super(result.state);

    this.#signal = result.signal;

    if (this.#signal) {
      this.#signal.addEventListener('abort', async () => {
        await this.#readableStream.cancel();
      });
    }

    this.#readableStream = new _ReadableStream<RunStreamEvent>({
      start: (controller) => {
        this.#readableController = controller;
      },
      cancel: () => {
        this.#cancelled = true;
      },
    });

    this.#completedPromise = new Promise((resolve, reject) => {
      this.#completedPromiseResolve = resolve;
      this.#completedPromiseReject = reject;
    });
  }

  /**
   * @internal
   * Adds an item to the stream of output items
   */
  _addItem(item: RunStreamEvent) {
    if (!this.cancelled) {
      this.#readableController?.enqueue(item);
    }
  }

  /**
   * @internal
   * Indicates that the stream has been completed
   */
  _done() {
    if (!this.cancelled && this.#readableController) {
      this.#readableController.close();
      this.#readableController = undefined;
      this.#completedPromiseResolve?.();
    }
  }

  /**
   * @internal
   * Handles an error in the stream loop.
   */
  _raiseError(err: unknown) {
    if (!this.cancelled && this.#readableController) {
      this.#readableController.error(err);
      this.#readableController = undefined;
    }
    this.#error = err;
    this.#completedPromiseReject?.(err);
    this.#completedPromise.catch((e) => {
      logger.debug(`Resulted in an error: ${e}`);
    });
  }

  /**
   * Returns true if the stream has been cancelled.
   */
  get cancelled(): boolean {
    return this.#cancelled;
  }

  /**
   * Returns the underlying readable stream.
   * @returns A readable stream of the agent run.
   */
  toStream(): ReadableStream<RunStreamEvent> {
    return this.#readableStream as ReadableStream<RunStreamEvent>;
  }

  /**
   * Await this promise to ensure that the stream has been completed if you are not consuming the
   * stream directly.
   */
  get completed() {
    return this.#completedPromise;
  }

  /**
   * Error thrown during the run, if any.
   */
  get error() {
    return this.#error;
  }

  /**
   * Returns a readable stream of the final text output of the agent run.
   *
   * @param options - Options for the stream.
   * @param options.compatibleWithNodeStreams - Whether to use Node.js streams or web standard streams.
   * @returns A readable stream of the final output of the agent run.
   */
  toTextStream(): ReadableStream<string>;
  toTextStream(options?: { compatibleWithNodeStreams: true }): Readable;
  toTextStream(options?: {
    compatibleWithNodeStreams?: false;
  }): ReadableStream<string>;
  toTextStream(
    options: { compatibleWithNodeStreams?: boolean } = {},
  ): Readable | ReadableStream<string> {
    const stream = this.#readableStream.pipeThrough(
      new TransformStream<RunStreamEvent, string>({
        transform(event, controller) {
          if (
            event.type === 'raw_model_stream_event' &&
            event.data.type === 'output_text_delta'
          ) {
            const item = StreamEventTextStream.parse(event.data);
            controller.enqueue(item.delta);
          }
        },
      }),
    );

    if (options.compatibleWithNodeStreams) {
      return Readable.fromWeb(stream);
    }

    return stream as ReadableStream<string>;
  }

  [Symbol.asyncIterator](): AsyncIterator<RunStreamEvent> {
    return this.#readableStream[Symbol.asyncIterator]();
  }
}



---
File: /packages/agents-core/src/run.ts
---

import { Agent, AgentOutputType } from './agent';
import {
  defineInputGuardrail,
  defineOutputGuardrail,
  InputGuardrail,
  InputGuardrailDefinition,
  OutputGuardrail,
  OutputGuardrailDefinition,
  OutputGuardrailFunctionArgs,
  OutputGuardrailMetadata,
} from './guardrail';
import { getHandoff, Handoff, HandoffInputFilter } from './handoff';
import {
  Model,
  ModelProvider,
  ModelResponse,
  ModelSettings,
  ModelTracing,
} from './model';
import { getDefaultModelProvider } from './providers';
import { RunContext } from './runContext';
import { AgentInputItem } from './types';
import { RunResult, StreamedRunResult } from './result';
import { RunHooks } from './lifecycle';
import logger from './logger';
import { serializeTool, serializeHandoff } from './utils/serialize';
import {
  GuardrailExecutionError,
  InputGuardrailTripwireTriggered,
  MaxTurnsExceededError,
  ModelBehaviorError,
  OutputGuardrailTripwireTriggered,
  UserError,
} from './errors';
import {
  addStepToRunResult,
  executeInterruptedToolsAndSideEffects,
  executeToolsAndSideEffects,
  maybeResetToolChoice,
  ProcessedResponse,
  processModelResponse,
} from './runImplementation';
import { RunItem } from './items';
import {
  getOrCreateTrace,
  resetCurrentSpan,
  setCurrentSpan,
  withNewSpanContext,
  withTrace,
} from './tracing/context';
import { createAgentSpan, withGuardrailSpan } from './tracing';
import { Usage } from './usage';
import { RunAgentUpdatedStreamEvent, RunRawModelStreamEvent } from './events';
import { RunState } from './runState';
import { StreamEventResponseCompleted } from './types/protocol';
import { convertAgentOutputTypeToSerializable } from './utils/tools';

const DEFAULT_MAX_TURNS = 10;

/**
 * Configures settings for the entire agent run.
 */
export type RunConfig = {
  /**
   * The model to use for the entire agent run. If set, will override the model set on every
   * agent. The modelProvider passed in below must be able to resolve this model name.
   */
  model?: string | Model;

  /**
   * The model provider to use when looking up string model names. Defaults to OpenAI.
   */
  modelProvider: ModelProvider;

  /**
   * Configure global model settings. Any non-null values will override the agent-specific model
   * settings.
   */
  modelSettings?: ModelSettings;

  /**
   * A global input filter to apply to all handoffs. If `Handoff.inputFilter` is set, then that
   * will take precedence. The input filter allows you to edit the inputs that are sent to the new
   * agent. See the documentation in `Handoff.inputFilter` for more details.
   */
  handoffInputFilter?: HandoffInputFilter;

  /**
   * A list of input guardrails to run on the initial run input.
   */
  inputGuardrails?: InputGuardrail[];

  /**
   * A list of output guardrails to run on the final output of the run.
   */
  outputGuardrails?: OutputGuardrail<AgentOutputType<unknown>>[];

  /**
   * Whether tracing is disabled for the agent run. If disabled, we will not trace the agent run.
   */
  tracingDisabled: boolean;

  /**
   * Whether we include potentially sensitive data (for example: inputs/outputs of tool calls or
   * LLM generations) in traces. If false, we'll still create spans for these events, but the
   * sensitive data will not be included.
   */
  traceIncludeSensitiveData: boolean;

  /**
   * The name of the run, used for tracing. Should be a logical name for the run, like
   * "Code generation workflow" or "Customer support agent".
   */
  workflowName?: string;

  /**
   * A custom trace ID to use for tracing. If not provided, we will generate a new trace ID.
   */
  traceId?: string;

  /**
   * A grouping identifier to use for tracing, to link multiple traces from the same conversation
   * or process. For example, you might use a chat thread ID.
   */
  groupId?: string;

  /**
   * An optional dictionary of additional metadata to include with the trace.
   */
  traceMetadata?: Record<string, string>;
};

type SharedRunOptions<TContext = undefined> = {
  context?: TContext | RunContext<TContext>;
  maxTurns?: number;
  signal?: AbortSignal;
  previousResponseId?: string;
};

export type StreamRunOptions<TContext = undefined> =
  SharedRunOptions<TContext> & {
    /**
     * Whether to stream the run. If true, the run will emit events as the model responds.
     */
    stream: true;
  };

export type NonStreamRunOptions<TContext = undefined> =
  SharedRunOptions<TContext> & {
    /**
     * Whether to stream the run. If true, the run will emit events as the model responds.
     */
    stream?: false;
  };

export type IndividualRunOptions<TContext = undefined> =
  | StreamRunOptions<TContext>
  | NonStreamRunOptions<TContext>;

/**
 * @internal
 */
export function getTracing(
  tracingDisabled: boolean,
  traceIncludeSensitiveData: boolean,
): ModelTracing {
  if (tracingDisabled) {
    return false;
  }

  if (traceIncludeSensitiveData) {
    return true;
  }

  return 'enabled_without_data';
}

export function getTurnInput(
  originalInput: string | AgentInputItem[],
  generatedItems: RunItem[],
): AgentInputItem[] {
  const rawItems = generatedItems
    .filter((item) => item.type !== 'tool_approval_item') // don't include approval items to avoid double function calls
    .map((item) => item.rawItem);

  if (typeof originalInput === 'string') {
    originalInput = [{ type: 'message', role: 'user', content: originalInput }];
  }

  return [...originalInput, ...rawItems];
}

/**
 * A Runner is responsible for running an agent workflow.
 */
export class Runner extends RunHooks<any, AgentOutputType<unknown>> {
  public readonly config: RunConfig;
  private readonly inputGuardrailDefs: InputGuardrailDefinition[];
  private readonly outputGuardrailDefs: OutputGuardrailDefinition<
    OutputGuardrailMetadata,
    AgentOutputType<unknown>
  >[];

  constructor(config: Partial<RunConfig> = {}) {
    super();
    this.config = {
      modelProvider: config.modelProvider ?? getDefaultModelProvider(),
      model: config.model,
      modelSettings: config.modelSettings,
      handoffInputFilter: config.handoffInputFilter,
      inputGuardrails: config.inputGuardrails,
      outputGuardrails: config.outputGuardrails,
      tracingDisabled: config.tracingDisabled ?? false,
      traceIncludeSensitiveData: config.traceIncludeSensitiveData ?? true,
      workflowName: config.workflowName ?? 'Agent workflow',
      traceId: config.traceId,
      groupId: config.groupId,
      traceMetadata: config.traceMetadata,
    };
    this.inputGuardrailDefs = (config.inputGuardrails ?? []).map(
      defineInputGuardrail,
    );
    this.outputGuardrailDefs = (config.outputGuardrails ?? []).map(
      defineOutputGuardrail,
    );
  }

  /**
   * @internal
   */
  async #runIndividualNonStream<
    TContext,
    TAgent extends Agent<TContext, AgentOutputType>,
    _THandoffs extends (Agent<any, any> | Handoff<any>)[] = any[],
  >(
    startingAgent: TAgent,
    input: string | AgentInputItem[] | RunState<TContext, TAgent>,
    options: NonStreamRunOptions<TContext>,
  ): Promise<RunResult<TContext, TAgent>> {
    return withNewSpanContext(async () => {
      // if we have a saved state we use that one, otherwise we create a new one
      const state =
        input instanceof RunState
          ? input
          : new RunState(
              options.context instanceof RunContext
                ? options.context
                : new RunContext(options.context),
              input,
              startingAgent,
              options.maxTurns ?? DEFAULT_MAX_TURNS,
            );

      try {
        while (true) {
          let model = selectModel(state._currentAgent.model, this.config.model);

          if (typeof model === 'string') {
            model = await this.config.modelProvider.getModel(model);
          }

          // if we don't have a current step, we treat this as a new run
          state._currentStep = state._currentStep ?? {
            type: 'next_step_run_again',
          };

          if (state._currentStep.type === 'next_step_interruption') {
            logger.debug('Continuing from interruption');
            if (!state._lastTurnResponse || !state._lastProcessedResponse) {
              throw new UserError(
                'No model response found in previous state',
                state,
              );
            }

            const turnResult =
              await executeInterruptedToolsAndSideEffects<TContext>(
                state._currentAgent,
                state._originalInput,
                state._generatedItems,
                state._lastTurnResponse,
                state._lastProcessedResponse as ProcessedResponse<unknown>,
                this,
                state,
              );

            state._toolUseTracker.addToolUse(
              state._currentAgent,
              state._lastProcessedResponse.toolsUsed,
            );

            state._originalInput = turnResult.originalInput;
            state._generatedItems = turnResult.generatedItems;
            state._currentStep = turnResult.nextStep;

            if (turnResult.nextStep.type === 'next_step_interruption') {
              // we are still in an interruption, so we need to avoid an infinite loop
              return new RunResult<TContext, TAgent>(state);
            }

            continue;
          }

          if (state._currentStep.type === 'next_step_run_again') {
            const handoffs: Handoff<any>[] = [];
            if (state._currentAgent.handoffs) {
              // While this array usually must not be undefined,
              // we've added this check to prevent unexpected runtime errors like https://github.com/openai/openai-agents-js/issues/138
              handoffs.push(...state._currentAgent.handoffs.map(getHandoff));
            }

            if (!state._currentAgentSpan) {
              const handoffNames = handoffs.map((h) => h.agentName);
              state._currentAgentSpan = createAgentSpan({
                data: {
                  name: state._currentAgent.name,
                  handoffs: handoffNames,
                  output_type: state._currentAgent.outputSchemaName,
                },
              });
              state._currentAgentSpan.start();
              setCurrentSpan(state._currentAgentSpan);
            }

            const tools = await state._currentAgent.getAllTools();
            const serializedTools = tools.map((t) => serializeTool(t));
            const serializedHandoffs = handoffs.map((h) => serializeHandoff(h));
            if (state._currentAgentSpan) {
              state._currentAgentSpan.spanData.tools = tools.map((t) => t.name);
            }

            state._currentTurn++;

            if (state._currentTurn > state._maxTurns) {
              state._currentAgentSpan?.setError({
                message: 'Max turns exceeded',
                data: { max_turns: state._maxTurns },
              });

              throw new MaxTurnsExceededError(
                `Max turns (${state._maxTurns}) exceeded`,
                state,
              );
            }

            logger.debug(
              `Running agent ${state._currentAgent.name} (turn ${state._currentTurn})`,
            );

            if (state._currentTurn === 1) {
              await this.#runInputGuardrails(state);
            }

            const turnInput = getTurnInput(
              state._originalInput,
              state._generatedItems,
            );

            if (state._noActiveAgentRun) {
              state._currentAgent.emit(
                'agent_start',
                state._context,
                state._currentAgent,
              );
              this.emit('agent_start', state._context, state._currentAgent);
            }

            let modelSettings = {
              ...this.config.modelSettings,
              ...state._currentAgent.modelSettings,
            };
            modelSettings = maybeResetToolChoice(
              state._currentAgent,
              state._toolUseTracker,
              modelSettings,
            );
            state._lastTurnResponse = await model.getResponse({
              systemInstructions: await state._currentAgent.getSystemPrompt(
                state._context,
              ),
              prompt: await state._currentAgent.getPrompt(state._context),
              input: turnInput,
              previousResponseId: options.previousResponseId,
              modelSettings,
              tools: serializedTools,
              outputType: convertAgentOutputTypeToSerializable(
                state._currentAgent.outputType,
              ),
              handoffs: serializedHandoffs,
              tracing: getTracing(
                this.config.tracingDisabled,
                this.config.traceIncludeSensitiveData,
              ),
              signal: options.signal,
            });
            state._modelResponses.push(state._lastTurnResponse);
            state._context.usage.add(state._lastTurnResponse.usage);
            state._noActiveAgentRun = false;

            const processedResponse = processModelResponse(
              state._lastTurnResponse,
              state._currentAgent,
              tools,
              handoffs,
            );

            state._lastProcessedResponse = processedResponse;
            const turnResult = await executeToolsAndSideEffects<TContext>(
              state._currentAgent,
              state._originalInput,
              state._generatedItems,
              state._lastTurnResponse,
              state._lastProcessedResponse,
              this,
              state,
            );

            state._toolUseTracker.addToolUse(
              state._currentAgent,
              state._lastProcessedResponse.toolsUsed,
            );

            state._originalInput = turnResult.originalInput;
            state._generatedItems = turnResult.generatedItems;
            state._currentStep = turnResult.nextStep;
          }

          if (
            state._currentStep &&
            state._currentStep.type === 'next_step_final_output'
          ) {
            await this.#runOutputGuardrails(state, state._currentStep.output);
            this.emit(
              'agent_end',
              state._context,
              state._currentAgent,
              state._currentStep.output,
            );
            state._currentAgent.emit(
              'agent_end',
              state._context,
              state._currentStep.output,
            );
            return new RunResult<TContext, TAgent>(state);
          } else if (
            state._currentStep &&
            state._currentStep.type === 'next_step_handoff'
          ) {
            state._currentAgent = state._currentStep.newAgent as TAgent;
            if (state._currentAgentSpan) {
              state._currentAgentSpan.end();
              resetCurrentSpan();
              state._currentAgentSpan = undefined;
            }
            state._noActiveAgentRun = true;

            // we've processed the handoff, so we need to run the loop again
            state._currentStep = { type: 'next_step_run_again' };
          } else if (
            state._currentStep &&
            state._currentStep.type === 'next_step_interruption'
          ) {
            // interrupted. Don't run any guardrails
            return new RunResult<TContext, TAgent>(state);
          } else {
            logger.debug('Running next loop');
          }
        }
      } catch (err) {
        if (state._currentAgentSpan) {
          state._currentAgentSpan.setError({
            message: 'Error in agent run',
            data: { error: String(err) },
          });
        }
        throw err;
      } finally {
        if (state._currentAgentSpan) {
          if (state._currentStep?.type !== 'next_step_interruption') {
            // don't end the span if the run was interrupted
            state._currentAgentSpan.end();
          }
          resetCurrentSpan();
        }
      }
    });
  }

  async #runInputGuardrails<
    TContext,
    TAgent extends Agent<TContext, AgentOutputType>,
  >(state: RunState<TContext, TAgent>) {
    const guardrails = this.inputGuardrailDefs.concat(
      state._currentAgent.inputGuardrails.map(defineInputGuardrail),
    );
    if (guardrails.length > 0) {
      const guardrailArgs = {
        agent: state._currentAgent,
        input: state._originalInput,
        context: state._context,
      };
      try {
        const results = await Promise.all(
          guardrails.map(async (guardrail) => {
            return withGuardrailSpan(
              async (span) => {
                const result = await guardrail.run(guardrailArgs);
                span.spanData.triggered = result.output.tripwireTriggered;
                return result;
              },
              { data: { name: guardrail.name } },
              state._currentAgentSpan,
            );
          }),
        );
        for (const result of results) {
          if (result.output.tripwireTriggered) {
            if (state._currentAgentSpan) {
              state._currentAgentSpan.setError({
                message: 'Guardrail tripwire triggered',
                data: { guardrail: result.guardrail.name },
              });
            }
            throw new InputGuardrailTripwireTriggered(
              `Input guardrail triggered: ${JSON.stringify(result.output.outputInfo)}`,
              result,
              state,
            );
          }
        }
      } catch (e) {
        if (e instanceof InputGuardrailTripwireTriggered) {
          throw e;
        }
        // roll back the current turn to enable reruns
        state._currentTurn--;
        throw new GuardrailExecutionError(
          `Input guardrail failed to complete: ${e}`,
          e as Error,
          state,
        );
      }
    }
  }

  async #runOutputGuardrails<
    TContext,
    TOutput extends AgentOutputType,
    TAgent extends Agent<TContext, TOutput>,
  >(state: RunState<TContext, TAgent>, output: string) {
    const guardrails = this.outputGuardrailDefs.concat(
      state._currentAgent.outputGuardrails.map(defineOutputGuardrail),
    );
    if (guardrails.length > 0) {
      const agentOutput = state._currentAgent.processFinalOutput(output);
      const guardrailArgs: OutputGuardrailFunctionArgs<unknown, TOutput> = {
        agent: state._currentAgent,
        agentOutput,
        context: state._context,
        details: { modelResponse: state._lastTurnResponse },
      };
      try {
        const results = await Promise.all(
          guardrails.map(async (guardrail) => {
            return withGuardrailSpan(
              async (span) => {
                const result = await guardrail.run(guardrailArgs);
                span.spanData.triggered = result.output.tripwireTriggered;
                return result;
              },
              { data: { name: guardrail.name } },
              state._currentAgentSpan,
            );
          }),
        );
        for (const result of results) {
          if (result.output.tripwireTriggered) {
            if (state._currentAgentSpan) {
              state._currentAgentSpan.setError({
                message: 'Guardrail tripwire triggered',
                data: { guardrail: result.guardrail.name },
              });
            }
            throw new OutputGuardrailTripwireTriggered(
              `Output guardrail triggered: ${JSON.stringify(result.output.outputInfo)}`,
              result,
              state,
            );
          }
        }
      } catch (e) {
        if (e instanceof OutputGuardrailTripwireTriggered) {
          throw e;
        }
        throw new GuardrailExecutionError(
          `Output guardrail failed to complete: ${e}`,
          e as Error,
          state,
        );
      }
    }
  }

  /**
   * @internal
   */
  async #runStreamLoop<
    TContext,
    TAgent extends Agent<TContext, AgentOutputType>,
  >(
    result: StreamedRunResult<TContext, TAgent>,
    options: StreamRunOptions<TContext>,
  ): Promise<void> {
    try {
      while (true) {
        const currentAgent = result.state._currentAgent;
        const handoffs = currentAgent.handoffs.map(getHandoff);
        const tools = await currentAgent.getAllTools();
        const serializedTools = tools.map((t) => serializeTool(t));
        const serializedHandoffs = handoffs.map((h) => serializeHandoff(h));

        result.state._currentStep = result.state._currentStep ?? {
          type: 'next_step_run_again',
        };

        if (result.state._currentStep.type === 'next_step_interruption') {
          logger.debug('Continuing from interruption');
          if (
            !result.state._lastTurnResponse ||
            !result.state._lastProcessedResponse
          ) {
            throw new UserError(
              'No model response found in previous state',
              result.state,
            );
          }

          const turnResult =
            await executeInterruptedToolsAndSideEffects<TContext>(
              result.state._currentAgent,
              result.state._originalInput,
              result.state._generatedItems,
              result.state._lastTurnResponse,
              result.state._lastProcessedResponse as ProcessedResponse<unknown>,
              this,
              result.state,
            );

          addStepToRunResult(result, turnResult);

          result.state._toolUseTracker.addToolUse(
            result.state._currentAgent,
            result.state._lastProcessedResponse.toolsUsed,
          );

          result.state._originalInput = turnResult.originalInput;
          result.state._generatedItems = turnResult.generatedItems;
          result.state._currentStep = turnResult.nextStep;
          if (turnResult.nextStep.type === 'next_step_interruption') {
            // we are still in an interruption, so we need to avoid an infinite loop
            return;
          }
          continue;
        }

        if (result.state._currentStep.type === 'next_step_run_again') {
          if (!result.state._currentAgentSpan) {
            const handoffNames = handoffs.map((h) => h.agentName);
            result.state._currentAgentSpan = createAgentSpan({
              data: {
                name: currentAgent.name,
                handoffs: handoffNames,
                tools: tools.map((t) => t.name),
                output_type: currentAgent.outputSchemaName,
              },
            });
            result.state._currentAgentSpan.start();
            setCurrentSpan(result.state._currentAgentSpan);
          }

          result.state._currentTurn++;

          if (result.state._currentTurn > result.state._maxTurns) {
            result.state._currentAgentSpan?.setError({
              message: 'Max turns exceeded',
              data: { max_turns: result.state._maxTurns },
            });
            throw new MaxTurnsExceededError(
              `Max turns (${result.state._maxTurns}) exceeded`,
              result.state,
            );
          }

          logger.debug(
            `Running agent ${currentAgent.name} (turn ${result.state._currentTurn})`,
          );

          let model = selectModel(currentAgent.model, this.config.model);

          if (typeof model === 'string') {
            model = await this.config.modelProvider.getModel(model);
          }

          if (result.state._currentTurn === 1) {
            await this.#runInputGuardrails(result.state);
          }

          let modelSettings = {
            ...this.config.modelSettings,
            ...currentAgent.modelSettings,
          };
          modelSettings = maybeResetToolChoice(
            currentAgent,
            result.state._toolUseTracker,
            modelSettings,
          );

          const turnInput = getTurnInput(result.input, result.newItems);

          if (result.state._noActiveAgentRun) {
            currentAgent.emit(
              'agent_start',
              result.state._context,
              currentAgent,
            );
            this.emit('agent_start', result.state._context, currentAgent);
          }

          let finalResponse: ModelResponse | undefined = undefined;

          for await (const event of model.getStreamedResponse({
            systemInstructions: await currentAgent.getSystemPrompt(
              result.state._context,
            ),
            prompt: await currentAgent.getPrompt(result.state._context),
            input: turnInput,
            previousResponseId: options.previousResponseId,
            modelSettings,
            tools: serializedTools,
            handoffs: serializedHandoffs,
            outputType: convertAgentOutputTypeToSerializable(
              currentAgent.outputType,
            ),
            tracing: getTracing(
              this.config.tracingDisabled,
              this.config.traceIncludeSensitiveData,
            ),
            signal: options.signal,
          })) {
            if (event.type === 'response_done') {
              const parsed = StreamEventResponseCompleted.parse(event);
              finalResponse = {
                usage: new Usage(parsed.response.usage),
                output: parsed.response.output,
                responseId: parsed.response.id,
              };
            }
            if (result.cancelled) {
              // When the user's code exits a loop to consume the stream, we need to break
              // this loop to prevent internal false errors and unnecessary processing
              return;
            }
            result._addItem(new RunRawModelStreamEvent(event));
          }

          result.state._noActiveAgentRun = false;

          if (!finalResponse) {
            throw new ModelBehaviorError(
              'Model did not produce a final response!',
              result.state,
            );
          }

          result.state._lastTurnResponse = finalResponse;
          result.state._modelResponses.push(result.state._lastTurnResponse);

          const processedResponse = processModelResponse(
            result.state._lastTurnResponse,
            currentAgent,
            tools,
            handoffs,
          );

          result.state._lastProcessedResponse = processedResponse;
          const turnResult = await executeToolsAndSideEffects<TContext>(
            currentAgent,
            result.state._originalInput,
            result.state._generatedItems,
            result.state._lastTurnResponse,
            result.state._lastProcessedResponse,
            this,
            result.state,
          );

          addStepToRunResult(result, turnResult);

          result.state._toolUseTracker.addToolUse(
            currentAgent,
            processedResponse.toolsUsed,
          );

          result.state._originalInput = turnResult.originalInput;
          result.state._generatedItems = turnResult.generatedItems;
          result.state._currentStep = turnResult.nextStep;
        }

        if (result.state._currentStep.type === 'next_step_final_output') {
          await this.#runOutputGuardrails(
            result.state,
            result.state._currentStep.output,
          );
          return;
        } else if (
          result.state._currentStep.type === 'next_step_interruption'
        ) {
          // we are done for now. Don't run any output guardrails
          return;
        } else if (result.state._currentStep.type === 'next_step_handoff') {
          result.state._currentAgent = result.state._currentStep
            ?.newAgent as TAgent;
          if (result.state._currentAgentSpan) {
            result.state._currentAgentSpan.end();
            resetCurrentSpan();
          }
          result.state._currentAgentSpan = undefined;
          result._addItem(
            new RunAgentUpdatedStreamEvent(result.state._currentAgent),
          );
          result.state._noActiveAgentRun = true;

          // we've processed the handoff, so we need to run the loop again
          result.state._currentStep = {
            type: 'next_step_run_again',
          };
        } else {
          logger.debug('Running next loop');
        }
      }
    } catch (error) {
      if (result.state._currentAgentSpan) {
        result.state._currentAgentSpan.setError({
          message: 'Error in agent run',
          data: { error: String(error) },
        });
      }
      throw error;
    } finally {
      if (result.state._currentAgentSpan) {
        if (result.state._currentStep?.type !== 'next_step_interruption') {
          result.state._currentAgentSpan.end();
        }
        resetCurrentSpan();
      }
    }
  }

  /**
   * @internal
   */
  async #runIndividualStream<
    TContext,
    TAgent extends Agent<TContext, AgentOutputType>,
  >(
    agent: TAgent,
    input: string | AgentInputItem[] | RunState<TContext, TAgent>,
    options?: StreamRunOptions<TContext>,
  ): Promise<StreamedRunResult<TContext, TAgent>> {
    options = options ?? ({} as StreamRunOptions<TContext>);
    return withNewSpanContext(async () => {
      // Initialize or reuse existing state
      const state: RunState<TContext, TAgent> =
        input instanceof RunState
          ? input
          : new RunState(
              options.context instanceof RunContext
                ? options.context
                : new RunContext(options.context),
              input as string | AgentInputItem[],
              agent,
              options.maxTurns ?? DEFAULT_MAX_TURNS,
            );

      // Initialize the streamed result with existing state
      const result = new StreamedRunResult<TContext, TAgent>({
        signal: options.signal,
        state,
      });

      // Setup defaults
      result.maxTurns = options.maxTurns ?? state._maxTurns;

      // Continue the stream loop without blocking
      this.#runStreamLoop(result, options).then(
        () => {
          result._done();
        },
        (err) => {
          result._raiseError(err);
        },
      );

      return result;
    });
  }

  /**
   * Run a workflow starting at the given agent. The agent will run in a loop until a final
   * output is generated. The loop runs like so:
   * 1. The agent is invoked with the given input.
   * 2. If there is a final output (i.e. the agent produces something of type
   *    `agent.outputType`, the loop terminates.
   * 3. If there's a handoff, we run the loop again, with the new agent.
   * 4. Else, we run tool calls (if any), and re-run the loop.
   *
   * In two cases, the agent may raise an exception:
   * 1. If the maxTurns is exceeded, a MaxTurnsExceeded exception is raised.
   * 2. If a guardrail tripwire is triggered, a GuardrailTripwireTriggered exception is raised.
   *
   * Note that only the first agent's input guardrails are run.
   *
   * @param agent - The starting agent to run.
   * @param input - The initial input to the agent. You can pass a string or an array of
   * `AgentInputItem`.
   * @param options - The options for the run.
   * @param options.stream - Whether to stream the run. If true, the run will emit events as the
   * model responds.
   * @param options.context - The context to run the agent with.
   * @param options.maxTurns - The maximum number of turns to run the agent.
   * @returns The result of the run.
   */
  run<TAgent extends Agent<any, any>, TContext = undefined>(
    agent: TAgent,
    input: string | AgentInputItem[] | RunState<TContext, TAgent>,
    options?: NonStreamRunOptions<TContext>,
  ): Promise<RunResult<TContext, TAgent>>;
  run<TAgent extends Agent<any, any>, TContext = undefined>(
    agent: TAgent,
    input: string | AgentInputItem[] | RunState<TContext, TAgent>,
    options?: StreamRunOptions<TContext>,
  ): Promise<StreamedRunResult<TContext, TAgent>>;
  run<TAgent extends Agent<any, any>, TContext = undefined>(
    agent: TAgent,
    input: string | AgentInputItem[] | RunState<TContext, TAgent>,
    options: IndividualRunOptions<TContext> = {
      stream: false,
      context: undefined,
    } as IndividualRunOptions<TContext>,
  ): Promise<
    RunResult<TContext, TAgent> | StreamedRunResult<TContext, TAgent>
  > {
    if (input instanceof RunState && input._trace) {
      return withTrace(input._trace, async () => {
        if (input._currentAgentSpan) {
          setCurrentSpan(input._currentAgentSpan);
        }

        if (options?.stream) {
          return this.#runIndividualStream(agent, input, options);
        } else {
          return this.#runIndividualNonStream(agent, input, options);
        }
      });
    }

    return getOrCreateTrace(
      async () => {
        if (options?.stream) {
          return this.#runIndividualStream(agent, input, options);
        } else {
          return this.#runIndividualNonStream(agent, input, options);
        }
      },
      {
        traceId: this.config.traceId,
        name: this.config.workflowName,
        groupId: this.config.groupId,
        metadata: this.config.traceMetadata,
      },
    );
  }
}

let _defaultRunner: Runner | undefined = undefined;
function getDefaultRunner() {
  if (_defaultRunner) {
    return _defaultRunner;
  }
  _defaultRunner = new Runner();
  return _defaultRunner;
}

export function selectModel(
  agentModel: string | Model,
  runConfigModel: string | Model | undefined,
): string | Model {
  // When initializing an agent without model name, the model property is set to an empty string. So,
  // * agentModel === '' & runConfigModel exists, runConfigModel will be used
  // * agentModel is set, the agentModel will be used over runConfigModel
  if (
    (typeof agentModel === 'string' &&
      agentModel !== Agent.DEFAULT_MODEL_PLACEHOLDER) ||
    agentModel // any truthy value
  ) {
    return agentModel;
  }
  return runConfigModel ?? agentModel ?? Agent.DEFAULT_MODEL_PLACEHOLDER;
}

export async function run<TAgent extends Agent<any, any>, TContext = undefined>(
  agent: TAgent,
  input: string | AgentInputItem[] | RunState<TContext, TAgent>,
  options?: NonStreamRunOptions<TContext>,
): Promise<RunResult<TContext, TAgent>>;
export async function run<TAgent extends Agent<any, any>, TContext = undefined>(
  agent: TAgent,
  input: string | AgentInputItem[] | RunState<TContext, TAgent>,
  options?: StreamRunOptions<TContext>,
): Promise<StreamedRunResult<TContext, TAgent>>;
export async function run<TAgent extends Agent<any, any>, TContext = undefined>(
  agent: TAgent,
  input: string | AgentInputItem[] | RunState<TContext, TAgent>,
  options?: StreamRunOptions<TContext> | NonStreamRunOptions<TContext>,
): Promise<RunResult<TContext, TAgent> | StreamedRunResult<TContext, TAgent>> {
  const runner = getDefaultRunner();
  if (options?.stream) {
    return await runner.run(agent, input, options);
  } else {
    return await runner.run(agent, input, options);
  }
}



---
File: /packages/agents-core/src/runContext.ts
---

import { RunToolApprovalItem } from './items';
import logger from './logger';
import { UnknownContext } from './types';
import { Usage } from './usage';

type ApprovalRecord = {
  approved: boolean | string[];
  rejected: boolean | string[];
};

/**
 * A context object that is passed to the `Runner.run()` method.
 */
export class RunContext<TContext = UnknownContext> {
  /**
   * The context object passed by you to the `Runner.run()`
   */
  context: TContext;

  /**
   * The usage of the agent run so far. For streamed responses, the usage will be stale until the
   * last chunk of the stream is processed.
   */
  usage: Usage;

  /**
   * A map of tool names to whether they have been approved.
   */
  #approvals: Map<string, ApprovalRecord>;

  constructor(context: TContext = {} as TContext) {
    this.context = context;
    this.usage = new Usage();
    this.#approvals = new Map();
  }

  /**
   * Rebuild the approvals map from a serialized state.
   * @internal
   *
   * @param approvals - The approvals map to rebuild.
   */
  _rebuildApprovals(approvals: Record<string, ApprovalRecord>) {
    this.#approvals = new Map(Object.entries(approvals));
  }

  /**
   * Check if a tool call has been approved.
   *
   * @param toolName - The name of the tool.
   * @param callId - The call ID of the tool call.
   * @returns `true` if the tool call has been approved, `false` if blocked and `undefined` if not yet approved or rejected.
   */
  isToolApproved({ toolName, callId }: { toolName: string; callId: string }) {
    const approvalEntry = this.#approvals.get(toolName);
    if (approvalEntry?.approved === true && approvalEntry.rejected === true) {
      logger.warn(
        'Tool is permanently approved and rejected at the same time. Approval takes precedence',
      );
      return true;
    }

    if (approvalEntry?.approved === true) {
      return true;
    }

    if (approvalEntry?.rejected === true) {
      return false;
    }

    const individualCallApproval = Array.isArray(approvalEntry?.approved)
      ? approvalEntry.approved.includes(callId)
      : false;
    const individualCallRejection = Array.isArray(approvalEntry?.rejected)
      ? approvalEntry.rejected.includes(callId)
      : false;

    if (individualCallApproval && individualCallRejection) {
      logger.warn(
        `Tool call ${callId} is both approved and rejected at the same time. Approval takes precedence`,
      );
      return true;
    }

    if (individualCallApproval) {
      return true;
    }

    if (individualCallRejection) {
      return false;
    }

    return undefined;
  }

  /**
   * Approve a tool call.
   *
   * @param toolName - The name of the tool.
   * @param callId - The call ID of the tool call.
   */
  approveTool(
    approvalItem: RunToolApprovalItem,
    { alwaysApprove = false }: { alwaysApprove?: boolean } = {},
  ) {
    const toolName = approvalItem.rawItem.name;
    if (alwaysApprove) {
      this.#approvals.set(toolName, {
        approved: true,
        rejected: [],
      });
      return;
    }

    const approvalEntry = this.#approvals.get(toolName) ?? {
      approved: [],
      rejected: [],
    };
    if (Array.isArray(approvalEntry.approved)) {
      // function tool has call_id, hosted tool call has id
      const callId =
        'callId' in approvalItem.rawItem
          ? approvalItem.rawItem.callId // function tools
          : approvalItem.rawItem.id!; // hosted tools
      approvalEntry.approved.push(callId);
    }
    this.#approvals.set(toolName, approvalEntry);
  }

  /**
   * Reject a tool call.
   *
   * @param approvalItem - The tool approval item to reject.
   */
  rejectTool(
    approvalItem: RunToolApprovalItem,
    { alwaysReject = false }: { alwaysReject?: boolean } = {},
  ) {
    const toolName = approvalItem.rawItem.name;
    if (alwaysReject) {
      this.#approvals.set(toolName, {
        approved: false,
        rejected: true,
      });
      return;
    }

    const approvalEntry = this.#approvals.get(toolName) ?? {
      approved: [] as string[],
      rejected: [] as string[],
    };

    if (Array.isArray(approvalEntry.rejected)) {
      // function tool has call_id, hosted tool call has id
      const callId =
        'callId' in approvalItem.rawItem
          ? approvalItem.rawItem.callId // function tools
          : approvalItem.rawItem.id!; // hosted tools
      approvalEntry.rejected.push(callId);
    }
    this.#approvals.set(toolName, approvalEntry);
  }

  toJSON(): {
    context: any;
    usage: Usage;
    approvals: Record<string, ApprovalRecord>;
  } {
    return {
      context: this.context,
      usage: this.usage,
      approvals: Object.fromEntries(this.#approvals.entries()),
    };
  }
}



---
File: /packages/agents-core/src/runImplementation.ts
---

import { FunctionCallResultItem } from './types/protocol';
import { Agent, AgentOutputType, ToolsToFinalOutputResult } from './agent';
import { ModelBehaviorError, ToolCallError, UserError } from './errors';
import { getTransferMessage, Handoff, HandoffInputData } from './handoff';
import {
  RunHandoffCallItem,
  RunHandoffOutputItem,
  RunMessageOutputItem,
  RunReasoningItem,
  RunItem,
  RunToolApprovalItem,
  RunToolCallItem,
  RunToolCallOutputItem,
} from './items';
import logger, { Logger } from './logger';
import { ModelResponse, ModelSettings } from './model';
import {
  ComputerTool,
  FunctionTool,
  Tool,
  FunctionToolResult,
  HostedMCPTool,
} from './tool';
import { AgentInputItem, UnknownContext } from './types';
import { Runner } from './run';
import { RunContext } from './runContext';
import { getLastTextFromOutputMessage } from './utils/messages';
import { withFunctionSpan, withHandoffSpan } from './tracing/createSpans';
import { getSchemaAndParserFromInputType } from './utils/tools';
import { safeExecute } from './utils/safeExecute';
import { addErrorToCurrentSpan } from './tracing/context';
import { RunItemStreamEvent, RunItemStreamEventName } from './events';
import { StreamedRunResult } from './result';
import { z } from '@openai/zod/v3';
import { toSmartString } from './utils/smartString';
import * as protocol from './types/protocol';
import { Computer } from './computer';
import { RunState } from './runState';
import { isZodObject } from './utils';
import * as ProviderData from './types/providerData';

type ToolRunHandoff = {
  toolCall: protocol.FunctionCallItem;
  handoff: Handoff;
};

type ToolRunFunction<TContext = UnknownContext> = {
  toolCall: protocol.FunctionCallItem;
  tool: FunctionTool<TContext>;
};

type ToolRunComputer = {
  toolCall: protocol.ComputerUseCallItem;
  computer: ComputerTool;
};

type ToolRunMCPApprovalRequest = {
  requestItem: RunToolApprovalItem;
  mcpTool: HostedMCPTool;
};

export type ProcessedResponse<TContext = UnknownContext> = {
  newItems: RunItem[];
  handoffs: ToolRunHandoff[];
  functions: ToolRunFunction<TContext>[];
  computerActions: ToolRunComputer[];
  mcpApprovalRequests: ToolRunMCPApprovalRequest[];
  toolsUsed: string[];
  hasToolsOrApprovalsToRun(): boolean;
};

/**
 * @internal
 */
export function processModelResponse<TContext>(
  modelResponse: ModelResponse,
  agent: Agent<any, any>,
  tools: Tool<TContext>[],
  handoffs: Handoff[],
): ProcessedResponse<TContext> {
  const items: RunItem[] = [];
  const runHandoffs: ToolRunHandoff[] = [];
  const runFunctions: ToolRunFunction<TContext>[] = [];
  const runComputerActions: ToolRunComputer[] = [];
  const runMCPApprovalRequests: ToolRunMCPApprovalRequest[] = [];
  const toolsUsed: string[] = [];
  const handoffMap = new Map(handoffs.map((h) => [h.toolName, h]));
  const functionMap = new Map(
    tools.filter((t) => t.type === 'function').map((t) => [t.name, t]),
  );
  const computerTool = tools.find((t) => t.type === 'computer');
  const mcpToolMap = new Map(
    tools
      .filter((t) => t.type === 'hosted_tool' && t.providerData?.type === 'mcp')
      .map((t) => t as HostedMCPTool)
      .map((t) => [t.providerData.server_label, t]),
  );

  for (const output of modelResponse.output) {
    if (output.type === 'message') {
      if (output.role === 'assistant') {
        items.push(new RunMessageOutputItem(output, agent));
      }
    } else if (output.type === 'hosted_tool_call') {
      items.push(new RunToolCallItem(output, agent));
      const toolName = output.name;
      toolsUsed.push(toolName);

      if (
        output.providerData?.type === 'mcp_approval_request' ||
        output.name === 'mcp_approval_request'
      ) {
        // Hosted remote MCP server's approval process
        const providerData =
          output.providerData as ProviderData.HostedMCPApprovalRequest;

        const mcpServerLabel = providerData.server_label;
        const mcpServerTool = mcpToolMap.get(mcpServerLabel);
        if (typeof mcpServerTool === 'undefined') {
          const message = `MCP server (${mcpServerLabel}) not found in Agent (${agent.name})`;
          addErrorToCurrentSpan({
            message,
            data: { mcp_server_label: mcpServerLabel },
          });
          throw new ModelBehaviorError(message);
        }

        // Do this approval later:
        // We support both onApproval callback (like the Python SDK does) and HITL patterns.
        const approvalItem = new RunToolApprovalItem(
          {
            type: 'hosted_tool_call',
            // We must use this name to align with the name sent from the servers
            name: providerData.name,
            id: providerData.id,
            status: 'in_progress',
            providerData,
          },
          agent,
        );
        runMCPApprovalRequests.push({
          requestItem: approvalItem,
          mcpTool: mcpServerTool,
        });
        if (!mcpServerTool.providerData.on_approval) {
          // When onApproval function exists, it confirms the approval right after this.
          // Thus, this approval item must be appended only for the next turn interruption patterns.
          items.push(approvalItem);
        }
      }
    } else if (output.type === 'reasoning') {
      items.push(new RunReasoningItem(output, agent));
    } else if (output.type === 'computer_call') {
      items.push(new RunToolCallItem(output, agent));
      toolsUsed.push('computer_use');
      if (!computerTool) {
        addErrorToCurrentSpan({
          message: 'Model produced computer action without a computer tool.',
          data: {
            agent_name: agent.name,
          },
        });
        throw new ModelBehaviorError(
          'Model produced computer action without a computer tool.',
        );
      }
      runComputerActions.push({
        toolCall: output,
        computer: computerTool,
      });
    }

    if (output.type !== 'function_call') {
      continue;
    }

    toolsUsed.push(output.name);

    const handoff = handoffMap.get(output.name);
    if (handoff) {
      items.push(new RunHandoffCallItem(output, agent));
      runHandoffs.push({
        toolCall: output,
        handoff: handoff,
      });
    } else {
      const functionTool = functionMap.get(output.name);
      if (!functionTool) {
        addErrorToCurrentSpan({
          message: `Tool ${output.name} not found in agent ${agent.name}.`,
          data: {
            tool_name: output.name,
            agent_name: agent.name,
          },
        });

        throw new ModelBehaviorError(
          `Tool ${output.name} not found in agent ${agent.name}.`,
        );
      }
      items.push(new RunToolCallItem(output, agent));
      runFunctions.push({
        toolCall: output,
        tool: functionTool,
      });
    }
  }

  return {
    newItems: items,
    handoffs: runHandoffs,
    functions: runFunctions,
    computerActions: runComputerActions,
    mcpApprovalRequests: runMCPApprovalRequests,
    toolsUsed: toolsUsed,
    hasToolsOrApprovalsToRun(): boolean {
      return (
        runHandoffs.length > 0 ||
        runFunctions.length > 0 ||
        runMCPApprovalRequests.length > 0 ||
        runComputerActions.length > 0
      );
    },
  };
}

export const nextStepSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('next_step_handoff'),
    newAgent: z.any(),
  }),
  z.object({
    type: z.literal('next_step_final_output'),
    output: z.string(),
  }),
  z.object({
    type: z.literal('next_step_run_again'),
  }),
  z.object({
    type: z.literal('next_step_interruption'),
    data: z.record(z.string(), z.any()),
  }),
]);

export type NextStep = z.infer<typeof nextStepSchema>;

class SingleStepResult {
  constructor(
    /**
     * The input items i.e. the items before run() was called. May be muted by handoff input filters
     */
    public originalInput: string | AgentInputItem[],
    /**
     * The model response for the current step
     */
    public modelResponse: ModelResponse,
    /**
     * The items before the current step was executed
     */
    public preStepItems: RunItem[],
    /**
     * The items after the current step was executed
     */
    public newStepItems: RunItem[],
    /**
     * The next step to execute
     */
    public nextStep: NextStep,
  ) {}

  /**
   * The items generated during the agent run (i.e. everything generated after originalInput)
   */
  get generatedItems(): RunItem[] {
    return this.preStepItems.concat(this.newStepItems);
  }
}

/**
 * @internal
 */
export function maybeResetToolChoice(
  agent: Agent<any, any>,
  toolUseTracker: AgentToolUseTracker,
  modelSettings: ModelSettings,
) {
  if (agent.resetToolChoice && toolUseTracker.hasUsedTools(agent)) {
    return { ...modelSettings, toolChoice: undefined };
  }
  return modelSettings;
}

/**
 * @internal
 */
export async function executeInterruptedToolsAndSideEffects<TContext>(
  agent: Agent<TContext, any>,
  originalInput: string | AgentInputItem[],
  originalPreStepItems: RunItem[],
  newResponse: ModelResponse,
  processedResponse: ProcessedResponse,
  runner: Runner,
  state: RunState<TContext, Agent<TContext, any>>,
): Promise<SingleStepResult> {
  // call_ids for function tools
  const functionCallIds = originalPreStepItems
    .filter(
      (item) =>
        item instanceof RunToolApprovalItem &&
        'callId' in item.rawItem &&
        item.rawItem.type === 'function_call',
    )
    .map((item) => (item.rawItem as protocol.FunctionCallItem).callId);
  // Run function tools that require approval after they get their approval results
  const functionToolRuns = processedResponse.functions.filter((run) => {
    return functionCallIds.includes(run.toolCall.callId);
  });

  const functionResults = await executeFunctionToolCalls(
    agent,
    functionToolRuns,
    runner,
    state,
  );

  // Create the initial set of the output items
  const newItems: RunItem[] = functionResults.map((r) => r.runItem);

  // Run MCP tools that require approval after they get their approval results
  const mcpApprovalRuns = processedResponse.mcpApprovalRequests.filter(
    (run) => {
      return (
        run.requestItem.type === 'tool_approval_item' &&
        run.requestItem.rawItem.type === 'hosted_tool_call' &&
        run.requestItem.rawItem.providerData?.type === 'mcp_approval_request'
      );
    },
  );
  for (const run of mcpApprovalRuns) {
    // the approval_request_id "mcpr_123..."
    const approvalRequestId = run.requestItem.rawItem.id!;
    const approved = state._context.isToolApproved({
      // Since this item name must be the same with the one sent from Responses API server
      toolName: run.requestItem.rawItem.name,
      callId: approvalRequestId,
    });
    if (typeof approved !== 'undefined') {
      const providerData: ProviderData.HostedMCPApprovalResponse = {
        approve: approved,
        approval_request_id: approvalRequestId,
        reason: undefined,
      };
      // Tell Responses API server the approval result in the next turn
      newItems.push(
        new RunToolCallItem(
          {
            type: 'hosted_tool_call',
            name: 'mcp_approval_response',
            providerData,
          },
          agent as Agent<unknown, 'text'>,
        ),
      );
    }
  }

  const checkToolOutput = await checkForFinalOutputFromTools(
    agent,
    functionResults,
    state,
  );

  // Exclude the tool approval items, which should not be sent to Responses API,
  // from the SingleStepResult's preStepItems
  const preStepItems = originalPreStepItems.filter((item) => {
    return !(item instanceof RunToolApprovalItem);
  });

  if (checkToolOutput.isFinalOutput) {
    runner.emit(
      'agent_end',
      state._context,
      agent,
      checkToolOutput.finalOutput,
    );
    agent.emit('agent_end', state._context, checkToolOutput.finalOutput);

    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      {
        type: 'next_step_final_output',
        output: checkToolOutput.finalOutput,
      },
    );
  } else if (checkToolOutput.isInterrupted) {
    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      {
        type: 'next_step_interruption',
        data: {
          interruptions: checkToolOutput.interruptions,
        },
      },
    );
  }

  // we only ran new tools and side effects. We need to run the rest of the agent
  return new SingleStepResult(
    originalInput,
    newResponse,
    preStepItems,
    newItems,
    { type: 'next_step_run_again' },
  );
}

/**
 * @internal
 */
export async function executeToolsAndSideEffects<TContext>(
  agent: Agent<TContext, any>,
  originalInput: string | AgentInputItem[],
  originalPreStepItems: RunItem[],
  newResponse: ModelResponse,
  processedResponse: ProcessedResponse<TContext>,
  runner: Runner,
  state: RunState<TContext, Agent<TContext, any>>,
): Promise<SingleStepResult> {
  const preStepItems = originalPreStepItems;
  let newItems = processedResponse.newItems;

  const [functionResults, computerResults] = await Promise.all([
    executeFunctionToolCalls(
      agent,
      processedResponse.functions as ToolRunFunction<unknown>[],
      runner,
      state,
    ),
    executeComputerActions(
      agent,
      processedResponse.computerActions,
      runner,
      state._context,
    ),
  ]);

  newItems = newItems.concat(functionResults.map((r) => r.runItem));
  newItems = newItems.concat(computerResults);

  // run hosted MCP approval requests
  if (processedResponse.mcpApprovalRequests.length > 0) {
    for (const approvalRequest of processedResponse.mcpApprovalRequests) {
      const toolData = approvalRequest.mcpTool
        .providerData as ProviderData.HostedMCPTool<TContext>;
      const requestData = approvalRequest.requestItem.rawItem
        .providerData as ProviderData.HostedMCPApprovalRequest;
      if (toolData.on_approval) {
        // synchronously handle the approval process here
        const approvalResult = await toolData.on_approval(
          state._context,
          approvalRequest.requestItem,
        );
        const approvalResponseData: ProviderData.HostedMCPApprovalResponse = {
          approve: approvalResult.approve,
          approval_request_id: requestData.id,
          reason: approvalResult.reason,
        };
        newItems.push(
          new RunToolCallItem(
            {
              type: 'hosted_tool_call',
              name: 'mcp_approval_response',
              providerData: approvalResponseData,
            },
            agent as Agent<unknown, 'text'>,
          ),
        );
      } else {
        // receive a user's approval on the next turn
        newItems.push(approvalRequest.requestItem);
        const approvalItem = {
          type: 'hosted_mcp_tool_approval' as const,
          tool: approvalRequest.mcpTool,
          runItem: new RunToolApprovalItem(
            {
              type: 'hosted_tool_call',
              name: requestData.name,
              id: requestData.id,
              arguments: requestData.arguments,
              status: 'in_progress',
              providerData: requestData,
            },
            agent,
          ),
        };
        functionResults.push(approvalItem);
        // newItems.push(approvalItem.runItem);
      }
    }
  }

  // process handoffs
  if (processedResponse.handoffs.length > 0) {
    return await executeHandoffCalls(
      agent,
      originalInput,
      preStepItems,
      newItems,
      newResponse,
      processedResponse.handoffs,
      runner,
      state._context,
    );
  }

  const checkToolOutput = await checkForFinalOutputFromTools(
    agent,
    functionResults,
    state,
  );

  if (checkToolOutput.isFinalOutput) {
    runner.emit(
      'agent_end',
      state._context,
      agent,
      checkToolOutput.finalOutput,
    );
    agent.emit('agent_end', state._context, checkToolOutput.finalOutput);

    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      {
        type: 'next_step_final_output',
        output: checkToolOutput.finalOutput,
      },
    );
  } else if (checkToolOutput.isInterrupted) {
    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      {
        type: 'next_step_interruption',
        data: {
          interruptions: checkToolOutput.interruptions,
        },
      },
    );
  }

  // check if the agent produced any messages
  const messageItems = newItems.filter(
    (item) => item instanceof RunMessageOutputItem,
  );

  // we will use the last content output as the final output
  const potentialFinalOutput =
    messageItems.length > 0
      ? getLastTextFromOutputMessage(
          messageItems[messageItems.length - 1].rawItem,
        )
      : undefined;

  // if there is no output we just run again
  if (!potentialFinalOutput) {
    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      { type: 'next_step_run_again' },
    );
  }

  if (
    agent.outputType === 'text' &&
    !processedResponse.hasToolsOrApprovalsToRun()
  ) {
    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      {
        type: 'next_step_final_output',
        output: potentialFinalOutput,
      },
    );
  } else if (agent.outputType !== 'text' && potentialFinalOutput) {
    // Structured output schema => always leads to a final output if we have text
    const { parser } = getSchemaAndParserFromInputType(
      agent.outputType,
      'final_output',
    );
    const [error] = await safeExecute(() => parser(potentialFinalOutput));
    if (error) {
      addErrorToCurrentSpan({
        message: 'Invalid output type',
        data: {
          error: String(error),
        },
      });
      throw new ModelBehaviorError('Invalid output type');
    }

    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newItems,
      { type: 'next_step_final_output', output: potentialFinalOutput },
    );
  }

  return new SingleStepResult(
    originalInput,
    newResponse,
    preStepItems,
    newItems,
    { type: 'next_step_run_again' },
  );
}

/**
 * @internal
 */
export function getToolCallOutputItem(
  toolCall: protocol.FunctionCallItem,
  output: string | unknown,
): FunctionCallResultItem {
  return {
    type: 'function_call_result',
    name: toolCall.name,
    callId: toolCall.callId,
    status: 'completed',
    output: {
      type: 'text',
      text: toSmartString(output),
    },
  };
}

/**
 * @internal
 */
export async function executeFunctionToolCalls<TContext = UnknownContext>(
  agent: Agent<any, any>,
  toolRuns: ToolRunFunction<unknown>[],
  runner: Runner,
  state: RunState<TContext, Agent<any, any>>,
): Promise<FunctionToolResult[]> {
  async function runSingleTool(toolRun: ToolRunFunction<unknown>) {
    let parsedArgs: any = toolRun.toolCall.arguments;
    if (toolRun.tool.parameters) {
      if (isZodObject(toolRun.tool.parameters)) {
        parsedArgs = toolRun.tool.parameters.parse(parsedArgs);
      } else {
        parsedArgs = JSON.parse(parsedArgs);
      }
    }
    const needsApproval = await toolRun.tool.needsApproval(
      state._context,
      parsedArgs,
      toolRun.toolCall.callId,
    );

    if (needsApproval) {
      const approval = state._context.isToolApproved({
        toolName: toolRun.tool.name,
        callId: toolRun.toolCall.callId,
      });

      if (approval === false) {
        // rejected
        return withFunctionSpan(
          async (span) => {
            const response = 'Tool execution was not approved.';

            span.setError({
              message: response,
              data: {
                tool_name: toolRun.tool.name,
                error: `Tool execution for ${toolRun.toolCall.callId} was manually rejected by user.`,
              },
            });

            span.spanData.output = response;
            return {
              type: 'function_output' as const,
              tool: toolRun.tool,
              output: response,
              runItem: new RunToolCallOutputItem(
                getToolCallOutputItem(toolRun.toolCall, response),
                agent,
                response,
              ),
            };
          },
          {
            data: {
              name: toolRun.tool.name,
            },
          },
        );
      }

      if (approval !== true) {
        // this approval process needs to be done in the next turn
        return {
          type: 'function_approval' as const,
          tool: toolRun.tool,
          runItem: new RunToolApprovalItem(toolRun.toolCall, agent),
        };
      }
    }

    return withFunctionSpan(
      async (span) => {
        if (runner.config.traceIncludeSensitiveData) {
          span.spanData.input = toolRun.toolCall.arguments;
        }

        try {
          runner.emit('agent_tool_start', state._context, agent, toolRun.tool, {
            toolCall: toolRun.toolCall,
          });
          agent.emit('agent_tool_start', state._context, toolRun.tool, {
            toolCall: toolRun.toolCall,
          });
          const result = await toolRun.tool.invoke(
            state._context,
            toolRun.toolCall.arguments,
          );
          // Use string data for tracing and event emitter
          const stringResult = toSmartString(result);

          runner.emit(
            'agent_tool_end',
            state._context,
            agent,
            toolRun.tool,
            stringResult,
            { toolCall: toolRun.toolCall },
          );
          agent.emit(
            'agent_tool_end',
            state._context,
            toolRun.tool,
            stringResult,
            { toolCall: toolRun.toolCall },
          );

          if (runner.config.traceIncludeSensitiveData) {
            span.spanData.output = stringResult;
          }

          return {
            type: 'function_output' as const,
            tool: toolRun.tool,
            output: result,
            runItem: new RunToolCallOutputItem(
              getToolCallOutputItem(toolRun.toolCall, result),
              agent,
              result,
            ),
          };
        } catch (error) {
          span.setError({
            message: 'Error running tool',
            data: {
              tool_name: toolRun.tool.name,
              error: String(error),
            },
          });
          throw error;
        }
      },
      {
        data: {
          name: toolRun.tool.name,
        },
      },
    );
  }

  try {
    const results = await Promise.all(toolRuns.map(runSingleTool));
    return results;
  } catch (e: unknown) {
    throw new ToolCallError(
      `Failed to run function tools: ${e}`,
      e as Error,
      state,
    );
  }
}

/**
 * @internal
 */
// Internal helper: dispatch a computer action and return a screenshot (sync/async)
async function _runComputerActionAndScreenshot(
  computer: Computer,
  toolCall: protocol.ComputerUseCallItem,
): Promise<string> {
  const action = toolCall.action;
  let screenshot: string | undefined;
  // Dispatch based on action type string (assume action.type exists)
  switch (action.type) {
    case 'click':
      await computer.click(action.x, action.y, action.button);
      break;
    case 'double_click':
      await computer.doubleClick(action.x, action.y);
      break;
    case 'drag':
      await computer.drag(action.path.map((p: any) => [p.x, p.y]));
      break;
    case 'keypress':
      await computer.keypress(action.keys);
      break;
    case 'move':
      await computer.move(action.x, action.y);
      break;
    case 'screenshot':
      screenshot = await computer.screenshot();
      break;
    case 'scroll':
      await computer.scroll(
        action.x,
        action.y,
        action.scroll_x,
        action.scroll_y,
      );
      break;
    case 'type':
      await computer.type(action.text);
      break;
    case 'wait':
      await computer.wait();
      break;
    default:
      action satisfies never; // ensures that we handle every action we know of
      // Unknown action, just take screenshot
      break;
  }
  if (typeof screenshot !== 'undefined') {
    return screenshot;
  }
  // Always return screenshot as base64 string
  if (typeof computer.screenshot === 'function') {
    screenshot = await computer.screenshot();
    if (typeof screenshot !== 'undefined') {
      return screenshot;
    }
  }
  throw new Error('Computer does not implement screenshot()');
}

/**
 * @internal
 */
export async function executeComputerActions(
  agent: Agent<any, any>,
  actions: ToolRunComputer[],
  runner: Runner,
  runContext: RunContext,
  customLogger: Logger | undefined = undefined,
): Promise<RunItem[]> {
  const _logger = customLogger ?? logger;
  const results: RunItem[] = [];
  for (const action of actions) {
    const computer = action.computer.computer;
    const toolCall = action.toolCall;

    // Hooks: on_tool_start (global + agent)
    runner.emit('agent_tool_start', runContext, agent, action.computer, {
      toolCall,
    });
    if (typeof agent.emit === 'function') {
      agent.emit('agent_tool_start', runContext, action.computer, { toolCall });
    }

    // Run the action and get screenshot
    let output: string;
    try {
      output = await _runComputerActionAndScreenshot(computer, toolCall);
    } catch (err) {
      _logger.error('Failed to execute computer action:', err);
      output = '';
    }

    // Hooks: on_tool_end (global + agent)
    runner.emit('agent_tool_end', runContext, agent, action.computer, output, {
      toolCall,
    });
    if (typeof agent.emit === 'function') {
      agent.emit('agent_tool_end', runContext, action.computer, output, {
        toolCall,
      });
    }

    // Always return a screenshot as a base64 data URL
    const imageUrl = output ? `data:image/png;base64,${output}` : '';
    const rawItem: protocol.ComputerCallResultItem = {
      type: 'computer_call_result',
      callId: toolCall.callId,
      output: { type: 'computer_screenshot', data: imageUrl },
    };
    results.push(new RunToolCallOutputItem(rawItem, agent, imageUrl));
  }
  return results;
}

/**
 * @internal
 */
export async function executeHandoffCalls<
  TContext,
  TOutput extends AgentOutputType,
>(
  agent: Agent<TContext, TOutput>,
  originalInput: string | AgentInputItem[],
  preStepItems: RunItem[],
  newStepItems: RunItem[],
  newResponse: ModelResponse,
  runHandoffs: ToolRunHandoff[],
  runner: Runner,
  runContext: RunContext<TContext>,
): Promise<SingleStepResult> {
  newStepItems = [...newStepItems];

  if (runHandoffs.length === 0) {
    logger.warn(
      'Incorrectly called executeHandoffCalls with no handoffs. This should not happen. Moving on.',
    );
    return new SingleStepResult(
      originalInput,
      newResponse,
      preStepItems,
      newStepItems,
      { type: 'next_step_run_again' },
    );
  }

  if (runHandoffs.length > 1) {
    // multiple handoffs. Ignoring all but the first one by adding reject responses for those
    const outputMessage = 'Multiple handoffs detected, ignoring this one.';
    for (let i = 1; i < runHandoffs.length; i++) {
      newStepItems.push(
        new RunToolCallOutputItem(
          getToolCallOutputItem(runHandoffs[i].toolCall, outputMessage),
          agent,
          outputMessage,
        ),
      );
    }
  }

  const actualHandoff = runHandoffs[0];

  return withHandoffSpan(
    async (handoffSpan) => {
      const handoff = actualHandoff.handoff;

      const newAgent = await handoff.onInvokeHandoff(
        runContext,
        actualHandoff.toolCall.arguments,
      );

      handoffSpan.spanData.to_agent = newAgent.name;

      if (runHandoffs.length > 1) {
        const requestedAgents = runHandoffs.map((h) => h.handoff.agentName);
        handoffSpan.setError({
          message: 'Multiple handoffs requested',
          data: {
            requested_agents: requestedAgents,
          },
        });
      }

      newStepItems.push(
        new RunHandoffOutputItem(
          getToolCallOutputItem(
            actualHandoff.toolCall,
            getTransferMessage(newAgent),
          ),
          agent,
          newAgent,
        ),
      );

      runner.emit('agent_handoff', runContext, agent, newAgent);
      agent.emit('agent_handoff', runContext, newAgent);

      const inputFilter =
        handoff.inputFilter ?? runner.config.handoffInputFilter;
      if (inputFilter) {
        logger.debug('Filtering inputs for handoff');

        if (typeof inputFilter !== 'function') {
          handoffSpan.setError({
            message: 'Invalid input filter',
            data: {
              details: 'not callable',
            },
          });
        }

        const handoffInputData: HandoffInputData = {
          inputHistory: Array.isArray(originalInput)
            ? [...originalInput]
            : originalInput,
          preHandoffItems: [...preStepItems],
          newItems: [...newStepItems],
        };

        const filtered = inputFilter(handoffInputData);

        originalInput = filtered.inputHistory;
        preStepItems = filtered.preHandoffItems;
        newStepItems = filtered.newItems;
      }

      return new SingleStepResult(
        originalInput,
        newResponse,
        preStepItems,
        newStepItems,
        { type: 'next_step_handoff', newAgent },
      );
    },
    {
      data: {
        from_agent: agent.name,
      },
    },
  );
}

const NOT_FINAL_OUTPUT: ToolsToFinalOutputResult = {
  isFinalOutput: false,
  isInterrupted: undefined,
};

/**
 * @internal
 */
export async function checkForFinalOutputFromTools<
  TContext,
  TOutput extends AgentOutputType,
>(
  agent: Agent<TContext, TOutput>,
  toolResults: FunctionToolResult[],
  state: RunState<TContext, Agent<TContext, TOutput>>,
): Promise<ToolsToFinalOutputResult> {
  if (toolResults.length === 0) {
    return NOT_FINAL_OUTPUT;
  }

  const interruptions: RunToolApprovalItem[] = toolResults
    .filter((r) => r.runItem instanceof RunToolApprovalItem)
    .map((r) => r.runItem as RunToolApprovalItem);

  if (interruptions.length > 0) {
    return {
      isFinalOutput: false,
      isInterrupted: true,
      interruptions,
    };
  }

  if (agent.toolUseBehavior === 'run_llm_again') {
    return NOT_FINAL_OUTPUT;
  }

  const firstToolResult = toolResults[0];
  if (agent.toolUseBehavior === 'stop_on_first_tool') {
    if (firstToolResult?.type === 'function_output') {
      const stringOutput = toSmartString(firstToolResult.output);
      return {
        isFinalOutput: true,
        isInterrupted: undefined,
        finalOutput: stringOutput,
      };
    }
    return NOT_FINAL_OUTPUT;
  }

  const toolUseBehavior = agent.toolUseBehavior;
  if (typeof toolUseBehavior === 'object') {
    const stoppingTool = toolResults.find((r) =>
      toolUseBehavior.stopAtToolNames.includes(r.tool.name),
    );
    if (stoppingTool?.type === 'function_output') {
      const stringOutput = toSmartString(stoppingTool.output);
      return {
        isFinalOutput: true,
        isInterrupted: undefined,
        finalOutput: stringOutput,
      };
    }
    return NOT_FINAL_OUTPUT;
  }

  if (typeof toolUseBehavior === 'function') {
    return toolUseBehavior(state._context, toolResults);
  }

  throw new UserError(`Invalid toolUseBehavior: ${toolUseBehavior}`, state);
}

export function addStepToRunResult(
  result: StreamedRunResult<any, any>,
  step: SingleStepResult,
): void {
  for (const item of step.newStepItems) {
    let itemName: RunItemStreamEventName;
    if (item instanceof RunMessageOutputItem) {
      itemName = 'message_output_created';
    } else if (item instanceof RunHandoffCallItem) {
      itemName = 'handoff_requested';
    } else if (item instanceof RunHandoffOutputItem) {
      itemName = 'handoff_occurred';
    } else if (item instanceof RunToolCallItem) {
      itemName = 'tool_called';
    } else if (item instanceof RunToolCallOutputItem) {
      itemName = 'tool_output';
    } else if (item instanceof RunReasoningItem) {
      itemName = 'reasoning_item_created';
    } else if (item instanceof RunToolApprovalItem) {
      itemName = 'tool_approval_requested';
    } else {
      logger.warn('Unknown item type: ', item);
      continue;
    }

    result._addItem(new RunItemStreamEvent(itemName, item));
  }
}

export class AgentToolUseTracker {
  #agentToTools = new Map<Agent<any, any>, string[]>();

  addToolUse(agent: Agent<any, any>, toolNames: string[]): void {
    this.#agentToTools.set(agent, toolNames);
  }

  hasUsedTools(agent: Agent<any, any>): boolean {
    return this.#agentToTools.has(agent);
  }

  toJSON(): Record<string, string[]> {
    return Object.fromEntries(
      Array.from(this.#agentToTools.entries()).map(([agent, toolNames]) => {
        return [agent.name, toolNames];
      }),
    );
  }
}



---
File: /packages/agents-core/src/runState.ts
---

import { z } from '@openai/zod/v3';
import { Agent } from './agent';
import {
  RunMessageOutputItem,
  RunItem,
  RunToolApprovalItem,
  RunToolCallItem,
  RunToolCallOutputItem,
  RunReasoningItem,
  RunHandoffCallItem,
  RunHandoffOutputItem,
} from './items';
import type { ModelResponse } from './model';
import { RunContext } from './runContext';
import {
  AgentToolUseTracker,
  nextStepSchema,
  NextStep,
  ProcessedResponse,
} from './runImplementation';
import type { AgentSpanData } from './tracing/spans';
import type { Span } from './tracing/spans';
import { SystemError, UserError } from './errors';
import { getGlobalTraceProvider } from './tracing/provider';
import { Usage } from './usage';
import { Trace } from './tracing/traces';
import { getCurrentTrace } from './tracing';
import logger from './logger';
import { handoff } from './handoff';
import * as protocol from './types/protocol';
import { AgentInputItem, UnknownContext } from './types';
import type { InputGuardrailResult, OutputGuardrailResult } from './guardrail';
import { safeExecute } from './utils/safeExecute';
import { HostedMCPTool } from './tool';

/**
 * The schema version of the serialized run state. This is used to ensure that the serialized
 * run state is compatible with the current version of the SDK.
 * If anything in this schema changes, the version will have to be incremented.
 */
export const CURRENT_SCHEMA_VERSION = '1.0' as const;
const $schemaVersion = z.literal(CURRENT_SCHEMA_VERSION);

const serializedAgentSchema = z.object({
  name: z.string(),
});

const serializedSpanBase = z.object({
  object: z.literal('trace.span'),
  id: z.string(),
  trace_id: z.string(),
  parent_id: z.string().nullable(),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  error: z
    .object({
      message: z.string(),
      data: z.record(z.string(), z.any()).optional(),
    })
    .nullable(),
  span_data: z.record(z.string(), z.any()),
});

type SerializedSpanType = z.infer<typeof serializedSpanBase> & {
  previous_span?: SerializedSpanType;
};

const SerializedSpan: z.ZodType<SerializedSpanType> = serializedSpanBase.extend(
  {
    previous_span: z.lazy(() => SerializedSpan).optional(),
  },
);

const usageSchema = z.object({
  requests: z.number(),
  inputTokens: z.number(),
  outputTokens: z.number(),
  totalTokens: z.number(),
});

const modelResponseSchema = z.object({
  usage: usageSchema,
  output: z.array(protocol.OutputModelItem),
  responseId: z.string().optional(),
  providerData: z.record(z.string(), z.any()).optional(),
});

const itemSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('message_output_item'),
    rawItem: protocol.AssistantMessageItem,
    agent: serializedAgentSchema,
  }),
  z.object({
    type: z.literal('tool_call_item'),
    rawItem: protocol.ToolCallItem.or(protocol.HostedToolCallItem),
    agent: serializedAgentSchema,
  }),
  z.object({
    type: z.literal('tool_call_output_item'),
    rawItem: protocol.FunctionCallResultItem,
    agent: serializedAgentSchema,
    output: z.string(),
  }),
  z.object({
    type: z.literal('reasoning_item'),
    rawItem: protocol.ReasoningItem,
    agent: serializedAgentSchema,
  }),
  z.object({
    type: z.literal('handoff_call_item'),
    rawItem: protocol.FunctionCallItem,
    agent: serializedAgentSchema,
  }),
  z.object({
    type: z.literal('handoff_output_item'),
    rawItem: protocol.FunctionCallResultItem,
    sourceAgent: serializedAgentSchema,
    targetAgent: serializedAgentSchema,
  }),
  z.object({
    type: z.literal('tool_approval_item'),
    rawItem: protocol.FunctionCallItem.or(protocol.HostedToolCallItem),
    agent: serializedAgentSchema,
  }),
]);

const serializedTraceSchema = z.object({
  object: z.literal('trace'),
  id: z.string(),
  workflow_name: z.string(),
  group_id: z.string().nullable(),
  metadata: z.record(z.string(), z.any()),
});

const serializedProcessedResponseSchema = z.object({
  newItems: z.array(itemSchema),
  toolsUsed: z.array(z.string()),
  handoffs: z.array(
    z.object({
      toolCall: z.any(),
      handoff: z.any(),
    }),
  ),
  functions: z.array(
    z.object({
      toolCall: z.any(),
      tool: z.any(),
    }),
  ),
  computerActions: z.array(
    z.object({
      toolCall: z.any(),
      computer: z.any(),
    }),
  ),
  mcpApprovalRequests: z
    .array(
      z.object({
        requestItem: z.object({
          // protocol.HostedToolCallItem
          rawItem: z.object({
            type: z.literal('hosted_tool_call'),
            name: z.string(),
            arguments: z.string().optional(),
            status: z.string().optional(),
            output: z.string().optional(),
            // this always exists but marked as optional for early version compatibility; when releasing 1.0, we can remove the nullable and optional
            providerData: z.record(z.string(), z.any()).nullable().optional(),
          }),
        }),
        // HostedMCPTool
        mcpTool: z.object({
          type: z.literal('hosted_tool'),
          name: z.literal('hosted_mcp'),
          providerData: z.record(z.string(), z.any()),
        }),
      }),
    )
    .optional(),
});

const guardrailFunctionOutputSchema = z.object({
  tripwireTriggered: z.boolean(),
  outputInfo: z.any(),
});

const inputGuardrailResultSchema = z.object({
  guardrail: z.object({
    type: z.literal('input'),
    name: z.string(),
  }),
  output: guardrailFunctionOutputSchema,
});

const outputGuardrailResultSchema = z.object({
  guardrail: z.object({
    type: z.literal('output'),
    name: z.string(),
  }),
  agentOutput: z.any(),
  agent: serializedAgentSchema,
  output: guardrailFunctionOutputSchema,
});

export const SerializedRunState = z.object({
  $schemaVersion,
  currentTurn: z.number(),
  currentAgent: serializedAgentSchema,
  originalInput: z.string().or(z.array(protocol.ModelItem)),
  modelResponses: z.array(modelResponseSchema),
  context: z.object({
    usage: usageSchema,
    approvals: z.record(
      z.string(),
      z.object({
        approved: z.array(z.string()).or(z.boolean()),
        rejected: z.array(z.string()).or(z.boolean()),
      }),
    ),
    context: z.record(z.string(), z.any()),
  }),
  toolUseTracker: z.record(z.string(), z.array(z.string())),
  maxTurns: z.number(),
  currentAgentSpan: SerializedSpan.nullable().optional(),
  noActiveAgentRun: z.boolean(),
  inputGuardrailResults: z.array(inputGuardrailResultSchema),
  outputGuardrailResults: z.array(outputGuardrailResultSchema),
  currentStep: nextStepSchema.optional(),
  lastModelResponse: modelResponseSchema.optional(),
  generatedItems: z.array(itemSchema),
  lastProcessedResponse: serializedProcessedResponseSchema.optional(),
  trace: serializedTraceSchema.nullable(),
});

/**
 * Serializable snapshot of an agent's run, including context, usage and trace.
 * While this class has publicly writable properties (prefixed with `_`), they are not meant to be
 * used directly. To read these properties, use the `RunResult` instead.
 *
 * Manipulation of the state directly can lead to unexpected behavior and should be avoided.
 * Instead, use the `approve` and `reject` methods to interact with the state.
 */
export class RunState<TContext, TAgent extends Agent<any, any>> {
  /**
   * Current turn number in the conversation.
   */
  public _currentTurn = 0;
  /**
   * The agent currently handling the conversation.
   */
  public _currentAgent: TAgent;
  /**
   * Original user input prior to any processing.
   */
  public _originalInput: string | AgentInputItem[];
  /**
   * Responses from the model so far.
   */
  public _modelResponses: ModelResponse[];
  /**
   * Active tracing span for the current agent if tracing is enabled.
   */
  public _currentAgentSpan: Span<AgentSpanData> | undefined;
  /**
   * Run context tracking approvals, usage, and other metadata.
   */
  public _context: RunContext<TContext>;
  /**
   * Tracks what tools each agent has used.
   */
  public _toolUseTracker: AgentToolUseTracker;
  /**
   * Items generated by the agent during the run.
   */
  public _generatedItems: RunItem[];
  /**
   * Maximum allowed turns before forcing termination.
   */
  public _maxTurns: number;
  /**
   * Whether the run has an active agent step in progress.
   */
  public _noActiveAgentRun = true;
  /**
   * Last model response for the previous turn.
   */
  public _lastTurnResponse: ModelResponse | undefined;
  /**
   * Results from input guardrails applied to the run.
   */
  public _inputGuardrailResults: InputGuardrailResult[];
  /**
   * Results from output guardrails applied to the run.
   */
  public _outputGuardrailResults: OutputGuardrailResult[];
  /**
   * Next step computed for the agent to take.
   */
  public _currentStep: NextStep | undefined = undefined;
  /**
   * Parsed model response after applying guardrails and tools.
   */
  public _lastProcessedResponse: ProcessedResponse<TContext> | undefined =
    undefined;
  /**
   * Trace associated with this run if tracing is enabled.
   */
  public _trace: Trace | null = null;

  constructor(
    context: RunContext<TContext>,
    originalInput: string | AgentInputItem[],
    startingAgent: TAgent,
    maxTurns: number,
  ) {
    this._context = context;
    this._originalInput = structuredClone(originalInput);
    this._modelResponses = [];
    this._currentAgentSpan = undefined;
    this._currentAgent = startingAgent;
    this._toolUseTracker = new AgentToolUseTracker();
    this._generatedItems = [];
    this._maxTurns = maxTurns;
    this._inputGuardrailResults = [];
    this._outputGuardrailResults = [];
    this._trace = getCurrentTrace();
  }

  /**
   * Returns all interruptions if the current step is an interruption otherwise returns an empty array.
   */
  getInterruptions() {
    if (this._currentStep?.type !== 'next_step_interruption') {
      return [];
    }
    return this._currentStep.data.interruptions;
  }

  /**
   * Approves a tool call requested by the agent through an interruption and approval item request.
   *
   * To approve the request use this method and then run the agent again with the same state object
   * to continue the execution.
   *
   * By default it will only approve the current tool call. To allow the tool to be used multiple
   * times throughout the run, set the `alwaysApprove` option to `true`.
   *
   * @param approvalItem - The tool call approval item to approve.
   * @param options - Options for the approval.
   */
  approve(
    approvalItem: RunToolApprovalItem,
    options: { alwaysApprove?: boolean } = { alwaysApprove: false },
  ) {
    this._context.approveTool(approvalItem, options);
  }

  /**
   * Rejects a tool call requested by the agent through an interruption and approval item request.
   *
   * To reject the request use this method and then run the agent again with the same state object
   * to continue the execution.
   *
   * By default it will only reject the current tool call. To allow the tool to be used multiple
   * times throughout the run, set the `alwaysReject` option to `true`.
   *
   * @param approvalItem - The tool call approval item to reject.
   * @param options - Options for the rejection.
   */
  reject(
    approvalItem: RunToolApprovalItem,
    options: { alwaysReject?: boolean } = { alwaysReject: false },
  ) {
    this._context.rejectTool(approvalItem, options);
  }

  /**
   * Serializes the run state to a JSON object.
   *
   * This method is used to serialize the run state to a JSON object that can be used to
   * resume the run later.
   *
   * @returns The serialized run state.
   */
  toJSON(): z.infer<typeof SerializedRunState> {
    const output = {
      $schemaVersion: CURRENT_SCHEMA_VERSION,
      currentTurn: this._currentTurn,
      currentAgent: {
        name: this._currentAgent.name,
      },
      originalInput: this._originalInput as any,
      modelResponses: this._modelResponses.map((response) => {
        return {
          usage: {
            requests: response.usage.requests,
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            totalTokens: response.usage.totalTokens,
          },
          output: response.output as any,
          responseId: response.responseId,
          providerData: response.providerData,
        };
      }),
      context: this._context.toJSON(),
      toolUseTracker: this._toolUseTracker.toJSON(),
      maxTurns: this._maxTurns,
      currentAgentSpan: this._currentAgentSpan?.toJSON() as any,
      noActiveAgentRun: this._noActiveAgentRun,
      inputGuardrailResults: this._inputGuardrailResults,
      outputGuardrailResults: this._outputGuardrailResults.map((r) => ({
        ...r,
        agent: r.agent.toJSON(),
      })),
      currentStep: this._currentStep as any,
      lastModelResponse: this._lastTurnResponse as any,
      generatedItems: this._generatedItems.map((item) => item.toJSON() as any),
      lastProcessedResponse: this._lastProcessedResponse as any,
      trace: this._trace ? (this._trace.toJSON() as any) : null,
    };

    // parsing the schema to ensure the output is valid for reparsing
    const parsed = SerializedRunState.safeParse(output);
    if (!parsed.success) {
      throw new SystemError(
        `Failed to serialize run state. ${parsed.error.message}`,
      );
    }

    return parsed.data;
  }

  /**
   * Serializes the run state to a string.
   *
   * This method is used to serialize the run state to a string that can be used to
   * resume the run later.
   *
   * @returns The serialized run state.
   */
  toString() {
    return JSON.stringify(this.toJSON());
  }

  /**
   * Deserializes a run state from a string.
   *
   * This method is used to deserialize a run state from a string that was serialized using the
   * `toString` method.
   */
  static async fromString<TContext, TAgent extends Agent<any, any>>(
    initialAgent: TAgent,
    str: string,
  ) {
    const [parsingError, jsonResult] = await safeExecute(() => JSON.parse(str));
    if (parsingError) {
      throw new UserError(
        `Failed to parse run state. ${parsingError instanceof Error ? parsingError.message : String(parsingError)}`,
      );
    }

    const currentSchemaVersion = jsonResult.$schemaVersion;
    if (!currentSchemaVersion) {
      throw new UserError('Run state is missing schema version');
    }
    if (currentSchemaVersion !== CURRENT_SCHEMA_VERSION) {
      throw new UserError(
        `Run state schema version ${currentSchemaVersion} is not supported. Please use version ${CURRENT_SCHEMA_VERSION}`,
      );
    }

    const stateJson = SerializedRunState.parse(JSON.parse(str));

    const agentMap = buildAgentMap(initialAgent);

    //
    // Rebuild the context
    //
    const context = new RunContext<TContext>(
      stateJson.context.context as TContext,
    );
    context._rebuildApprovals(stateJson.context.approvals);

    //
    // Find the current agent from the initial agent
    //
    const currentAgent = agentMap.get(stateJson.currentAgent.name);
    if (!currentAgent) {
      throw new UserError(`Agent ${stateJson.currentAgent.name} not found`);
    }

    const state = new RunState<TContext, TAgent>(
      context,
      '',
      currentAgent as TAgent,
      stateJson.maxTurns,
    );
    state._currentTurn = stateJson.currentTurn;

    // rebuild tool use tracker
    state._toolUseTracker = new AgentToolUseTracker();
    for (const [agentName, toolNames] of Object.entries(
      stateJson.toolUseTracker,
    )) {
      state._toolUseTracker.addToolUse(
        agentMap.get(agentName) as TAgent,
        toolNames,
      );
    }

    // rebuild current agent span
    if (stateJson.currentAgentSpan) {
      if (!stateJson.trace) {
        logger.warn('Trace is not set, skipping tracing setup');
      }

      const trace = getGlobalTraceProvider().createTrace({
        traceId: stateJson.trace?.id,
        name: stateJson.trace?.workflow_name,
        groupId: stateJson.trace?.group_id ?? undefined,
        metadata: stateJson.trace?.metadata,
      });

      state._currentAgentSpan = deserializeSpan(
        trace,
        stateJson.currentAgentSpan,
      );
      state._trace = trace;
    }
    state._noActiveAgentRun = stateJson.noActiveAgentRun;

    state._inputGuardrailResults =
      stateJson.inputGuardrailResults as InputGuardrailResult[];
    state._outputGuardrailResults = stateJson.outputGuardrailResults.map(
      (r) => ({
        ...r,
        agent: agentMap.get(r.agent.name) as Agent<any, any>,
      }),
    ) as OutputGuardrailResult[];

    state._currentStep = stateJson.currentStep;

    state._originalInput = stateJson.originalInput;
    state._modelResponses = stateJson.modelResponses.map(
      deserializeModelResponse,
    );
    state._lastTurnResponse = stateJson.lastModelResponse
      ? deserializeModelResponse(stateJson.lastModelResponse)
      : undefined;

    state._generatedItems = stateJson.generatedItems.map((item) =>
      deserializeItem(item, agentMap),
    );
    state._lastProcessedResponse = stateJson.lastProcessedResponse
      ? await deserializeProcessedResponse(
          agentMap,
          state._currentAgent,
          stateJson.lastProcessedResponse,
        )
      : undefined;

    if (stateJson.currentStep?.type === 'next_step_handoff') {
      state._currentStep = {
        type: 'next_step_handoff',
        newAgent: agentMap.get(stateJson.currentStep.newAgent.name) as TAgent,
      };
    }
    return state;
  }
}

/**
 * @internal
 */
export function buildAgentMap(
  initialAgent: Agent<any, any>,
): Map<string, Agent<any, any>> {
  const map = new Map<string, Agent<any, any>>();
  const queue: Agent<any, any>[] = [initialAgent];

  while (queue.length > 0) {
    const currentAgent = queue.shift()!;
    if (map.has(currentAgent.name)) {
      continue;
    }
    map.set(currentAgent.name, currentAgent);

    for (const handoff of currentAgent.handoffs) {
      if (handoff instanceof Agent) {
        if (!map.has(handoff.name)) {
          queue.push(handoff);
        }
      } else if (handoff.agent) {
        if (!map.has(handoff.agent.name)) {
          queue.push(handoff.agent);
        }
      }
    }
  }

  return map;
}

/**
 * @internal
 */
export function deserializeSpan(
  trace: Trace,
  serializedSpan: SerializedSpanType,
): Span<any> {
  const spanData = serializedSpan.span_data;
  const previousSpan = serializedSpan.previous_span
    ? deserializeSpan(trace, serializedSpan.previous_span)
    : undefined;

  const span = getGlobalTraceProvider().createSpan(
    {
      spanId: serializedSpan.id,
      traceId: serializedSpan.trace_id,
      parentId: serializedSpan.parent_id ?? undefined,
      startedAt: serializedSpan.started_at ?? undefined,
      endedAt: serializedSpan.ended_at ?? undefined,
      data: spanData as any,
    },
    trace,
  );
  span.previousSpan = previousSpan;

  return span;
}

/**
 * @internal
 */
export function deserializeModelResponse(
  serializedModelResponse: z.infer<typeof modelResponseSchema>,
): ModelResponse {
  const usage = new Usage();
  usage.requests = serializedModelResponse.usage.requests;
  usage.inputTokens = serializedModelResponse.usage.inputTokens;
  usage.outputTokens = serializedModelResponse.usage.outputTokens;
  usage.totalTokens = serializedModelResponse.usage.totalTokens;

  return {
    usage,
    output: serializedModelResponse.output.map((item) =>
      protocol.OutputModelItem.parse(item),
    ),
    responseId: serializedModelResponse.responseId,
    providerData: serializedModelResponse.providerData,
  };
}

/**
 * @internal
 */
export function deserializeItem(
  serializedItem: z.infer<typeof itemSchema>,
  agentMap: Map<string, Agent<any, any>>,
): RunItem {
  switch (serializedItem.type) {
    case 'message_output_item':
      return new RunMessageOutputItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
      );
    case 'tool_call_item':
      return new RunToolCallItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
      );
    case 'tool_call_output_item':
      return new RunToolCallOutputItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
        serializedItem.output,
      );
    case 'reasoning_item':
      return new RunReasoningItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
      );
    case 'handoff_call_item':
      return new RunHandoffCallItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
      );
    case 'handoff_output_item':
      return new RunHandoffOutputItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.sourceAgent.name) as Agent<any, any>,
        agentMap.get(serializedItem.targetAgent.name) as Agent<any, any>,
      );
    case 'tool_approval_item':
      return new RunToolApprovalItem(
        serializedItem.rawItem,
        agentMap.get(serializedItem.agent.name) as Agent<any, any>,
      );
  }
}

/**
 * @internal
 */
async function deserializeProcessedResponse<TContext = UnknownContext>(
  agentMap: Map<string, Agent<any, any>>,
  currentAgent: Agent<TContext, any>,
  serializedProcessedResponse: z.infer<
    typeof serializedProcessedResponseSchema
  >,
): Promise<ProcessedResponse<TContext>> {
  const allTools = await currentAgent.getAllTools();
  const tools = new Map(
    allTools
      .filter((tool) => tool.type === 'function')
      .map((tool) => [tool.name, tool]),
  );
  const computerTools = new Map(
    allTools
      .filter((tool) => tool.type === 'computer')
      .map((tool) => [tool.name, tool]),
  );
  const handoffs = new Map(
    currentAgent.handoffs.map((entry) => {
      if (entry instanceof Agent) {
        return [entry.name, handoff(entry)];
      }

      return [entry.toolName, entry];
    }),
  );

  const result = {
    newItems: serializedProcessedResponse.newItems.map((item) =>
      deserializeItem(item, agentMap),
    ),
    toolsUsed: serializedProcessedResponse.toolsUsed,
    handoffs: serializedProcessedResponse.handoffs.map((handoff) => {
      if (!handoffs.has(handoff.handoff.toolName)) {
        throw new UserError(`Handoff ${handoff.handoff.toolName} not found`);
      }

      return {
        toolCall: handoff.toolCall,
        handoff: handoffs.get(handoff.handoff.toolName)!,
      };
    }),
    functions: await Promise.all(
      serializedProcessedResponse.functions.map(async (functionCall) => {
        if (!tools.has(functionCall.tool.name)) {
          throw new UserError(`Tool ${functionCall.tool.name} not found`);
        }

        return {
          toolCall: functionCall.toolCall,
          tool: tools.get(functionCall.tool.name)!,
        };
      }),
    ),
    computerActions: serializedProcessedResponse.computerActions.map(
      (computerAction) => {
        const toolName = computerAction.computer.name;
        if (!computerTools.has(toolName)) {
          throw new UserError(`Computer tool ${toolName} not found`);
        }

        return {
          toolCall: computerAction.toolCall,
          computer: computerTools.get(toolName)!,
        };
      },
    ),
    mcpApprovalRequests: (
      serializedProcessedResponse.mcpApprovalRequests ?? []
    ).map((approvalRequest) => ({
      requestItem: new RunToolApprovalItem(
        approvalRequest.requestItem
          .rawItem as unknown as protocol.HostedToolCallItem,
        currentAgent,
      ),
      mcpTool: approvalRequest.mcpTool as unknown as HostedMCPTool,
    })),
  };

  return {
    ...result,
    hasToolsOrApprovalsToRun(): boolean {
      return (
        result.handoffs.length > 0 ||
        result.functions.length > 0 ||
        result.mcpApprovalRequests.length > 0 ||
        result.computerActions.length > 0
      );
    },
  };
}



---
File: /packages/agents-core/src/tool.ts
---

import type { Computer } from './computer';
import type { infer as zInfer, ZodObject } from 'zod/v3';
import {
  JsonObjectSchema,
  JsonObjectSchemaNonStrict,
  JsonObjectSchemaStrict,
  UnknownContext,
} from './types';
import { safeExecute } from './utils/safeExecute';
import { toFunctionToolName } from './utils/tools';
import { getSchemaAndParserFromInputType } from './utils/tools';
import { isZodObject } from './utils/typeGuards';
import { RunContext } from './runContext';
import { ModelBehaviorError, UserError } from './errors';
import logger from './logger';
import { getCurrentSpan } from './tracing';
import { RunToolApprovalItem, RunToolCallOutputItem } from './items';
import { toSmartString } from './utils/smartString';
import * as ProviderData from './types/providerData';

/**
 * A function that determines if a tool call should be approved.
 *
 * @param runContext The current run context
 * @param input The input to the tool
 * @param callId The ID of the tool call
 * @returns True if the tool call should be approved, false otherwise
 */
export type ToolApprovalFunction<TParameters extends ToolInputParameters> = (
  runContext: RunContext,
  input: ToolExecuteArgument<TParameters>,
  callId?: string,
) => Promise<boolean>;

/**
 * Exposes a function to the agent as a tool to be called
 *
 * @param Context The context of the tool
 * @param Result The result of the tool
 */
export type FunctionTool<
  Context = UnknownContext,
  TParameters extends ToolInputParameters = undefined,
  Result = unknown,
> = {
  type: 'function';
  /**
   * The name of the tool.
   */
  name: string;
  /**
   * The description of the tool that helps the model to understand when to use the tool
   */
  description: string;
  /**
   * A JSON schema describing the parameters of the tool.
   */
  parameters: JsonObjectSchema<any>;
  /**
   * Whether the tool is strict. If true, the model must try to strictly follow the schema (might result in slower response times).
   */
  strict: boolean;

  /**
   * The function to invoke when the tool is called.
   */
  invoke: (
    runContext: RunContext<Context>,
    input: string,
  ) => Promise<string | Result>;

  /**
   * Whether the tool needs human approval before it can be called. If this is true, the run will result in an `interruption` that the
   * program has to resolve by approving or rejecting the tool call.
   */
  needsApproval: ToolApprovalFunction<TParameters>;
};

/**
 * Exposes a computer to the model as a tool to be called
 *
 * @param Context The context of the tool
 * @param Result The result of the tool
 */
export type ComputerTool = {
  type: 'computer';
  /**
   * The name of the tool.
   */
  name: 'computer_use_preview' | string;

  /**
   * The computer to use.
   */
  computer: Computer;
};

/**
 * Exposes a computer to the agent as a tool to be called
 *
 * @param options Additional configuration for the computer tool like specifying the location of your agent
 * @returns a computer tool definition
 */
export function computerTool(
  options: Partial<Omit<ComputerTool, 'type'>> & { computer: Computer },
): ComputerTool {
  return {
    type: 'computer',
    name: options.name ?? 'computer_use_preview',
    computer: options.computer,
  };
}

export type HostedMCPApprovalFunction<Context = UnknownContext> = (
  context: RunContext<Context>,
  data: RunToolApprovalItem,
) => Promise<{ approve: boolean; reason?: string }>;

/**
 * A hosted MCP tool that lets the model call a remote MCP server directly
 * without a round trip back to your code.
 */
export type HostedMCPTool<Context = UnknownContext> = HostedTool & {
  name: 'hosted_mcp';
  providerData: ProviderData.HostedMCPTool<Context>;
};

/**
 * Creates a hosted MCP tool definition.
 *
 * @param serverLabel - The label identifying the MCP server.
 * @param serverUrl - The URL of the MCP server.
 * @param requireApproval - Whether tool calls require approval.
 */
export function hostedMcpTool<Context = UnknownContext>(
  options: {
    serverLabel: string;
    serverUrl: string;
    allowedTools?: string[] | { toolNames?: string[] };
    headers?: Record<string, string>;
  } & (
    | { requireApproval?: never }
    | { requireApproval: 'never' }
    | {
        requireApproval:
          | 'always'
          | {
              never?: { toolNames: string[] };
              always?: { toolNames: string[] };
            };
        onApproval?: HostedMCPApprovalFunction<Context>;
      }
  ),
): HostedMCPTool<Context> {
  const providerData: ProviderData.HostedMCPTool<Context> =
    typeof options.requireApproval === 'undefined' ||
    options.requireApproval === 'never'
      ? {
          type: 'mcp',
          server_label: options.serverLabel,
          server_url: options.serverUrl,
          require_approval: 'never',
          allowed_tools: toMcpAllowedToolsFilter(options.allowedTools),
          headers: options.headers,
        }
      : {
          type: 'mcp',
          server_label: options.serverLabel,
          server_url: options.serverUrl,
          allowed_tools: toMcpAllowedToolsFilter(options.allowedTools),
          headers: options.headers,
          require_approval:
            typeof options.requireApproval === 'string'
              ? 'always'
              : buildRequireApproval(options.requireApproval),
          on_approval: options.onApproval,
        };
  return {
    type: 'hosted_tool',
    name: 'hosted_mcp',
    providerData,
  };
}

/**
 * A built-in hosted tool that will be executed directly by the model during the request and won't result in local code executions.
 * Examples of these are `web_search_call` or `file_search_call`.
 *
 * @param Context The context of the tool
 * @param Result The result of the tool
 */
export type HostedTool = {
  type: 'hosted_tool';
  /**
   * A unique name for the tool.
   */
  name: string;
  /**
   * Additional configuration data that gets passed to the tool
   */
  providerData?: Record<string, any>;
};

/**
 * A tool that can be called by the model.
 * @template Context The context passed to the tool
 */
export type Tool<Context = unknown> =
  | FunctionTool<Context, any, any>
  | ComputerTool
  | HostedTool;

/**
 * The result of invoking a function tool. Either the actual output of the execution or a tool
 * approval request.
 *
 * These get passed for example to the `toolUseBehavior` option of the `Agent` constructor.
 */
export type FunctionToolResult<
  Context = UnknownContext,
  TParameters extends ToolInputParameters = any,
  Result = any,
> =
  | {
      type: 'function_output';
      /**
       * The tool that was called.
       */
      tool: FunctionTool<Context, TParameters, Result>;
      /**
       * The output of the tool call. This can be a string or a stringifable item.
       */
      output: string | unknown;
      /**
       * The run item representing the tool call output.
       */
      runItem: RunToolCallOutputItem;
    }
  | {
      /**
       * Indicates that the tool requires approval before it can be called.
       */
      type: 'function_approval';
      /**
       * The tool that is requiring to be approved.
       */
      tool: FunctionTool<Context, TParameters, Result>;
      /**
       * The item representing the tool call that is requiring approval.
       */
      runItem: RunToolApprovalItem;
    }
  | {
      /**
       * Indicates that the tool requires approval before it can be called.
       */
      type: 'hosted_mcp_tool_approval';
      /**
       * The tool that is requiring to be approved.
       */
      tool: HostedMCPTool<Context>;
      /**
       * The item representing the tool call that is requiring approval.
       */
      runItem: RunToolApprovalItem;
    };

/**
 * The parameters of a tool.
 *
 * This can be a Zod schema, a JSON schema or undefined.
 *
 * If a Zod schema is provided, the arguments to the tool will automatically be parsed and validated
 * against the schema.
 *
 * If a JSON schema is provided, the arguments to the tool will be passed as is.
 *
 * If undefined is provided, the arguments to the tool will be passed as a string.
 */
export type ToolInputParameters =
  | undefined
  | ZodObject<any>
  | JsonObjectSchema<any>;

/**
 * The parameters of a tool that has strict mode enabled.
 *
 * This can be a Zod schema, a JSON schema or undefined.
 *
 * If a Zod schema is provided, the arguments to the tool will automatically be parsed and validated
 * against the schema.
 *
 * If a JSON schema is provided, the arguments to the tool will be parsed as JSON but not validated.
 *
 * If undefined is provided, the arguments to the tool will be passed as a string.
 */
export type ToolInputParametersStrict =
  | undefined
  | ZodObject<any>
  | JsonObjectSchemaStrict<any>;

/**
 * The parameters of a tool that has strict mode disabled.
 *
 * If a JSON schema is provided, the arguments to the tool will be parsed as JSON but not validated.
 *
 * Zod schemas are not supported without strict: true.
 */
export type ToolInputParametersNonStrict =
  | undefined
  | JsonObjectSchemaNonStrict<any>;

/**
 * The arguments to a tool.
 *
 * The type of the arguments are derived from the parameters passed to the tool definition.
 *
 * If the parameters are passed as a JSON schema the type is `unknown`. For Zod schemas it will
 * match the inferred Zod type. Otherwise the type is `string`
 */
export type ToolExecuteArgument<TParameters extends ToolInputParameters> =
  TParameters extends ZodObject<any>
    ? zInfer<TParameters>
    : TParameters extends JsonObjectSchema<any>
      ? unknown
      : string;

/**
 * The function to invoke when the tool is called.
 *
 * @param input The arguments to the tool (see ToolExecuteArgument)
 * @param context An instance of the current RunContext
 */
type ToolExecuteFunction<
  TParameters extends ToolInputParameters,
  Context = UnknownContext,
> = (
  input: ToolExecuteArgument<TParameters>,
  context?: RunContext<Context>,
) => Promise<unknown> | unknown;

/**
 * The function to invoke when an error occurs while running the tool. This can be used to define
 * what the model should receive as tool output in case of an error. It can be used to provide
 * for example additional context or a fallback value.
 *
 * @param context An instance of the current RunContext
 * @param error The error that occurred
 */
type ToolErrorFunction = (
  context: RunContext,
  error: Error | unknown,
) => Promise<string> | string;

/**
 * The default function to invoke when an error occurs while running the tool.
 *
 * Always returns `An error occurred while running the tool. Please try again. Error: <error details>`
 *
 * @param context An instance of the current RunContext
 * @param error The error that occurred
 */
function defaultToolErrorFunction(context: RunContext, error: Error | unknown) {
  const details = error instanceof Error ? error.toString() : String(error);
  return `An error occurred while running the tool. Please try again. Error: ${details}`;
}

/**
 * The options for a tool that has strict mode enabled.
 *
 * @param TParameters The parameters of the tool
 * @param Context The context of the tool
 */
type StrictToolOptions<
  TParameters extends ToolInputParametersStrict,
  Context = UnknownContext,
> = {
  /**
   * The name of the tool. Must be unique within the agent.
   */
  name?: string;

  /**
   * The description of the tool. This is used to help the model understand when to use the tool.
   */
  description: string;

  /**
   * A Zod schema or JSON schema describing the parameters of the tool.
   * If a Zod schema is provided, the arguments to the tool will automatically be parsed and validated
   * against the schema.
   */
  parameters: TParameters;

  /**
   * Whether the tool is strict. If true, the model must try to strictly follow the schema (might result in slower response times).
   */
  strict?: true;

  /**
   * The function to invoke when the tool is called.
   */
  execute: ToolExecuteFunction<TParameters, Context>;

  /**
   * The function to invoke when an error occurs while running the tool.
   */
  errorFunction?: ToolErrorFunction | null;

  /**
   * Whether the tool needs human approval before it can be called. If this is true, the run will result in an `interruption` that the
   * program has to resolve by approving or rejecting the tool call.
   */
  needsApproval?: boolean | ToolApprovalFunction<TParameters>;
};

/**
 * The options for a tool that has strict mode disabled.
 *
 * @param TParameters The parameters of the tool
 * @param Context The context of the tool
 */
type NonStrictToolOptions<
  TParameters extends ToolInputParametersNonStrict,
  Context = UnknownContext,
> = {
  /**
   * The name of the tool. Must be unique within the agent.
   */
  name?: string;

  /**
   * The description of the tool. This is used to help the model understand when to use the tool.
   */
  description: string;

  /**
   * A JSON schema of the tool. To use a Zod schema, you need to use a `strict` schema.
   */
  parameters: TParameters;

  /**
   * Whether the tool is strict  If true, the model must try to strictly follow the schema (might result in slower response times).
   */
  strict: false;

  /**
   * The function to invoke when the tool is called.
   */
  execute: ToolExecuteFunction<TParameters, Context>;

  /**
   * The function to invoke when an error occurs while running the tool.
   */
  errorFunction?: ToolErrorFunction | null;

  /**
   * Whether the tool needs human approval before it can be called. If this is true, the run will result in an `interruption` that the
   * program has to resolve by approving or rejecting the tool call.
   */
  needsApproval?: boolean | ToolApprovalFunction<TParameters>;
};

/**
 * The options for a tool.
 *
 * @param TParameters The parameters of the tool
 * @param Context The context of the tool
 */
export type ToolOptions<
  TParameters extends ToolInputParameters,
  Context = UnknownContext,
> =
  | StrictToolOptions<Extract<TParameters, ToolInputParametersStrict>, Context>
  | NonStrictToolOptions<
      Extract<TParameters, ToolInputParametersNonStrict>,
      Context
    >;

/**
 * Exposes a function to the agent as a tool to be called
 *
 * @param options The options for the tool
 * @returns A new tool
 */
export function tool<
  TParameters extends ToolInputParameters = undefined,
  Context = UnknownContext,
  Result = string,
>(
  options: ToolOptions<TParameters, Context>,
): FunctionTool<Context, TParameters, Result> {
  const name = options.name
    ? toFunctionToolName(options.name)
    : toFunctionToolName(options.execute.name);
  const toolErrorFunction: ToolErrorFunction | null =
    typeof options.errorFunction === 'undefined'
      ? defaultToolErrorFunction
      : options.errorFunction;

  if (!name) {
    throw new Error(
      'Tool name cannot be empty. Either name your function or provide a name in the options.',
    );
  }

  const strictMode = options.strict ?? true;
  if (!strictMode && isZodObject(options.parameters)) {
    throw new UserError('Strict mode is required for Zod parameters');
  }

  const { parser, schema: parameters } = getSchemaAndParserFromInputType(
    options.parameters,
    name,
  );

  async function _invoke(
    runContext: RunContext<Context>,
    input: string,
  ): Promise<Result> {
    const [error, parsed] = await safeExecute(() => parser(input));
    if (error !== null) {
      if (logger.dontLogToolData) {
        logger.debug(`Invalid JSON input for tool ${name}`);
      } else {
        logger.debug(`Invalid JSON input for tool ${name}: ${input}`);
      }
      throw new ModelBehaviorError('Invalid JSON input for tool');
    }

    if (logger.dontLogToolData) {
      logger.debug(`Invoking tool ${name}`);
    } else {
      logger.debug(`Invoking tool ${name} with input ${input}`);
    }

    const result = await options.execute(parsed, runContext);
    const stringResult = toSmartString(result);

    if (logger.dontLogToolData) {
      logger.debug(`Tool ${name} completed`);
    } else {
      logger.debug(`Tool ${name} returned: ${stringResult}`);
    }

    return result as Result;
  }

  async function invoke(
    runContext: RunContext<Context>,
    input: string,
  ): Promise<string | Result> {
    return _invoke(runContext, input).catch<string>((error) => {
      if (toolErrorFunction) {
        const currentSpan = getCurrentSpan();
        currentSpan?.setError({
          message: 'Error running tool (non-fatal)',
          data: {
            tool_name: name,
            error: error.toString(),
          },
        });
        return toolErrorFunction(runContext, error);
      }

      throw error;
    });
  }

  const needsApproval: ToolApprovalFunction<TParameters> =
    typeof options.needsApproval === 'function'
      ? options.needsApproval
      : async () =>
          typeof options.needsApproval === 'boolean'
            ? options.needsApproval
            : false;

  return {
    type: 'function',
    name,
    description: options.description,
    parameters,
    strict: strictMode,
    invoke,
    needsApproval,
  };
}

function buildRequireApproval(requireApproval: {
  never?: { toolNames: string[] };
  always?: { toolNames: string[] };
}): { never?: { tool_names: string[] }; always?: { tool_names: string[] } } {
  const result: {
    never?: { tool_names: string[] };
    always?: { tool_names: string[] };
  } = {};
  if (requireApproval.always) {
    result.always = { tool_names: requireApproval.always.toolNames };
  }
  if (requireApproval.never) {
    result.never = { tool_names: requireApproval.never.toolNames };
  }
  return result;
}

function toMcpAllowedToolsFilter(
  allowedTools: string[] | { toolNames?: string[] } | undefined,
): { tool_names: string[] } | undefined {
  if (typeof allowedTools === 'undefined') {
    return undefined;
  }
  if (Array.isArray(allowedTools)) {
    return { tool_names: allowedTools };
  }
  return { tool_names: allowedTools?.toolNames ?? [] };
}



---
File: /packages/agents-core/src/usage.ts
---

import { UsageData } from './types/protocol';

/**
 * Tracks token usage and request counts for an agent run.
 */
export class Usage {
  /**
   * The number of requests made to the LLM API.
   */
  public requests: number;

  /**
   * The number of input tokens used across all requests.
   */
  public inputTokens: number;

  /**
   * The number of output tokens used across all requests.
   */
  public outputTokens: number;

  /**
   * The total number of tokens sent and received, across all requests.
   */
  public totalTokens: number;

  /**
   * Details about the input tokens used across all requests.
   */
  public inputTokensDetails: Array<Record<string, number>> = [];

  /**
   * Details about the output tokens used across all requests.
   */
  public outputTokensDetails: Array<Record<string, number>> = [];

  constructor(input?: Partial<UsageData> & { requests?: number }) {
    if (typeof input === 'undefined') {
      this.requests = 0;
      this.inputTokens = 0;
      this.outputTokens = 0;
      this.totalTokens = 0;
      this.inputTokensDetails = [];
      this.outputTokensDetails = [];
    } else {
      this.requests = input?.requests ?? 1;
      this.inputTokens = input?.inputTokens ?? 0;
      this.outputTokens = input?.outputTokens ?? 0;
      this.totalTokens = input?.totalTokens ?? 0;
      this.inputTokensDetails = input?.inputTokensDetails
        ? [input.inputTokensDetails]
        : [];
      this.outputTokensDetails = input?.outputTokensDetails
        ? [input.outputTokensDetails]
        : [];
    }
  }

  add(newUsage: Usage) {
    this.requests += newUsage.requests;
    this.inputTokens += newUsage.inputTokens;
    this.outputTokens += newUsage.outputTokens;
    this.totalTokens += newUsage.totalTokens;
    if (newUsage.inputTokensDetails) {
      // The type does not allow undefined, but it could happen runtime
      this.inputTokensDetails.push(...newUsage.inputTokensDetails);
    }
    if (newUsage.outputTokensDetails) {
      // The type does not allow undefined, but it could happen runtime
      this.outputTokensDetails.push(...newUsage.outputTokensDetails);
    }
  }
}

export { UsageData };



---
File: /packages/agents-core/CHANGELOG.md
---

# @openai/agents-core

## 0.0.13

### Patch Changes

- bd463ef: Fix #219 MCPServer#invalidateToolsCache() not exposed while being mentioned in the documents

## 0.0.12

### Patch Changes

- af73bfb: Rebinds cached tools to the current MCP server to avoid stale tool invocation (fixes #195)
- 046f8cc: Fix typos across repo
- ed66acf: Fixes handling of `agent_updated_stream_event` in run implementation and adds corresponding test coverage.
- 40dc0be: Fix #216 Publicly accessible PDF file URL is not yet supported in the input_file content data

## 0.0.11

### Patch Changes

- a60eabe: Fix #131 Human in the Loop MCP approval fails
- a153963: Tentative fix for #187 : Lock zod version to <=3.25.67
- 17077d8: Fix #175 by removing internal system.exit calls

## 0.0.10

### Patch Changes

- c248a7d: Fix #138 by checking the unexpected absence of state.currentAgent.handoffs
- ff63127: Fix #129 The model in run config should be used over an agent's default setting
- 9c60282: Fix a bug where some of the exceptions thrown from runImplementation.ts could be unhandled
- f61fd18: Don't enable `cacheToolsList` per default for MCP servers
- c248a7d: Fix #138 by checking the unexpected absence of currentAgent.handoffs

## 0.0.9

### Patch Changes

- 9028df4: Adjust Usage object to accept empty data
- ce62f7c: Fix #117 by adding groupId, metadata to trace data

## 0.0.8

### Patch Changes

- 6e1d67d: Add OpenAI Response object on ResponseSpanData for other exporters.
- 52eb3f9: fix(interruptions): avoid double outputting function calls for approval requests
- 9e6db14: Adding support for prompt configuration to agents
- 0565bf1: Add details to output guardrail execution
- 52eb3f9: fix(interruptions): avoid accidental infinite loop if all interruptions were not cleared. expose interruptions helper on state

## 0.0.7

### Patch Changes

- 0580b9b: Add remote MCP server (Streamable HTTP) support
- 77c603a: Add allowed_tools and headers to hosted mcp server factory method
- 1fccdca: Publishes types that were marked as internal but caused build errors when not exported in typings.
- 2fae25c: Add hosted MCP server support

## 0.0.6

### Patch Changes

- 2c6cfb1: Pass through signal to model call
- 36a401e: Add force flush to global provider. Consistently default disable logging loop in Cloudflare Workers and Browser

## 0.0.5

### Patch Changes

- 544ed4b: Continue agent execution when function calls are pending

## 0.0.4

### Patch Changes

- 25165df: fix: Process hangs on SIGINT because `process.exit` is never called
- 6683db0: fix(shims): Naively polyfill AsyncLocalStorage in browser
- 78811c6: fix(shims): Bind crypto to randomUUID
- 426ad73: ensure getTransferMessage returns valid JSON

## 0.0.3

### Patch Changes

- d7fd8dc: Export CURRENT_SCHEMA_VERSION constant and use it when serializing run state.
- 284d0ab: Update internal module in agents-core to accept a custom logger

## 0.0.2

### Patch Changes

- a2979b6: fix: ensure process.on exists and is a function before adding event handlers

## 0.0.1

### Patch Changes

- aaa6d08: Initial release

## 0.0.1-next.0

### Patch Changes

- Initial release



---
File: /packages/agents-core/package.json
---

{
  "name": "@openai/agents-core",
  "repository": "https://github.com/openai/openai-agents-js",
  "homepage": "https://openai.github.io/openai-agents-js/",
  "version": "0.0.13",
  "description": "The OpenAI Agents SDK is a lightweight yet powerful framework for building multi-agent workflows.",
  "author": "OpenAI <support@openai.com>",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "prebuild": "tsx ../../scripts/embedMeta.ts",
    "build": "tsc",
    "build-check": "tsc --noEmit -p ./tsconfig.test.json"
  },
  "exports": {
    ".": {
      "require": {
        "types": "./dist/index.d.ts",
        "default": "./dist/index.js"
      },
      "types": "./dist/index.d.ts",
      "default": "./dist/index.mjs"
    },
    "./model": {
      "require": {
        "types": "./dist/model.d.ts",
        "default": "./dist/model.js"
      },
      "types": "./dist/model.d.ts",
      "default": "./dist/model.mjs"
    },
    "./utils": {
      "require": {
        "types": "./dist/utils/index.d.ts",
        "default": "./dist/utils/index.js"
      },
      "types": "./dist/utils/index.d.ts",
      "default": "./dist/utils/index.mjs"
    },
    "./extensions": {
      "require": {
        "types": "./dist/extensions/index.d.ts",
        "default": "./dist/extensions/index.js"
      },
      "types": "./dist/extensions/index.d.ts",
      "default": "./dist/extensions/index.mjs"
    },
    "./types": {
      "require": {
        "types": "./dist/types/index.d.ts",
        "default": "./dist/types/index.js"
      },
      "types": "./dist/types/index.d.ts",
      "default": "./dist/types/index.mjs"
    },
    "./_shims": {
      "workerd": {
        "require": "./dist/shims/shims-workerd.js",
        "types": "./dist/shims/shims-workerd.d.ts",
        "default": "./dist/shims/shims-workerd.mjs"
      },
      "browser": {
        "require": "./dist/shims/shims-browser.js",
        "types": "./dist/shims/shims-browser.d.ts",
        "default": "./dist/shims/shims-browser.mjs"
      },
      "node": {
        "require": "./dist/shims/shims-node.js",
        "types": "./dist/shims/shims-node.d.ts",
        "default": "./dist/shims/shims-node.mjs"
      },
      "require": {
        "types": "./dist/shims/shims-node.d.ts",
        "default": "./dist/shims/shims-node.js"
      },
      "types": "./dist/shims/shims-node.d.ts",
      "default": "./dist/shims/shims-node.mjs"
    }
  },
  "keywords": [
    "openai",
    "agents",
    "ai",
    "agentic"
  ],
  "license": "MIT",
  "optionalDependencies": {
    "@modelcontextprotocol/sdk": "^1.12.0"
  },
  "dependencies": {
    "@openai/zod": "npm:zod@3.25.40 - 3.25.67",
    "debug": "^4.4.0",
    "openai": "^5.10.1"
  },
  "peerDependencies": {
    "zod": "3.25.40 - 3.25.67"
  },
  "peerDependenciesMeta": {
    "zod": {
      "optional": true
    }
  },
  "typesVersions": {
    "*": {
      "model": [
        "dist/model.d.ts"
      ],
      "utils": [
        "dist/utils/index.d.ts"
      ],
      "extensions": [
        "dist/extensions/index.d.ts"
      ],
      "types": [
        "dist/types/index.d.ts"
      ],
      "_shims": [
        "dist/shims/shims-node.d.ts"
      ]
    }
  },
  "devDependencies": {
    "@types/debug": "^4.1.12",
    "zod": "3.25.40 - 3.25.67"
  },
  "files": [
    "dist"
  ]
}



---
File: /packages/agents-core/README.md
---

# OpenAI Agents SDK

The OpenAI Agents SDK is a lightweight yet powerful framework for building multi-agent workflows.

## Installation

```bash
npm install @openai/agents
```

## License

MIT



---
File: /packages/agents-core/tsconfig.json
---

{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "paths": {
      "@openai/agents-core": ["./src/index.ts"],
      "@openai/agents-core/_shims": ["./src/shims/shims-node.ts"]
    }
  },
  "exclude": ["dist/**", "test/**"]
}



---
File: /packages/agents-core/tsconfig.test.json
---

{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "paths": {
      "@openai/agents-core": ["./src/index.ts"],
      "@openai/agents-core/_shims": ["./src/shims/shims-node.ts"]
    }
  },
  "include": ["src/**/*.ts", "test/**/*.ts"],
  "exclude": ["dist/**"]
}

